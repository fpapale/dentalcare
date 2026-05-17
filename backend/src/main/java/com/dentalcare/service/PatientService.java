package com.dentalcare.service;

import com.dentalcare.dto.CreatePatientRequest;
import com.dentalcare.dto.PatientDetailDto;
import com.dentalcare.dto.PatientListDto;
import com.dentalcare.dto.UpdatePatientRequest;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class PatientService {

    private final NamedParameterJdbcTemplate jdbc;

    public PatientService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    public List<PatientListDto> findAll(String search, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String providerFilter = providerId != null
                ? "AND EXISTS (SELECT 1 FROM " + s() + ".appointments a WHERE a.patient_id = v.patient_id AND a.provider_id = :providerId AND a.clinic_id = v.clinic_id)\n"
                : "";
        String sql = """
            SELECT v.patient_id, v.patient_first_name, v.patient_last_name, v.patient_full_name,
                   v.fiscal_code, v.birth_date, v.age_years, v.phone, v.email, v.city, v.province,
                   v.treatment_plans_count, v.open_treatment_items_count,
                   v.accepted_estimates_amount,
                   (SELECT COUNT(*) FROM %s.appointments a
                    WHERE a.patient_id = v.patient_id AND a.clinic_id = v.clinic_id) AS total_appointments,
                   pat.photo_url
            FROM %s.v_patient_dashboard v
            JOIN %s.patients pat ON pat.id = v.patient_id
            WHERE v.clinic_id = :clinicId
              AND (CAST(:search AS text) IS NULL
                   OR v.patient_full_name ILIKE '%%' || CAST(:search AS text) || '%%'
                   OR v.fiscal_code ILIKE '%%' || CAST(:search AS text) || '%%'
                   OR v.phone ILIKE '%%' || CAST(:search AS text) || '%%')
            """.formatted(s(), s(), s()) + providerFilter + """
            ORDER BY v.patient_last_name, v.patient_first_name
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("search", (search == null || search.isBlank()) ? null : search.trim());
        if (providerId != null) params.addValue("providerId", providerId);
        return jdbc.query(sql, params, (rs, n) -> mapListRow(rs));
    }

    public UUID create(CreatePatientRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID patientId = UUID.randomUUID();
        String sql = """
            INSERT INTO %s.patients
                (id, clinic_id, first_name, last_name, fiscal_code, birth_date,
                 phone, email, address_line1, city, province, postal_code, notes)
            VALUES
                (:id, :clinicId, :firstName, :lastName, :fiscalCode, :birthDate,
                 :phone, :email, :addressLine1, :city, :province, :postalCode, :notes)
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", patientId)
                .addValue("clinicId", clinicId)
                .addValue("firstName", request.firstName())
                .addValue("lastName", request.lastName())
                .addValue("fiscalCode", request.fiscalCode())
                .addValue("birthDate", request.birthDate())
                .addValue("phone", request.phone())
                .addValue("email", request.email())
                .addValue("addressLine1", request.addressLine1())
                .addValue("city", request.city())
                .addValue("province", request.province())
                .addValue("postalCode", request.postalCode())
                .addValue("notes", request.notes());
        jdbc.update(sql, params);
        return patientId;
    }

    public void update(UUID patientId, UpdatePatientRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE %s.patients
            SET first_name    = :firstName,
                last_name     = :lastName,
                fiscal_code   = :fiscalCode,
                birth_date    = :birthDate,
                phone         = :phone,
                email         = :email,
                address_line1 = :addressLine1,
                city          = :city,
                province      = :province,
                postal_code   = :postalCode,
                notes         = :notes
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("firstName",   request.firstName())
                .addValue("lastName",    request.lastName())
                .addValue("fiscalCode",  request.fiscalCode())
                .addValue("birthDate",   request.birthDate())
                .addValue("phone",       request.phone())
                .addValue("email",       request.email())
                .addValue("addressLine1",request.addressLine1())
                .addValue("city",        request.city())
                .addValue("province",    request.province())
                .addValue("postalCode",  request.postalCode())
                .addValue("notes",       request.notes())
                .addValue("id",          patientId)
                .addValue("clinicId",    clinicId);
        jdbc.update(sql, params);
    }

    public Optional<PatientDetailDto> findById(UUID patientId, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String providerFilter = providerId != null
                ? "AND EXISTS (SELECT 1 FROM " + s() + ".appointments a WHERE a.patient_id = p.patient_id AND a.provider_id = :providerId AND a.clinic_id = p.clinic_id)"
                : "";
        String sql = """
            SELECT p.patient_id, p.first_name, p.last_name, p.full_name,
                   p.fiscal_code, p.birth_date, p.age_years, p.phone, p.email,
                   p.city, p.province, p.patient_notes,
                   p.blood_type, p.smoker, p.hypertension, p.diabetes, p.heart_disease,
                   p.taking_anticoagulants, p.taking_bisphosphonates,
                   p.allergy_penicillin, p.allergy_latex, p.allergy_anesthetic,
                   p.other_allergies, p.anamnesis_notes, p.anamnesis_date,
                   p.total_appointments,
                   (SELECT COUNT(*) FROM %s.treatment_plans tp
                    WHERE tp.patient_id = p.patient_id AND tp.clinic_id = p.clinic_id) AS treatment_plans_count,
                   (SELECT COUNT(*) FROM %s.treatment_plan_items tpi
                    JOIN %s.treatment_plans tp2 ON tp2.id = tpi.treatment_plan_id AND tp2.clinic_id = tpi.clinic_id
                    WHERE tp2.patient_id = p.patient_id AND tpi.clinic_id = p.clinic_id
                      AND tpi.status IN ('planned','accepted','scheduled')) AS open_treatment_items_count,
                   pat.address_line1, pat.postal_code, pat.photo_url
            FROM %s.v_patient_clinical_card p
            JOIN %s.patients pat ON pat.id = p.patient_id
            WHERE p.patient_id = :patientId
              AND p.clinic_id = :clinicId
            """.formatted(s(), s(), s(), s(), s()) + providerFilter;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("patientId", patientId)
                .addValue("clinicId", clinicId);
        if (providerId != null) params.addValue("providerId", providerId);
        List<PatientDetailDto> result = jdbc.query(sql, params, (rs, n) -> mapDetailRow(rs));
        return result.isEmpty() ? Optional.empty() : Optional.of(result.get(0));
    }

    private PatientListDto mapListRow(ResultSet rs) throws SQLException {
        return new PatientListDto(
                rs.getObject("patient_id", UUID.class),
                rs.getString("patient_full_name"),
                rs.getString("patient_first_name"),
                rs.getString("patient_last_name"),
                rs.getString("fiscal_code"),
                rs.getDate("birth_date") != null ? rs.getDate("birth_date").toLocalDate() : null,
                rs.getObject("age_years", Integer.class),
                rs.getString("phone"),
                rs.getString("email"),
                rs.getString("city"),
                rs.getString("province"),
                rs.getLong("treatment_plans_count"),
                rs.getLong("open_treatment_items_count"),
                rs.getLong("total_appointments"),
                rs.getBigDecimal("accepted_estimates_amount"),
                rs.getString("photo_url")
        );
    }

    private PatientDetailDto mapDetailRow(ResultSet rs) throws SQLException {
        return new PatientDetailDto(
                rs.getObject("patient_id", UUID.class),
                rs.getString("first_name"),
                rs.getString("last_name"),
                rs.getString("full_name"),
                rs.getString("fiscal_code"),
                rs.getDate("birth_date") != null ? rs.getDate("birth_date").toLocalDate() : null,
                rs.getObject("age_years", Integer.class),
                rs.getString("phone"),
                rs.getString("email"),
                rs.getString("city"),
                rs.getString("province"),
                rs.getString("address_line1"),
                rs.getString("postal_code"),
                rs.getString("patient_notes"),
                rs.getString("blood_type"),
                rs.getObject("smoker", Boolean.class),
                rs.getObject("hypertension", Boolean.class),
                rs.getObject("diabetes", Boolean.class),
                rs.getObject("heart_disease", Boolean.class),
                rs.getObject("taking_anticoagulants", Boolean.class),
                rs.getObject("taking_bisphosphonates", Boolean.class),
                rs.getObject("allergy_penicillin", Boolean.class),
                rs.getObject("allergy_latex", Boolean.class),
                rs.getObject("allergy_anesthetic", Boolean.class),
                rs.getString("other_allergies"),
                rs.getString("anamnesis_notes"),
                rs.getTimestamp("anamnesis_date") != null
                        ? rs.getTimestamp("anamnesis_date").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getLong("total_appointments"),
                rs.getLong("treatment_plans_count"),
                rs.getLong("open_treatment_items_count"),
                rs.getString("photo_url")
        );
    }

    public void updatePhoto(UUID patientId, String photoDataUrl) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE %s.patients
            SET photo_url = :photoUrl
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("photoUrl", photoDataUrl)
                .addValue("id", patientId)
                .addValue("clinicId", clinicId);
        jdbc.update(sql, params);
    }
}
