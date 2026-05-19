package com.dentalcare.service;

import com.dentalcare.dto.CreatePrescrizioneRequest;
import com.dentalcare.dto.PrescrizioneDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

@Service
public class PrescrizioneService {

    private final NamedParameterJdbcTemplate jdbc;

    public PrescrizioneService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }

    public List<PrescrizioneDto> findByPatient(UUID patientId) {
        String sql = """
            SELECT pr.id, pr.drug_name, pr.dosage, pr.frequency, pr.duration, pr.notes,
                   pr.prescribed_at, pr.expires_at, pr.active, pr.created_at,
                   concat_ws(' ', p.last_name, p.first_name) AS provider_name
            FROM %s.patient_prescriptions pr
            JOIN %s.providers p ON p.id = pr.provider_id AND p.clinic_id = pr.clinic_id
            WHERE pr.clinic_id = :clinicId AND pr.patient_id = :patientId
            ORDER BY pr.prescribed_at DESC
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource("clinicId", clinicId()).addValue("patientId", patientId),
                (rs, n) -> new PrescrizioneDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("drug_name"),
                        rs.getString("dosage"),
                        rs.getString("frequency"),
                        rs.getString("duration"),
                        rs.getString("notes"),
                        rs.getString("provider_name"),
                        rs.getDate("prescribed_at") != null ? rs.getDate("prescribed_at").toLocalDate() : null,
                        rs.getDate("expires_at") != null ? rs.getDate("expires_at").toLocalDate() : null,
                        rs.getBoolean("active"),
                        rs.getTimestamp("created_at") != null
                                ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null
                ));
    }

    public PrescrizioneDto create(UUID patientId, CreatePrescrizioneRequest req) {
        UUID id = UUID.randomUUID();
        UUID cid = clinicId();
        String sql = """
            INSERT INTO %s.patient_prescriptions
                (id, clinic_id, patient_id, provider_id, drug_name, dosage, frequency, duration, notes, prescribed_at, expires_at)
            VALUES (:id, :clinicId, :patientId, :providerId, :drugName, :dosage, :frequency, :duration, :notes, :prescribedAt, :expiresAt)
            """.formatted(s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", cid)
                .addValue("patientId", patientId)
                .addValue("providerId", req.providerId())
                .addValue("drugName", req.drugName())
                .addValue("dosage", req.dosage())
                .addValue("frequency", req.frequency())
                .addValue("duration", req.duration())
                .addValue("notes", req.notes())
                .addValue("prescribedAt", req.prescribedAt() != null ? req.prescribedAt() : LocalDate.now())
                .addValue("expiresAt", req.expiresAt()));
        return findByPatient(patientId).stream()
                .filter(p -> p.id().equals(id))
                .findFirst().orElseThrow();
    }

    public PrescrizioneDto deactivate(UUID patientId, UUID prescrizioneId) {
        String sql = """
            UPDATE %s.patient_prescriptions
            SET active = false, updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId AND patient_id = :patientId
            """.formatted(s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", prescrizioneId)
                .addValue("clinicId", clinicId())
                .addValue("patientId", patientId));
        return findByPatient(patientId).stream()
                .filter(p -> p.id().equals(prescrizioneId))
                .findFirst().orElseThrow();
    }

    public void delete(UUID patientId, UUID prescrizioneId) {
        jdbc.update(
                "DELETE FROM %s.patient_prescriptions WHERE id = :id AND clinic_id = :clinicId AND patient_id = :patientId"
                        .formatted(s()),
                new MapSqlParameterSource("id", prescrizioneId)
                        .addValue("clinicId", clinicId())
                        .addValue("patientId", patientId));
    }
}
