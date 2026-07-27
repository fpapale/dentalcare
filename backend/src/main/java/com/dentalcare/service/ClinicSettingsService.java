package com.dentalcare.service;

import com.dentalcare.dto.ClinicBillingDto;
import com.dentalcare.dto.ClinicScheduleDto;
import com.dentalcare.dto.CreateClinicRequest;
import com.dentalcare.dto.UpdateClinicBillingRequest;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Types;
import java.util.List;
import java.util.UUID;

@Service
public class ClinicSettingsService {

    private final NamedParameterJdbcTemplate jdbc;

    public ClinicSettingsService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    @Transactional(readOnly = true)
    public ClinicBillingDto getClinicBilling() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT id, name, legal_name, vat_number, fiscal_code,
                   phone, email, address_line1, address_line2,
                   city, province, postal_code, country
            FROM %s.clinics
            WHERE id = :id
            """.formatted(s());
        List<ClinicBillingDto> rows = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", clinicId),
                (rs, n) -> new ClinicBillingDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("name"),
                        rs.getString("legal_name"),
                        rs.getString("vat_number"),
                        rs.getString("fiscal_code"),
                        rs.getString("phone"),
                        rs.getString("email"),
                        rs.getString("address_line1"),
                        rs.getString("address_line2"),
                        rs.getString("city"),
                        rs.getString("province"),
                        rs.getString("postal_code"),
                        rs.getString("country")
                ));
        return rows.isEmpty() ? null : rows.get(0);
    }

    @Transactional(readOnly = true)
    public List<ClinicBillingDto> findAll() {
        return jdbc.query("""
            SELECT id, name, legal_name, vat_number, fiscal_code,
                   phone, email, address_line1, address_line2,
                   city, province, postal_code, country
            FROM %s.clinics
            ORDER BY name
            """.formatted(s()),
            new MapSqlParameterSource(),
            (rs, n) -> new ClinicBillingDto(
                    rs.getObject("id", UUID.class),
                    rs.getString("name"),
                    rs.getString("legal_name"),
                    rs.getString("vat_number"),
                    rs.getString("fiscal_code"),
                    rs.getString("phone"),
                    rs.getString("email"),
                    rs.getString("address_line1"),
                    rs.getString("address_line2"),
                    rs.getString("city"),
                    rs.getString("province"),
                    rs.getString("postal_code"),
                    rs.getString("country")
            ));
    }

    @Transactional
    public ClinicBillingDto create(CreateClinicRequest request) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO %s.clinics
                (id, name, legal_name, vat_number, fiscal_code, phone, email,
                 address_line1, city, province, postal_code, country)
            VALUES
                (:id, :name, :legalName, :vatNumber, :fiscalCode, :phone, :email,
                 :addressLine1, :city, :province, :postalCode, 'IT')
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("name", request.name())
                .addValue("legalName", request.legalName())
                .addValue("vatNumber", request.vatNumber())
                .addValue("fiscalCode", request.fiscalCode())
                .addValue("phone", request.phone())
                .addValue("email", request.email())
                .addValue("addressLine1", request.addressLine1())
                .addValue("city", request.city())
                .addValue("province", request.province())
                .addValue("postalCode", request.postalCode()));
        return findAll().stream()
                .filter(c -> c.id().equals(id))
                .findFirst()
                .orElseThrow();
    }

    @Transactional
    public void updateClinicBilling(UpdateClinicBillingRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.clinics
            SET name         = :name,
                legal_name   = :legalName,
                vat_number   = :vatNumber,
                fiscal_code  = :fiscalCode,
                phone        = :phone,
                email        = :email,
                address_line1 = :addressLine1,
                address_line2 = :addressLine2,
                city         = :city,
                province     = :province,
                postal_code  = :postalCode,
                country      = COALESCE(:country, country),
                updated_at   = now()
            WHERE id = :id
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", clinicId)
                        .addValue("name", request.name())
                        .addValue("legalName", request.legalName())
                        .addValue("vatNumber", request.vatNumber())
                        .addValue("fiscalCode", request.fiscalCode())
                        .addValue("phone", request.phone())
                        .addValue("email", request.email())
                        .addValue("addressLine1", request.addressLine1())
                        .addValue("addressLine2", request.addressLine2())
                        .addValue("city", request.city())
                        .addValue("province", request.province())
                        .addValue("postalCode", request.postalCode())
                        .addValue("country", request.country()));
    }

    // ── #31 Orari studio, configurabili per tenant ─────────────────────────────

    @Transactional(readOnly = true)
    public ClinicScheduleDto getSchedule() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<ClinicScheduleDto> rows = jdbc.query("""
            SELECT to_char(work_start_time, 'HH24:MI') AS work_start_time,
                   to_char(work_end_time,   'HH24:MI') AS work_end_time,
                   slot_minutes, working_days
            FROM %s.clinics
            WHERE id = :id
            """.formatted(s()),
                new MapSqlParameterSource().addValue("id", clinicId),
                (rs, n) -> new ClinicScheduleDto(
                        rs.getString("work_start_time"),
                        rs.getString("work_end_time"),
                        (Integer) rs.getObject("slot_minutes"),
                        rs.getString("working_days")));
        // Nessuna riga: campi null -> il chiamante applica i default.
        return rows.isEmpty() ? new ClinicScheduleDto(null, null, null, null) : rows.get(0);
    }

    /** Modalità di visibilità pazienti per ruolo della sede corrente (#42). */
    public com.dentalcare.dto.PatientVisibilityDto getPatientVisibility() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<String> rows = jdbc.queryForList(
                "SELECT patient_visibility_mode FROM " + s() + ".clinics WHERE id = :id",
                new MapSqlParameterSource("id", clinicId), String.class);
        String mode = rows.isEmpty() || rows.get(0) == null ? "per_provider" : rows.get(0);
        return new com.dentalcare.dto.PatientVisibilityDto(mode);
    }

    @Transactional
    public void updatePatientVisibility(com.dentalcare.dto.PatientVisibilityDto request) {
        String mode = request == null ? null : request.mode();
        if (!"per_provider".equals(mode) && !"shared".equals(mode)) {
            throw new IllegalArgumentException("Modalità non valida: usare 'per_provider' o 'shared'");
        }
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update(
                "UPDATE " + s() + ".clinics SET patient_visibility_mode = :mode, updated_at = now() WHERE id = :id",
                new MapSqlParameterSource().addValue("id", clinicId).addValue("mode", mode));
    }

    /** Modalità di fatturazione della sede corrente (#44). */
    public com.dentalcare.dto.BillingModeDto getBillingMode() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<String> rows = jdbc.queryForList(
                "SELECT billing_mode FROM " + s() + ".clinics WHERE id = :id",
                new MapSqlParameterSource("id", clinicId), String.class);
        String mode = rows.isEmpty() || rows.get(0) == null ? "studio" : rows.get(0);
        return new com.dentalcare.dto.BillingModeDto(mode);
    }

    @Transactional
    public void updateBillingMode(com.dentalcare.dto.BillingModeDto request) {
        String mode = request == null ? null : request.mode();
        if (!"studio".equals(mode) && !"provider".equals(mode)) {
            throw new IllegalArgumentException("Modalità non valida: usare 'studio' o 'provider'");
        }
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update(
                "UPDATE " + s() + ".clinics SET billing_mode = :mode, updated_at = now() WHERE id = :id",
                new MapSqlParameterSource().addValue("id", clinicId).addValue("mode", mode));
    }

    @Transactional
    public void updateSchedule(ClinicScheduleDto request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.clinics
            SET work_start_time = CAST(NULLIF(:workStartTime, '') AS TIME),
                work_end_time   = CAST(NULLIF(:workEndTime, '')   AS TIME),
                slot_minutes    = :slotMinutes,
                working_days    = NULLIF(:workingDays, ''),
                updated_at      = now()
            WHERE id = :id
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", clinicId)
                        .addValue("workStartTime", request.workStartTime(), Types.VARCHAR)
                        .addValue("workEndTime",   request.workEndTime(),   Types.VARCHAR)
                        .addValue("slotMinutes",   request.slotMinutes(),   Types.INTEGER)
                        .addValue("workingDays",   request.workingDays(),   Types.VARCHAR));
    }
}
