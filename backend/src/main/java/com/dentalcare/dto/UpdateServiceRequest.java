package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;

public record UpdateServiceRequest(
        @NotBlank String name,
        String category,
        String description,
        @NotNull @PositiveOrZero BigDecimal defaultPrice,
        BigDecimal defaultVatRate,
        Integer durationMinutes,
        Integer minToothDigit,
        Integer maxToothDigit,
        Boolean applicableToDeciduous,
        boolean active
) {}
