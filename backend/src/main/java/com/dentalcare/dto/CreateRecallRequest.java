package com.dentalcare.dto;

import java.time.LocalDate;
import java.util.UUID;

public record CreateRecallRequest(
        UUID patientId,
        String recallType,
        LocalDate dueDate,
        String priority,
        String notes,
        UUID sourceAppointmentId
) {}
