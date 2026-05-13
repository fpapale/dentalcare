package com.dentalcare.dto;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record TreatmentPlanDto(
        UUID planId,
        String name,
        String description,
        String status,
        UUID patientId,
        String patientFullName,
        UUID createdByProviderId,
        String createdByProviderName,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        List<TreatmentPlanItemDto> items
) {}
