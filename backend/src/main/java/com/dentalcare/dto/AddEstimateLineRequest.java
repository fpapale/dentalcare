package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;

public record AddEstimateLineRequest(
        @NotNull UUID serviceId,
        UUID treatmentPlanItemId,
        String descriptionOverride,
        String toothSnapshot,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal discountAmount,
        BigDecimal vatRate,
        Integer linePosition
) {}
