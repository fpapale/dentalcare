package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateEstimateStatusRequest(
        @NotBlank String status
) {}
