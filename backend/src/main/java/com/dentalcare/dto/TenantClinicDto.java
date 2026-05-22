package com.dentalcare.dto;

import java.util.UUID;

public record TenantClinicDto(
        UUID id,
        String name,
        String legalName,
        String city,
        String province,
        String addressLine1,
        String postalCode,
        String phone,
        String email,
        boolean active
) {}
