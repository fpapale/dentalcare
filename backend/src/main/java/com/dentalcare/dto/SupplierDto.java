package com.dentalcare.dto;

import java.util.UUID;

public record SupplierDto(
        UUID supplierId,
        String name,
        String contactPerson,
        String phone,
        String email,
        String notes,
        boolean isActive
) {}
