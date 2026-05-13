package com.dentalcare.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record TreatmentPlanSummaryDto(
        UUID planId,
        String name,
        String status,
        int totalItems,
        int completedItems,
        int openItems,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}
