package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Corpo di {@code DELETE /api/tenant-admin/tenant} (#47).
 * {@code deletionToken}: token monouso ottenuto da {@code /deletion/prepare}.
 * {@code confirmationName}: nome del tenant digitato dall'utente (deve coincidere esattamente).
 */
public record DeleteTenantRequest(
        @NotBlank String deletionToken,
        @NotBlank String confirmationName
) {
}
