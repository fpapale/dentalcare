package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record CreateConditionDefaultRequest(
        @NotBlank String conditionName,
        @NotNull UUID serviceId,
        Integer sortOrder
) {}
