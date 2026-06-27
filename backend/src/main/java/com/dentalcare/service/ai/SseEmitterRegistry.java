package com.dentalcare.service.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class SseEmitterRegistry {

    private static final Logger log = LoggerFactory.getLogger(SseEmitterRegistry.class);
    private static final long TIMEOUT_MS = 120_000L;

    private final ConcurrentHashMap<UUID, SseEmitter> emitters = new ConcurrentHashMap<>();

    public SseEmitter create(UUID analysisId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);
        emitter.onCompletion(() -> emitters.remove(analysisId, emitter));
        emitter.onTimeout(() -> emitters.remove(analysisId, emitter));
        emitter.onError(e -> emitters.remove(analysisId, emitter));
        emitters.put(analysisId, emitter);
        return emitter;
    }

    public void emit(UUID analysisId, String status) {
        SseEmitter emitter = emitters.get(analysisId);
        if (emitter == null) return;
        try {
            emitter.send(SseEmitter.event().name("analysis-status").data(status));
            emitter.complete();
        } catch (IOException e) {
            log.debug("SSE emit failed for {}: {}", analysisId, e.getMessage());
            emitters.remove(analysisId, emitter);
        }
    }
}
