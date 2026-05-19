package com.dentalcare.dto;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record DiagnosiDto(
        UUID id,
        String toothNumber,
        String title,
        String description,
        String icdCode,
        String status,
        String providerName,
        LocalDate diagnosedAt,
        LocalDate resolvedAt,
        OffsetDateTime createdAt
) {}
