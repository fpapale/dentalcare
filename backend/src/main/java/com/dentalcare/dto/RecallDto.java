package com.dentalcare.dto;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public record RecallDto(
        UUID recallId,
        UUID patientId,
        String patientFullName,
        String patientPhone,
        String recallType,
        LocalDate dueDate,
        String status,
        String priority,
        String notes,
        int contactCount,
        LocalDate lastContactAt,
        LocalDate sourceAppointmentDate,
        OffsetDateTime createdAt
) {}
