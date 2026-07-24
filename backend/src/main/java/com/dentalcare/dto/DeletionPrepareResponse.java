package com.dentalcare.dto;

/**
 * Risposta di {@code POST /api/tenant-admin/tenant/deletion/prepare} (#47).
 * Il token è monouso e a scadenza breve: la conferma della cancellazione lo richiede.
 * {@code archivePassword} è la password monouso dell'archivio scaricabile (Slice B):
 * mostrata una sola volta, serve ad aprire il file e non è recuperabile dopo.
 */
public record DeletionPrepareResponse(
        String deletionToken,
        String expiresAt,
        long exportSizeBytes,
        String archivePassword
) {
}
