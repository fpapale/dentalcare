package com.dentalcare.service.ai;

import org.springframework.stereotype.Component;
import java.util.UUID;

@Component
public class SseEmitterRegistry {
    public void emit(UUID analysisId, String status) { /* implemented in Task 8 */ }
}
