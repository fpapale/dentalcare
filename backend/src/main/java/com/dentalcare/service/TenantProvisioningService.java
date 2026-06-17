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

import java.util.UUID;

/**
 * Provisioning di un nuovo tenant. Tutta la creazione (schema + tabelle/viste +
 * tenant + clinic + admin) è delegata alla stored function PL/pgSQL
 * {@code dentalcare.create_tenant}, che gira in un'unica transazione:
 * qualunque errore produce un rollback totale, senza schemi/record orfani.
 */
@Service
public class TenantProvisioningService {

    private static final Logger log = LoggerFactory.getLogger(TenantProvisioningService.class);
    private static final String SCHEMA_PATTERN = "^t_[0-9a-f]{8}$";

    private final JdbcTemplate jdbc;
    private final TenantSchemaRegistry registry;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    @Value("${app.frontend.base-url:http://localhost:4200}")
    private String frontendBaseUrl;

    public TenantProvisioningService(JdbcTemplate jdbc,
                                     TenantSchemaRegistry registry,
                                     PasswordEncoder passwordEncoder,
                                     EmailService emailService) {
        this.jdbc = jdbc;
        this.registry = registry;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
    }

    public TenantProvisioningResult provision(RegistrationRequest req) {
        if (req.adminPassword() == null || req.adminPassword().isBlank()) {
            throw new IllegalArgumentException("adminPassword is required for tenant provisioning");
        }

        UUID tenantId = UUID.randomUUID();
        UUID clinicId = UUID.randomUUID();
        String schemaName = "t_" + clinicId.toString().replace("-", "").substring(0, 8);
        if (!schemaName.matches(SCHEMA_PATTERN)) {
            throw new IllegalStateException("Invalid schema name derived: " + schemaName);
        }

        String plan = (req.plan() != null && !req.plan().isBlank()) ? req.plan() : "professional";
        String passwordHash = passwordEncoder.encode(req.adminPassword());

        // Chiamata atomica: schema + DDL + tenant + clinic + admin in una sola transazione.
        UUID adminId = jdbc.queryForObject(
                "SELECT dentalcare.create_tenant(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                UUID.class,
                tenantId, clinicId, schemaName,
                req.studioName(), req.email(), req.telefono(), plan, req.partitaIva(),
                req.indirizzo(), req.citta(), req.provincia(),
                req.adminNome(), req.adminCognome(), req.adminEmail(), passwordHash);

        registry.register(clinicId.toString(), schemaName);
        log.info("Tenant provisioned: schema={} clinicId={} tenantId={} adminId={}",
                schemaName, clinicId, tenantId, adminId);

        // Email di benvenuto dopo il commit. send() gestisce internamente i propri errori.
        emailService.sendStudioWelcome(
                req.adminEmail(), req.adminNome(), req.studioName(),
                frontendBaseUrl.stripTrailing().replaceAll("/+$", "") + "/login");

        return new TenantProvisioningResult(tenantId, clinicId, schemaName);
    }
}
