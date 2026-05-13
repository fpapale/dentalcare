package com.dentalcare.dto;

import java.time.OffsetDateTime;

public record OdontogramSummaryDto(
        boolean exists,
        int totalTeeth,
        int healthyTeeth,
        int missingTeeth,
        int treatedTeeth,
        OffsetDateTime lastUpdatedAt
) {}
