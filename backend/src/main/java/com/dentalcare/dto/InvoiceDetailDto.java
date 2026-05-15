package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record InvoiceDetailDto(
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
        BigDecimal subtotalAmount,
        BigDecimal discountAmount,
        BigDecimal taxableAmount,
        BigDecimal vatAmount,
        BigDecimal totalAmount,
        String currency,
        // issuer snapshot
        String issuerName,
        String issuerVatNumber,
        String issuerFiscalCode,
        String issuerAddress,
        String issuerEmail,
        String issuerPec,
        String issuerSdiCode,
        String issuerIban,
        // patient snapshot
        String patientFiscalCode,
        String patientAddress,
        String patientEmail,
        // other
        String notes,
        String paymentMethod,
        OffsetDateTime paidAt,
        OffsetDateTime issuedAt,
        OffsetDateTime createdAt,
        List<InvoiceLineDto> lines
) {}
