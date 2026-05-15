package com.dentalcare.dto;

import java.util.UUID;

public record PlanItemCoverageDto(
        UUID planItemId,
        UUID estimateId,
        String estimateNumber,
        String estimateTitle,
        String estimateStatus
) {}
