package com.dentalcare.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class CopilotSuggestionServiceTest {

    @Test
    void publish_doesNotThrow_whenNoSubscriber() {
        CopilotSuggestionService service = new CopilotSuggestionService(new ObjectMapper());
        service.publish(UUID.randomUUID(), "recall_overdue", "3 richiami scaduti da contattare.");
        // nessun subscriber registrato: deve essere un no-op silenzioso
    }

    @Test
    void subscribe_returnsEmitter_andPublishSendsWithoutError() {
        CopilotSuggestionService service = new CopilotSuggestionService(new ObjectMapper());
        UUID clinicId = UUID.randomUUID();

        SseEmitter emitter = service.subscribe(clinicId);
        assertNotNull(emitter);

        service.publish(clinicId, "recall_overdue", "1 richiamo scaduto da contattare: Mario Rossi");
    }

    @Test
    void publish_afterEmitterCompleted_removesEmitterAndStaysSilent() {
        CopilotSuggestionService service = new CopilotSuggestionService(new ObjectMapper());
        UUID clinicId = UUID.randomUUID();

        SseEmitter emitter = service.subscribe(clinicId);
        emitter.complete();

        // Il completamento rimuove l'emitter dal registry: pubblicare di nuovo non deve lanciare.
        service.publish(clinicId, "recall_overdue", "richiamo scaduto");
    }
}
