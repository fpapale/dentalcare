package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.UUID;

public record CreateInvoiceFromEstimateRequest(
        @NotNull
        UUID estimateId,
        @NotNull
        String issuerType,
        UUID providerId,
        String documentType,
        LocalDate dueDate,
        String notes,
        String paymentMethod
) {}
