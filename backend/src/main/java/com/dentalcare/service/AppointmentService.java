package com.dentalcare.service;

import com.dentalcare.dto.AppointmentDto;
import com.dentalcare.dto.CreateAppointmentRequest;
import com.dentalcare.dto.RescheduleAppointmentRequest;
import com.dentalcare.exception.AppointmentConflictException;
import com.dentalcare.exception.ResourceNotFoundException;
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
        String providerFilter = providerId != null ? "AND v.provider_id = :providerId\n" : "";
        String sql = """
            SELECT v.appointment_id, v.clinic_id, v.starts_at, v.ends_at, v.chair_label,
                   v.appointment_status, v.notes,
                   v.patient_id, v.patient_full_name, v.patient_phone,
                   v.provider_id, v.provider_name, v.provider_role,
                   v.service_name, v.service_category, v.tooth_number,
                   v.has_allergy_alert, v.has_medication_alert,
                   (SELECT COUNT(*)::integer FROM %s.patient_recalls r
                    WHERE r.patient_id = v.patient_id AND r.clinic_id = v.clinic_id
                      AND r.due_date < CURRENT_DATE
                      AND r.status::text NOT IN ('completed', 'cancelled')) AS overdue_recall_count,
                   (SELECT COUNT(*)::integer FROM %s.patient_recalls r
                    WHERE r.patient_id = v.patient_id AND r.clinic_id = v.clinic_id
                      AND r.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '14 days'
                      AND r.status::text NOT IN ('completed', 'cancelled', 'booked')) AS upcoming_recall_count,
                   (SELECT COUNT(*)::integer FROM %s.estimates e
                    WHERE e.patient_id = v.patient_id AND e.clinic_id = v.clinic_id
                      AND e.status::text = 'sent') AS open_estimate_count,
                   (SELECT COUNT(*)::integer FROM %s.invoices i
                    WHERE i.patient_id = v.patient_id AND i.clinic_id = v.clinic_id
                      AND i.status::text = 'overdue') AS overdue_invoice_count
            FROM %s.v_agenda_daily v
            WHERE v.clinic_id = :clinicId
              AND v.starts_at::date = :date
            """.formatted(s(), s(), s(), s(), s()) + providerFilter + """
            ORDER BY v.starts_at, v.chair_label
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("date", date);
        if (providerId != null) params.addValue("providerId", providerId);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public List<AppointmentDto> findByPatient(UUID patientId, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String providerFilter = providerId != null ? "AND v.provider_id = :providerId\n" : "";
        String sql = """
            SELECT v.appointment_id, v.clinic_id, v.starts_at, v.ends_at, v.chair_label,
                   v.appointment_status, v.notes,
                   v.patient_id, v.patient_full_name, v.patient_phone,
                   v.provider_id, v.provider_name, v.provider_role,
                   v.service_name, v.service_category, v.tooth_number,
                   v.has_allergy_alert, v.has_medication_alert,
                   (SELECT COUNT(*)::integer FROM %s.patient_recalls r
                    WHERE r.patient_id = v.patient_id AND r.clinic_id = v.clinic_id
                      AND r.due_date < CURRENT_DATE
                      AND r.status::text NOT IN ('completed', 'cancelled')) AS overdue_recall_count,
                   (SELECT COUNT(*)::integer FROM %s.patient_recalls r
                    WHERE r.patient_id = v.patient_id AND r.clinic_id = v.clinic_id
                      AND r.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '14 days'
                      AND r.status::text NOT IN ('completed', 'cancelled', 'booked')) AS upcoming_recall_count,
                   (SELECT COUNT(*)::integer FROM %s.estimates e
                    WHERE e.patient_id = v.patient_id AND e.clinic_id = v.clinic_id
                      AND e.status::text = 'sent') AS open_estimate_count,
                   (SELECT COUNT(*)::integer FROM %s.invoices i
                    WHERE i.patient_id = v.patient_id AND i.clinic_id = v.clinic_id
                      AND i.status::text = 'overdue') AS overdue_invoice_count
            FROM %s.v_agenda_daily v
            WHERE v.clinic_id = :clinicId
              AND v.patient_id = :patientId
            """.formatted(s(), s(), s(), s(), s()) + providerFilter + """
            ORDER BY v.starts_at DESC
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
        String providerFilter = providerId != null ? "AND v.provider_id = :providerId\n" : "";
        String sql = """
            SELECT v.appointment_id, v.clinic_id, v.starts_at, v.ends_at, v.chair_label,
                   v.appointment_status, v.notes,
                   v.patient_id, v.patient_full_name, v.patient_phone,
                   v.provider_id, v.provider_name, v.provider_role,
                   v.service_name, v.service_category, v.tooth_number,
                   v.has_allergy_alert, v.has_medication_alert,
                   (SELECT COUNT(*)::integer FROM %s.patient_recalls r
                    WHERE r.patient_id = v.patient_id AND r.clinic_id = v.clinic_id
                      AND r.due_date < CURRENT_DATE
                      AND r.status::text NOT IN ('completed', 'cancelled')) AS overdue_recall_count,
                   (SELECT COUNT(*)::integer FROM %s.patient_recalls r
                    WHERE r.patient_id = v.patient_id AND r.clinic_id = v.clinic_id
                      AND r.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '14 days'
                      AND r.status::text NOT IN ('completed', 'cancelled', 'booked')) AS upcoming_recall_count,
                   (SELECT COUNT(*)::integer FROM %s.estimates e
                    WHERE e.patient_id = v.patient_id AND e.clinic_id = v.clinic_id
                      AND e.status::text = 'sent') AS open_estimate_count,
                   (SELECT COUNT(*)::integer FROM %s.invoices i
                    WHERE i.patient_id = v.patient_id AND i.clinic_id = v.clinic_id
                      AND i.status::text = 'overdue') AS overdue_invoice_count
            FROM %s.v_agenda_daily v
            WHERE v.clinic_id = :clinicId
              AND v.starts_at::date BETWEEN :from AND :to
            """.formatted(s(), s(), s(), s(), s()) + providerFilter + """
            ORDER BY v.starts_at, v.chair_label
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
            JOIN dentalcare.cities  ci ON ci.id = cl.city_id
            JOIN dentalcare.regions r  ON r.id  = ci.region_id
            JOIN dentalcare.states  s  ON s.id  = r.state_id
            WHERE cl.id = :clinicId
            """.formatted(s());
        List<UUID> stateIds = jdbc.queryForList(stateQuery,
                new MapSqlParameterSource("clinicId", clinicId), UUID.class);

        if (stateIds.isEmpty()) return; // no geo data → skip holiday check

        String holidayQuery = """
            SELECT name FROM dentalcare.national_holidays
            WHERE state_id = :stateId
              AND (
                (is_recurring = TRUE  AND month = :month AND day = :day)
                OR
                (is_recurring = FALSE AND holiday_date = :date)
              )
            LIMIT 1
            """;
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

    public void reschedule(UUID appointmentId, RescheduleAppointmentRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        List<UUID> providers = jdbc.queryForList(
                "SELECT provider_id FROM %s.appointments WHERE id = :id AND clinic_id = :clinicId".formatted(s()),
                new MapSqlParameterSource().addValue("id", appointmentId).addValue("clinicId", clinicId),
                UUID.class);
        if (providers.isEmpty()) throw new ResourceNotFoundException("Appointment not found: " + appointmentId);
        UUID providerId = providers.get(0);

        String chairSql = """
                SELECT COUNT(*) FROM %s.appointments
                WHERE clinic_id   = :clinicId
                  AND chair_label = :chairLabel
                  AND id         != :excludeId
                  AND status::text NOT IN ('cancelled')
                  AND starts_at  < :endsAt
                  AND ends_at    > :startsAt
                """.formatted(s());
        Integer chairCount = jdbc.queryForObject(chairSql, new MapSqlParameterSource()
                .addValue("clinicId",   clinicId)
                .addValue("chairLabel", request.chairLabel())
                .addValue("excludeId",  appointmentId)
                .addValue("startsAt",   request.startsAt())
                .addValue("endsAt",     request.endsAt()), Integer.class);
        if (chairCount != null && chairCount > 0)
            throw new AppointmentConflictException("CHAIR_CONFLICT",
                    "La " + request.chairLabel() + " è già occupata in questo orario.");

        String provSql = """
                SELECT COUNT(*) FROM %s.appointments
                WHERE clinic_id   = :clinicId
                  AND provider_id = :providerId
                  AND id         != :excludeId
                  AND status::text NOT IN ('cancelled')
                  AND starts_at  < :endsAt
                  AND ends_at    > :startsAt
                """.formatted(s());
        Integer provCount = jdbc.queryForObject(provSql, new MapSqlParameterSource()
                .addValue("clinicId",   clinicId)
                .addValue("providerId", providerId)
                .addValue("excludeId",  appointmentId)
                .addValue("startsAt",   request.startsAt())
                .addValue("endsAt",     request.endsAt()), Integer.class);
        if (provCount != null && provCount > 0)
            throw new AppointmentConflictException("PROVIDER_CONFLICT",
                    "Il medico ha già un appuntamento in questo orario.");

        jdbc.update("""
                UPDATE %s.appointments
                SET starts_at = :startsAt, ends_at = :endsAt, chair_label = :chairLabel
                WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id",         appointmentId)
                        .addValue("clinicId",   clinicId)
                        .addValue("startsAt",   request.startsAt())
                        .addValue("endsAt",     request.endsAt())
                        .addValue("chairLabel", request.chairLabel()));
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
                rs.getObject("has_medication_alert", Boolean.class),
                rs.getObject("overdue_recall_count", Integer.class),
                rs.getObject("upcoming_recall_count", Integer.class),
                rs.getObject("open_estimate_count", Integer.class),
                rs.getObject("overdue_invoice_count", Integer.class)
        );
    }
}
