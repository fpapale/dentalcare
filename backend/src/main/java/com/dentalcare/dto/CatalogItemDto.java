package com.dentalcare.dto;

import java.util.UUID;

public record CatalogItemDto(
        UUID id, UUID categoryId, String code, String label,
        String description, boolean isAlert, int sortOrder, boolean enabled
) {}
