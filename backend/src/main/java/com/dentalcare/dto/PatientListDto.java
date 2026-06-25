package com.dentalcare.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record PatientListDto(
        UUID patientId,
        String patientFullName,
        String firstName,
        String lastName,
        String fiscalCode,
        LocalDate birthDate,
        Integer ageYears,
        String phone,
        String email,
        String city,
        String province,
        Long treatmentPlansCount,
        Long openTreatmentItemsCount,
        Long totalAppointments,
        BigDecimal acceptedEstimatesAmount,
        String photoUrl,
        boolean active
) {}
