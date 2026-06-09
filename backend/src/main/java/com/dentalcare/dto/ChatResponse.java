package com.dentalcare.dto;
import java.util.UUID;
public record ChatResponse(String text, UUID sessionId) {}
