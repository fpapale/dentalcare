package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UpdateAiPromptRequest(
        @NotBlank @Size(max = 20000) String value
) {}
