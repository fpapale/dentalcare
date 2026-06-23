package com.dentalcare.service;

import com.dentalcare.dto.CreateTenantClinicRequest;
import com.dentalcare.dto.CreateTenantUserRequest;
import com.dentalcare.dto.LoginResponse;
import com.dentalcare.dto.TenantClinicDto;
import com.dentalcare.dto.TenantUserDto;
import com.dentalcare.security.JwtService;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
import com.dentalcare.util.TempPasswordGenerator;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class TenantAdminService {

    private final NamedParameterJdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;
    private final JwtService jwtService;
    private final TenantSchemaRegistry registry;

    @org.springframework.beans.factory.annotation.Value("${app.demo.password:}")
    private String demoPassword;

    @org.springframework.beans.factory.annotation.Value("${app.demo.schema:t_9d754153}")
    private String demoSchema;

    private boolean isDemoSchema() { return demoSchema.equals(s()); }

    public TenantAdminService(NamedParameterJdbcTemplate jdbc, PasswordEncoder passwordEncoder,
                              EmailService emailService, JwtService jwtService,
                              TenantSchemaRegistry registry) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
        this.jwtService = jwtService;
        this.registry = registry;
    }

    private String s() { return TenantContext.validatedSchema(); }

    /** tenant_id del tenant corrente (schema → dentalcare.tenants). */
    private UUID currentTenantId() {
        return jdbc.queryForObject(
                "SELECT id FROM dentalcare.tenants WHERE schema_name = :schema",
                new MapSqlParameterSource("schema", s()), UUID.class);
    }

    /** email (citext → PGobject) del provider chiamante. */
    private String currentEmail(String schema) {
        String pid = SecurityContextHolder.getContext().getAuthentication().getPrincipal().toString();
        Object email = jdbc.queryForObject(
                "SELECT email FROM " + schema + ".providers WHERE id = :id AND active = true",
                new MapSqlParameterSource("id", UUID.fromString(pid)), Object.class);
        return email == null ? null : email.toString();
    }

    @Transactional(readOnly = true)
    public List<TenantClinicDto> findClinics() {
        String sql = """
            SELECT id, name, legal_name, city, province, address_line1, postal_code, phone, email
            FROM %s.clinics
            ORDER BY name
            """.formatted(s());
        return jdbc.query(sql, new MapSqlParameterSource(), (rs, n) -> mapClinic(rs));
    }

    @Transactional
    public TenantClinicDto createClinic(CreateTenantClinicRequest request) {
        String schema = s();
        UUID id = UUID.randomUUID();
        String sql = """
            INSERT INTO %s.clinics (id, name, legal_name, city, province, address_line1, postal_code, phone, email)
            VALUES (:id, :name, :legalName, :city, :province, :addressLine1, :postalCode, :phone, :email)
            """.formatted(schema);
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("name", request.name())
                .addValue("legalName", request.legalName())
                .addValue("city", request.city())
                .addValue("province", request.province())
                .addValue("addressLine1", request.addressLine1())
                .addValue("postalCode", request.postalCode())
                .addValue("phone", request.phone())
                .addValue("email", request.email());
        jdbc.update(sql, params);

        // Mappa la nuova sede al tenant (necessario per login/enter su quella clinica).
        UUID tenantId = currentTenantId();
        jdbc.update("INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id) VALUES (:clinicId, :tenantId)",
                new MapSqlParameterSource("clinicId", id).addValue("tenantId", tenantId));
        registry.register(id.toString(), schema);

        // Associa automaticamente il chiamante come admin della nuova sede.
        addSelfAsClinicAdmin(id);

        return new TenantClinicDto(
                id,
                request.name(),
                request.legalName(),
                request.city(),
                request.province(),
                request.addressLine1(),
                request.postalCode(),
                request.phone(),
                request.email(),
                true
        );
    }

    @Transactional
    public TenantClinicDto updateClinic(UUID clinicId, CreateTenantClinicRequest request) {
        String schema = s();
        int updated = jdbc.update("""
            UPDATE %s.clinics
            SET name = :name, legal_name = :legalName, city = :city, province = :province,
                address_line1 = :addressLine1, postal_code = :postalCode, phone = :phone, email = :email
            WHERE id = :id
            """.formatted(schema),
                new MapSqlParameterSource()
                        .addValue("id", clinicId)
                        .addValue("name", request.name())
                        .addValue("legalName", request.legalName())
                        .addValue("city", request.city())
                        .addValue("province", request.province())
                        .addValue("addressLine1", request.addressLine1())
                        .addValue("postalCode", request.postalCode())
                        .addValue("phone", request.phone())
                        .addValue("email", request.email()));
        if (updated == 0) {
            throw new IllegalStateException("Clinic not found");
        }
        return new TenantClinicDto(clinicId, request.name(), request.legalName(), request.city(),
                request.province(), request.addressLine1(), request.postalCode(),
                request.phone(), request.email(), true);
    }

    @Transactional
    public void deleteClinic(UUID clinicId) {
        Integer patientsCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM " + s() + ".patients WHERE clinic_id = :clinicId",
                new MapSqlParameterSource("clinicId", clinicId),
                Integer.class);
        if (patientsCount != null && patientsCount > 0) {
            throw new IllegalStateException("Clinic has patients");
        }

        Integer totalClinics = jdbc.queryForObject(
                "SELECT COUNT(*) FROM " + s() + ".clinics",
                new MapSqlParameterSource(),
                Integer.class);
        if (totalClinics != null && totalClinics <= 1) {
            throw new IllegalStateException("Cannot delete last clinic");
        }

        jdbc.update(
                "DELETE FROM " + s() + ".clinics WHERE id = :clinicId",
                new MapSqlParameterSource("clinicId", clinicId));

        // Pulisci mappatura tenant + cache registry.
        jdbc.update("DELETE FROM dentalcare.tenant_clinics WHERE clinic_id = :clinicId",
                new MapSqlParameterSource("clinicId", clinicId));
        registry.unregister(clinicId.toString());
    }

    /**
     * Elimina l'intero tenant corrente: drop dello schema dedicato + pulizia registry/mappature.
     * Operazione distruttiva e irreversibile. L'export va effettuato prima (lato client).
     */
    @Transactional
    public void deleteTenant() {
        String schema = s();
        if (!schema.matches("^t_[0-9a-f]{8}$")) {
            throw new IllegalStateException("Invalid schema");
        }
        if ("t_9d754153".equals(schema)) {
            throw new IllegalStateException("Cannot delete demo tenant");
        }
        UUID tenantId = currentTenantId();

        jdbc.getJdbcTemplate().execute("DROP SCHEMA IF EXISTS " + schema + " CASCADE");
        jdbc.update("DELETE FROM dentalcare.tenant_clinics WHERE tenant_id = :tenantId",
                new MapSqlParameterSource("tenantId", tenantId));
        jdbc.update("DELETE FROM dentalcare.tenants WHERE id = :tenantId",
                new MapSqlParameterSource("tenantId", tenantId));
        registry.unregisterSchema(schema);
    }

    @Transactional(readOnly = true)
    public List<TenantUserDto> findUsers(UUID clinicId) {
        String sql = """
            SELECT id, clinic_id, first_name, last_name, email, role::text AS role, active
            FROM %s.providers
            WHERE clinic_id = :clinicId AND active = true
              AND role != CAST('tenant_admin' AS dentalcare.provider_role)
            ORDER BY last_name, first_name
            """.formatted(s());
        return jdbc.query(sql,
                new MapSqlParameterSource("clinicId", clinicId),
                (rs, n) -> mapUser(rs));
    }

    @Transactional
    public TenantUserDto createUser(UUID clinicId, CreateTenantUserRequest request) {
        UUID id = UUID.randomUUID();

        // Portale demo: password demo nota, nessun cambio forzato né email.
        // Cambio password al primo accesso solo per utenti reali.
        boolean demo = isDemoSchema();
        boolean temporary = !demo;
        String plainPassword = demo ? demoPassword : TempPasswordGenerator.generate();
        String hashed = passwordEncoder.encode(plainPassword);

        String sql = """
            INSERT INTO %s.providers (id, clinic_id, first_name, last_name, email, password_hash, role, active, password_temporary)
            VALUES (:id, :clinicId, :firstName, :lastName, :email, :passwordHash,
                    CAST(:role AS dentalcare.provider_role), true, :temporary)
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("firstName", request.firstName())
                .addValue("lastName", request.lastName())
                .addValue("email", request.email())
                .addValue("passwordHash", hashed)
                .addValue("role", request.role())
                .addValue("temporary", temporary);
        jdbc.update(sql, params);

        if (temporary) {
            emailService.sendTempPassword(request.email(), request.firstName(), plainPassword);
        }

        return new TenantUserDto(
                id,
                clinicId,
                request.firstName(),
                request.lastName(),
                request.email(),
                request.role(),
                true
        );
    }

    @Transactional(readOnly = true)
    public List<String> getSelfAdminClinicIds() {
        String schema = s();
        String currentProviderId = SecurityContextHolder.getContext().getAuthentication().getPrincipal().toString();

        String email = jdbc.queryForObject(
                "SELECT email FROM " + schema + ".providers WHERE id = :id AND active = true",
                new MapSqlParameterSource("id", UUID.fromString(currentProviderId)),
                String.class);

        return jdbc.queryForList(
                "SELECT clinic_id::text FROM " + schema +
                        ".providers WHERE lower(email) = lower(:email) AND role = CAST('admin' AS dentalcare.provider_role) AND active = true",
                new MapSqlParameterSource("email", email),
                String.class);
    }

    @Transactional
    public void removeSelfAsClinicAdmin(UUID clinicId) {
        String schema = s();
        String currentProviderId = SecurityContextHolder.getContext().getAuthentication().getPrincipal().toString();

        String email = jdbc.queryForObject(
                "SELECT email FROM " + schema + ".providers WHERE id = :id AND active = true",
                new MapSqlParameterSource("id", UUID.fromString(currentProviderId)),
                String.class);

        int deleted = jdbc.update(
                "DELETE FROM " + schema +
                        ".providers WHERE lower(email) = lower(:email) AND clinic_id = :clinicId AND role = CAST('admin' AS dentalcare.provider_role)",
                new MapSqlParameterSource("email", email).addValue("clinicId", clinicId));

        if (deleted == 0) {
            throw new IllegalStateException("Not admin of this clinic");
        }
    }

    @Transactional
    public TenantUserDto addSelfAsClinicAdmin(UUID clinicId) {
        String schema = s();
        String currentProviderId = SecurityContextHolder.getContext().getAuthentication().getPrincipal().toString();

        Map<String, Object> self = jdbc.queryForMap(
                "SELECT id, first_name, last_name, email, password_hash FROM " + schema +
                        ".providers WHERE id = :id AND active = true",
                new MapSqlParameterSource("id", UUID.fromString(currentProviderId)));

        // email è citext -> PGobject: usare toString()
        String email = self.get("email") == null ? null : self.get("email").toString();
        String firstName = (String) self.get("first_name");
        String lastName = (String) self.get("last_name");
        String passwordHash = (String) self.get("password_hash");

        Integer existing = jdbc.queryForObject(
                "SELECT COUNT(*) FROM " + schema +
                        ".providers WHERE lower(email) = lower(:email) AND clinic_id = :clinicId AND role = CAST('admin' AS dentalcare.provider_role) AND active = true",
                new MapSqlParameterSource("email", email).addValue("clinicId", clinicId),
                Integer.class);
        if (existing != null && existing > 0) {
            throw new IllegalStateException("Already admin of this clinic");
        }

        UUID newId = UUID.randomUUID();
        String sql = """
            INSERT INTO %s.providers (id, clinic_id, first_name, last_name, email, password_hash, role, active)
            VALUES (:id, :clinicId, :firstName, :lastName, :email, :passwordHash,
                    CAST('admin' AS dentalcare.provider_role), true)
            """.formatted(schema);
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", newId)
                .addValue("clinicId", clinicId)
                .addValue("firstName", firstName)
                .addValue("lastName", lastName)
                .addValue("email", email)
                .addValue("passwordHash", passwordHash));

        return new TenantUserDto(newId, clinicId, firstName, lastName, email, "admin", true);
    }

    /**
     * Entra in uno studio come amministratore senza logout: rilascia un nuovo token
     * con ruolo admin sulla clinica scelta. Crea il provider admin se non esiste.
     */
    @Transactional
    public LoginResponse enterClinic(UUID clinicId) {
        String schema = s();
        String currentProviderId = SecurityContextHolder.getContext().getAuthentication().getPrincipal().toString();

        Map<String, Object> self = jdbc.queryForMap(
                "SELECT first_name, last_name, email, password_hash FROM " + schema +
                        ".providers WHERE id = :id AND active = true",
                new MapSqlParameterSource("id", UUID.fromString(currentProviderId)));

        // email è citext -> PGobject: usare toString()
        String email = self.get("email") == null ? null : self.get("email").toString();
        String firstName = (String) self.get("first_name");
        String lastName = (String) self.get("last_name");
        String passwordHash = (String) self.get("password_hash");

        // clinica deve appartenere a questo tenant
        Integer clinicExists = jdbc.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".clinics WHERE id = :clinicId",
                new MapSqlParameterSource("clinicId", clinicId), Integer.class);
        if (clinicExists == null || clinicExists == 0) {
            throw new IllegalStateException("Clinic not found in tenant");
        }

        // get-or-create provider admin del chiamante nella clinica scelta
        List<String> adminIds = jdbc.queryForList(
                "SELECT id::text FROM " + schema +
                        ".providers WHERE lower(email) = lower(:email) AND clinic_id = :clinicId" +
                        " AND role = CAST('admin' AS dentalcare.provider_role) AND active = true",
                new MapSqlParameterSource("email", email).addValue("clinicId", clinicId),
                String.class);

        UUID adminProviderId;
        if (!adminIds.isEmpty()) {
            adminProviderId = UUID.fromString(adminIds.get(0));
        } else {
            adminProviderId = UUID.randomUUID();
            String sql = """
                INSERT INTO %s.providers (id, clinic_id, first_name, last_name, email, password_hash, role, active)
                VALUES (:id, :clinicId, :firstName, :lastName, :email, :passwordHash,
                        CAST('admin' AS dentalcare.provider_role), true)
                """.formatted(schema);
            jdbc.update(sql, new MapSqlParameterSource()
                    .addValue("id", adminProviderId)
                    .addValue("clinicId", clinicId)
                    .addValue("firstName", firstName)
                    .addValue("lastName", lastName)
                    .addValue("email", email)
                    .addValue("passwordHash", passwordHash));
        }

        String tenantName = jdbc.queryForObject(
                "SELECT name FROM dentalcare.tenants WHERE schema_name = :schema",
                new MapSqlParameterSource("schema", schema), String.class);

        String token = jwtService.generate(adminProviderId, clinicId, schema, "admin", tenantName);

        return new LoginResponse(
                token, email, adminProviderId.toString(), clinicId.toString(),
                "admin", firstName, lastName, schema, tenantName, false);
    }

    private TenantClinicDto mapClinic(ResultSet rs) throws SQLException {
        return new TenantClinicDto(
                rs.getObject("id", UUID.class),
                rs.getString("name"),
                rs.getString("legal_name"),
                rs.getString("city"),
                rs.getString("province"),
                rs.getString("address_line1"),
                rs.getString("postal_code"),
                rs.getString("phone"),
                rs.getString("email"),
                true
        );
    }

    private TenantUserDto mapUser(ResultSet rs) throws SQLException {
        return new TenantUserDto(
                rs.getObject("id", UUID.class),
                rs.getObject("clinic_id", UUID.class),
                rs.getString("first_name"),
                rs.getString("last_name"),
                rs.getString("email"),
                rs.getString("role"),
                rs.getBoolean("active")
        );
    }
}
