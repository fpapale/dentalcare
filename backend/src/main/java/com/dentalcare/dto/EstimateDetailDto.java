package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record EstimateDetailDto(
        UUID estimateId,
        String estimateNumber,
        Integer version,
        String status,
        String title,
        String notes,
        String currency,
        BigDecimal subtotalAmount,
        BigDecimal discountAmount,
        BigDecimal taxableAmount,
        BigDecimal vatAmount,
        BigDecimal totalAmount,
        UUID patientId,
        String patientFullName,
        UUID treatmentPlanId,
        String treatmentPlanName,
        OffsetDateTime issuedAt,
        OffsetDateTime sentAt,
        LocalDate validUntil,
        OffsetDateTime acceptedAt,
        OffsetDateTime rejectedAt,
        OffsetDateTime createdAt,
        List<EstimateLineDto> lines
) {}
