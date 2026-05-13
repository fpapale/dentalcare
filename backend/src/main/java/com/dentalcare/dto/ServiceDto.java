package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record ServiceDto(
        UUID serviceId,
        String code,
        String name,
        String category,
        BigDecimal defaultPrice,
        Integer durationMinutes
) {}
