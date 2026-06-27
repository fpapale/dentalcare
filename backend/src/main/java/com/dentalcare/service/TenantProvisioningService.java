package com.dentalcare.service;

import com.dentalcare.dto.RegistrationRequest;
import com.dentalcare.dto.TenantProvisioningResult;
import com.dentalcare.security.TenantSchemaRegistry;
import com.dentalcare.util.TempPasswordGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

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
    private final MinioStorageService minio;

    @Value("${app.frontend.base-url:http://localhost:4200}")
    private String frontendBaseUrl;

    public TenantProvisioningService(JdbcTemplate jdbc,
                                     TenantSchemaRegistry registry,
                                     PasswordEncoder passwordEncoder,
                                     EmailService emailService,
                                     MinioStorageService minio) {
        this.jdbc = jdbc;
        this.registry = registry;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
        this.minio = minio;
    }

    public TenantProvisioningResult provision(RegistrationRequest req) {
        UUID tenantId = UUID.randomUUID();
        UUID clinicId = UUID.randomUUID();
        String schemaName = "t_" + clinicId.toString().replace("-", "").substring(0, 8);
        if (!schemaName.matches(SCHEMA_PATTERN)) {
            throw new IllegalStateException("Invalid schema name derived: " + schemaName);
        }

        String plan = (req.plan() != null && !req.plan().isBlank()) ? req.plan() : "professional";

        // Password temporanea generata: inviata via email, cambio forzato al primo accesso.
        String tempPassword = TempPasswordGenerator.generate();
        String passwordHash = passwordEncoder.encode(tempPassword);

        // Chiamata atomica: schema + DDL + tenant + clinic + admin in una sola transazione.
        UUID adminId = jdbc.queryForObject(
                "SELECT dentalcare.create_tenant(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                UUID.class,
                tenantId, clinicId, schemaName,
                req.studioName(), req.email(), req.telefono(), plan, req.partitaIva(),
                req.indirizzo(), req.citta(), req.provincia(),
                req.adminNome(), req.adminCognome(), req.adminEmail(), passwordHash);

        // Marca la password come temporanea: cambio obbligatorio al primo login.
        jdbc.update("UPDATE " + schemaName + ".providers SET password_temporary = true WHERE id = ?", adminId);

        registry.register(clinicId.toString(), schemaName);
        log.info("Tenant provisioned: schema={} clinicId={} tenantId={} adminId={}",
                schemaName, clinicId, tenantId, adminId);

        final String bucket = minio.bucketFor(schemaName);
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCommit() { minio.ensureBucketExists(bucket); }
            });
        } else {
            minio.ensureBucketExists(bucket);
        }

        // Email con password temporanea dopo il commit. send() gestisce i propri errori.
        emailService.sendStudioWelcomeTempPassword(
                req.adminEmail(), req.adminNome(), req.studioName(), tempPassword,
                frontendBaseUrl.stripTrailing().replaceAll("/+$", "") + "/login");

        return new TenantProvisioningResult(tenantId, clinicId, schemaName);
    }
}
