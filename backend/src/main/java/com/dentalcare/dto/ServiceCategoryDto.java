package com.dentalcare.dto;

import java.util.List;
import java.util.UUID;

public record ServiceCategoryDto(
        UUID id,
        String name,
        int sortOrder,
        boolean active,
        long usageCount,
        /** Ruoli abilitati a selezionare le prestazioni della categoria. Vuoto = tutti. */
        List<String> allowedRoles
) {}
