package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record EstimateDto(
        UUID estimateId,
        String estimateNumber,
        Integer version,
        String estimateStatus,
        String estimateTitle,
        String currency,
        BigDecimal subtotalAmount,
        BigDecimal discountAmount,
        BigDecimal taxableAmount,
        BigDecimal vatAmount,
        BigDecimal totalAmount,
        UUID patientId,
        String patientFullName,
        String patientFiscalCode,
        String patientPhone,
        OffsetDateTime issuedAt,
        OffsetDateTime sentAt,
        LocalDate validUntil,
        OffsetDateTime acceptedAt,
        OffsetDateTime rejectedAt,
        OffsetDateTime estimateCreatedAt
) {}
