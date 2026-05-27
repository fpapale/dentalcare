package com.dentalcare.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * When app.demo.enabled=true, ensures the demo admin user's password_hash
 * in every tenant schema matches the configured app.demo.password.
 * Runs after EstimateSchemaInitializer (Order 2 vs default Order).
 */
@Component
@Order(2)
public class DemoDataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoDataInitializer.class);
    private static final String SCHEMA_PATTERN = "^t_[0-9a-f]{8}$";

    private final JdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.demo.enabled:false}")
    private boolean demoEnabled;

    @Value("${app.demo.email:}")
    private String demoEmail;

    @Value("${app.demo.password:}")
    private String demoPassword;

    public DemoDataInitializer(JdbcTemplate jdbc, PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!demoEnabled || demoEmail == null || demoEmail.isBlank()
                || demoPassword == null || demoPassword.isBlank()) {
            return;
        }

        try {
            java.util.List<String> schemas = discoverSchemas();
            for (String schema : schemas) {
                if (!schema.matches(SCHEMA_PATTERN)) continue;
                syncDemoPassword(schema);
            }
        } catch (Exception e) {
            log.warn("DemoDataInitializer: failed: {}", e.getMessage());
        }
    }

    private java.util.List<String> discoverSchemas() {
        try {
            return jdbc.queryForList(
                    "SELECT schema_name FROM dentalcare.tenants WHERE active = true",
                    String.class);
        } catch (Exception e) {
            return jdbc.queryForList(
                    "SELECT schema_name FROM information_schema.schemata WHERE schema_name ~ '^t_[0-9a-f]{8}$'",
                    String.class);
        }
    }

    private void syncDemoPassword(String schema) {
        try {
            // Check if the demo user exists and if password matches
            java.util.List<java.util.Map<String, Object>> rows = jdbc.queryForList(
                    "SELECT id, password_hash FROM " + schema + ".providers WHERE lower(email) = lower(?) AND active = true",
                    demoEmail);

            if (rows.isEmpty()) {
                log.warn("DemoDataInitializer: demo user {} not found in schema {}", demoEmail, schema);
                return;
            }

            String newHash = passwordEncoder.encode(demoPassword);
            int updated = 0;
            for (java.util.Map<String, Object> row : rows) {
                String existingHash = (String) row.get("password_hash");
                if (existingHash == null || !passwordEncoder.matches(demoPassword, existingHash)) {
                    java.util.UUID id = (java.util.UUID) row.get("id");
                    jdbc.update(
                            "UPDATE " + schema + ".providers SET password_hash = ?, password_temporary = false, updated_at = now() WHERE id = ?",
                            newHash, id);
                    updated++;
                }
            }
            if (updated > 0) {
                log.info("DemoDataInitializer: updated password hash for {} demo user(s) in schema {}", updated, schema);
            } else {
                log.info("DemoDataInitializer: demo user password OK in schema {}", schema);
            }
        } catch (Exception e) {
            log.warn("DemoDataInitializer: sync failed for schema {}: {}", schema, e.getMessage());
        }
    }
}
