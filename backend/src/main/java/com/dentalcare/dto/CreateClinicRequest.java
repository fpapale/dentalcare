package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateClinicRequest(
        @NotBlank String name,
        String legalName,
        String vatNumber,
        String fiscalCode,
        String phone,
        String email,
        String addressLine1,
        String city,
        String province,
        String postalCode
) {}
