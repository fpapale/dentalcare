package com.dentalcare.service;

import com.dentalcare.dto.AiPromptDto;
import com.dentalcare.dto.AiPromptLocaleDto;
import com.dentalcare.security.TenantContext;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Gestione centralizzata dei prompt AI, multilingua e manutenibili senza redeploy.
 *
 * <p>Fonti, in ordine di precedenza (locale-first: la lingua giusta batte l'override):
 * <ol>
 *   <li>override di studio (schema del tenant) per (chiave, lingua richiesta)</li>
 *   <li>default globale (schema {@code dentalcare}) per (chiave, lingua richiesta)</li>
 *   <li>override di studio per (chiave, lingua base)</li>
 *   <li>default globale per (chiave, lingua base)</li>
 *   <li>risorsa bundle {@code ai-prompts/<chiave>.<lingua>.txt} (fallback anche senza DB)</li>
 * </ol>
 *
 * <p>Le chiavi sono definite qui dagli sviluppatori (non creabili da UI); l'admin di studio
 * può solo modificare i valori per lingua (override) o resettarli.
 */
@Service
public class PromptService {

    private static final Logger log = LoggerFactory.getLogger(PromptService.class);

    public static final String BASE_LOCALE = "it";
    public static final List<String> LOCALES = List.of("it", "en");

    /** Chiave prompt con descrizione leggibile per la UI admin. */
    public record PromptKey(String key, String description) {}

    private static final List<PromptKey> KEYS = List.of(
            new PromptKey("chat.system",
                    "Prompt di sistema dell'assistente SegretarIA (chat / copilot)")
    );

    private final NamedParameterJdbcTemplate jdbc;

    /** Cache dei valori risolti. Chiave: schema|clinic|promptKey|locale. Svuotata ad ogni scrittura. */
    private final Map<String, String> cache = new ConcurrentHashMap<>();
    /** Cache dei testi bundle (immutabili). Chiave: promptKey|locale. */
    private final Map<String, String> resourceCache = new ConcurrentHashMap<>();

    public PromptService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── Bootstrap: popola la tabella globale con i default bundle (senza sovrascrivere edit) ──
    @PostConstruct
    void seedGlobalDefaults() {
        try {
            jdbc.getJdbcTemplate().execute("""
                    CREATE TABLE IF NOT EXISTS dentalcare.ai_prompts (
                        prompt_key  text NOT NULL,
                        locale      text NOT NULL,
                        value       text NOT NULL,
                        description text,
                        updated_at  timestamptz NOT NULL DEFAULT now(),
                        PRIMARY KEY (prompt_key, locale)
                    )
                    """);
            for (PromptKey pk : KEYS) {
                for (String locale : LOCALES) {
                    String bundled = readResource(pk.key(), locale);
                    if (bundled == null) continue;
                    jdbc.update("""
                            INSERT INTO dentalcare.ai_prompts (prompt_key, locale, value, description)
                            VALUES (:k, :l, :v, :d)
                            ON CONFLICT (prompt_key, locale) DO NOTHING
                            """,
                            new MapSqlParameterSource()
                                    .addValue("k", pk.key())
                                    .addValue("l", locale)
                                    .addValue("v", bundled)
                                    .addValue("d", pk.description()));
                }
            }
            log.info("PromptService: default globali AI verificati/inseriti");
        } catch (DataAccessException e) {
            // Tabella non ancora presente (patch non applicata): il fallback su risorsa mantiene
            // la chat funzionante; il seeding riavverrà al prossimo avvio dopo la patch.
            log.warn("PromptService: seeding default globali saltato ({})", e.getMessage());
        }
    }

    // ── Risoluzione runtime ──────────────────────────────────────────────────────────────
    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }

    /** Ritorna il valore grezzo del prompt (con placeholder) o null se assente ovunque. */
    public String get(String key, String locale) {
        String loc = (locale == null || locale.isBlank()) ? BASE_LOCALE : locale;
        String schema = s();
        UUID clinic = clinicId();
        String cacheKey = schema + "|" + clinic + "|" + key + "|" + loc;
        String cached = cache.get(cacheKey);
        if (cached != null) return cached;

        String value = tenantOverride(schema, clinic, key, loc);
        if (value == null) value = global(key, loc);
        if (value == null && !loc.equals(BASE_LOCALE)) {
            value = tenantOverride(schema, clinic, key, BASE_LOCALE);
            if (value == null) value = global(key, BASE_LOCALE);
        }
        if (value == null) value = readResource(key, loc);
        if (value == null) value = readResource(key, BASE_LOCALE);

        if (value != null) cache.put(cacheKey, value);
        return value;
    }

    /** Ritorna il prompt con i placeholder {@code {{var}}} sostituiti dai valori indicati. */
    public String render(String key, String locale, Map<String, String> vars) {
        String value = get(key, locale);
        if (value == null) return null;
        if (vars != null) {
            for (Map.Entry<String, String> e : vars.entrySet()) {
                value = value.replace("{{" + e.getKey() + "}}", e.getValue());
            }
        }
        return value;
    }

    private String global(String key, String locale) {
        try {
            List<String> r = jdbc.queryForList(
                    "SELECT value FROM dentalcare.ai_prompts WHERE prompt_key = :k AND locale = :l",
                    new MapSqlParameterSource("k", key).addValue("l", locale), String.class);
            return r.isEmpty() ? null : r.get(0);
        } catch (DataAccessException e) {
            return null;
        }
    }

    private String tenantOverride(String schema, UUID clinic, String key, String locale) {
        try {
            List<String> r = jdbc.queryForList(
                    ("SELECT value FROM %s.ai_prompt_overrides "
                            + "WHERE clinic_id = :c AND prompt_key = :k AND locale = :l").formatted(schema),
                    new MapSqlParameterSource("c", clinic).addValue("k", key).addValue("l", locale),
                    String.class);
            return r.isEmpty() ? null : r.get(0);
        } catch (DataAccessException e) {
            // schema tenant non ancora dotato della tabella override: nessun override
            return null;
        }
    }

    private String readResource(String key, String locale) {
        String rk = key + "|" + locale;
        String cached = resourceCache.get(rk);
        if (cached != null) return cached;
        ClassPathResource res = new ClassPathResource("ai-prompts/" + key + "." + locale + ".txt");
        if (!res.exists()) return null;
        try (InputStream in = res.getInputStream()) {
            String text = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            resourceCache.put(rk, text);
            return text;
        } catch (IOException e) {
            log.warn("PromptService: lettura risorsa {} fallita: {}", res.getPath(), e.getMessage());
            return null;
        }
    }

    // ── API admin (override per-tenant, solo valori) ──────────────────────────────────────
    public List<AiPromptDto> listForAdmin() {
        String schema = s();
        UUID clinic = clinicId();
        List<AiPromptDto> out = new ArrayList<>();
        for (PromptKey pk : KEYS) {
            List<AiPromptLocaleDto> locales = new ArrayList<>();
            for (String locale : LOCALES) {
                String globalVal = firstNonNull(global(pk.key(), locale), readResource(pk.key(), locale));
                String override = tenantOverride(schema, clinic, pk.key(), locale);
                String effective = override != null ? override : globalVal;
                locales.add(new AiPromptLocaleDto(locale, effective, globalVal, override != null));
            }
            out.add(new AiPromptDto(pk.key(), pk.description(), locales));
        }
        return out;
    }

    public void upsertOverride(String key, String locale, String value) {
        requireValid(key, locale);
        jdbc.update(
                ("INSERT INTO %s.ai_prompt_overrides (clinic_id, prompt_key, locale, value) "
                        + "VALUES (:c, :k, :l, :v) "
                        + "ON CONFLICT (clinic_id, prompt_key, locale) "
                        + "DO UPDATE SET value = EXCLUDED.value, updated_at = now()").formatted(s()),
                new MapSqlParameterSource("c", clinicId()).addValue("k", key)
                        .addValue("l", locale).addValue("v", value));
        cache.clear();
    }

    public void deleteOverride(String key, String locale) {
        requireValid(key, locale);
        jdbc.update(
                ("DELETE FROM %s.ai_prompt_overrides "
                        + "WHERE clinic_id = :c AND prompt_key = :k AND locale = :l").formatted(s()),
                new MapSqlParameterSource("c", clinicId()).addValue("k", key).addValue("l", locale));
        cache.clear();
    }

    private void requireValid(String key, String locale) {
        boolean okKey = KEYS.stream().anyMatch(pk -> pk.key().equals(key));
        if (!okKey) throw new IllegalArgumentException("Chiave prompt sconosciuta: " + key);
        if (!LOCALES.contains(locale)) throw new IllegalArgumentException("Lingua non supportata: " + locale);
    }

    private static String firstNonNull(String a, String b) {
        return a != null ? a : b;
    }
}
