package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;

public record AddInvoiceLineRequest(
        @NotBlank
        String description,
        String toothInfo,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal discountAmount,
        BigDecimal vatRate
) {}
