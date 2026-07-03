package com.dentalcare.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Registry in-memory di SseEmitter per i suggerimenti proattivi del Copilot (#14.B).
 * Copia strutturale di {@link AppointmentEventService}: un client con la chat Copilot aperta
 * si sottoscrive per il proprio clinicId; i job che rilevano condizioni degne di attenzione
 * (richiami scaduti, preventivi fermi, ecc.) pubblicano un suggerimento a tutti gli emitter
 * dello stesso clinicId.
 * Il messaggio PROPONE un'azione all'utente: non esegue alcuna scrittura e non sostituisce
 * la conferma esplicita richiesta dai tool applicativi.
 */
@Component
public class CopilotSuggestionService {

    private static final Logger log = LoggerFactory.getLogger(CopilotSuggestionService.class);
    private static final long TIMEOUT_MS = 0L; // nessun timeout: la connessione resta aperta finche' il client non la chiude

    private final ObjectMapper objectMapper;
    private final ConcurrentHashMap<UUID, Set<SseEmitter>> emittersByClinic = new ConcurrentHashMap<>();

    public CopilotSuggestionService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public SseEmitter subscribe(UUID clinicId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);
        Set<SseEmitter> emitters = emittersByClinic.computeIfAbsent(clinicId, id -> ConcurrentHashMap.newKeySet());
        emitters.add(emitter);

        emitter.onCompletion(() -> removeEmitter(clinicId, emitter));
        emitter.onTimeout(() -> removeEmitter(clinicId, emitter));
        emitter.onError(e -> removeEmitter(clinicId, emitter));

        return emitter;
    }

    /**
     * Pubblica un suggerimento proponente (tipo + messaggio leggibile) a tutti i client
     * sottoscritti della clinica. Nessuna azione viene eseguita: e' solo un ping informativo
     * che il client puo' mostrare e su cui l'utente puo' scegliere di agire in chat.
     */
    public void publish(UUID clinicId, String type, String message) {
        Set<SseEmitter> emitters = emittersByClinic.get(clinicId);
        if (emitters == null || emitters.isEmpty()) return;

        String payload = toJson(type, message);

        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event().name("suggestion").data(payload));
            } catch (IOException | IllegalStateException e) {
                log.debug("Rimozione emitter suggerimenti non raggiungibile per clinic {}: {}", clinicId, e.getMessage());
                removeEmitter(clinicId, emitter);
            }
        }
    }

    private String toJson(String type, String message) {
        try {
            return objectMapper.writeValueAsString(
                    new SuggestionPayload(type, message, OffsetDateTime.now().toString()));
        } catch (Exception e) {
            log.warn("Impossibile serializzare il suggerimento Copilot: {}", e.getMessage());
            return "{}";
        }
    }

    private void removeEmitter(UUID clinicId, SseEmitter emitter) {
        Set<SseEmitter> emitters = emittersByClinic.get(clinicId);
        if (emitters == null) return;
        emitters.remove(emitter);
        if (emitters.isEmpty()) {
            emittersByClinic.remove(clinicId, emitters);
        }
    }

    private record SuggestionPayload(String type, String message, String createdAt) {}
}
