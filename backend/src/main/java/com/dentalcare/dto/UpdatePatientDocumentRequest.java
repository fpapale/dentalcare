package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;

public record UpdatePatientDocumentRequest(
        @NotBlank String title,
        String documentType,
        String notes,
        LocalDate takenAt
) {}
