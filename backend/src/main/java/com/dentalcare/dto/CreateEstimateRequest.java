package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import java.util.UUID;

public record CreateEstimateRequest(
        @NotNull UUID patientId,
        UUID treatmentPlanId,
        UUID createdByProviderId,
        String title,
        String notes,
        LocalDate validUntil
) {}
