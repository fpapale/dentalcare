package com.dentalcare.dto;

/**
 * Valore di un prompt per una singola lingua.
 *
 * @param locale       codice lingua (es. "it", "en")
 * @param value        valore effettivo mostrato (override tenant se presente, altrimenti globale)
 * @param globalValue  valore di default globale corrente (per confronto)
 * @param defaultValue testo predefinito di fabbrica (risorsa bundle), per il ripristino
 * @param overridden   true se lo studio ha un override per questa lingua
 */
public record AiPromptLocaleDto(
        String locale,
        String value,
        String globalValue,
        String defaultValue,
        boolean overridden
) {}
