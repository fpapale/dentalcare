package com.dentalcare.service.ai;

import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Stub — implemented in Task B10.
 */
@Service
public class OdontogramSyncService {

    private final NamedParameterJdbcTemplate jdbc;

    public OdontogramSyncService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void syncFromAnalysis(UUID patientId, UUID analysisId) {
        /* implemented in B10 */
    }
}
