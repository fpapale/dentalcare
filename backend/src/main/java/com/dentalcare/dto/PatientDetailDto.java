package com.dentalcare.dto;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record PatientDetailDto(
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
        // Anamnesi
        String bloodType,
        Boolean smoker,
        Boolean hypertension,
        Boolean diabetes,
        Boolean heartDisease,
        Boolean takingAnticoagulants,
        Boolean takingBisphosphonates,
        Boolean allergyPenicillin,
        Boolean allergyLatex,
        Boolean allergyAnesthetic,
        String otherAllergies,
        String anamnesisNotes,
        OffsetDateTime anamnesisDate,
        // Stats
        Long totalAppointments,
        Long treatmentPlansCount,
        Long openTreatmentItemsCount,
        String photoUrl,
        // Medico di riferimento
        UUID primaryProviderId,
        String primaryProviderName
) {}
