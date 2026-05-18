package com.dentalcare.dto;

import java.util.UUID;

public record TenantProvisioningResult(
        UUID tenantId,
        UUID clinicId,
        String schemaName
) {}
