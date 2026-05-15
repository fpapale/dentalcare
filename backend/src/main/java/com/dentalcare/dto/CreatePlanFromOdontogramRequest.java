package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.UUID;

public record CreatePlanFromOdontogramRequest(
        @NotNull UUID patientId,
        @NotBlank String name,
        @NotEmpty List<OdontogramPlanItemRequest> items
) {}
