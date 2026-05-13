package com.dentalcare.dto;

import java.util.UUID;

public record ProviderDto(
        UUID providerId,
        String firstName,
        String lastName,
        String fullName,
        String role,
        String phone,
        String email,
        boolean active
) {}
