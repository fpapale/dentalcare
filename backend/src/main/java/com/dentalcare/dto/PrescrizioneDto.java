package com.dentalcare.dto;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record PrescrizioneDto(
        UUID id,
        String drugName,
        String dosage,
        String frequency,
        String duration,
        String notes,
        String providerName,
        LocalDate prescribedAt,
        LocalDate expiresAt,
        boolean active,
        OffsetDateTime createdAt
) {}
