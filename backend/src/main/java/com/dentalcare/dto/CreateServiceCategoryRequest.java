package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.List;

public record CreateServiceCategoryRequest(
        @NotBlank
        String name,

        Integer sortOrder,

        /** Ruoli abilitati. Null o lista vuota = nessun vincolo. */
        List<String> allowedRoles
) {}
