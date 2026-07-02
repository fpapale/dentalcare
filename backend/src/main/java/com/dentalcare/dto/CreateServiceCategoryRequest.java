package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateServiceCategoryRequest(
        @NotBlank
        String name,

        Integer sortOrder
) {}
