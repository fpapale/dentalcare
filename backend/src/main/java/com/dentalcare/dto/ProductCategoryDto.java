package com.dentalcare.dto;

import java.util.UUID;

public record ProductCategoryDto(
        UUID categoryId,
        String name
) {}
