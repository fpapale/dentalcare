package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;

public record UpdateClinicalHistoryEntryRequest(
        LocalDate entryDate,
        String toothNumber,
        String serviceCode,
        String serviceName,
        @NotBlank String clinicalNotes,
        String materialsUsed,
        String nextVisitNotes
) {}
