package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CreateStockMovementRequest(
        UUID productId,
        String movementType,
        BigDecimal quantity,
        BigDecimal unitCost,
        String notes,
        String referenceDoc,
        UUID createdByProviderId
) {}
