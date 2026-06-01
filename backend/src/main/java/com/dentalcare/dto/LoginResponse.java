package com.dentalcare.dto;

public record LoginResponse(
        String token,
        String email,
        String providerId,
        String clinicId,
        String role,
        String firstName,
        String lastName,
        String schemaName,
        String tenantName,
        boolean mustChangePassword
) {}
