package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record EstimateLineDto(
        UUID lineId,
        int linePosition,
        UUID serviceId,
        String serviceName,
        UUID treatmentPlanItemId,
        String descriptionSnapshot,
        String toothSnapshot,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal discountAmount,
        BigDecimal vatRate,
        BigDecimal lineSubtotal,
        BigDecimal lineTaxable,
        BigDecimal lineVatAmount,
        BigDecimal lineTotal
) {}
