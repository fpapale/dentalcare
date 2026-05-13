package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record TreatmentPlanItemDto(
        UUID itemId,
        UUID serviceId,
        String serviceName,
        String serviceCategory,
        Integer durationMinutes,
        UUID providerId,
        String providerName,
        String toothNumber,
        Integer quadrant,
        BigDecimal plannedPrice,
        String status,
        Integer priority,
        LocalDate plannedDate,
        String clinicalNotes,
        OffsetDateTime createdAt
) {}
