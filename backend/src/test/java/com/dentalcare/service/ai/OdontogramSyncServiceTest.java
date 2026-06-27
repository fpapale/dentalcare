package com.dentalcare.service.ai;

import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class OdontogramSyncServiceTest {

    private NamedParameterJdbcTemplate jdbc;
    private OdontogramSyncService svc;

    @BeforeEach
    void setUp() {
        jdbc = mock(NamedParameterJdbcTemplate.class);
        svc = new OdontogramSyncService(jdbc);
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(UUID.randomUUID().toString());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    @Test
    void sync_insertsCariesForMappableLabelsOnly() {
        UUID analysisId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        when(jdbc.queryForList(contains("patient_document_labels"), any(MapSqlParameterSource.class))).thenReturn(List.of(
                Map.of("tooth_fdi", "16", "disease", "Caries"),
                Map.of("tooth_fdi", "26", "disease", "Deep_Caries"),
                Map.of("tooth_fdi", "36", "disease", "Periapical_Lesion"), // skipped
                new java.util.HashMap<>() {{ put("tooth_fdi", null); put("disease", "Caries"); }} // skipped (no tooth)
        ));
        svc.syncFromAnalysis(patientId, analysisId);
        // 1 delete (ai rows for this analysis) + 2 inserts (16, 26)
        verify(jdbc, times(1)).update(contains("DELETE"), any(MapSqlParameterSource.class));
        verify(jdbc, times(2)).update(contains("INSERT"), any(MapSqlParameterSource.class));
    }
}
