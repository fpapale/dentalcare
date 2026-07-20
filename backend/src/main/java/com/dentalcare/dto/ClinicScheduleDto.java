package com.dentalcare.dto;

/**
 * Orari di apertura dello studio, configurabili per tenant (#31).
 *
 * <p>Ogni campo null significa "usa il default applicativo" (vedi
 * {@code AppointmentService.ScheduleConfig.defaults()}): così un tenant che non ha
 * mai aperto le impostazioni continua a funzionare senza righe di configurazione.
 *
 * @param workStartTime apertura, formato "HH:mm"
 * @param workEndTime   chiusura, formato "HH:mm"
 * @param slotMinutes   granularità degli slot proposti, in minuti
 * @param workingDays   giorni lavorativi come numeri ISO separati da virgola
 *                      (1 = lunedì … 7 = domenica), es. "1,2,3,4,5"
 */
public record ClinicScheduleDto(
        String workStartTime,
        String workEndTime,
        Integer slotMinutes,
        String workingDays
) {}
