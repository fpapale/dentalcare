package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import java.util.UUID;

public record CreateClinicalHistoryEntryRequest(
        @NotNull UUID providerId,
        LocalDate entryDate,
        String toothNumber,
        String serviceCode,
        String serviceName,
        @NotBlank String clinicalNotes,
        String materialsUsed,
        String nextVisitNotes
) {}
