package com.dentalcare.dto;

import java.util.List;

/**
 * Confronto tra le voci di anamnesi attive ora e quelle attive all'ultimo punto nel tempo
 * precedente in cui qualcosa e' cambiato (nuova selezione o risoluzione). Vedi
 * {@code AnamnesisService.getDiffSinceLastVisit}.
 */
public record AnamnesisDiffDto(
        List<AnamnesisDiffItem> newItems,
        List<AnamnesisDiffItem> resolvedItems,
        List<AnamnesisDiffItem> unchangedItems
) {
    public record AnamnesisDiffItem(String code, String label, String severity) {}
}
