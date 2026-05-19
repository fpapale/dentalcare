package com.dentalcare.service;

import com.dentalcare.dto.ClinicalHistoryEntryDto;
import com.dentalcare.dto.CreateClinicalHistoryEntryRequest;
import com.dentalcare.dto.OdontogramSummaryDto;
import com.dentalcare.dto.TreatmentPlanSummaryDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
public class ClinicalRecordService {

    private final NamedParameterJdbcTemplate jdbc;

    public ClinicalRecordService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    public List<ClinicalHistoryEntryDto> findDiary(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT che.id, che.entry_date,
                   concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
                   che.tooth_number, che.service_name,
                   che.clinical_notes, che.next_visit_notes
            FROM %s.clinical_history_entries che
            JOIN %s.providers prov ON prov.id = che.provider_id AND prov.clinic_id = che.clinic_id
            WHERE che.clinic_id = :clinicId
              AND che.patient_id = :patientId
            ORDER BY che.entry_date DESC
            LIMIT 50
            """.formatted(s(), s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        return jdbc.query(sql, params, (rs, n) -> new ClinicalHistoryEntryDto(
                rs.getObject("id", UUID.class),
                rs.getDate("entry_date") != null ? rs.getDate("entry_date").toLocalDate() : null,
                rs.getString("provider_name"),
                rs.getString("tooth_number"),
                rs.getString("service_name"),
                rs.getString("clinical_notes"),
                rs.getString("next_visit_notes")
        ));
    }

    public ClinicalHistoryEntryDto createDiaryEntry(UUID patientId, CreateClinicalHistoryEntryRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();
        String insert = """
            INSERT INTO %s.clinical_history_entries
                (id, clinic_id, patient_id, provider_id, entry_date,
                 tooth_number, service_code, service_name, clinical_notes, materials_used, next_visit_notes)
            VALUES (:id, :clinicId, :patientId, :providerId, :entryDate,
                    :toothNumber, :serviceCode, :serviceName, :clinicalNotes, :materialsUsed, :nextVisitNotes)
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId)
                .addValue("providerId", request.providerId())
                .addValue("entryDate", request.entryDate() != null ? request.entryDate() : LocalDate.now())
                .addValue("toothNumber", request.toothNumber())
                .addValue("serviceCode", request.serviceCode())
                .addValue("serviceName", request.serviceName())
                .addValue("clinicalNotes", request.clinicalNotes())
                .addValue("materialsUsed", request.materialsUsed())
                .addValue("nextVisitNotes", request.nextVisitNotes());
        jdbc.update(insert, params);

        String select = """
            SELECT che.id, che.entry_date,
                   concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
                   che.tooth_number, che.service_name,
                   che.clinical_notes, che.next_visit_notes
            FROM %s.clinical_history_entries che
            JOIN %s.providers prov ON prov.id = che.provider_id AND prov.clinic_id = che.clinic_id
            WHERE che.id = :id AND che.clinic_id = :clinicId
            """.formatted(s(), s());
        return jdbc.queryForObject(select,
                new MapSqlParameterSource("id", id).addValue("clinicId", clinicId),
                (rs, n) -> new ClinicalHistoryEntryDto(
                        rs.getObject("id", UUID.class),
                        rs.getDate("entry_date") != null ? rs.getDate("entry_date").toLocalDate() : null,
                        rs.getString("provider_name"),
                        rs.getString("tooth_number"),
                        rs.getString("service_name"),
                        rs.getString("clinical_notes"),
                        rs.getString("next_visit_notes")
                ));
    }

    public List<TreatmentPlanSummaryDto> findTreatmentPlans(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT tp.id, tp.name, tp.status::text,
                   COUNT(tpi.id)                                          AS total_items,
                   COUNT(tpi.id) FILTER (WHERE tpi.status = 'completed') AS completed_items,
                   COUNT(tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled')) AS open_items,
                   tp.created_at, tp.updated_at
            FROM %s.treatment_plans tp
            LEFT JOIN %s.treatment_plan_items tpi
                   ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = tp.clinic_id
            WHERE tp.clinic_id = :clinicId
              AND tp.patient_id = :patientId
            GROUP BY tp.id, tp.name, tp.status, tp.created_at, tp.updated_at
            ORDER BY tp.updated_at DESC
            """.formatted(s(), s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        return jdbc.query(sql, params, (rs, n) -> new TreatmentPlanSummaryDto(
                rs.getObject("id", UUID.class),
                rs.getString("name"),
                rs.getString("status"),
                rs.getInt("total_items"),
                rs.getInt("completed_items"),
                rs.getInt("open_items"),
                rs.getTimestamp("created_at") != null
                        ? rs.getTimestamp("created_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getTimestamp("updated_at") != null
                        ? rs.getTimestamp("updated_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null
        ));
    }

    public OdontogramSummaryDto findOdontogramSummary(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT
                COUNT(DISTINCT tooth_fdi)                                                        AS total_teeth,
                COUNT(DISTINCT tooth_fdi) FILTER (WHERE surface = 'WHOLE' AND condition = 'missing')  AS missing_teeth,
                COUNT(DISTINCT tooth_fdi) FILTER (WHERE surface = 'WHOLE' AND condition NOT IN ('missing','extracted')) AS treated_teeth,
                MAX(updated_at)                                                                  AS last_updated_at
            FROM %s.tooth_conditions
            WHERE clinic_id = :clinicId
              AND patient_id = :patientId
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        return jdbc.queryForObject(sql, params, (rs, n) -> {
            int total = rs.getInt("total_teeth");
            int missing = rs.getInt("missing_teeth");
            int treated = rs.getInt("treated_teeth");
            return new OdontogramSummaryDto(
                    total > 0,
                    total,
                    Math.max(0, 32 - missing - treated),
                    missing,
                    treated,
                    rs.getTimestamp("last_updated_at") != null
                            ? rs.getTimestamp("last_updated_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null
            );
        });
    }
}
