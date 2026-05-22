package com.dentalcare.service;

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

import java.util.Map;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private static final String DEMO_SCHEMA = "t_9d754153";

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

    public LoginResponse login(LoginRequest request) {
        if (request.clinicId() == null || request.clinicId().isBlank()
                || request.email() == null || request.email().isBlank()
                || request.password() == null || request.password().isBlank()) {
            throw new BadCredentialsException("Missing credentials");
        }

        String schemaName = registry.findSchemaForClinic(request.clinicId())
                .orElseThrow(() -> new ResourceNotFoundException("Clinic not found"));

        if (!schemaName.matches("^t_[0-9a-f]{8}$")) {
            throw new IllegalStateException("Invalid schema name resolved for clinic");
        }

        UUID clinicUuid;
        try {
            clinicUuid = UUID.fromString(request.clinicId());
        } catch (IllegalArgumentException e) {
            throw new BadCredentialsException("Invalid clinic id");
        }

        String sql = "SELECT id, email, password_hash, role, first_name, last_name " +
                "FROM " + schemaName + ".providers " +
                "WHERE lower(email) = lower(?) AND clinic_id = ? AND active = true";

        Map<String, Object> row;
        try {
            row = jdbc.queryForMap(sql, request.email(), clinicUuid);
        } catch (EmptyResultDataAccessException e) {
            log.info("Login failed: provider not found email={} clinicId={}", request.email(), request.clinicId());
            throw new BadCredentialsException("Invalid credentials");
        }

        String storedHash = (String) row.get("password_hash");
        if (storedHash == null || storedHash.isBlank()
                || !passwordEncoder.matches(request.password(), storedHash)) {
            log.info("Login failed: password mismatch email={} clinicId={}", request.email(), request.clinicId());
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
}
