package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record InvoiceLineDto(
        UUID id,
        int linePosition,
        String description,
        String toothInfo,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal discountAmount,
        BigDecimal vatRate,
        BigDecimal lineSubtotal,
        BigDecimal lineTaxable,
        BigDecimal lineVatAmount,
        BigDecimal lineTotal
) {}
