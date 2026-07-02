package com.dentalcare.service;

import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Map;
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
     * Rimuove e ritorna tutte le azioni in sospeso per lo scope indicato, più recenti prima.
     * Serve a confermare l'ultima anteprima quando il modello non riporta il codice tra i turni.
     */
    public java.util.List<Pending> consumeAllForScope(UUID scope) {
        purge();
        java.util.List<Map.Entry<String, Pending>> mine = store.entrySet().stream()
                .filter(e -> java.util.Objects.equals(e.getValue().providerScope(), scope))
                .sorted((a, b) -> b.getValue().expiresAt().compareTo(a.getValue().expiresAt()))
                .toList();
        java.util.List<Pending> out = new java.util.ArrayList<>();
        for (Map.Entry<String, Pending> e : mine) {
            if (store.remove(e.getKey()) != null) out.add(e.getValue());
        }
        return out;
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
