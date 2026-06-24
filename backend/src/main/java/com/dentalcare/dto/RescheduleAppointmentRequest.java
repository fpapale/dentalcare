package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.OffsetDateTime;
import java.util.UUID;

public record RescheduleAppointmentRequest(
        @NotNull OffsetDateTime startsAt,
        @NotNull OffsetDateTime endsAt,
        @NotBlank String chairLabel,
        // Opzionale: se valorizzato riassegna l'appuntamento a un altro medico.
        // null = mantiene il medico corrente (compatibile con la UI esistente).
        UUID providerId
) {}
