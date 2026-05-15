package com.dentalcare.dto;

import java.time.LocalDate;

public record UpdateInvoiceRequest(
        String documentType,
        LocalDate invoiceDate,
        LocalDate dueDate,
        String notes,
        String paymentMethod
) {}
