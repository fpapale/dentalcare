package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.UUID;

public record CreateCatalogItemRequest(
        UUID categoryId,
        @NotBlank String code,
        @NotBlank String label,
        String description,
        @Pattern(regexp = "normale|grave|severa") String severity,
        int sortOrder
) {}
