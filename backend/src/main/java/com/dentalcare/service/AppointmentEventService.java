package com.dentalcare.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Registry in-memory di SseEmitter per l'aggiornamento in tempo reale dell'agenda.
 * Un client con l'agenda aperta si sottoscrive per il proprio clinicId; ad ogni scrittura
 * rilevante (create/reschedule/cancel/updateStatus) viene inviato un ping "changed" a tutti
 * gli emitter dello stesso clinicId, cosi' il client puo' ricaricare i dati con la propria auth.
 * Nessun dato applicativo viene incluso nel messaggio.
 */
@Component
public class AppointmentEventService {

    private static final Logger log = LoggerFactory.getLogger(AppointmentEventService.class);
    private static final long TIMEOUT_MS = 0L; // nessun timeout: la connessione resta aperta finche' il client non la chiude

    private final ConcurrentHashMap<UUID, Set<SseEmitter>> emittersByClinic = new ConcurrentHashMap<>();

    public SseEmitter subscribe(UUID clinicId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);
        Set<SseEmitter> emitters = emittersByClinic.computeIfAbsent(clinicId, id -> ConcurrentHashMap.newKeySet());
        emitters.add(emitter);

        emitter.onCompletion(() -> removeEmitter(clinicId, emitter));
        emitter.onTimeout(() -> removeEmitter(clinicId, emitter));
        emitter.onError(e -> removeEmitter(clinicId, emitter));

        return emitter;
    }

    public void publish(UUID clinicId, String message) {
        Set<SseEmitter> emitters = emittersByClinic.get(clinicId);
        if (emitters == null || emitters.isEmpty()) return;

        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event().name("agenda").data(message));
            } catch (IOException | IllegalStateException e) {
                log.debug("Rimozione emitter agenda non raggiungibile per clinic {}: {}", clinicId, e.getMessage());
                removeEmitter(clinicId, emitter);
            }
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
}
