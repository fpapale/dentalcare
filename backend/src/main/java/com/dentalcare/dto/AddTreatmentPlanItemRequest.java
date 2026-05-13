package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record AddTreatmentPlanItemRequest(
        @NotNull UUID serviceId,
        UUID providerId,
        String toothNumber,
        Integer quadrant,
        BigDecimal plannedPrice,
        Integer priority,
        LocalDate plannedDate,
        String clinicalNotes
) {}
