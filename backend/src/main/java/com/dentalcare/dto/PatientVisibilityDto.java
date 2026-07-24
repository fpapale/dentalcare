package com.dentalcare.dto;

/**
 * Modalità di visibilità dei pazienti per ruolo della sede (#42):
 * {@code per_provider} (default) | {@code shared}.
 */
public record PatientVisibilityDto(String mode) {
}
