package com.dentalcare.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

/** Imposta un override prezzo per (medico, prestazione) — crea una nuova versione (#44). */
public record SetProviderPriceRequest(
        @NotNull UUID serviceId,
        @NotNull BigDecimal price
) {}
