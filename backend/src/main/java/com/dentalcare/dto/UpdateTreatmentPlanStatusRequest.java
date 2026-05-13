package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

public record UpdateTreatmentPlanStatusRequest(
        @NotBlank String status
) {}
