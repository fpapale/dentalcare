package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record CreateProductRequest(
        UUID categoryId,
        UUID supplierId,
        String name,
        String description,
        String sku,
        String unit,
        BigDecimal minStockQuantity,
        BigDecimal reorderQuantity,
        BigDecimal unitCost
) {}
