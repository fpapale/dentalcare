package com.dentalcare.service;

import com.dentalcare.dto.AvailabilitySlotDto;
import org.junit.jupiter.api.Test;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Logica di ricerca disponibilità (AppointmentService.computeAvailability), testata sul metodo
 * package-private puro: nessun mock di NamedParameterJdbcTemplate necessario, stesso approccio
 * usato in EstimateServiceTest per il ricalcolo dei totali dei preventivi.
 */
class AppointmentAvailabilityTest {

    private static final ZoneId ROME = ZoneId.of("Europe/Rome");

    private final UUID providerA = UUID.fromString("00000000-0000-0000-0000-0000000000aa");
    private final UUID providerB = UUID.fromString("00000000-0000-0000-0000-0000000000bb");

    private final AppointmentService.AvailabilityProvider drA =
            new AppointmentService.AvailabilityProvider(providerA, "Dr. Rossi");
    private final AppointmentService.AvailabilityProvider drB =
            new AppointmentService.AvailabilityProvider(providerB, "Dr. Bianchi");

    /** Un lunedì fisso, indipendente dal giorno in cui girano i test. */
    private static LocalDate aMonday() {
        return LocalDate.now().with(TemporalAdjusters.nextOrSame(DayOfWeek.MONDAY));
    }

    private static OffsetDateTime at(LocalDate date, int hour, int minute) {
        return date.atTime(hour, minute).atZone(ROME).toOffsetDateTime();
    }

    @Test
    void primoSlotLiberoTrovatoQuandoTuttoELibero() {
        LocalDate monday = aMonday();

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, monday, 1,
                List.of(drA), List.of("Studio 1"), List.of());

        assertThat(result).hasSize(1);
        AvailabilitySlotDto slot = result.get(0);
        assertThat(slot.date()).isEqualTo(monday);
        assertThat(slot.startTime()).isEqualTo("08:00");
        assertThat(slot.endTime()).isEqualTo("08:30");
        assertThat(slot.chairLabel()).isEqualTo("Studio 1");
        assertThat(slot.providerId()).isEqualTo(providerA);
        assertThat(slot.providerName()).isEqualTo("Dr. Rossi");
    }

    @Test
    void slotSaltatoQuandoLaPoltronaEOccupata() {
        LocalDate monday = aMonday();
        // Studio 1 occupato 08:00-08:30 (il medico dell'appuntamento è irrilevante: è un
        // conflitto di poltrona, non di medico).
        AppointmentService.BusyAppointment busy = new AppointmentService.BusyAppointment(
                at(monday, 8, 0), at(monday, 8, 30), "Studio 1", providerB);

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, monday, 1,
                List.of(drA), List.of("Studio 1"), List.of(busy));

        assertThat(result).hasSize(1);
        // 08:00-08:30 e 08:15-08:45 si sovrappongono ancora all'occupazione: il primo slot
        // libero è quello che parte esattamente alla fine dell'appuntamento esistente.
        assertThat(result.get(0).startTime()).isEqualTo("08:30");
        assertThat(result.get(0).endTime()).isEqualTo("09:00");
    }

    @Test
    void slotSaltatoQuandoIlMedicoEOccupato() {
        LocalDate monday = aMonday();
        // Dr. Rossi occupato 08:00-08:30 su una poltrona diversa da quella cercata: isola il
        // conflitto medico da quello poltrona (Studio 1 resta libera per tutto l'intervallo).
        AppointmentService.BusyAppointment busy = new AppointmentService.BusyAppointment(
                at(monday, 8, 0), at(monday, 8, 30), "Studio 2", providerA);

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, monday, 1,
                List.of(drA), List.of("Studio 1"), List.of(busy));

        assertThat(result).hasSize(1);
        assertThat(result.get(0).startTime()).isEqualTo("08:30");
        assertThat(result.get(0).providerId()).isEqualTo(providerA);
    }

    @Test
    void primoMedicoDisponibileSceltoQuandoIlPrimoEOccupato() {
        LocalDate monday = aMonday();
        // Dr. Rossi (primo in scope) occupato su Studio 1 alle 08:00; Dr. Bianchi è libero.
        AppointmentService.BusyAppointment busy = new AppointmentService.BusyAppointment(
                at(monday, 8, 0), at(monday, 8, 30), "Studio 1", providerA);

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, monday, 1,
                List.of(drA, drB), List.of("Studio 1", "Studio 2"), List.of(busy));

        assertThat(result).hasSize(1);
        AvailabilitySlotDto slot = result.get(0);
        assertThat(slot.startTime()).isEqualTo("08:00"); // stesso orario, medico diverso
        assertThat(slot.providerId()).isEqualTo(providerB);
        assertThat(slot.providerName()).isEqualTo("Dr. Bianchi");
        assertThat(slot.chairLabel()).isEqualTo("Studio 2"); // Studio 1 occupata dall'appuntamento del Dr. Rossi
    }

    @Test
    void rispettaOrarioDiChiusuraENonProponeOltre() {
        LocalDate monday = aMonday();
        // Giornata piena dalle 08:00 alle 18:00: con durata 60 min l'unico slot valido è 18:00-19:00.
        AppointmentService.BusyAppointment busyAllDay = new AppointmentService.BusyAppointment(
                at(monday, 8, 0), at(monday, 18, 0), "Studio 1", providerA);

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                60, monday, 1,
                List.of(drA), List.of("Studio 1"), List.of(busyAllDay));

        assertThat(result).hasSize(1);
        assertThat(result.get(0).date()).isEqualTo(monday);
        assertThat(result.get(0).startTime()).isEqualTo("18:00");
        assertThat(result.get(0).endTime()).isEqualTo("19:00");
    }

    @Test
    void weekendSaltatoPrimaPropostaCadeSulLunediSuccessivo() {
        LocalDate saturday = LocalDate.now().with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
        LocalDate followingMonday = saturday.plusDays(2);

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, saturday, 1,
                List.of(drA), List.of("Studio 1"), List.of());

        assertThat(result).hasSize(1);
        assertThat(result.get(0).date()).isEqualTo(followingMonday);
        assertThat(result.get(0).date().getDayOfWeek()).isEqualTo(DayOfWeek.MONDAY);
    }

    @Test
    void proposteMultipleRispettanoIlLimiteERestanoInOrdineCronologico() {
        LocalDate monday = aMonday();

        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                15, monday, 3,
                List.of(drA), List.of("Studio 1"), List.of());

        assertThat(result).hasSize(3);
        assertThat(result.get(0).startTime()).isEqualTo("08:00");
        assertThat(result.get(1).startTime()).isEqualTo("08:15");
        assertThat(result.get(2).startTime()).isEqualTo("08:30");
    }

    @Test
    void nessunMedicoInScopeNessunaProposta() {
        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, aMonday(), 3, List.of(), List.of("Studio 1"), List.of());

        assertThat(result).isEmpty();
    }

    @Test
    void nessunaPoltronaNessunaProposta() {
        List<AvailabilitySlotDto> result = AppointmentService.computeAvailability(
                30, aMonday(), 3, List.of(drA), List.of(), List.of());

        assertThat(result).isEmpty();
    }
}
