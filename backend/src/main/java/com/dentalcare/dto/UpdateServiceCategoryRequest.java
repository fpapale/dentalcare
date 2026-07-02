package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateServiceCategoryRequest(
        @NotBlank
        String name,

        Integer sortOrder,

        boolean active
) {}
