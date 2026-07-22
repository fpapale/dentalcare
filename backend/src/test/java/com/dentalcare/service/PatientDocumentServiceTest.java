package com.dentalcare.service;

import com.dentalcare.dto.PatientDocumentSummaryDto;
import com.dentalcare.dto.UpdatePatientDocumentRequest;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PatientDocumentServiceTest {

    @Mock
    NamedParameterJdbcTemplate jdbc;

    @Mock
    MinioStorageService minio;

    @InjectMocks
    PatientDocumentService service;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID patientId = UUID.fromString("00000000-0000-0000-0000-000000000002");
    private final UUID docId = UUID.fromString("00000000-0000-0000-0000-000000000003");
    private final UUID providerId = UUID.fromString("00000000-0000-0000-0000-000000000004");

    @BeforeEach
    void setupContext() {
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(providerId.toString(), null, List.of()));
    }

    @AfterEach
    void clearContext() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    @Test
    void findAll_returnsListFromDb() {
        java.sql.Timestamp now = java.sql.Timestamp.valueOf(LocalDateTime.now());
        Map<String, Object> row = new java.util.HashMap<>();
        row.put("id", docId);
        row.put("document_type", "rx_panoramica");
        row.put("title", "RX 2026");
        row.put("file_name", "rx.jpg");
        row.put("mime_type", "image/jpeg");
        row.put("file_size_bytes", 1024L);
        row.put("created_at", now);
        row.put("notes", null);
        row.put("taken_at", null);

        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(row));

        List<PatientDocumentSummaryDto> result = service.findAll(patientId);

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().documentType()).isEqualTo("rx_panoramica");
        assertThat(result.getFirst().title()).isEqualTo("RX 2026");
        assertThat(result.getFirst().notes()).isNull();
        assertThat(result.getFirst().takenAt()).isNull();
    }

    @Test
    void findById_throwsWhenNotFound() {
        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of());

        assertThatThrownBy(() -> service.findById(patientId, docId))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining(docId.toString());
    }

    @Test
    void updateMetadata_throwsWhenNotFound() {
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(0);

        assertThatThrownBy(() -> service.updateMetadata(patientId, docId,
                new UpdatePatientDocumentRequest("Titolo", "altro", null, null)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_callsMinioDeleteAfterDbDelete() {
        String objectKey = "patients/" + patientId + "/" + docId + "/file.jpg";
        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(Map.of("file_path", objectKey)));
        // No AI analyses on this document -> releaseAiArtifacts is a no-op.
        when(jdbc.queryForList(contains("patient_document_analyses"), any(MapSqlParameterSource.class)))
                .thenReturn(List.of());

        service.delete(patientId, docId);

        verify(jdbc).update(anyString(), any(MapSqlParameterSource.class));
        verify(minio).delete(objectKey);
    }

    @Test
    void upload_deletesMinioObjectWhenInsertFails() throws Exception {
        // Arrange: jdbc.update throws (simulates INSERT failure)
        org.springframework.web.multipart.MultipartFile mockFile =
                mock(org.springframework.web.multipart.MultipartFile.class);
        when(mockFile.getBytes()).thenReturn(new byte[]{1, 2, 3});
        when(mockFile.getSize()).thenReturn(3L);
        when(mockFile.getContentType()).thenReturn("image/jpeg");
        when(mockFile.getOriginalFilename()).thenReturn("test.jpg");

        // First jdbc call is the INSERT (upload doesn't call queryForList)
        doThrow(new RuntimeException("DB error")).when(jdbc).update(anyString(), any(MapSqlParameterSource.class));

        // Act + Assert
        assertThatThrownBy(() -> service.upload(patientId, mockFile, "Test", "rx_panoramica", null, null))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("DB error");

        // Verify MinIO delete was called to clean up the orphan
        verify(minio).upload(anyString(), any(byte[].class), anyString());
        verify(minio).delete(anyString());
    }

    @Test
    void delete_callsMinioBeforeDb() {
        String objectKey = "patients/" + patientId + "/" + docId + "/file.jpg";
        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(Map.of("file_path", objectKey)));
        when(jdbc.queryForList(contains("patient_document_analyses"), any(MapSqlParameterSource.class)))
                .thenReturn(List.of());

        // Track call order
        org.mockito.InOrder inOrder = inOrder(minio, jdbc);

        service.delete(patientId, docId);

        inOrder.verify(minio).delete(objectKey);
        inOrder.verify(jdbc).update(anyString(), any(MapSqlParameterSource.class));
    }

    @Test
    void delete_releasesAiArtifacts_whenDocumentHasAnalyses() {
        String docKey = "patients/" + patientId + "/" + docId + "/rx.jpg";
        UUID analysisId = UUID.fromString("00000000-0000-0000-0000-0000000000aa");
        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(Map.of("file_path", docKey)));
        when(jdbc.queryForList(contains("patient_document_analyses"), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(Map.of(
                        "id", analysisId,
                        "result_object_key", "ai/result.json",
                        "annotated_object_key", "ai/annotated.png")));

        service.delete(patientId, docId);

        // Promote AI conditions to manual + mark analysis document_deleted_at + delete document row.
        org.mockito.ArgumentCaptor<String> sql = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(jdbc, times(3)).update(sql.capture(), any(MapSqlParameterSource.class));
        assertThat(sql.getAllValues()).anySatisfy(s -> assertThat(s)
                .contains("UPDATE").contains("tooth_conditions").contains("'manual'"));
        assertThat(sql.getAllValues()).anySatisfy(s -> assertThat(s).contains("document_deleted_at"));

        // AI image derivatives purged, plus the RX file itself. Analysis + labels rows are kept.
        verify(minio).delete("ai/result.json");
        verify(minio).delete("ai/annotated.png");
        verify(minio).delete(docKey);
    }
}
