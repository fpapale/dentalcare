package com.dentalcare.service;

import com.dentalcare.dto.SaveOdontogramRequest;
import com.dentalcare.dto.ToothConditionDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class OdontogramService {

    private final NamedParameterJdbcTemplate jdbc;

    public OdontogramService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<ToothConditionDto> findByPatient(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT tooth_fdi, surface, condition, notes
            FROM dentalcare.tooth_conditions
            WHERE clinic_id = :clinicId
              AND patient_id = :patientId
            ORDER BY tooth_fdi, surface
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        return jdbc.query(sql, params, (rs, n) -> new ToothConditionDto(
                rs.getInt("tooth_fdi"),
                rs.getString("surface"),
                rs.getString("condition"),
                rs.getString("notes")
        ));
    }

    @Transactional
    public void save(UUID patientId, SaveOdontogramRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        jdbc.update("""
            DELETE FROM dentalcare.tooth_conditions
            WHERE clinic_id = :clinicId AND patient_id = :patientId
            """,
            new MapSqlParameterSource()
                    .addValue("clinicId", clinicId)
                    .addValue("patientId", patientId));

        if (request.conditions() == null || request.conditions().isEmpty()) return;

        List<ToothConditionDto> toSave = request.conditions().stream()
                .filter(c -> c.condition() != null && !"healthy".equals(c.condition()) && !"none".equals(c.condition()))
                .toList();

        if (toSave.isEmpty()) return;

        String insertSql = """
            INSERT INTO dentalcare.tooth_conditions
                (id, clinic_id, patient_id, tooth_fdi, surface, condition, notes, updated_at)
            VALUES
                (:id, :clinicId, :patientId, :toothFdi, :surface, :condition, :notes, now())
            """;

        for (ToothConditionDto c : toSave) {
            jdbc.update(insertSql, new MapSqlParameterSource()
                    .addValue("id", UUID.randomUUID())
                    .addValue("clinicId", clinicId)
                    .addValue("patientId", patientId)
                    .addValue("toothFdi", c.toothFdi())
                    .addValue("surface", c.surface())
                    .addValue("condition", c.condition())
                    .addValue("notes", c.notes()));
        }
    }
}
