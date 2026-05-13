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
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
public class AppointmentService {

    private final NamedParameterJdbcTemplate jdbc;

    public AppointmentService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

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
            FROM dentalcare.v_agenda_daily
            WHERE clinic_id = :clinicId
              AND starts_at::date = :date
            """ + providerFilter + """
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
            FROM dentalcare.v_agenda_daily
            WHERE clinic_id = :clinicId
              AND patient_id = :patientId
            """ + providerFilter + """
            ORDER BY starts_at DESC
            LIMIT 50
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        if (providerId != null) params.addValue("providerId", providerId);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public List<AppointmentDto> findByDateRange(LocalDate from, LocalDate to) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT appointment_id, clinic_id, starts_at, ends_at, chair_label,
                   appointment_status, notes,
                   patient_id, patient_full_name, patient_phone,
                   provider_id, provider_name, provider_role,
                   service_name, service_category, tooth_number,
                   has_allergy_alert, has_medication_alert
            FROM dentalcare.v_agenda_daily
            WHERE clinic_id = :clinicId
              AND starts_at::date BETWEEN :from AND :to
            ORDER BY starts_at, chair_label
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("from", from)
                .addValue("to", to);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public void updateStatus(UUID appointmentId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE dentalcare.appointments
            SET status = :status
            WHERE id = :id AND clinic_id = :clinicId
            """;
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", appointmentId)
                .addValue("clinicId", clinicId)
                .addValue("status", status));
    }

    public UUID create(CreateAppointmentRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        checkChairConflict(clinicId, request);
        checkProviderConflict(clinicId, request);

        UUID id = UUID.randomUUID();
        String sql = """
            INSERT INTO dentalcare.appointments
                (id, clinic_id, patient_id, provider_id, chair_label, starts_at, ends_at, status, notes)
            VALUES
                (:id, :clinicId, :patientId, :providerId, :chairLabel, :startsAt, :endsAt, 'scheduled', :notes)
            """;
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

    private void checkChairConflict(UUID clinicId, CreateAppointmentRequest request) {
        String sql = """
            SELECT COUNT(*) FROM dentalcare.appointments
            WHERE clinic_id  = :clinicId
              AND chair_label = :chairLabel
              AND status NOT IN ('cancelled')
              AND starts_at < :endsAt
              AND ends_at   > :startsAt
            """;
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
            SELECT COUNT(*) FROM dentalcare.appointments
            WHERE clinic_id   = :clinicId
              AND provider_id  = :providerId
              AND status NOT IN ('cancelled')
              AND starts_at < :endsAt
              AND ends_at   > :startsAt
            """;
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
            FROM dentalcare.appointments
            WHERE clinic_id = :clinicId
            ORDER BY chair_label
            """;
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
