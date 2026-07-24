package com.dentalcare.dto;

import java.util.UUID;

public record AnamnesisItemDto(
        UUID id,
        String code,
        String label,
        String description,
        String severity,
        int sortOrder,
        boolean selected,
        String selectionNotes
) {
}
