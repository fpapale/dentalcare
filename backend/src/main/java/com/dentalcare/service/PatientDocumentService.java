package com.dentalcare.service;

import com.dentalcare.dto.PatientDocumentSummaryDto;
import com.dentalcare.dto.UpdatePatientDocumentRequest;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class PatientDocumentService {

    private static final Logger log = LoggerFactory.getLogger(PatientDocumentService.class);

    private final NamedParameterJdbcTemplate jdbc;
    private final MinioStorageService minio;

    public PatientDocumentService(NamedParameterJdbcTemplate jdbc, MinioStorageService minio) {
        this.jdbc = jdbc;
        this.minio = minio;
    }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }
    private UUID currentProviderId() {
        return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName());
    }

    @Transactional(readOnly = true)
    public List<PatientDocumentSummaryDto> findAll(UUID patientId) {
        String sql = """
            SELECT id, document_type, title, file_name, mime_type, file_size_bytes, notes, taken_at, created_at
            FROM %s.patient_documents
            WHERE patient_id = :patientId AND clinic_id = :clinicId
            ORDER BY taken_at DESC NULLS LAST, created_at DESC
            """.formatted(s());
        List<Map<String, Object>> rows = jdbc.queryForList(sql,
                new MapSqlParameterSource()
                        .addValue("patientId", patientId)
                        .addValue("clinicId", clinicId()));
        return rows.stream().map(this::mapSummary).toList();
    }

    @Transactional
    public PatientDocumentSummaryDto upload(UUID patientId, MultipartFile file,
                                            String title, String documentType,
                                            String notes, LocalDate takenAt) {
        UUID clinic = clinicId();
        UUID docId = UUID.randomUUID();
        String safeFileName = sanitizeFileName(file.getOriginalFilename());
        String objectKey = buildObjectKey(patientId, docId, safeFileName);
        String mimeType = file.getContentType() != null ? file.getContentType() : "application/octet-stream";

        try {
            minio.upload(objectKey, file.getBytes(), mimeType);
        } catch (IOException e) {
            throw new RuntimeException("Upload failed for patient " + patientId, e);
        }

        String sql = """
            INSERT INTO %s.patient_documents
                (id, clinic_id, patient_id, document_type, title, file_name, file_path,
                 file_size_bytes, mime_type, notes, taken_at, uploaded_by_provider_id)
            VALUES
                (:id, :clinicId, :patientId, :documentType::dentalcare.document_type, :title,
                 :fileName, :filePath, :fileSizeBytes, :mimeType, :notes, :takenAt, :uploadedBy)
            """.formatted(s());

        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", docId)
                .addValue("clinicId", clinic)
                .addValue("patientId", patientId)
                .addValue("documentType", documentType != null ? documentType : "altro")
                .addValue("title", title)
                .addValue("fileName", safeFileName)
                .addValue("filePath", objectKey)
                .addValue("fileSizeBytes", file.getSize())
                .addValue("mimeType", mimeType)
                .addValue("notes", notes)
                .addValue("takenAt", takenAt)
                .addValue("uploadedBy", currentProviderId()));

        return findById(patientId, docId);
    }

    @Transactional(readOnly = true)
    public PatientDocumentSummaryDto findById(UUID patientId, UUID docId) {
        UUID clinic = clinicId();
        String sql = """
            SELECT id, document_type, title, file_name, mime_type, file_size_bytes, notes, taken_at, created_at
            FROM %s.patient_documents
            WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
            """.formatted(s());
        List<Map<String, Object>> rows = jdbc.queryForList(sql,
                new MapSqlParameterSource()
                        .addValue("id", docId)
                        .addValue("patientId", patientId)
                        .addValue("clinicId", clinic));
        if (rows.isEmpty()) throw new ResourceNotFoundException("Document not found: " + docId);
        return mapSummary(rows.getFirst());
    }

    @Transactional(readOnly = true)
    public byte[] downloadContent(UUID patientId, UUID docId) {
        UUID clinic = clinicId();
        String sql = """
            SELECT file_path FROM %s.patient_documents
            WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
            """.formatted(s());
        List<Map<String, Object>> rows = jdbc.queryForList(sql,
                new MapSqlParameterSource()
                        .addValue("id", docId)
                        .addValue("patientId", patientId)
                        .addValue("clinicId", clinic));
        if (rows.isEmpty()) throw new ResourceNotFoundException("Document not found: " + docId);
        return minio.download((String) rows.getFirst().get("file_path"));
    }

    @Transactional
    public PatientDocumentSummaryDto updateMetadata(UUID patientId, UUID docId,
                                                     UpdatePatientDocumentRequest req) {
        UUID clinic = clinicId();
        String sql = """
            UPDATE %s.patient_documents
            SET title         = :title,
                document_type = :documentType::dentalcare.document_type,
                notes         = :notes,
                taken_at      = :takenAt,
                updated_at    = now()
            WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
            """.formatted(s());
        int updated = jdbc.update(sql, new MapSqlParameterSource()
                .addValue("title", req.title())
                .addValue("documentType", req.documentType() != null ? req.documentType() : "altro")
                .addValue("notes", req.notes())
                .addValue("takenAt", req.takenAt())
                .addValue("id", docId)
                .addValue("patientId", patientId)
                .addValue("clinicId", clinic));
        if (updated == 0) throw new ResourceNotFoundException("Document not found: " + docId);
        return findById(patientId, docId);
    }

    @Transactional
    public void delete(UUID patientId, UUID docId) {
        UUID clinic = clinicId();
        String selectSql = """
            SELECT file_path FROM %s.patient_documents
            WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
            """.formatted(s());
        List<Map<String, Object>> rows = jdbc.queryForList(selectSql,
                new MapSqlParameterSource()
                        .addValue("id", docId)
                        .addValue("patientId", patientId)
                        .addValue("clinicId", clinic));
        if (rows.isEmpty()) throw new ResourceNotFoundException("Document not found: " + docId);
        String objectKey = (String) rows.getFirst().get("file_path");

        jdbc.update(
                "DELETE FROM %s.patient_documents WHERE id = :id AND clinic_id = :clinicId".formatted(s()),
                new MapSqlParameterSource().addValue("id", docId).addValue("clinicId", clinic));

        try {
            minio.delete(objectKey);
        } catch (Exception e) {
            log.warn("MinIO delete failed for key={} (file orphaned): {}", objectKey, e.getMessage());
        }
    }

    private String buildObjectKey(UUID patientId, UUID docId, String fileName) {
        return "%s/patients/%s/%s/%s".formatted(s(), patientId, docId, fileName);
    }

    private String sanitizeFileName(String original) {
        if (original == null || original.isBlank()) return "document";
        return original.replaceAll("[^a-zA-Z0-9._-]", "_").toLowerCase();
    }

    private PatientDocumentSummaryDto mapSummary(Map<String, Object> row) {
        return new PatientDocumentSummaryDto(
                (UUID) row.get("id"),
                (String) row.get("document_type"),
                (String) row.get("title"),
                (String) row.get("file_name"),
                (String) row.get("mime_type"),
                row.get("file_size_bytes") != null ? ((Number) row.get("file_size_bytes")).longValue() : null,
                (String) row.get("notes"),
                row.get("taken_at") != null ? ((java.sql.Date) row.get("taken_at")).toLocalDate() : null,
                row.get("created_at") != null ? ((Timestamp) row.get("created_at")).toLocalDateTime() : null
        );
    }
}
