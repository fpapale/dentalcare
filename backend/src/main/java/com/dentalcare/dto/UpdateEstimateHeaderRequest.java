package com.dentalcare.dto;

import java.time.LocalDate;

public record UpdateEstimateHeaderRequest(
        String title,
        String notes,
        LocalDate validUntil
) {}
