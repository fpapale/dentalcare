package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import java.util.UUID;

public record CreatePrescrizioneRequest(
        @NotNull UUID providerId,
        @NotBlank String drugName,
        String dosage,
        String frequency,
        String duration,
        String notes,
        LocalDate prescribedAt,
        LocalDate expiresAt
) {}
