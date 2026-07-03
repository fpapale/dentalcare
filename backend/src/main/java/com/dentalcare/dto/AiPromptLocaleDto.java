package com.dentalcare.dto;

/**
 * Valore di un prompt per una singola lingua.
 *
 * @param locale      codice lingua (es. "it", "en")
 * @param value       valore effettivo mostrato (override tenant se presente, altrimenti globale)
 * @param globalValue valore di default globale (per confronto e reset)
 * @param overridden  true se lo studio ha un override per questa lingua
 */
public record AiPromptLocaleDto(
        String locale,
        String value,
        String globalValue,
        boolean overridden
) {}
