package com.dentalcare.service;

import com.dentalcare.dto.ClinicOption;
import com.dentalcare.dto.LoginConfirmRequest;
import com.dentalcare.dto.LoginPreflightRequest;
import com.dentalcare.dto.LoginPreflightResponse;
import com.dentalcare.dto.LoginRequest;
import com.dentalcare.dto.LoginResponse;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.JwtService;
import com.dentalcare.security.TenantSchemaRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private static final String DEMO_SCHEMA = "t_9d754153";
    private static final String SCHEMA_PATTERN = "^t_[0-9a-f]{8}$";

    private final JdbcTemplate jdbc;
    private final JwtService jwtService;
    private final TenantSchemaRegistry registry;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.demo.enabled:false}")
    private boolean demoEnabled;

    public AuthService(JdbcTemplate jdbc,
                       JwtService jwtService,
                       TenantSchemaRegistry registry,
                       PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.jwtService = jwtService;
        this.registry = registry;
        this.passwordEncoder = passwordEncoder;
    }

    public LoginResponse demoToken() {
        if (!demoEnabled) {
            throw new ResourceNotFoundException("Demo mode not enabled");
        }
        Map<String, Object> row;
        try {
            row = jdbc.queryForMap(
                "SELECT id, clinic_id, role::text AS role, first_name, last_name FROM " + DEMO_SCHEMA +
                ".providers WHERE active = true AND role::text = 'tenant_admin' ORDER BY created_at LIMIT 1");
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("Demo tenant_admin provider not found");
        }
        UUID providerId = (UUID) row.get("id");
        UUID clinicId   = (UUID) row.get("clinic_id");
        String role     = String.valueOf(row.get("role"));
        String firstName = (String) row.get("first_name");
        String lastName  = (String) row.get("last_name");
        String tenantName = fetchTenantName(DEMO_SCHEMA);
        String token = jwtService.generate(providerId, clinicId, DEMO_SCHEMA, role, tenantName);
        log.info("Demo login: provider={} clinic={}", providerId, clinicId);
        return new LoginResponse(token, providerId.toString(), clinicId.toString(), role, firstName, lastName, DEMO_SCHEMA, tenantName);
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
            log.warn("Preflight: tenant lookup failed: {}", e.getMessage());
            throw new BadCredentialsException("Invalid credentials");
        }

        List<Match> matches = new ArrayList<>();

        for (Map<String, Object> tenantRow : activeTenants) {
            String schemaName = String.valueOf(tenantRow.get("schema_name"));
            if (schemaName == null || !schemaName.matches(SCHEMA_PATTERN)) {
                continue;
            }

            List<Map<String, Object>> rows;
            try {
                String sql = "SELECT id, clinic_id, role::text AS role, first_name, last_name, password_hash " +
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

                matches.add(new Match(schemaName, providerId, clinicId, role, firstName, lastName));
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
                    tenantName);
        }

        List<ClinicOption> options = new ArrayList<>();
        for (Match m : matches) {
            String tenantName = fetchTenantName(m.schemaName);
            String clinicName = fetchClinicName(m.schemaName, m.clinicId);
            boolean isTenantAdmin = "tenant_admin".equals(m.role);
            options.add(new ClinicOption(
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
        return doLogin(request.clinicId(), request.email(), request.password());
    }

    public LoginResponse login(LoginRequest request) {
        if (request.clinicId() == null || request.clinicId().isBlank()
                || request.email() == null || request.email().isBlank()
                || request.password() == null || request.password().isBlank()) {
            throw new BadCredentialsException("Missing credentials");
        }
        return doLogin(request.clinicId(), request.email(), request.password());
    }

    private LoginResponse doLogin(String clinicIdRaw, String email, String password) {
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

        String sql = "SELECT id, email, password_hash, role, first_name, last_name " +
                "FROM " + schemaName + ".providers " +
                "WHERE lower(email) = lower(?) AND clinic_id = ? AND active = true";

        Map<String, Object> row;
        try {
            row = jdbc.queryForMap(sql, email, clinicUuid);
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

        String tenantName = fetchTenantName(schemaName);
        String token = jwtService.generate(providerId, clinicUuid, schemaName, role, tenantName);

        log.info("Login OK provider={} clinic={} schema={}", providerId, clinicUuid, schemaName);

        return new LoginResponse(
                token,
                providerId.toString(),
                clinicUuid.toString(),
                role,
                firstName,
                lastName,
                schemaName,
                tenantName);
    }

    private record Match(
            String schemaName,
            UUID providerId,
            UUID clinicId,
            String role,
            String firstName,
            String lastName) {}
}
