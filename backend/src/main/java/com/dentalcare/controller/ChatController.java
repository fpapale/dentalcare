package com.dentalcare.controller;

import com.dentalcare.dto.ChatMessageDto;
import com.dentalcare.dto.ChatRequest;
import com.dentalcare.dto.ChatResponse;
import com.dentalcare.dto.ChatSessionDto;
import com.dentalcare.service.ChatHistoryService;
import com.dentalcare.service.ChatService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;
    private final ChatHistoryService chatHistoryService;

    public ChatController(ChatService chatService, ChatHistoryService chatHistoryService) {
        this.chatService = chatService;
        this.chatHistoryService = chatHistoryService;
    }

    @PostMapping
    public ChatResponse chat(@Valid @RequestBody ChatRequest request) {
        UUID sessionId = request.sessionId() != null
            ? request.sessionId()
            : chatHistoryService.createSession(request.message());

        chatHistoryService.appendMessage(sessionId, "user", request.message());
        ChatResponse aiResponse = chatService.chat(request);
        chatHistoryService.appendMessage(sessionId, "assistant", aiResponse.text());

        return new ChatResponse(aiResponse.text(), sessionId);
    }

    @PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> stream(@Valid @RequestBody ChatRequest request) {
        UUID sessionId = request.sessionId() != null
            ? request.sessionId()
            : chatHistoryService.createSession(request.message());

        chatHistoryService.appendMessage(sessionId, "user", request.message());

        StringBuilder acc = new StringBuilder();

        Flux<ServerSentEvent<String>> meta = Flux.just(
            ServerSentEvent.<String>builder().event("meta").data(sessionId.toString()).build());

        Flux<ServerSentEvent<String>> tokens = chatService.stream(request)
            .doOnNext(acc::append)
            .map(tok -> ServerSentEvent.<String>builder().event("token").data(tok).build());

        Flux<ServerSentEvent<String>> done = Flux.defer(() -> {
            chatHistoryService.appendMessage(sessionId, "assistant", acc.toString());
            return Flux.just(ServerSentEvent.<String>builder().event("done").data("").build());
        });

        // contextCapture: i ThreadLocal (tenant + security) presenti sul thread di richiesta
        // vengono propagati ai thread reactor che eseguono i tool e la persistenza finale.
        return Flux.concat(meta, tokens, done).contextCapture();
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
