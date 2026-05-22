package com.dentalcare.service;

import com.dentalcare.dto.CreateTenantClinicRequest;
import com.dentalcare.dto.CreateTenantUserRequest;
import com.dentalcare.dto.TenantClinicDto;
import com.dentalcare.dto.TenantUserDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.UUID;

@Service
public class TenantAdminService {

    private final NamedParameterJdbcTemplate jdbc;
    private final PasswordEncoder passwordEncoder;

    public TenantAdminService(NamedParameterJdbcTemplate jdbc, PasswordEncoder passwordEncoder) {
        this.jdbc = jdbc;
        this.passwordEncoder = passwordEncoder;
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
            ORDER BY last_name, first_name
            """.formatted(s());
        return jdbc.query(sql,
                new MapSqlParameterSource("clinicId", clinicId),
                (rs, n) -> mapUser(rs));
    }

    @Transactional
    public TenantUserDto createUser(UUID clinicId, CreateTenantUserRequest request) {
        UUID id = UUID.randomUUID();
        String hashed = passwordEncoder.encode(request.password());

        String sql = """
            INSERT INTO %s.providers (id, clinic_id, first_name, last_name, email, password_hash, role, active)
            VALUES (:id, :clinicId, :firstName, :lastName, :email, :passwordHash,
                    CAST(:role AS dentalcare.provider_role), true)
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
