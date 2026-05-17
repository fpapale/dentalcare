package com.dentalcare.service;

import com.dentalcare.dto.AppointmentDto;
import com.dentalcare.dto.CreateAppointmentRequest;
import com.dentalcare.exception.AppointmentConflictException;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

@Service
public class AppointmentService {

    private final NamedParameterJdbcTemplate jdbc;

    public AppointmentService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    public List<AppointmentDto> findByDate(LocalDate date, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String providerFilter = providerId != null ? "AND provider_id = :providerId\n" : "";
        String sql = """
            SELECT appointment_id, clinic_id, starts_at, ends_at, chair_label,
                   appointment_status, notes,
                   patient_id, patient_full_name, patient_phone,
                   provider_id, provider_name, provider_role,
                   service_name, service_category, tooth_number,
                   has_allergy_alert, has_medication_alert
            FROM %s.v_agenda_daily
            WHERE clinic_id = :clinicId
              AND starts_at::date = :date
            """.formatted(s()) + providerFilter + """
            ORDER BY starts_at, chair_label
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("date", date);
        if (providerId != null) params.addValue("providerId", providerId);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public List<AppointmentDto> findByPatient(UUID patientId, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String providerFilter = providerId != null ? "AND provider_id = :providerId\n" : "";
        String sql = """
            SELECT appointment_id, clinic_id, starts_at, ends_at, chair_label,
                   appointment_status, notes,
                   patient_id, patient_full_name, patient_phone,
                   provider_id, provider_name, provider_role,
                   service_name, service_category, tooth_number,
                   has_allergy_alert, has_medication_alert
            FROM %s.v_agenda_daily
            WHERE clinic_id = :clinicId
              AND patient_id = :patientId
            """.formatted(s()) + providerFilter + """
            ORDER BY starts_at DESC
            LIMIT 50
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        if (providerId != null) params.addValue("providerId", providerId);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public List<AppointmentDto> findByDateRange(LocalDate from, LocalDate to, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String providerFilter = providerId != null ? "AND provider_id = :providerId\n" : "";
        String sql = """
            SELECT appointment_id, clinic_id, starts_at, ends_at, chair_label,
                   appointment_status, notes,
                   patient_id, patient_full_name, patient_phone,
                   provider_id, provider_name, provider_role,
                   service_name, service_category, tooth_number,
                   has_allergy_alert, has_medication_alert
            FROM %s.v_agenda_daily
            WHERE clinic_id = :clinicId
              AND starts_at::date BETWEEN :from AND :to
            """.formatted(s()) + providerFilter + """
            ORDER BY starts_at, chair_label
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("from", from)
                .addValue("to", to);
        if (providerId != null) params.addValue("providerId", providerId);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public void updateStatus(UUID appointmentId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE %s.appointments
            SET status = CAST(:status AS %s.appointment_status)
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s(), s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", appointmentId)
                .addValue("clinicId", clinicId)
                .addValue("status", status));
    }

    public UUID create(CreateAppointmentRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        checkWorkingDay(clinicId, request);
        checkChairConflict(clinicId, request);
        checkProviderConflict(clinicId, request);

        UUID id = UUID.randomUUID();
        String sql = """
            INSERT INTO %s.appointments
                (id, clinic_id, patient_id, provider_id, chair_label, starts_at, ends_at, status, notes)
            VALUES
                (:id, :clinicId, :patientId, :providerId, :chairLabel, :startsAt, :endsAt, 'scheduled', :notes)
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("patientId", request.patientId())
                .addValue("providerId", request.providerId())
                .addValue("chairLabel", request.chairLabel())
                .addValue("startsAt", request.startsAt())
                .addValue("endsAt", request.endsAt())
                .addValue("notes", request.notes());
        jdbc.update(sql, params);
        return id;
    }

    private void checkWorkingDay(UUID clinicId, CreateAppointmentRequest request) {
        LocalDate date = request.startsAt()
                .atZoneSameInstant(ZoneId.of("Europe/Rome"))
                .toLocalDate();

        DayOfWeek dow = date.getDayOfWeek();
        if (dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY) {
            throw new AppointmentConflictException("WEEKEND",
                    "Non è possibile prenotare appuntamenti nei giorni di sabato e domenica.");
        }

        // Resolve state via clinic → city → region → state (nullable chain)
        String stateQuery = """
            SELECT s.id
            FROM %s.clinics cl
            JOIN %s.cities  ci ON ci.id = cl.city_id
            JOIN %s.regions r  ON r.id  = ci.region_id
            JOIN %s.states  s  ON s.id  = r.state_id
            WHERE cl.id = :clinicId
            """.formatted(s(), s(), s(), s());
        List<UUID> stateIds = jdbc.queryForList(stateQuery,
                new MapSqlParameterSource("clinicId", clinicId), UUID.class);

        if (stateIds.isEmpty()) return; // no geo data → skip holiday check

        String holidayQuery = """
            SELECT name FROM %s.national_holidays
            WHERE state_id = :stateId
              AND (
                (is_recurring = TRUE  AND month = :month AND day = :day)
                OR
                (is_recurring = FALSE AND holiday_date = :date)
              )
            LIMIT 1
            """.formatted(s());
        List<String> names = jdbc.queryForList(holidayQuery,
                new MapSqlParameterSource()
                        .addValue("stateId", stateIds.get(0))
                        .addValue("month", date.getMonthValue())
                        .addValue("day",   date.getDayOfMonth())
                        .addValue("date",  date),
                String.class);

        if (!names.isEmpty()) {
            throw new AppointmentConflictException("HOLIDAY",
                    "Il giorno selezionato è festivo: " + names.get(0) + ".");
        }
    }

    private void checkChairConflict(UUID clinicId, CreateAppointmentRequest request) {
        String sql = """
            SELECT COUNT(*) FROM %s.appointments
            WHERE clinic_id  = :clinicId
              AND chair_label = :chairLabel
              AND status NOT IN ('cancelled')
              AND starts_at < :endsAt
              AND ends_at   > :startsAt
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId",   clinicId)
                .addValue("chairLabel", request.chairLabel())
                .addValue("startsAt",   request.startsAt())
                .addValue("endsAt",     request.endsAt());
        Integer count = jdbc.queryForObject(sql, params, Integer.class);
        if (count != null && count > 0) {
            throw new AppointmentConflictException(
                "CHAIR_CONFLICT",
                "La " + request.chairLabel() + " è già occupata in questo orario."
            );
        }
    }

    private void checkProviderConflict(UUID clinicId, CreateAppointmentRequest request) {
        String sql = """
            SELECT COUNT(*) FROM %s.appointments
            WHERE clinic_id   = :clinicId
              AND provider_id  = :providerId
              AND status NOT IN ('cancelled')
              AND starts_at < :endsAt
              AND ends_at   > :startsAt
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId",   clinicId)
                .addValue("providerId", request.providerId())
                .addValue("startsAt",   request.startsAt())
                .addValue("endsAt",     request.endsAt());
        Integer count = jdbc.queryForObject(sql, params, Integer.class);
        if (count != null && count > 0) {
            throw new AppointmentConflictException(
                "PROVIDER_CONFLICT",
                "Il medico selezionato ha già un appuntamento in questo orario."
            );
        }
    }

    public List<String> findChairLabels() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT DISTINCT chair_label
            FROM %s.appointments
            WHERE clinic_id = :clinicId
            ORDER BY chair_label
            """.formatted(s());
        return jdbc.queryForList(sql, new MapSqlParameterSource("clinicId", clinicId), String.class);
    }

    private AppointmentDto mapRow(ResultSet rs) throws SQLException {
        return new AppointmentDto(
                rs.getObject("appointment_id", UUID.class),
                rs.getTimestamp("starts_at") != null
                        ? rs.getTimestamp("starts_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getTimestamp("ends_at") != null
                        ? rs.getTimestamp("ends_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getString("chair_label"),
                rs.getString("appointment_status"),
                rs.getString("notes"),
                rs.getObject("patient_id", UUID.class),
                rs.getString("patient_full_name"),
                rs.getString("patient_phone"),
                rs.getObject("provider_id", UUID.class),
                rs.getString("provider_name"),
                rs.getString("provider_role"),
                rs.getString("service_name"),
                rs.getString("service_category"),
                rs.getString("tooth_number"),
                rs.getObject("has_allergy_alert", Boolean.class),
                rs.getObject("has_medication_alert", Boolean.class)
        );
    }
}
