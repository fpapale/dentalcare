package com.dentalcare.service;

import com.dentalcare.dto.LoginRequest;
import com.dentalcare.dto.LoginResponse;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.JwtService;
import com.dentalcare.security.TenantSchemaRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private final JdbcTemplate jdbc;
    private final JwtService jwtService;
    private final TenantSchemaRegistry registry;
    private final PasswordEncoder passwordEncoder;

    public AuthService(JdbcTemplate jdbc,
                       JwtService jwtService,
                       TenantSchemaRegistry registry,
                       PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.jwtService = jwtService;
        this.registry = registry;
        this.passwordEncoder = passwordEncoder;
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

        String token = jwtService.generate(providerId, clinicUuid, schemaName, role);

        log.info("Login OK provider={} clinic={} schema={}", providerId, clinicUuid, schemaName);

        return new LoginResponse(
                token,
                providerId.toString(),
                clinicUuid.toString(),
                role,
                firstName,
                lastName,
                schemaName);
    }
}
