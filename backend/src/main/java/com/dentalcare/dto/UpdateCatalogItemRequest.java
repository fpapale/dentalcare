package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateCatalogItemRequest(
        @NotBlank String label,
        String description,
        boolean isAlert,
        int sortOrder,
        boolean enabled
) {}
