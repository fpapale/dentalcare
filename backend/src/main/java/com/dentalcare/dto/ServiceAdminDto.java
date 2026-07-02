package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record ServiceAdminDto(
        UUID serviceId,
        String code,
        String name,
        String category,
        String description,
        BigDecimal defaultPrice,
        BigDecimal defaultVatRate,
        Integer durationMinutes,
        Integer minToothDigit,
        Integer maxToothDigit,
        boolean applicableToDeciduous,
        boolean active
) {}
