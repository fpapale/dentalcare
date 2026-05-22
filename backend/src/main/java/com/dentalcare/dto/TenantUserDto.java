package com.dentalcare.dto;

import java.util.UUID;

public record TenantUserDto(
        UUID id,
        UUID clinicId,
        String firstName,
        String lastName,
        String email,
        String role,
        boolean active
) {}
