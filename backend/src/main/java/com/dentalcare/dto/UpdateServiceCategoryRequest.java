package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.List;

public record UpdateServiceCategoryRequest(
        @NotBlank
        String name,

        Integer sortOrder,

        boolean active,

        /** Ruoli abilitati. Null o lista vuota = nessun vincolo. */
        List<String> allowedRoles
) {}
