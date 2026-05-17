package com.dentalcare.dto;

public record RegistrationRequest(
        String plan,
        String studioName,
        String telefono,
        String email,
        String indirizzo,
        String citta,
        String provincia,
        String partitaIva,
        String adminNome,
        String adminCognome,
        String adminEmail
) {}
