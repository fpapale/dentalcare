package com.dentalcare.dto;
import java.time.OffsetDateTime;
import java.util.UUID;
public record ChatMessageDto(UUID id, String role, String content, OffsetDateTime createdAt) {}
