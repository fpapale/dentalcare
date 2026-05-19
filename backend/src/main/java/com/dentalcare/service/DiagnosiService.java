package com.dentalcare.service;

import com.dentalcare.dto.CreateDiagnosiRequest;
import com.dentalcare.dto.DiagnosiDto;
import com.dentalcare.dto.UpdateDiagnosiRequest;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

@Service
public class DiagnosiService {

    private final NamedParameterJdbcTemplate jdbc;

    public DiagnosiService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }

    public List<DiagnosiDto> findByPatient(UUID patientId) {
        String sql = """
            SELECT d.id, d.tooth_number, d.title, d.description, d.icd_code,
                   d.status, d.diagnosed_at, d.resolved_at, d.created_at,
                   concat_ws(' ', p.last_name, p.first_name) AS provider_name
            FROM %s.patient_diagnoses d
            JOIN %s.providers p ON p.id = d.provider_id AND p.clinic_id = d.clinic_id
            WHERE d.clinic_id = :clinicId AND d.patient_id = :patientId
            ORDER BY d.diagnosed_at DESC
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource("clinicId", clinicId()).addValue("patientId", patientId),
                (rs, n) -> new DiagnosiDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("tooth_number"),
                        rs.getString("title"),
                        rs.getString("description"),
                        rs.getString("icd_code"),
                        rs.getString("status"),
                        rs.getString("provider_name"),
                        rs.getDate("diagnosed_at") != null ? rs.getDate("diagnosed_at").toLocalDate() : null,
                        rs.getDate("resolved_at") != null ? rs.getDate("resolved_at").toLocalDate() : null,
                        rs.getTimestamp("created_at") != null
                                ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null
                ));
    }

    public DiagnosiDto create(UUID patientId, CreateDiagnosiRequest req) {
        UUID id = UUID.randomUUID();
        UUID cid = clinicId();
        String sql = """
            INSERT INTO %s.patient_diagnoses
                (id, clinic_id, patient_id, provider_id, tooth_number, title, description, icd_code, diagnosed_at)
            VALUES (:id, :clinicId, :patientId, :providerId, :toothNumber, :title, :description, :icdCode, :diagnosedAt)
            """.formatted(s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", cid)
                .addValue("patientId", patientId)
                .addValue("providerId", req.providerId())
                .addValue("toothNumber", req.toothNumber())
                .addValue("title", req.title())
                .addValue("description", req.description())
                .addValue("icdCode", req.icdCode())
                .addValue("diagnosedAt", req.diagnosedAt() != null ? req.diagnosedAt() : LocalDate.now()));
        return findByPatient(patientId).stream()
                .filter(d -> d.id().equals(id))
                .findFirst().orElseThrow();
    }

    public DiagnosiDto update(UUID patientId, UUID diagnosiId, UpdateDiagnosiRequest req) {
        String sql = """
            UPDATE %s.patient_diagnoses
            SET title = :title, description = :description, icd_code = :icdCode,
                status = :status, resolved_at = :resolvedAt, updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId AND patient_id = :patientId
            """.formatted(s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("title", req.title())
                .addValue("description", req.description())
                .addValue("icdCode", req.icdCode())
                .addValue("status", req.status())
                .addValue("resolvedAt", req.resolvedAt())
                .addValue("id", diagnosiId)
                .addValue("clinicId", clinicId())
                .addValue("patientId", patientId));
        return findByPatient(patientId).stream()
                .filter(d -> d.id().equals(diagnosiId))
                .findFirst().orElseThrow();
    }

    public void delete(UUID patientId, UUID diagnosiId) {
        jdbc.update(
                "DELETE FROM %s.patient_diagnoses WHERE id = :id AND clinic_id = :clinicId AND patient_id = :patientId"
                        .formatted(s()),
                new MapSqlParameterSource("id", diagnosiId)
                        .addValue("clinicId", clinicId())
                        .addValue("patientId", patientId));
    }
}
