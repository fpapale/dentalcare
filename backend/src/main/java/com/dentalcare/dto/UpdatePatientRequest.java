package com.dentalcare.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.UUID;

public record UpdatePatientRequest(
        @NotBlank @Size(max = 100) String firstName,
        @NotBlank @Size(max = 100) String lastName,
        @Size(max = 16) String fiscalCode,
        LocalDate birthDate,
        @Size(max = 30) String phone,
        @Email @Size(max = 200) String email,
        @Size(max = 200) String addressLine1,
        @Size(max = 100) String city,
        @Size(max = 5) String province,
        @Size(max = 10) String postalCode,
        String notes,
        UUID primaryProviderId
) {}
