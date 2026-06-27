package com.dentalcare.service.ai;

import com.dentalcare.security.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class OdontogramSyncService {

    private static final Logger log = LoggerFactory.getLogger(OdontogramSyncService.class);

    private static final Set<String> CARIES_DISEASES = Set.of("Caries", "Deep_Caries");
    private static final String DEFAULT_SURFACE = "V";  // panoramic gives no surface; dentist can refine

    private final NamedParameterJdbcTemplate jdbc;

    public OdontogramSyncService(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }

    @Transactional
    public void syncFromAnalysis(UUID patientId, UUID analysisId) {
        log.info("syncFromAnalysis patientId={} analysisId={}", patientId, analysisId);

        UUID clinic = clinicId();

        // Remove prior AI rows for THIS analysis (idempotent re-review), never touching manual rows.
        jdbc.update("""
                DELETE FROM %s.tooth_conditions
                WHERE clinic_id = :clinic AND patient_id = :pat AND source = 'ai' AND analysis_id = :aid
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("clinic", clinic).addValue("pat", patientId).addValue("aid", analysisId));

        List<Map<String, Object>> labels = jdbc.queryForList("""
                SELECT tooth_fdi, disease, disease_confidence FROM %s.patient_document_labels
                WHERE analysis_id = :aid
                """.formatted(s()), new MapSqlParameterSource("aid", analysisId));

        for (Map<String, Object> label : labels) {
            String tooth = (String) label.get("tooth_fdi");
            String disease = (String) label.get("disease");
            if (tooth == null || !CARIES_DISEASES.contains(disease)) continue;

            short toothNum;
            try {
                toothNum = Short.parseShort(tooth);
            } catch (NumberFormatException e) {
                log.warn("syncFromAnalysis: skipping label with unparseable tooth_fdi='{}' for analysis {}", tooth, analysisId);
                continue;
            }

            jdbc.update("""
                    INSERT INTO %s.tooth_conditions
                      (id, clinic_id, patient_id, tooth_fdi, surface, condition, notes, source, analysis_id, updated_at)
                    VALUES (:id, :clinic, :pat, :tooth, :surface, 'caries', :notes, 'ai', :aid, now())
                    ON CONFLICT (clinic_id, patient_id, tooth_fdi, surface) DO NOTHING
                    """.formatted(s()), new MapSqlParameterSource()
                    .addValue("id", UUID.randomUUID()).addValue("clinic", clinic).addValue("pat", patientId)
                    .addValue("tooth", toothNum).addValue("surface", DEFAULT_SURFACE)
                    .addValue("notes", "AI: " + disease).addValue("aid", analysisId));
        }
    }
}
