package com.dentalcare.service;

import com.dentalcare.dto.ClinicOption;
import com.dentalcare.dto.DemoConfigResponse;
import com.dentalcare.dto.LoginConfirmRequest;
import com.dentalcare.dto.LoginPreflightRequest;
import com.dentalcare.dto.LoginPreflightResponse;
import com.dentalcare.dto.LoginRequest;
import com.dentalcare.dto.LoginResponse;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.JwtService;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
import com.dentalcare.util.TempPasswordGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private static final String SCHEMA_PATTERN = "^t_[0-9a-f]{8}$";

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate namedJdbc;
    private final JwtService jwtService;
    private final TenantSchemaRegistry registry;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    @Value("${app.demo.enabled:false}")
    private boolean demoEnabled;

    @Value("${app.demo.email:}")
    private String demoEmail;

    @Value("${app.demo.password:}")
    private String demoPassword;

    public AuthService(JdbcTemplate jdbc,
                       NamedParameterJdbcTemplate namedJdbc,
                       JwtService jwtService,
                       TenantSchemaRegistry registry,
                       PasswordEncoder passwordEncoder,
                       EmailService emailService) {
        this.jdbc = jdbc;
        this.namedJdbc = namedJdbc;
        this.jwtService = jwtService;
        this.registry = registry;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
    }

    public DemoConfigResponse demoConfig() {
        if (!demoEnabled) {
            return new DemoConfigResponse(false, null, null);
        }
        return new DemoConfigResponse(true, demoEmail, demoPassword);
    }

    private String fetchTenantName(String schemaName) {
        try {
            String name = jdbc.queryForObject(
                    "SELECT name FROM dentalcare.tenants WHERE schema_name = ?",
                    String.class, schemaName);
            return name != null ? name : "";
        } catch (Exception e) {
            return "";
        }
    }

    private String fetchClinicName(String schemaName, UUID clinicId) {
        try {
            String name = jdbc.queryForObject(
                    "SELECT name FROM " + schemaName + ".clinics WHERE id = ?",
                    String.class, clinicId);
            return name != null ? name : "";
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * Preflight: cerca l'utente in TUTTI gli schema dei tenant attivi.
     * - 0 match → BadCredentialsException
     * - 1 match → response "direct" con token
     * - >1 match → response "choose" con lista opzioni
     */
    public LoginPreflightResponse preflight(LoginPreflightRequest request) {
        if (request == null
                || request.email() == null || request.email().isBlank()
                || request.password() == null || request.password().isBlank()) {
            throw new BadCredentialsException("Missing credentials");
        }

        List<Map<String, Object>> activeTenants;
        try {
            activeTenants = jdbc.queryForList(
                    "SELECT schema_name FROM dentalcare.tenants WHERE active = true");
        } catch (Exception e) {
            log.warn("Preflight: dentalcare.tenants not found, using pattern fallback: {}", e.getMessage());
            try {
                activeTenants = jdbc.queryForList(
                        "SELECT schema_name FROM information_schema.schemata WHERE schema_name ~ '^t_[0-9a-f]{8}$'");
            } catch (Exception e2) {
                log.warn("Preflight: pattern fallback also failed: {}", e2.getMessage());
                throw new BadCredentialsException("Invalid credentials");
            }
        }

        List<Match> matches = new ArrayList<>();

        for (Map<String, Object> tenantRow : activeTenants) {
            String schemaName = String.valueOf(tenantRow.get("schema_name"));
            if (schemaName == null || !schemaName.matches(SCHEMA_PATTERN)) {
                continue;
            }

            List<Map<String, Object>> rows;
            try {
                String sql = "SELECT id, clinic_id, role::text AS role, first_name, last_name, password_hash, password_temporary " +
                        "FROM " + schemaName + ".providers " +
                        "WHERE lower(email) = lower(?) AND active = true";
                rows = jdbc.queryForList(sql, request.email());
            } catch (Exception e) {
                log.warn("Preflight: query failed for schema {}: {}", schemaName, e.getMessage());
                continue;
            }

            for (Map<String, Object> row : rows) {
                String storedHash = (String) row.get("password_hash");
                if (storedHash == null || storedHash.isBlank()) continue;
                if (!passwordEncoder.matches(request.password(), storedHash)) continue;

                UUID providerId = (UUID) row.get("id");
                UUID clinicId = (UUID) row.get("clinic_id");
                String role = String.valueOf(row.get("role"));
                String firstName = (String) row.get("first_name");
                String lastName = (String) row.get("last_name");
                boolean mustChangePassword = Boolean.TRUE.equals(row.get("password_temporary"));

                matches.add(new Match(schemaName, providerId, clinicId, role, firstName, lastName, mustChangePassword));
            }
        }

        if (matches.isEmpty()) {
            log.info("Preflight failed: no valid match for email={}", request.email());
            throw new BadCredentialsException("Invalid credentials");
        }

        if (matches.size() == 1) {
            Match m = matches.get(0);
            String tenantName = fetchTenantName(m.schemaName);
            String token = jwtService.generate(m.providerId, m.clinicId, m.schemaName, m.role, tenantName);
            log.info("Preflight direct: provider={} clinic={} schema={}", m.providerId, m.clinicId, m.schemaName);
            return LoginPreflightResponse.direct(
                    request.email(),
                    token,
                    m.providerId.toString(),
                    m.clinicId.toString(),
                    m.role,
                    m.firstName,
                    m.lastName,
                    m.schemaName,
                    tenantName,
                    m.mustChangePassword);
        }

        List<ClinicOption> options = new ArrayList<>();
        for (Match m : matches) {
            String tenantName = fetchTenantName(m.schemaName);
            String clinicName = fetchClinicName(m.schemaName, m.clinicId);
            boolean isTenantAdmin = "tenant_admin".equals(m.role);
            options.add(new ClinicOption(
                    m.providerId.toString(),
                    m.clinicId.toString(),
                    clinicName,
                    m.role,
                    isTenantAdmin,
                    m.schemaName,
                    tenantName));
        }
        log.info("Preflight choose: {} options for email={}", options.size(), request.email());
        return LoginPreflightResponse.choose(request.email(), Collections.unmodifiableList(options));
    }

    /**
     * Confirm: identico al vecchio login() — risolve schema da clinicId,
     * verifica email+password, genera token.
     */
    public LoginResponse confirm(LoginConfirmRequest request) {
        if (request == null
                || request.clinicId() == null || request.clinicId().isBlank()
                || request.email() == null || request.email().isBlank()
                || request.password() == null || request.password().isBlank()) {
            throw new BadCredentialsException("Missing credentials");
        }
        return doLogin(request.clinicId(), request.email(), request.password(), request.providerId());
    }

    public LoginResponse login(LoginRequest request) {
        if (request.clinicId() == null || request.clinicId().isBlank()
                || request.email() == null || request.email().isBlank()
                || request.password() == null || request.password().isBlank()) {
            throw new BadCredentialsException("Missing credentials");
        }
        return doLogin(request.clinicId(), request.email(), request.password(), null);
    }

    private LoginResponse doLogin(String clinicIdRaw, String email, String password, String providerIdHint) {
        String schemaName = registry.findSchemaForClinic(clinicIdRaw)
                .orElseThrow(() -> new ResourceNotFoundException("Clinic not found"));

        if (!schemaName.matches(SCHEMA_PATTERN)) {
            throw new IllegalStateException("Invalid schema name resolved for clinic");
        }

        UUID clinicUuid;
        try {
            clinicUuid = UUID.fromString(clinicIdRaw);
        } catch (IllegalArgumentException e) {
            throw new BadCredentialsException("Invalid clinic id");
        }

        // Se providerId è noto (selezione da choose screen), cerca per id diretto
        // per evitare ambiguità quando lo stesso utente ha ruoli diversi nella stessa clinica
        String sql;
        Object[] args;
        if (providerIdHint != null && !providerIdHint.isBlank()) {
            UUID providerUuid;
            try {
                providerUuid = UUID.fromString(providerIdHint);
            } catch (IllegalArgumentException e) {
                throw new BadCredentialsException("Invalid provider id");
            }
            sql = "SELECT id, email, password_hash, role, first_name, last_name, password_temporary " +
                    "FROM " + schemaName + ".providers " +
                    "WHERE id = ? AND clinic_id = ? AND active = true";
            args = new Object[]{providerUuid, clinicUuid};
        } else {
            sql = "SELECT id, email, password_hash, role, first_name, last_name, password_temporary " +
                    "FROM " + schemaName + ".providers " +
                    "WHERE lower(email) = lower(?) AND clinic_id = ? AND active = true";
            args = new Object[]{email, clinicUuid};
        }

        Map<String, Object> row;
        try {
            row = jdbc.queryForMap(sql, args);
        } catch (EmptyResultDataAccessException e) {
            log.info("Login failed: provider not found email={} clinicId={}", email, clinicIdRaw);
            throw new BadCredentialsException("Invalid credentials");
        }

        String storedHash = (String) row.get("password_hash");
        if (storedHash == null || storedHash.isBlank()
                || !passwordEncoder.matches(password, storedHash)) {
            log.info("Login failed: password mismatch email={} clinicId={}", email, clinicIdRaw);
            throw new BadCredentialsException("Invalid credentials");
        }

        UUID providerId = (UUID) row.get("id");
        String role = String.valueOf(row.get("role"));
        String firstName = (String) row.get("first_name");
        String lastName = (String) row.get("last_name");
        boolean mustChangePassword = Boolean.TRUE.equals(row.get("password_temporary"));

        String tenantName = fetchTenantName(schemaName);
        String token = jwtService.generate(providerId, clinicUuid, schemaName, role, tenantName);

        log.info("Login OK provider={} clinic={} schema={} mustChangePwd={}", providerId, clinicUuid, schemaName, mustChangePassword);

        return new LoginResponse(
                token,
                providerId.toString(),
                clinicUuid.toString(),
                role,
                firstName,
                lastName,
                schemaName,
                tenantName,
                mustChangePassword);
    }

    @Transactional
    public void changePassword(String currentPassword, String newPassword) {
        String providerId = SecurityContextHolder.getContext().getAuthentication().getPrincipal().toString();
        String schema = TenantContext.validatedSchema();
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        Map<String, Object> row = namedJdbc.queryForMap(
                "SELECT password_hash FROM " + schema + ".providers WHERE id = :id AND clinic_id = :clinicId AND active = true",
                new MapSqlParameterSource("id", UUID.fromString(providerId)).addValue("clinicId", clinicId));

        String storedHash = (String) row.get("password_hash");
        if (!passwordEncoder.matches(currentPassword, storedHash)) {
            throw new BadCredentialsException("Current password incorrect");
        }

        namedJdbc.update(
                "UPDATE " + schema + ".providers SET password_hash = :hash, password_temporary = false, updated_at = now() WHERE id = :id AND clinic_id = :clinicId",
                new MapSqlParameterSource("hash", passwordEncoder.encode(newPassword))
                        .addValue("id", UUID.fromString(providerId))
                        .addValue("clinicId", clinicId));

        log.info("Password changed for provider={}", providerId);
    }

    @Transactional
    public boolean setDemoPassword(String email, String newPassword) {
        if (!demoEnabled) return false;
        List<Map<String, Object>> tenants = jdbc.queryForList(
                "SELECT schema_name FROM dentalcare.tenants WHERE active = true");
        for (Map<String, Object> tenant : tenants) {
            String schema = (String) tenant.get("schema_name");
            if (schema == null || !schema.matches(SCHEMA_PATTERN)) continue;
            try {
                List<Map<String, Object>> rows = namedJdbc.queryForList(
                        "SELECT id, clinic_id FROM " + schema +
                                ".providers WHERE lower(email) = lower(:email) AND active = true LIMIT 1",
                        new MapSqlParameterSource("email", email));
                if (!rows.isEmpty()) {
                    UUID pid = (UUID) rows.get(0).get("id");
                    UUID cid = (UUID) rows.get(0).get("clinic_id");
                    namedJdbc.update(
                            "UPDATE " + schema + ".providers SET password_hash = :hash, password_temporary = false, updated_at = now() WHERE id = :id AND clinic_id = :cid",
                            new MapSqlParameterSource("hash", passwordEncoder.encode(newPassword))
                                    .addValue("id", pid).addValue("cid", cid));
                    log.info("Demo password set for email={}", email);
                    return true;
                }
            } catch (Exception e) {
                log.warn("setDemoPassword error for schema {}: {}", schema, e.getMessage());
            }
        }
        return false;
    }

    @Transactional
    public void forgotPassword(String email) {
        List<Map<String, Object>> tenants = jdbc.queryForList(
                "SELECT schema_name FROM dentalcare.tenants WHERE active = true");

        for (Map<String, Object> tenant : tenants) {
            String schema = (String) tenant.get("schema_name");
            if (schema == null || !schema.matches(SCHEMA_PATTERN)) continue;
            try {
                List<Map<String, Object>> rows = namedJdbc.queryForList(
                        "SELECT id, clinic_id, first_name FROM " + schema +
                                ".providers WHERE lower(email) = lower(:email) AND active = true LIMIT 1",
                        new MapSqlParameterSource("email", email));
                if (!rows.isEmpty()) {
                    Map<String, Object> row = rows.get(0);
                    String tempPassword = TempPasswordGenerator.generate();
                    UUID pid = (UUID) row.get("id");
                    UUID cid = (UUID) row.get("clinic_id");
                    String firstName = (String) row.get("first_name");
                    namedJdbc.update(
                            "UPDATE " + schema + ".providers SET password_hash = :hash, password_temporary = true, updated_at = now() WHERE id = :id AND clinic_id = :clinicId",
                            new MapSqlParameterSource("hash", passwordEncoder.encode(tempPassword))
                                    .addValue("id", pid)
                                    .addValue("clinicId", cid));
                    emailService.sendPasswordResetCode(email, firstName, tempPassword);
                    log.info("Forgot-password reset sent for email={} schema={}", email, schema);
                    return;
                }
            } catch (Exception e) {
                log.warn("Error checking schema {} for forgot-password: {}", schema, e.getMessage());
            }
        }
        log.info("Forgot-password: no match for email={} (silent)", email);
    }

    private record Match(
            String schemaName,
            UUID providerId,
            UUID clinicId,
            String role,
            String firstName,
            String lastName,
            boolean mustChangePassword) {}
}
