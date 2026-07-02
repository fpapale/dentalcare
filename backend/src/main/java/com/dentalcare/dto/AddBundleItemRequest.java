package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record AddBundleItemRequest(
        @NotNull UUID childServiceId,
        Integer sortOrder
) {}
