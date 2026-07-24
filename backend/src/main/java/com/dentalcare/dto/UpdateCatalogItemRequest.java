package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateCatalogItemRequest(
        @NotBlank String label,
        String description,
        @Pattern(regexp = "normale|grave|severa") String severity,
        int sortOrder,
        boolean enabled
) {}
