package com.dentalcare.dto;

import java.util.List;

/**
 * Un prompt AI con le sue lingue. La chiave è definita dagli sviluppatori (non creabile da UI);
 * l'admin di studio può solo modificare i valori per lingua (override) o resettarli.
 */
public record AiPromptDto(
        String key,
        String description,
        List<AiPromptLocaleDto> locales
) {}
