package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Traccia le azioni del Copilot AI (Segreteria AI) su tabella per-tenant ai_audit_log.
 * Il logging non deve mai far fallire l'azione applicativa che lo invoca: qualsiasi
 * errore di scrittura viene loggato a livello warn e ignorato.
 */
@Service
public class AiAuditService {

    private static final Logger log = LoggerFactory.getLogger(AiAuditService.class);

    private final NamedParameterJdbcTemplate jdbc;

    public AiAuditService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    /**
     * Registra un'azione del Copilot AI (tool call o azione confermata). Best-effort:
     * eventuali errori (es. schema non pronto, connessione) vengono solo loggati.
     */
    public void log(UUID providerId, String actionType, String toolName, String argsSummary, String result) {
        try {
            UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
            jdbc.update("""
                INSERT INTO %s.ai_audit_log
                    (clinic_id, provider_id, action_type, tool_name, args_summary, result)
                VALUES (:clinicId, :providerId, :actionType, :toolName, :argsSummary, :result)
                """.formatted(s()),
                new MapSqlParameterSource()
                    .addValue("clinicId", clinicId)
                    .addValue("providerId", providerId)
                    .addValue("actionType", actionType)
                    .addValue("toolName", toolName)
                    .addValue("argsSummary", argsSummary)
                    .addValue("result", result));
        } catch (Exception e) {
            log.warn("AiAuditService: impossibile registrare audit log (actionType={}, toolName={}): {}",
                    actionType, toolName, e.getMessage());
        }
    }
}
