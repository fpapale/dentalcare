package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.UUID;

public record CreateCatalogItemRequest(
        UUID categoryId,
        @NotBlank String code,
        @NotBlank String label,
        String description,
        boolean isAlert,
        int sortOrder
) {}
