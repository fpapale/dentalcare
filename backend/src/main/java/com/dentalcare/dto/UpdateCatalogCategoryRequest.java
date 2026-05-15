package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateCatalogCategoryRequest(
        @NotBlank String name,
        String description,
        String icon,
        int sortOrder,
        boolean enabled
) {}
