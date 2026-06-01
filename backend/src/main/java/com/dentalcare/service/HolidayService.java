package com.dentalcare.service;

import com.dentalcare.dto.HolidayDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
public class HolidayService {

    private final NamedParameterJdbcTemplate jdbc;

    public HolidayService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    /**
     * Expand the holidays applicable to the current clinic's state into concrete
     * dates within [from, to]. Reuses the geo resolution + holiday model used by
     * AppointmentService.checkWorkingDay (clinic -> city -> region -> state).
     */
    @Transactional(readOnly = true)
    public List<HolidayDto> findInRange(LocalDate from, LocalDate to) {
        if (from == null || to == null || to.isBefore(from)) {
            return List.of();
        }

        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String stateQuery = """
            SELECT s.id
            FROM %s.clinics cl
            JOIN dentalcare.cities  ci ON ci.id = cl.city_id
            JOIN dentalcare.regions r  ON r.id  = ci.region_id
            JOIN dentalcare.states  s  ON s.id  = r.state_id
            WHERE cl.id = :clinicId
            """.formatted(s());
        List<UUID> stateIds = jdbc.queryForList(stateQuery,
                new MapSqlParameterSource("clinicId", clinicId), UUID.class);

        if (stateIds.isEmpty()) {
            return List.of(); // no geo data -> no holidays
        }
        UUID stateId = stateIds.get(0);

        List<HolidayDto> result = new ArrayList<>();

        // Specific (non-recurring) holidays already carry a concrete date.
        result.addAll(jdbc.query("""
            SELECT holiday_date, name
            FROM dentalcare.national_holidays
            WHERE state_id = :stateId
              AND is_recurring = FALSE
              AND holiday_date BETWEEN :from AND :to
            """,
                new MapSqlParameterSource()
                        .addValue("stateId", stateId)
                        .addValue("from", from)
                        .addValue("to", to),
                (rs, n) -> new HolidayDto(rs.getObject("holiday_date", LocalDate.class), rs.getString("name"))));

        // Recurring holidays are stored as (month, day) and expanded per year in range.
        List<RecurringHoliday> recurring = jdbc.query("""
            SELECT month, day, name
            FROM dentalcare.national_holidays
            WHERE state_id = :stateId AND is_recurring = TRUE
            """,
                new MapSqlParameterSource("stateId", stateId),
                (rs, n) -> new RecurringHoliday(rs.getInt("month"), rs.getInt("day"), rs.getString("name")));

        for (RecurringHoliday rh : recurring) {
            for (int year = from.getYear(); year <= to.getYear(); year++) {
                try {
                    LocalDate date = LocalDate.of(year, rh.month(), rh.day());
                    if (!date.isBefore(from) && !date.isAfter(to)) {
                        result.add(new HolidayDto(date, rh.name()));
                    }
                } catch (DateTimeException ignored) {
                    // e.g. Feb 29 on a non-leap year -> skip
                }
            }
        }

        return result.stream()
                .sorted(Comparator.comparing(HolidayDto::date))
                .distinct()
                .toList();
    }

    private record RecurringHoliday(int month, int day, String name) {}
}
