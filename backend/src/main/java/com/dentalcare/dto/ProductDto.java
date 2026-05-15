package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

public record ProductDto(
        UUID productId,
        UUID categoryId,
        String categoryName,
        UUID supplierId,
        String supplierName,
        String name,
        String description,
        String sku,
        String unit,
        BigDecimal minStockQuantity,
        BigDecimal reorderQuantity,
        BigDecimal unitCost,
        BigDecimal currentStock,
        String stockStatus,
        boolean isActive
) {}
