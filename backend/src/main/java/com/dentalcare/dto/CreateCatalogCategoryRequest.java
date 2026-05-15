package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateCatalogCategoryRequest(
        @NotBlank String code,
        @NotBlank String name,
        String description,
        String icon,
        int sortOrder
) {}
