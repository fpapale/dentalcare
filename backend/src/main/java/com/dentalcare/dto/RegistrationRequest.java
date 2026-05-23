package com.dentalcare.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record RegistrationRequest(
        String plan,
        @NotBlank String studioName,
        String telefono,
        @NotBlank @Email String email,
        String indirizzo,
        String citta,
        String provincia,
        String partitaIva,
        @NotBlank String adminNome,
        @NotBlank String adminCognome,
        @NotBlank @Email String adminEmail,
        @NotBlank String adminPassword
) {}
