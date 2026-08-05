package com.dentalcare.service;

import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Comparator;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

/**
 * Gate di conferma server-side per le azioni di scrittura della chat AI.
 * L'anteprima registra l'azione con un codice corto (4 cifre) e una closure che esegue
 * l'azione vera e propria; la conferma invoca la closure memorizzata. Così il modello non
 * deve trasportare UUID lunghi tra i turni (fonte di errori) ed evitiamo di affidarci solo
 * al prompt per il gate di conferma. Il modello a closure è generico e permette a qualsiasi
 * tool di scrittura (agenda, preventivi, richiami, pazienti, piani di cura, clinico) di
 * registrare un'anteprima senza dover estendere questo servizio.
 */
@Service
public class PendingActionService {

    public record Pending(
            String actionType,
            UUID providerScope,
            String summary,
            Instant expiresAt,
            Supplier<String> action
    ) {}

    private static final long TTL_SECONDS = 600;

    private final Map<String, Pending> store = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();

    /**
     * Registra un'azione in sospeso e ritorna il codice di conferma a 4 cifre.
     *
     * @param actionType  etichetta libera dell'azione (es. "CREATE_APPOINTMENT", "CREATE_ESTIMATE"),
     *                    usata solo per audit/log
     * @param providerScope provider a cui è associata l'anteprima (per il controllo di scope alla conferma)
     * @param summary     descrizione leggibile mostrata all'utente e salvata nell'audit
     * @param action      closure che esegue realmente l'azione e ritorna il messaggio di esito
     */
    public String register(String actionType, UUID providerScope, String summary, Supplier<String> action) {
        purge();
        String code = nextCode();
        store.put(code, new Pending(actionType, providerScope, summary,
                Instant.now().plusSeconds(TTL_SECONDS), action));
        return code;
    }

    /** Rimuove e ritorna l'azione associata al codice, oppure null se assente/scaduta. */
    public Pending consume(String code) {
        purge();
        if (code == null) return null;
        return store.remove(code.trim());
    }

    /**
     * Rimuove e ritorna la SOLA anteprima più recente per lo scope indicato (#20).
     * Serve a confermare l'ultima anteprima quando il modello non riporta il codice tra i turni,
     * senza eseguire in blocco anche le altre in sospeso: ciascuna richiede una conferma esplicita.
     */
    public Optional<Pending> consumeLatestForScope(UUID scope) {
        purge();
        return store.entrySet().stream()
                .filter(e -> Objects.equals(e.getValue().providerScope(), scope))
                .max(Comparator.comparing(e -> e.getValue().expiresAt()))
                .filter(e -> store.remove(e.getKey()) != null)
                .map(Map.Entry::getValue);
    }

    /** Numero di anteprime ancora in sospeso per lo scope indicato (per avvisare l'utente). */
    public long countForScope(UUID scope) {
        purge();
        return store.values().stream()
                .filter(p -> Objects.equals(p.providerScope(), scope))
                .count();
    }

    private String nextCode() {
        String code;
        do { code = String.format("%04d", random.nextInt(10000)); }
        while (store.containsKey(code));
        return code;
    }

    private void purge() {
        Instant now = Instant.now();
        store.entrySet().removeIf(e -> e.getValue().expiresAt().isBefore(now));
    }
}
