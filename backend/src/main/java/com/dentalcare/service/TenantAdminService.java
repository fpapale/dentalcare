package com.dentalcare.service;

import com.dentalcare.dto.CreateTenantClinicRequest;
import com.dentalcare.dto.CreateTenantUserRequest;
import com.dentalcare.dto.TenantClinicDto;
import com.dentalcare.dto.TenantUserDto;
import com.dentalcare.security.TenantContext;
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

    public TenantAdminService(NamedParameterJdbcTemplate jdbc, PasswordEncoder passwordEncoder, EmailService emailService) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
    }

    private String s() { return TenantContext.validatedSchema(); }

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
        UUID id = UUID.randomUUID();
        String sql = """
            INSERT INTO %s.clinics (id, name, legal_name, city, province, address_line1, postal_code, phone, email)
            VALUES (:id, :name, :legalName, :city, :province, :addressLine1, :postalCode, :phone, :email)
            """.formatted(s());
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
        String tempPassword = TempPasswordGenerator.generate();
        String hashed = passwordEncoder.encode(tempPassword);

        String sql = """
            INSERT INTO %s.providers (id, clinic_id, first_name, last_name, email, password_hash, role, active, password_temporary)
            VALUES (:id, :clinicId, :firstName, :lastName, :email, :passwordHash,
                    CAST(:role AS dentalcare.provider_role), true, true)
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("firstName", request.firstName())
                .addValue("lastName", request.lastName())
                .addValue("email", request.email())
                .addValue("passwordHash", hashed)
                .addValue("role", request.role());
        jdbc.update(sql, params);

        emailService.sendTempPassword(request.email(), request.firstName(), tempPassword);

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

        String email = (String) self.get("email");
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
