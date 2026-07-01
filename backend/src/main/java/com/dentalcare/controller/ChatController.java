package com.dentalcare.controller;

import com.dentalcare.dto.ChatMessageDto;
import com.dentalcare.dto.ChatRequest;
import com.dentalcare.dto.ChatResponse;
import com.dentalcare.dto.ChatSessionDto;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.ChatHistoryService;
import com.dentalcare.service.ChatService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;
    private final ChatHistoryService chatHistoryService;
    private final ExecutorService streamExecutor = Executors.newFixedThreadPool(8);

    public ChatController(ChatService chatService, ChatHistoryService chatHistoryService) {
        this.chatService = chatService;
        this.chatHistoryService = chatHistoryService;
    }

    @PostMapping
    public ChatResponse chat(@Valid @RequestBody ChatRequest request) {
        UUID sessionId = chatHistoryService.resolveOwnedSession(request.sessionId(), request.message());

        chatHistoryService.appendMessage(sessionId, "user", request.message());
        ChatResponse aiResponse = chatService.chat(request);
        chatHistoryService.appendMessage(sessionId, "assistant", aiResponse.text());

        return new ChatResponse(aiResponse.text(), sessionId);
    }

    /**
     * Streaming via SseEmitter. La generazione (con tool) gira in modo bloccante su un worker
     * dove copiamo tenant + security context: niente thread-hop reattivi, quindi nessun problema
     * di isolamento o di "response already committed" col security filter. Il testo completo viene
     * inviato a blocchi per dare un rendering progressivo lato client.
     */
    @PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(@Valid @RequestBody ChatRequest request) {
        UUID sessionId = chatHistoryService.resolveOwnedSession(request.sessionId(), request.message());
        chatHistoryService.appendMessage(sessionId, "user", request.message());

        // Cattura il contesto del thread di richiesta per ripristinarlo sul worker.
        String schema = TenantContext.getCurrentSchema();
        String clinicId = TenantContext.getCurrentClinicId();
        SecurityContext security = SecurityContextHolder.getContext();

        SseEmitter emitter = new SseEmitter(120_000L);
        streamExecutor.execute(() -> {
            try {
                TenantContext.setCurrentSchema(schema);
                TenantContext.setCurrentClinicId(clinicId);
                SecurityContextHolder.setContext(security);

                emitter.send(SseEmitter.event().name("meta").data(sessionId.toString()));

                ChatResponse aiResponse = chatService.chat(request);
                String text = aiResponse.text() != null ? aiResponse.text() : "";
                chatHistoryService.appendMessage(sessionId, "assistant", text);

                for (int i = 0; i < text.length(); i += 24) {
                    emitter.send(SseEmitter.event().name("token")
                            .data(text.substring(i, Math.min(i + 24, text.length()))));
                }
                emitter.send(SseEmitter.event().name("done").data(""));
                emitter.complete();
            } catch (IOException io) {
                emitter.completeWithError(io);
            } catch (Exception e) {
                try {
                    emitter.send(SseEmitter.event().name("token")
                            .data("Si è verificato un errore. Riprova più tardi."));
                    emitter.send(SseEmitter.event().name("done").data(""));
                    emitter.complete();
                } catch (IOException ignored) {
                    emitter.completeWithError(e);
                }
            } finally {
                TenantContext.clear();
                SecurityContextHolder.clearContext();
            }
        });
        return emitter;
    }

    @GetMapping("/sessions")
    public List<ChatSessionDto> listSessions(
            @RequestParam(name = "retentionDays", defaultValue = "90") int retentionDays) {
        return chatHistoryService.listSessions(retentionDays);
    }

    @GetMapping("/sessions/{id}/messages")
    public List<ChatMessageDto> getSessionMessages(@PathVariable UUID id) {
        return chatHistoryService.getSessionMessages(id);
    }

    @DeleteMapping("/sessions/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteSession(@PathVariable UUID id) {
        chatHistoryService.deleteSession(id);
    }
}
