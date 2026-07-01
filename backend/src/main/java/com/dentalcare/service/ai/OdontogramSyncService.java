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

    /** AI disease (DENTEX) -> DentalCare odontogram condition (consistent for every tenant). */
    private static final Map<String, String> DISEASE_TO_CONDITION = Map.of(
            "Caries", "cavity",
            "Deep_Caries", "cavity",
            "Periapical_Lesion", "root_canal",
            "Impacted", "impacted"
    );
    /** Surface-scoped conditions go on the vestibular surface; the rest are whole-tooth. */
    private static final Set<String> SURFACE_CONDITIONS = Set.of("cavity", "filling");
    private static final String DEFAULT_SURFACE = "B";   // vestibular key used by the odontogram UI; panoramic gives no real surface, dentist refines
    private static final String WHOLE_SURFACE = "WHOLE"; // whole-tooth conditions (root_canal, impacted)

    private final NamedParameterJdbcTemplate jdbc;

    public OdontogramSyncService(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }

    @Transactional
    public void syncFromAnalysis(UUID patientId, UUID analysisId) {
        log.info("syncFromAnalysis patientId={} analysisId={}", patientId, analysisId);

        UUID clinic = clinicId();

        // Replace ALL prior AI rows for this patient (latest analysis wins), never touching
        // manual rows. Scoping the delete to one analysis_id would let stale AI rows from an
        // earlier analysis block re-insertion via the (clinic,patient,tooth,surface) constraint.
        jdbc.update("""
                DELETE FROM %s.tooth_conditions
                WHERE clinic_id = :clinic AND patient_id = :pat AND source = 'ai'
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("clinic", clinic).addValue("pat", patientId));

        List<Map<String, Object>> labels = jdbc.queryForList("""
                SELECT tooth_fdi, disease, disease_confidence FROM %s.patient_document_labels
                WHERE analysis_id = :aid
                """.formatted(s()), new MapSqlParameterSource("aid", analysisId));

        for (Map<String, Object> label : labels) {
            String tooth = (String) label.get("tooth_fdi");
            String disease = (String) label.get("disease");
            String condition = disease == null ? null : DISEASE_TO_CONDITION.get(disease);
            if (tooth == null || condition == null) continue;

            short toothNum;
            try {
                toothNum = Short.parseShort(tooth);
            } catch (NumberFormatException e) {
                log.warn("syncFromAnalysis: skipping label with unparseable tooth_fdi='{}' for analysis {}", tooth, analysisId);
                continue;
            }

            String surface = SURFACE_CONDITIONS.contains(condition) ? DEFAULT_SURFACE : WHOLE_SURFACE;

            jdbc.update("""
                    INSERT INTO %s.tooth_conditions
                      (id, clinic_id, patient_id, tooth_fdi, surface, condition, notes, source, analysis_id, updated_at)
                    VALUES (:id, :clinic, :pat, :tooth, :surface, :condition, :notes, 'ai', :aid, now())
                    ON CONFLICT (clinic_id, patient_id, tooth_fdi, surface) DO NOTHING
                    """.formatted(s()), new MapSqlParameterSource()
                    .addValue("id", UUID.randomUUID()).addValue("clinic", clinic).addValue("pat", patientId)
                    .addValue("tooth", toothNum).addValue("surface", surface).addValue("condition", condition)
                    .addValue("notes", "AI: " + disease).addValue("aid", analysisId));
        }
    }
}
