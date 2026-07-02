package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;

public record UpdatePrescrizioneRequest(
        @NotBlank String drugName,
        String dosage,
        String frequency,
        String duration,
        String notes,
        LocalDate prescribedAt,
        LocalDate expiresAt,
        boolean active
) {}
