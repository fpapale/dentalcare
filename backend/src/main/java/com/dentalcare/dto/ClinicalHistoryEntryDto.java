package com.dentalcare.dto;

import java.time.LocalDate;
import java.util.UUID;

public record ClinicalHistoryEntryDto(
        UUID entryId,
        LocalDate entryDate,
        String providerName,
        String toothNumber,
        String serviceName,
        String clinicalNotes,
        String nextVisitNotes
) {}
