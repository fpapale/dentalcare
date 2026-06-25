package com.dentalcare.service;

import com.dentalcare.dto.CreateAppointmentRequest;
import com.dentalcare.dto.RescheduleAppointmentRequest;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Gate di conferma server-side per le azioni di scrittura della chat AI.
 * L'anteprima registra l'azione con un codice corto (4 cifre); la conferma esegue
 * l'azione memorizzata. Così il modello non deve trasportare UUID lunghi tra i turni
 * (fonte di errori) ed evitiamo di affidarci solo al prompt per il gate di conferma.
 */
@Service
public class PendingActionService {

    public enum Type { CREATE, RESCHEDULE, CANCEL }

    public record Pending(
            Type type,
            UUID providerScope,
            CreateAppointmentRequest create,
            UUID appointmentId,
            RescheduleAppointmentRequest reschedule,
            String summary,
            Instant expiresAt
    ) {}

    private static final long TTL_SECONDS = 600;

    private final Map<String, Pending> store = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();

    public String register(Type type, UUID providerScope,
                           CreateAppointmentRequest create,
                           UUID appointmentId,
                           RescheduleAppointmentRequest reschedule,
                           String summary) {
        purge();
        String code = nextCode();
        store.put(code, new Pending(type, providerScope, create, appointmentId, reschedule,
                summary, Instant.now().plusSeconds(TTL_SECONDS)));
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
