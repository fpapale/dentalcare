package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record OdontogramPlanItemRequest(
        @NotNull Integer toothFdi,
        String condition,
        @NotNull UUID serviceId,
        String clinicalNotes
) {}
