package com.dentalcare.service;

import com.dentalcare.dto.DeletionPrepareResponse;
import com.dentalcare.dto.DeletionScheduledResponse;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Guardia di cancellazione del tenant con grace period (#47).
 *
 * <p>Flusso: {@code prepare} genera un export completo, lo salva cifrato a riposo su MinIO
 * (retention) e rilascia un token monouso a scadenza breve → {@code confirm} valida token +
 * nome digitato e mette il tenant in soft-delete ({@code active=false} +
 * {@code scheduled_drop_at=now()+N gg}) → {@code cancel} annulla nella finestra →
 * {@link TenantDeletionScheduler} esegue il {@code DROP SCHEMA} reale allo scadere.
 *
 * <p>La checkbox "hai salvato?" è deliberatamente evitata: la guardia si basa su fatti
 * verificabili dal server (export generato e trasmesso, token, nome esatto).
 */
@Service
public class TenantDeletionService {

    private static final Logger log = LoggerFactory.getLogger(TenantDeletionService.class);

    private final NamedParameterJdbcTemplate jdbc;
    private final MinioStorageService minio;
    private final TenantExportService exportService;
    private final TenantSchemaRegistry registry;

    @Value("${app.tenant.deletion-grace-days:30}")
    private int graceDays;

    @Value("${app.tenant.deletion-token-ttl-minutes:15}")
    private int tokenTtlMinutes;

    @Value("${app.demo.schema:t_9d754153}")
    private String demoSchema;

    /** Token monouso in memoria: token → dettagli. Persi al riavvio (TTL breve, accettabile). */
    private final Map<String, PendingDeletion> tokens = new ConcurrentHashMap<>();

    private record PendingDeletion(String schema, UUID tenantId, String objectKey, Instant expiresAt) {
    }

    public TenantDeletionService(NamedParameterJdbcTemplate jdbc, MinioStorageService minio,
                                 TenantExportService exportService, TenantSchemaRegistry registry) {
        this.jdbc = jdbc;
        this.minio = minio;
        this.exportService = exportService;
        this.registry = registry;
    }

    private String s() { return TenantContext.validatedSchema(); }

    /**
     * Genera l'export completo del tenant, lo salva cifrato su MinIO come copia di retention e
     * rilascia un token monouso richiesto dalla conferma. Auditato.
     */
    public DeletionPrepareResponse prepare() throws IOException {
        String schema = s();
        if (schema.equals(demoSchema)) {
            throw new IllegalStateException("Il tenant demo non può essere eliminato");
        }
        UUID tenantId = tenantIdFor(schema);

        byte[] exportBytes;
        try (ByteArrayOutputStream baos = new ByteArrayOutputStream()) {
            exportService.exportToStream(baos);
            exportBytes = baos.toByteArray();
        }

        String objectKey = "_deletion/export_" + Instant.now().toEpochMilli() + ".zip";
        minio.upload(objectKey, exportBytes, "application/zip");

        pruneExpired();
        String token = UUID.randomUUID().toString();
        Instant expiresAt = Instant.now().plus(tokenTtlMinutes, ChronoUnit.MINUTES);
        tokens.put(token, new PendingDeletion(schema, tenantId, objectKey, expiresAt));

        log.info("AUDIT tenant-deletion prepare: schema={} provider={} objectKey={} sizeBytes={}",
                schema, currentProvider(), objectKey, exportBytes.length);

        return new DeletionPrepareResponse(token, expiresAt.toString(), exportBytes.length);
    }

    /** Streamma al client la copia di export preparata (decifrata da MinIO), validando il token. */
    public void streamPreparedExport(String deletionToken, OutputStream out) throws IOException {
        PendingDeletion pending = validToken(deletionToken);
        byte[] bytes = minio.download(pending.objectKey());
        out.write(bytes);
        out.flush();
    }

    /**
     * Conferma la cancellazione: valida token + nome digitato, poi soft-delete
     * ({@code active=false} + {@code scheduled_drop_at}). Il DROP reale è differito.
     */
    @Transactional
    public DeletionScheduledResponse confirmDeleteTenant(String deletionToken, String confirmationName) {
        String schema = s();
        PendingDeletion pending = validToken(deletionToken);
        if (!pending.schema().equals(schema)) {
            throw new IllegalStateException("Token di cancellazione non valido per questo tenant");
        }
        if (schema.equals(demoSchema)) {
            throw new IllegalStateException("Il tenant demo non può essere eliminato");
        }

        String tenantName = jdbc.queryForObject(
                "SELECT name FROM dentalcare.tenants WHERE schema_name = :schema",
                new MapSqlParameterSource("schema", schema), String.class);
        if (tenantName == null || confirmationName == null
                || !tenantName.trim().equals(confirmationName.trim())) {
            throw new IllegalArgumentException("Il nome digitato non coincide con il nome del tenant");
        }

        Instant dropAt = Instant.now().plus(graceDays, ChronoUnit.DAYS);
        jdbc.update(
                "UPDATE dentalcare.tenants SET active = false, scheduled_drop_at = :dropAt, updated_at = now() "
                        + "WHERE schema_name = :schema",
                new MapSqlParameterSource("schema", schema).addValue("dropAt", java.sql.Timestamp.from(dropAt)));

        tokens.remove(deletionToken);
        log.info("AUDIT tenant-deletion confirm: schema={} provider={} scheduledDropAt={}",
                schema, currentProvider(), dropAt);

        return new DeletionScheduledResponse(dropAt.toString());
    }

    /** Annulla una cancellazione programmata, se ancora nella finestra di grazia. */
    @Transactional
    public void cancelDeleteTenant() {
        String schema = s();
        int updated = jdbc.update(
                "UPDATE dentalcare.tenants SET active = true, scheduled_drop_at = NULL, updated_at = now() "
                        + "WHERE schema_name = :schema AND scheduled_drop_at IS NOT NULL AND scheduled_drop_at > now()",
                new MapSqlParameterSource("schema", schema));
        if (updated == 0) {
            throw new IllegalStateException("Nessuna cancellazione annullabile per questo tenant");
        }
        log.info("AUDIT tenant-deletion cancel: schema={} provider={}", schema, currentProvider());
    }

    /**
     * Esegue il DROP reale dei tenant la cui finestra di grazia è scaduta. Invocato dallo scheduler.
     * Fuori dal contesto di richiesta: schema e bucket passati esplicitamente. Best-effort per tenant.
     */
    public void dropExpiredTenants() {
        List<Map<String, Object>> due = jdbc.queryForList(
                "SELECT id, schema_name FROM dentalcare.tenants "
                        + "WHERE scheduled_drop_at IS NOT NULL AND scheduled_drop_at <= now()",
                new MapSqlParameterSource());
        for (Map<String, Object> row : due) {
            String schema = String.valueOf(row.get("schema_name"));
            UUID tenantId = (UUID) row.get("id");
            try {
                dropTenantHard(schema, tenantId);
                log.info("AUDIT tenant-deletion hard-drop: schema={} tenantId={}", schema, tenantId);
            } catch (Exception e) {
                log.error("tenant-deletion hard-drop failed schema={} tenantId={}: {}", schema, tenantId, e.getMessage(), e);
            }
        }
    }

    private void dropTenantHard(String schema, UUID tenantId) {
        if (!schema.matches("^t_[0-9a-f]{8}$")) {
            throw new IllegalStateException("Invalid schema: " + schema);
        }
        if (schema.equals(demoSchema)) {
            throw new IllegalStateException("Refuse to drop demo schema");
        }
        String bucket = minio.bucketFor(schema);
        jdbc.getJdbcTemplate().execute("DROP SCHEMA IF EXISTS " + schema + " CASCADE");
        jdbc.update("DELETE FROM dentalcare.tenant_clinics WHERE tenant_id = :tenantId",
                new MapSqlParameterSource("tenantId", tenantId));
        jdbc.update("DELETE FROM dentalcare.tenants WHERE id = :tenantId",
                new MapSqlParameterSource("tenantId", tenantId));
        registry.unregisterSchema(schema);
        try {
            minio.purgeBucket(bucket);
        } catch (Exception e) {
            log.error("purgeBucket failed for bucket={} — storage leak, manual cleanup required", bucket, e);
        }
    }

    private PendingDeletion validToken(String deletionToken) {
        pruneExpired();
        PendingDeletion pending = deletionToken == null ? null : tokens.get(deletionToken);
        if (pending == null || pending.expiresAt().isBefore(Instant.now())) {
            throw new IllegalStateException("Token di cancellazione assente o scaduto: eseguire di nuovo l'export");
        }
        return pending;
    }

    private void pruneExpired() {
        Instant now = Instant.now();
        tokens.values().removeIf(p -> p.expiresAt().isBefore(now));
    }

    private UUID tenantIdFor(String schema) {
        return jdbc.queryForObject(
                "SELECT id FROM dentalcare.tenants WHERE schema_name = :schema",
                new MapSqlParameterSource("schema", schema), UUID.class);
    }

    private String currentProvider() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null ? auth.getName() : "unknown";
    }
}
