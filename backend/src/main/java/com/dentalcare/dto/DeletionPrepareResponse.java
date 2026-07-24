package com.dentalcare.dto;

/**
 * Risposta di {@code POST /api/tenant-admin/tenant/deletion/prepare} (#47).
 * Il token è monouso e a scadenza breve: la conferma della cancellazione lo richiede.
 */
public record DeletionPrepareResponse(
        String deletionToken,
        String expiresAt,
        long exportSizeBytes
) {
}
