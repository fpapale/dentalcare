package com.dentalcare.dto;

import java.util.UUID;

public record ServiceCategoryDto(
        UUID id,
        String name,
        int sortOrder,
        boolean active,
        long usageCount
) {}
