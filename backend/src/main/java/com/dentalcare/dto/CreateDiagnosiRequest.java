package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import java.util.UUID;

public record CreateDiagnosiRequest(
        @NotNull UUID providerId,
        String toothNumber,
        @NotBlank String title,
        String description,
        String icdCode,
        LocalDate diagnosedAt
) {}
