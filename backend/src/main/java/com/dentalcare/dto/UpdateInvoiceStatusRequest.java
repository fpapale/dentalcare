package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateInvoiceStatusRequest(
        @NotBlank
        String status
) {}
