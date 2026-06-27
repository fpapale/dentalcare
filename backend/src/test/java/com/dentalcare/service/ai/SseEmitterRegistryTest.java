package com.dentalcare.service.ai;

import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class SseEmitterRegistryTest {

    @Test
    void emit_doesNotThrow_whenNoSubscriber() {
        SseEmitterRegistry reg = new SseEmitterRegistry();
        reg.emit(UUID.randomUUID(), "COMPLETED");  // must be a silent no-op
    }

    @Test
    void create_returnsEmitter_andEmitSendsWithoutError() {
        SseEmitterRegistry reg = new SseEmitterRegistry();
        UUID id = UUID.randomUUID();
        SseEmitter emitter = reg.create(id);
        assertNotNull(emitter);
        reg.emit(id, "COMPLETED");  // should complete the emitter without throwing
    }
}
