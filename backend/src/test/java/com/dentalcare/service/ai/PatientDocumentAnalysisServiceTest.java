package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiCallbackRequest;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class PatientDocumentAnalysisServiceTest {

    private NamedParameterJdbcTemplate jdbc;
    private PatientDocumentAnalysisService svc;
    private SseEmitterRegistry sse;

    @BeforeEach
    void setUp() {
        jdbc = mock(NamedParameterJdbcTemplate.class);
        sse = mock(SseEmitterRegistry.class);
        svc = new PatientDocumentAnalysisService(jdbc, null, null, sse);
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(UUID.randomUUID().toString());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    @Test
    void applyCallback_completed_updatesOnlyWhenProcessing_andEmitsSse() {
        // pretend the UPDATE ... WHERE status='PROCESSING' affected 1 row
        when(jdbc.update(contains("UPDATE"), any(MapSqlParameterSource.class))).thenReturn(1);
        AiCallbackRequest cb = new AiCallbackRequest(
                "job-1", "completed", "t_abcd1234",
                UUID.randomUUID().toString(), UUID.randomUUID().toString(), UUID.randomUUID().toString(),
                "dc-t-abcd1234", "patients/x/ai/result.json", "patients/x/ai/annotated.png",
                List.of(new AiCallbackRequest.Detection("16", "Caries", 0.8, 0.7,
                        List.of(10, 10, 90, 90), "iou", 0.3, false)),
                null);
        svc.applyCallback(cb);
        verify(sse).emit(eq(UUID.fromString(cb.analysis_id())), eq("COMPLETED"));
    }

    @Test
    void applyCallback_whenAlreadyCompleted_doesNotEmit() {
        when(jdbc.update(contains("UPDATE"), any(MapSqlParameterSource.class))).thenReturn(0); // guard: no row in PROCESSING
        AiCallbackRequest cb = new AiCallbackRequest(
                "job-1", "completed", "t_abcd1234",
                UUID.randomUUID().toString(), UUID.randomUUID().toString(), UUID.randomUUID().toString(),
                "dc-t-abcd1234", "k", "a", List.of(), null);
        svc.applyCallback(cb);
        verify(sse, never()).emit(any(), any());
    }
}
