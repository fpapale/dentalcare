package com.dentalcare.dto;

/**
 * Risposta della conferma di cancellazione (#47): il tenant è in soft-delete,
 * il DROP reale avverrà a {@code scheduledDropAt}. Annullabile fino a quella data.
 */
public record DeletionScheduledResponse(
        String scheduledDropAt
) {
}
