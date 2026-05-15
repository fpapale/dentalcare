package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public record StockMovementDto(
        UUID movementId,
        UUID productId,
        String productName,
        String movementType,
        BigDecimal quantity,
        BigDecimal unitCost,
        String notes,
        String referenceDoc,
        UUID createdByProviderId,
        OffsetDateTime createdAt
) {}
