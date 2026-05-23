package com.dentalcare.dto;

public record ClinicOption(
        String providerId,
        String clinicId,
        String clinicName,
        String role,
        boolean isTenantAdmin,
        String schemaName,
        String tenantName
) {}
