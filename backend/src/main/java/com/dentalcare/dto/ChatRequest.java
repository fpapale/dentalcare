package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

public record ChatRequest(
    @NotBlank String message,
    List<ChatTurnDto> history
) {}
