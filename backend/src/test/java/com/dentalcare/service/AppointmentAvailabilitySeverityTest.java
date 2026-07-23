package com.dentalcare.service;

import com.dentalcare.dto.AvailabilitySlotDto;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AppointmentAvailabilitySeverityTest {

    @Test
    void computeAvailability_endOfDayOnly_proposesOnlyLastSlotsOfTheDay() {
        UUID providerId = UUID.randomUUID();
        var providers = List.of(new AppointmentService.AvailabilityProvider(providerId, "Dr. Test"));
        var chairs = List.of("Studio 1");
        var busy = List.<AppointmentService.BusyAppointment>of();

        AppointmentService.ScheduleConfig cfg = new AppointmentService.ScheduleConfig(
                LocalTime.of(8, 0), LocalTime.of(19, 0), 15,
                java.util.EnumSet.of(java.time.DayOfWeek.MONDAY, java.time.DayOfWeek.TUESDAY,
                        java.time.DayOfWeek.WEDNESDAY, java.time.DayOfWeek.THURSDAY, java.time.DayOfWeek.FRIDAY));

        LocalDate monday = LocalDate.of(2026, 7, 27); // lunedì
        List<AvailabilitySlotDto> proposals = AppointmentService.computeAvailability(
                30, monday, 3, providers, chairs, busy, cfg, true);

        assertThat(proposals).isNotEmpty();
        assertThat(proposals).allSatisfy(slot ->
                assertThat(slot.startTime()).isEqualTo("18:30")); // ultimo slot che chiude entro le 19:00 con durata 30min
    }

    @Test
    void computeAvailability_notEndOfDayOnly_proposesFirstAvailableSlot() {
        UUID providerId = UUID.randomUUID();
        var providers = List.of(new AppointmentService.AvailabilityProvider(providerId, "Dr. Test"));
        var chairs = List.of("Studio 1");
        var busy = List.<AppointmentService.BusyAppointment>of();

        AppointmentService.ScheduleConfig cfg = new AppointmentService.ScheduleConfig(
                LocalTime.of(8, 0), LocalTime.of(19, 0), 15,
                java.util.EnumSet.of(java.time.DayOfWeek.MONDAY));

        LocalDate monday = LocalDate.of(2026, 7, 27);
        List<AvailabilitySlotDto> proposals = AppointmentService.computeAvailability(
                30, monday, 1, providers, chairs, busy, cfg, false);

        assertThat(proposals).hasSize(1);
        assertThat(proposals.get(0).startTime()).isEqualTo("08:00");
    }
}
