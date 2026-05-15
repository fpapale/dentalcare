package com.dentalcare.dto;

import java.util.UUID;

public record ClinicBillingDto(
        UUID id,
        String name,
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
