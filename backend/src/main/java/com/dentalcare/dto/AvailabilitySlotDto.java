package com.dentalcare.dto;

import java.time.LocalDate;
import java.util.UUID;

/** Proposta di slot libero (poltrona + medico) restituita da GET /api/appointments/availability. */
public record AvailabilitySlotDto(
        LocalDate date,
        String startTime,
        String endTime,
        String chairLabel,
        UUID providerId,
        String providerName
) {}
