package com.dentalcare.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AppointmentDto(
        UUID appointmentId,
        OffsetDateTime startsAt,
        OffsetDateTime endsAt,
        String chairLabel,
        String appointmentStatus,
        String notes,
        UUID patientId,
        String patientFullName,
        String patientPhone,
        UUID providerId,
        String providerName,
        String providerRole,
        String serviceName,
        String serviceCategory,
        String toothNumber,
        Boolean hasAllergyAlert,
        Boolean hasMedicationAlert,
        Integer overdueRecallCount,
        Integer upcomingRecallCount,
        Integer openEstimateCount,
        Integer overdueInvoiceCount
) {}
