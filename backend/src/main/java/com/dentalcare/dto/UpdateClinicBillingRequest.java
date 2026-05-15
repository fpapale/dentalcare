package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateClinicBillingRequest(
        @NotBlank
        String legalName,
        String vatNumber,
        String fiscalCode,
        String phone,
        String email,
        String addressLine1,
        String addressLine2,
        String city,
        String province,
        String postalCode,
        String country
) {}
