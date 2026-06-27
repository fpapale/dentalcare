package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.*;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.MinioStorageService;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class PatientDocumentAnalysisService {

    private static final com.fasterxml.jackson.databind.ObjectMapper MAPPER = new com.fasterxml.jackson.databind.ObjectMapper();

    private final NamedParameterJdbcTemplate jdbc;
    private final MinioStorageService minio;
    private final AiInferenceClient ai;
    private final SseEmitterRegistry sse;

    public PatientDocumentAnalysisService(NamedParameterJdbcTemplate jdbc, MinioStorageService minio,
                                          AiInferenceClient ai, SseEmitterRegistry sse) {
        this.jdbc = jdbc; this.minio = minio; this.ai = ai; this.sse = sse;
    }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }
    private UUID providerId() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) throw new IllegalStateException("No authenticated provider in context");
        return UUID.fromString(auth.getName());
    }

    public record StaleAnalysis(UUID id, String jobId, String resultBucket) {}

    public StartAnalysisResponse startAnalysis(UUID patientId, UUID documentId) {
        Map<String, Object> doc = jdbc.queryForList("""
                SELECT document_type, file_path FROM %s.patient_documents
                WHERE id = :doc AND patient_id = :pat AND clinic_id = :clinic
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("doc", documentId).addValue("pat", patientId).addValue("clinic", clinicId()))
                .stream().findFirst().orElseThrow(() -> new ResourceNotFoundException("Document not found"));
        if (!"rx_panoramica".equals(doc.get("document_type"))) {
            throw new IllegalArgumentException("Only rx_panoramica can be analyzed");
        }

        UUID analysisId = UUID.randomUUID();
        String bucket = minio.bucketFor(s());
        String outputPrefix = "patients/%s/%s/ai/%s/".formatted(patientId, documentId, analysisId);

        jdbc.update("""
                INSERT INTO %s.patient_document_analyses
                  (id, clinic_id, patient_id, document_id, status, result_bucket, requested_by_provider_id)
                VALUES (:id, :clinic, :pat, :doc, 'PROCESSING', :bucket, :prov)
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("id", analysisId).addValue("clinic", clinicId()).addValue("pat", patientId)
                .addValue("doc", documentId).addValue("bucket", bucket).addValue("prov", providerId()));

        AiJobRequest jobReq = new AiJobRequest(
                patientId.toString(), documentId.toString(), analysisId.toString(), s(),
                bucket, (String) doc.get("file_path"), bucket, outputPrefix, true,
                Map.of("source", "DentalCare"));
        String jobId;
        try {
            jobId = ai.createJob(jobReq);
        } catch (Exception e) {
            jdbc.update("UPDATE %s.patient_document_analyses SET status='FAILED', error_message=:err, updated_at=now() WHERE id=:id".formatted(s()),
                    new MapSqlParameterSource().addValue("err", e.getMessage()).addValue("id", analysisId));
            throw new IllegalStateException("AI service unavailable", e);
        }
        jdbc.update("UPDATE %s.patient_document_analyses SET job_id=:job, updated_at=now() WHERE id=:id".formatted(s()),
                new MapSqlParameterSource().addValue("job", jobId).addValue("id", analysisId));
        return new StartAnalysisResponse(analysisId, "PROCESSING", jobId);
    }

    /** Idempotent: writes labels + COMPLETED/FAILED only if the row is still PROCESSING. */
    @Transactional
    public void applyCallback(AiCallbackRequest cb) {
        String schema = TenantContext.validatedSchema();
        if (!schema.equals(cb.schema_name())) {
            throw new IllegalStateException("Schema mismatch: context=" + schema + " payload=" + cb.schema_name());
        }
        UUID analysisId = UUID.fromString(cb.analysis_id());
        boolean failed = "failed".equalsIgnoreCase(cb.status());
        String newStatus = failed ? "FAILED" : "COMPLETED";

        int updated = jdbc.update("""
                UPDATE %s.patient_document_analyses
                SET status = CAST(:status AS dentalcare.ai_analysis_status),
                    result_object_key = :resKey, annotated_object_key = :annKey,
                    detections_count = :count, needs_review = :needsReview,
                    error_message = :err, updated_at = now()
                WHERE id = :id AND status = 'PROCESSING'
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("status", newStatus)
                .addValue("resKey", cb.result_object_key())
                .addValue("annKey", cb.annotated_object_key())
                .addValue("count", cb.detections() == null ? 0 : cb.detections().size())
                .addValue("needsReview", cb.detections() != null && cb.detections().stream()
                        .anyMatch(d -> Boolean.TRUE.equals(d.needs_review())))
                .addValue("err", cb.error())
                .addValue("id", analysisId));

        if (updated == 0) return;  // already finalized — idempotent no-op

        if (!failed && cb.detections() != null) {
            for (AiCallbackRequest.Detection d : cb.detections()) {
                List<Integer> b = d.bbox_xyxy();
                if (b == null || b.size() < 4) {
                    continue;  // skip malformed detection; row still finalizes
                }
                jdbc.update("""
                        INSERT INTO %s.patient_document_labels
                          (analysis_id, tooth_fdi, disease, disease_confidence, fdi_confidence,
                           bbox_x1, bbox_y1, bbox_x2, bbox_y2, matching_method, matching_score, needs_review, source)
                        VALUES (:aid, :tooth, :disease, :dconf, :fconf, :x1, :y1, :x2, :y2, :method, :score, :nr, 'ai')
                        """.formatted(s()), new MapSqlParameterSource()
                        .addValue("aid", analysisId).addValue("tooth", d.tooth()).addValue("disease", d.disease())
                        .addValue("dconf", d.disease_confidence()).addValue("fconf", d.fdi_confidence())
                        .addValue("x1", b.get(0)).addValue("y1", b.get(1)).addValue("x2", b.get(2)).addValue("y2", b.get(3))
                        .addValue("method", d.matching_method()).addValue("score", d.matching_score())
                        .addValue("nr", Boolean.TRUE.equals(d.needs_review())));
            }
        }
        sse.emit(analysisId, newStatus);
    }

    @Transactional(readOnly = true)
    public AnalysisDto getAnalysis(UUID patientId, UUID analysisId) {
        Map<String, Object> a = jdbc.queryForList("""
                SELECT * FROM %s.patient_document_analyses
                WHERE id = :id AND patient_id = :pat AND clinic_id = :clinic
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("id", analysisId).addValue("pat", patientId).addValue("clinic", clinicId()))
                .stream().findFirst().orElseThrow(() -> new ResourceNotFoundException("Analysis not found"));
        List<LabelDto> labels = jdbc.query("""
                SELECT * FROM %s.patient_document_labels WHERE analysis_id = :id ORDER BY created_at
                """.formatted(s()), new MapSqlParameterSource("id", analysisId), (rs, n) -> new LabelDto(
                rs.getObject("id", UUID.class), rs.getString("tooth_fdi"), rs.getString("disease"),
                (Double) rs.getObject("disease_confidence"), (Double) rs.getObject("fdi_confidence"),
                rs.getInt("bbox_x1"), rs.getInt("bbox_y1"), rs.getInt("bbox_x2"), rs.getInt("bbox_y2"),
                rs.getString("matching_method"), (Double) rs.getObject("matching_score"),
                rs.getBoolean("needs_review"), rs.getString("source"), rs.getString("action")));
        return mapAnalysis(a, labels);
    }

    @Transactional(readOnly = true)
    public List<AnalysisDto> listByDocument(UUID patientId, UUID documentId) {
        return jdbc.queryForList("""
                SELECT * FROM %s.patient_document_analyses
                WHERE document_id = :doc AND patient_id = :pat AND clinic_id = :clinic
                ORDER BY created_at DESC
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("doc", documentId).addValue("pat", patientId).addValue("clinic", clinicId()))
                .stream().map(a -> mapAnalysis(a, List.of())).toList();
    }

    @Transactional(readOnly = true)
    public List<StaleAnalysis> findStaleProcessing(Duration olderThan) {
        return jdbc.query("""
                SELECT id, job_id, result_bucket FROM %s.patient_document_analyses
                WHERE status = 'PROCESSING' AND job_id IS NOT NULL
                  AND updated_at < now() - (:secs * interval '1 second')
                """.formatted(s()), new MapSqlParameterSource("secs", olderThan.getSeconds()),
                (rs, n) -> new StaleAnalysis(rs.getObject("id", UUID.class), rs.getString("job_id"), rs.getString("result_bucket")));
    }

    @Transactional
    public AnalysisDto review(UUID patientId, UUID analysisId, com.dentalcare.dto.ai.ReviewAnalysisRequest req) {
        int updated = jdbc.update("""
                UPDATE %s.patient_document_analyses
                SET review_status = CAST(:rs AS dentalcare.ai_review_status),
                    reviewed_by_provider_id = :prov, reviewed_at = now(), updated_at = now()
                WHERE id = :id AND patient_id = :pat AND clinic_id = :clinic AND status = 'COMPLETED'
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("rs", req.reviewStatus()).addValue("prov", providerId())
                .addValue("id", analysisId).addValue("pat", patientId).addValue("clinic", clinicId()));
        if (updated == 0) throw new ResourceNotFoundException("Analysis not found or not completed");
        return getAnalysis(patientId, analysisId);
    }

    /** Reconciler entry: re-applies a completed job whose callback was lost. */
    @Transactional
    public void reconcileOne(StaleAnalysis stale) {
        Map<String, Object> status = ai.getJobStatus(stale.resultBucket(), stale.jobId());
        if (status == null) return;
        if (!"completed".equalsIgnoreCase(String.valueOf(status.get("status")))) return;
        // Rebuild a callback from the job-status document and apply it idempotently.
        // The job-status 'detections' have the same field names as the callback detections.
        java.util.Map<String, Object> payload = new java.util.HashMap<>();
        payload.put("job_id", stale.jobId());
        payload.put("status", "completed");
        payload.put("schema_name", s());
        payload.put("analysis_id", stale.id().toString());
        payload.put("patient_id", "");
        payload.put("document_id", "");
        payload.put("result_bucket", stale.resultBucket());
        payload.put("result_object_key", status.get("result_object_key"));
        payload.put("annotated_object_key", status.get("annotated_image_object_key"));
        payload.put("detections", status.getOrDefault("detections", java.util.List.of()));
        AiCallbackRequest cb = MAPPER.convertValue(payload, AiCallbackRequest.class);
        applyCallback(cb);
    }

    private AnalysisDto mapAnalysis(Map<String, Object> a, List<LabelDto> labels) {
        return new AnalysisDto(
                (UUID) a.get("id"), (UUID) a.get("patient_id"), (UUID) a.get("document_id"),
                String.valueOf(a.get("status")), a.get("detections_count") != null ? ((Number) a.get("detections_count")).intValue() : 0,
                Boolean.TRUE.equals(a.get("needs_review")), String.valueOf(a.get("review_status")),
                (String) a.get("result_bucket"), (String) a.get("result_object_key"),
                (String) a.get("annotated_object_key"), (String) a.get("error_message"),
                a.get("created_at") != null ? ((java.sql.Timestamp) a.get("created_at")).toLocalDateTime() : (LocalDateTime) null,
                labels);
    }
}
