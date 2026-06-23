package com.dentalcare.dto;

import java.time.LocalDate;

public record DailyBriefingDto(
        LocalDate date,
        long appointmentsTotal,
        long appointmentsConfirmed,
        long appointmentsCompleted,
        long appointmentsCancelled,
        long overdueRecalls,
        long overdueInvoices,
        long pendingEstimates
) {}
