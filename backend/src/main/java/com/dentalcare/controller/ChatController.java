package com.dentalcare.controller;

import com.dentalcare.dto.ChatMessageDto;
import com.dentalcare.dto.ChatRequest;
import com.dentalcare.dto.ChatResponse;
import com.dentalcare.dto.ChatSessionDto;
import com.dentalcare.service.ChatHistoryService;
import com.dentalcare.service.ChatService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

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
