package com.dentalcare.dto;

import java.util.UUID;

public record CatalogItemDto(
        UUID id, UUID categoryId, String code, String label,
        String description, String severity, int sortOrder, boolean enabled
) {}
