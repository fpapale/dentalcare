package com.dentalcare.dto;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;
public record ChatRequest(@NotBlank String message, List<ChatTurnDto> history, UUID sessionId) {}
