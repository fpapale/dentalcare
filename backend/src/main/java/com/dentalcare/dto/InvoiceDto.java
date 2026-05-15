package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record InvoiceDto(
        UUID id,
        String invoiceNumber,
        String documentType,
        LocalDate invoiceDate,
        LocalDate dueDate,
        String status,
        String issuerType,
        String providerFullName,
        String patientFullName,
        UUID estimateId,
        String estimateNumber,
        BigDecimal totalAmount,
        String currency,
        OffsetDateTime createdAt
) {}
