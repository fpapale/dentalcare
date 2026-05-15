package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateProviderProfileRequest(
        @NotBlank String firstName,
        @NotBlank String lastName,
        @NotBlank String role,
        String phone,
        String email,
        boolean active
) {}
