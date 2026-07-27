package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Riga di "Le mie tariffe" (#44): prezzo di listino studio + eventuale override del medico.
 * {@code effectivePrice} = override se presente, altrimenti {@code catalogPrice}.
 */
public record ProviderPriceDto(
        UUID serviceId,
        String serviceName,
        String category,
        BigDecimal catalogPrice,
        BigDecimal overridePrice,
        BigDecimal effectivePrice,
        String source
) {}
