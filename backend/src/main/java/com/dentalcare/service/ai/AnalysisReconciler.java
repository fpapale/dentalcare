package com.dentalcare.service.ai;

import com.dentalcare.security.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;

@Component
public class AnalysisReconciler {

    private static final Logger log = LoggerFactory.getLogger(AnalysisReconciler.class);
    private static final Duration STALE_AFTER = Duration.ofMinutes(2);

    private final JdbcTemplate jdbc;
    private final PatientDocumentAnalysisService service;

    public AnalysisReconciler(JdbcTemplate jdbc, PatientDocumentAnalysisService service) {
        this.jdbc = jdbc; this.service = service;
    }

    /** Every 2 minutes, across all tenant schemas, recover PROCESSING analyses whose callback was lost. */
    @Scheduled(fixedDelay = 120_000L)
    public void reconcile() {
        List<String> schemas = jdbc.queryForList(
                "SELECT schema_name FROM information_schema.schemata WHERE schema_name ~ '^t_[0-9a-f]{8}$'",
                String.class);
        for (String schema : schemas) {
            try {
                TenantContext.setCurrentSchema(schema);
                for (var stale : service.findStaleProcessing(STALE_AFTER)) {
                    try {
                        service.reconcileOne(stale);
                    } catch (Exception e) {
                        log.warn("reconcileOne failed schema={} analysis={}: {}", schema, stale.id(), e.getMessage());
                    }
                }
            } finally {
                TenantContext.clear();
            }
        }
    }
}
