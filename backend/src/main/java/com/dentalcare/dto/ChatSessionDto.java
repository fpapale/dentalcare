package com.dentalcare.dto;
import java.time.OffsetDateTime;
import java.util.UUID;
public record ChatSessionDto(UUID id, String title, int messageCount, OffsetDateTime createdAt) {}
