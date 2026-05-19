package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import java.time.LocalDate;

public record UpdateDiagnosiRequest(
        @NotBlank String title,
        String description,
        String icdCode,
        String status,
        LocalDate resolvedAt
) {}
