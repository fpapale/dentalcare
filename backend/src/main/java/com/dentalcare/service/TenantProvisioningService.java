package com.dentalcare.service;

import com.dentalcare.dto.RegistrationRequest;
import com.dentalcare.dto.TenantProvisioningResult;
import com.dentalcare.security.TenantSchemaRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class TenantProvisioningService {

    private static final Logger log = LoggerFactory.getLogger(TenantProvisioningService.class);

    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final TenantSchemaRegistry registry;
    private final PasswordEncoder passwordEncoder;

    @Value("${tenant.tablespace.base-path:}")
    private String tablespaceBasePath;

    public TenantProvisioningService(JdbcTemplate jdbc,
                                     PlatformTransactionManager txManager,
                                     TenantSchemaRegistry registry,
                                     PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(txManager);
        this.registry = registry;
        this.passwordEncoder = passwordEncoder;
    }

    public TenantProvisioningResult provision(RegistrationRequest req) {
        UUID tenantId = UUID.randomUUID();
        UUID clinicId = UUID.randomUUID();
        String hex = clinicId.toString().replace("-", "");
        String schemaName = "t_" + hex.substring(0, 8);

        if (!schemaName.matches("^t_[0-9a-f]{8}$")) {
            throw new IllegalStateException("Invalid schema name derived: " + schemaName);
        }

        Integer existing = jdbc.queryForObject(
                "SELECT COUNT(*) FROM dentalcare.tenants WHERE schema_name = ?",
                Integer.class, schemaName);
        if (existing != null && existing > 0) {
            throw new IllegalStateException("Schema name collision: " + schemaName + ". Retry.");
        }

        // CREATE TABLESPACE is non-transactional in PostgreSQL — must run outside tx
        String tablespaceName = createTablespaceIfConfigured(schemaName);

        try {
            tx.execute(status -> {
                provisionInTransaction(tenantId, clinicId, schemaName, tablespaceName, req);
                return null;
            });
        } catch (Exception e) {
            // If tablespace was created but transaction failed, log for manual cleanup
            if (!"pg_default".equals(tablespaceName)) {
                log.error("Transaction failed after tablespace {} was created. " +
                          "Manual cleanup may be required: DROP TABLESPACE IF EXISTS {}",
                          tablespaceName, tablespaceName);
            }
            throw e;
        }

        registry.register(clinicId.toString(), schemaName);
        log.info("Tenant provisioned: schema={} clinicId={} tenantId={}", schemaName, clinicId, tenantId);

        return new TenantProvisioningResult(tenantId, clinicId, schemaName);
    }

    private void provisionInTransaction(UUID tenantId, UUID clinicId,
                                        String schemaName, String tablespaceName,
                                        RegistrationRequest req) {
        String plan = (req.plan() != null && !req.plan().isBlank()) ? req.plan() : "professional";

        jdbc.update("""
                INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active)
                VALUES (?, ?, ?, ?, ?, ?, true)
                """,
                tenantId, req.studioName(), schemaName,
                req.email(), req.telefono(), plan);

        jdbc.execute("CREATE SCHEMA IF NOT EXISTS " + schemaName);

        String ddl = loadTemplate()
                .replace("{schema}", schemaName)
                .replace("{tablespace}", tablespaceName);
        executeSqlStatements(ddl);

        jdbc.update(
                "INSERT INTO " + schemaName + ".clinics " +
                "(id, name, legal_name, vat_number, fiscal_code, phone, email, " +
                " address_line1, city, province, country, timezone) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'IT', 'Europe/Rome')",
                clinicId,
                req.studioName(),
                req.studioName(),
                req.partitaIva(),
                req.partitaIva(),
                req.telefono(),
                req.email(),
                req.indirizzo(),
                req.citta(),
                req.provincia());

        jdbc.update("""
                INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id)
                VALUES (?, ?)
                """,
                clinicId, tenantId);

        if (req.adminPassword() == null || req.adminPassword().isBlank()) {
            throw new IllegalArgumentException("adminPassword is required for tenant provisioning");
        }
        UUID adminProviderId = UUID.randomUUID();
        String hashed = passwordEncoder.encode(req.adminPassword());
        jdbc.update(
                "INSERT INTO " + schemaName + ".providers " +
                "(id, clinic_id, first_name, last_name, email, role, active, password_hash) " +
                "VALUES (?, ?, ?, ?, ?, 'admin'::dentalcare.provider_role, true, ?)",
                adminProviderId,
                clinicId,
                req.adminNome(),
                req.adminCognome(),
                req.adminEmail(),
                hashed);

        log.debug("Provisioning transaction complete: schema={} adminProvider={}", schemaName, adminProviderId);
    }

    private String createTablespaceIfConfigured(String schemaName) {
        if (tablespaceBasePath == null || tablespaceBasePath.isBlank()) {
            return "pg_default";
        }
        String tablespaceName = "ts_" + schemaName;
        String tablespacePath = tablespaceBasePath.stripTrailing() + "/" + schemaName;

        // PostgreSQL requires the directory to exist before CREATE TABLESPACE.
        // The process must have write access to tablespaceBasePath.
        try {
            Path path = Path.of(tablespacePath);
            Files.createDirectories(path);
            // PostgreSQL requires mode 700 on the tablespace directory
            try {
                Files.setPosixFilePermissions(path,
                        PosixFilePermissions.fromString("rwx------"));
            } catch (UnsupportedOperationException ignored) {
                // Windows dev environment — skip posix permissions
            }
            log.info("Tablespace directory created: {}", tablespacePath);
        } catch (IOException e) {
            throw new RuntimeException(
                    "Cannot create tablespace directory: " + tablespacePath +
                    ". Create it manually on the DB server and ensure the process user has write access: " +
                    "mkdir -p " + tablespacePath + " && chown postgres:postgres " + tablespacePath, e);
        }

        // Use format with safe values: tablespaceName is ts_t_[0-9a-f]{8}, path from config
        jdbc.execute(String.format(
                "CREATE TABLESPACE %s OWNER CURRENT_USER LOCATION '%s'",
                tablespaceName,
                tablespacePath.replace("'", "''")));
        log.info("Tablespace created: {} -> {}", tablespaceName, tablespacePath);
        return tablespaceName;
    }

    private String loadTemplate() {
        try (InputStream is = getClass().getResourceAsStream("/db/tenant-schema-template.sql")) {
            if (is == null) {
                throw new IllegalStateException("tenant-schema-template.sql not found on classpath");
            }
            return new String(is.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new RuntimeException("Failed to load tenant schema template", e);
        }
    }

    private void executeSqlStatements(String sql) {
        for (String stmt : splitSql(sql)) {
            jdbc.execute(stmt);
        }
    }

    /**
     * Splits a SQL script into individual statements, correctly handling
     * dollar-quoted PL/pgSQL blocks (e.g. $$ ... $$ or $BODY$ ... $BODY$).
     * Single-line comments (--) are preserved inside statements but do not
     * affect the split logic.
     */
    static List<String> splitSql(String sql) {
        List<String> statements = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        int i = 0;
        String dollarTag = null;

        while (i < sql.length()) {
            if (dollarTag == null) {
                // Check for dollar-quote opening tag: $identifier$ or $$
                if (sql.charAt(i) == '$') {
                    int j = sql.indexOf('$', i + 1);
                    if (j > i) {
                        String tag = sql.substring(i, j + 1);
                        if (tag.matches("\\$[A-Za-z_0-9]*\\$")) {
                            dollarTag = tag;
                            current.append(sql, i, j + 1);
                            i = j + 1;
                            continue;
                        }
                    }
                }

                if (sql.charAt(i) == ';') {
                    String stmt = current.toString().strip();
                    if (!stmt.isEmpty()) {
                        statements.add(stmt);
                    }
                    current.setLength(0);
                    i++;
                    continue;
                }

                current.append(sql.charAt(i));
                i++;
            } else {
                // Inside dollar-quote block — scan for matching closing tag
                if (sql.startsWith(dollarTag, i)) {
                    current.append(dollarTag);
                    i += dollarTag.length();
                    dollarTag = null;
                } else {
                    current.append(sql.charAt(i));
                    i++;
                }
            }
        }

        String remaining = current.toString().strip();
        if (!remaining.isEmpty()) {
            statements.add(remaining);
        }

        return statements;
    }
}
