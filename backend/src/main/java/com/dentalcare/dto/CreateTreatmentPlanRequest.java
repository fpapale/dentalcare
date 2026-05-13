package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record CreateTreatmentPlanRequest(
        @NotNull UUID patientId,
        @NotBlank String name,
        String description
) {}
