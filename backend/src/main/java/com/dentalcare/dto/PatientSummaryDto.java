package com.dentalcare.dto;

import java.time.LocalDate;
import java.util.UUID;

public record PatientSummaryDto(
        UUID patientId,
        String firstName,
        String lastName,
        String fullName,
        String fiscalCode,
        LocalDate birthDate,
        Integer ageYears,
        String phone,
        String email,
        String city,
        String province,
        String addressLine1,
        String postalCode,
        String notes,
        Long totalAppointments,
        Long treatmentPlansCount,
        Long openTreatmentItemsCount,
        String photoUrl,
        UUID primaryProviderId,
        String primaryProviderName
) {}
