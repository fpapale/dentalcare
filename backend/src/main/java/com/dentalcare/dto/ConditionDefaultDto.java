package com.dentalcare.dto;

import java.util.UUID;

public record ConditionDefaultDto(
        UUID id,
        String conditionName,
        UUID serviceId,
        String serviceName,
        int sortOrder
) {}
