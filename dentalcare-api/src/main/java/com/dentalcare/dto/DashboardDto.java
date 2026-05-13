package com.dentalcare.dto;

import java.math.BigDecimal;
import java.util.List;

public record DashboardDto(
        String clinicName,
        String city,
        long patientsCount,
        long activeProvidersCount,
        long treatmentPlansInProgress,
        long sentEstimatesCount,
        BigDecimal acceptedEstimatesAmount,
        long todayTotal,
        long todayConfirmed,
        long todayCompleted,
        long todayCancelled,
        List<AppointmentDto> todayAppointments
) {}
