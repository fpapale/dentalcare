package com.dentalcare.security;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory cache mapping clinic_id → schema_name.
 * Loaded from dentalcare.tenant_clinics + dentalcare.tenants on startup.
 * New tenants can be registered at runtime via register().
 */
@Component
public class TenantSchemaRegistry {

    private static final Logger log = LoggerFactory.getLogger(TenantSchemaRegistry.class);

    private final NamedParameterJdbcTemplate jdbc;
    private final Map<String, String> clinicToSchema = new ConcurrentHashMap<>();

    public TenantSchemaRegistry(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @PostConstruct
    public void load() {
        try {
            String sql = """
                SELECT tc.clinic_id::text, t.schema_name
                FROM dentalcare.tenant_clinics tc
                JOIN dentalcare.tenants t ON t.id = tc.tenant_id
                WHERE t.active = true
                """;
            Map<String, Object> params = new HashMap<>();
            jdbc.query(sql, params, (rs, n) -> {
                clinicToSchema.put(rs.getString("clinic_id"), rs.getString("schema_name"));
                return null;
            });
            log.info("TenantSchemaRegistry loaded {} clinic→schema mappings", clinicToSchema.size());
        } catch (Exception e) {
            log.warn("TenantSchemaRegistry: tenant tables not yet available, using pattern fallback. Error: {}", e.getMessage());
            loadFromPattern();
        }
    }

    private void loadFromPattern() {
        try {
            List<String> schemas = jdbc.getJdbcTemplate().queryForList(
                    "SELECT schema_name FROM information_schema.schemata WHERE schema_name ~ '^t_[0-9a-f]{8}$'",
                    String.class);
            for (String schema : schemas) {
                try {
                    List<String> clinicIds = jdbc.getJdbcTemplate().queryForList(
                            "SELECT DISTINCT clinic_id::text FROM " + schema + ".providers WHERE active = true",
                            String.class);
                    for (String cid : clinicIds) {
                        clinicToSchema.put(cid, schema);
                    }
                } catch (Exception ex) {
                    log.warn("TenantSchemaRegistry: clinic discovery for schema {} failed: {}", schema, ex.getMessage());
                }
            }
            log.info("TenantSchemaRegistry pattern fallback loaded {} clinic→schema mappings", clinicToSchema.size());
        } catch (Exception e) {
            log.warn("TenantSchemaRegistry: pattern fallback failed: {}", e.getMessage());
        }
    }

    /**
     * Returns schema name for the given clinic_id.
     * Falls back to the demo schema if not found (development convenience).
     */
    public String getSchemaForClinic(String clinicId) {
        return clinicToSchema.getOrDefault(clinicId, "t_9d754153");
    }

    /**
     * Returns schema name for the given clinic_id, or empty if not registered.
     * Use this in auth flows where missing clinic must produce a 404, not a fallback.
     */
    public Optional<String> findSchemaForClinic(String clinicId) {
        return Optional.ofNullable(clinicToSchema.get(clinicId));
    }

    /** Called when a new tenant is provisioned at runtime. */
    public void register(String clinicId, String schemaName) {
        clinicToSchema.put(clinicId, schemaName);
    }
}
