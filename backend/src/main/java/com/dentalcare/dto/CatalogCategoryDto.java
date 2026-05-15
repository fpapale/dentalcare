package com.dentalcare.dto;

import java.util.UUID;

public record CatalogCategoryDto(
        UUID id, String code, String name, String description,
        String icon, int sortOrder, boolean enabled, long itemsCount
) {}
