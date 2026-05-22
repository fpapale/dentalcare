package com.dentalcare.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record CreateTenantClinicRequest(
        @NotBlank String name,
        String legalName,
        String city,
        String province,
        String addressLine1,
        String postalCode,
        String phone,
        @Email String email
) {}
