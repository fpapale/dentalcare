package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;
import java.util.UUID;

public record CreateAppointmentRequest(
        @NotNull UUID patientId,
        @NotNull UUID providerId,
        @NotBlank String chairLabel,
        @NotNull OffsetDateTime startsAt,
        @NotNull OffsetDateTime endsAt,
        String notes
) {}
