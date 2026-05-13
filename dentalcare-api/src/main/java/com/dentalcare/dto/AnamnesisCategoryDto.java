package com.dentalcare.dto;

import java.util.List;
import java.util.UUID;

public record AnamnesisCategoryDto(
        UUID id,
        String code,
        String name,
        String description,
        String icon,
        int sortOrder,
        List<AnamnesisItemDto> items,
        boolean hasSelections
) {
}
