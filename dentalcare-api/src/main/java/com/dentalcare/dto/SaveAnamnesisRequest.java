package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;

import java.util.List;
import java.util.UUID;

public record SaveAnamnesisRequest(
        @NotNull
        List<ItemSelection> selections,
        String bloodType,
        String generalNotes
) {
    public record ItemSelection(
            @NotNull UUID itemId,
            String notes
    ) {
    }
}
