package com.dentalcare.dto;

/**
 * Modalità di fatturazione della sede (#44): {@code studio} (default, intestata allo
 * studio) | {@code provider} (parcella intestata al medico del preventivo).
 */
public record BillingModeDto(String mode) {
}
