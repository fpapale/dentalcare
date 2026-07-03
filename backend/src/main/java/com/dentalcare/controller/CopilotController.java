package com.dentalcare.controller;

import com.dentalcare.security.TenantContext;
import com.dentalcare.service.CopilotSuggestionService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.UUID;

@RestController
@RequestMapping("/api/copilot")
public class CopilotController {

    private final CopilotSuggestionService suggestionService;

    public CopilotController(CopilotSuggestionService suggestionService) {
        this.suggestionService = suggestionService;
    }

    // EventSource non puo' inviare header — questo stream si autentica via ?token=<jwt>,
    // stesso meccanismo dello stream agenda (supportato da JwtAuthenticationFilter).
    @GetMapping(value = "/suggestions/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        return suggestionService.subscribe(clinicId);
    }
}
