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
        Map<String, Object> row = Map.of(
                "id", docId, "document_type", "rx_panoramica", "title", "RX 2026",
                "file_name", "rx.jpg", "mime_type", "image/jpeg",
                "file_size_bytes", 1024L, "created_at", now);

        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(row));

        List<PatientDocumentSummaryDto> result = service.findAll(patientId);

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().documentType()).isEqualTo("rx_panoramica");
        assertThat(result.getFirst().title()).isEqualTo("RX 2026");
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
        String objectKey = "t_abcd1234/patients/" + patientId + "/" + docId + "/file.jpg";
        when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                .thenReturn(List.of(Map.of("file_path", objectKey)));
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(1);

        service.delete(patientId, docId);

        verify(jdbc).update(anyString(), any(MapSqlParameterSource.class));
        verify(minio).delete(objectKey);
    }
}
