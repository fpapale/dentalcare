package com.dentalcare.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public record PatientDocumentSummaryDto(
        UUID id,
        String documentType,
        String title,
        String fileName,
        String mimeType,
        Long fileSizeBytes,
        String notes,
        LocalDate takenAt,
        LocalDateTime createdAt
) {}
