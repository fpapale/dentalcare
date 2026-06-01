package com.dentalcare.service;

import com.dentalcare.dto.CreateProviderRequest;
import com.dentalcare.dto.ProviderDto;
import com.dentalcare.dto.UpdateProviderBillingRequest;
import com.dentalcare.dto.UpdateProviderProfileRequest;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.UUID;

@Service
public class ProviderService {

    private final NamedParameterJdbcTemplate jdbc;

    public ProviderService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    @Transactional(readOnly = true)
    public List<ProviderDto> findAll(boolean activeOnly) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT id, clinic_id, first_name, last_name,
                   concat_ws(' ', last_name, first_name) AS full_name,
                   role, phone, email, active,
                   vat_number, fiscal_code, professional_register, register_number,
                   billing_address_street, billing_address_zip, billing_address_city, billing_address_province,
                   billing_pec, billing_iban, billing_sdi_code, invoice_prefix, photo_url,
                   (SELECT count(*) FROM %1$s.patients pt
                     WHERE pt.primary_provider_id = providers.id AND pt.clinic_id = :clinicId) AS assigned_patient_count
            FROM %1$s.providers
            WHERE clinic_id = :clinicId
              AND (:activeOnly = false OR active = true)
              AND role != CAST('tenant_admin' AS dentalcare.provider_role)
            ORDER BY last_name, first_name
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("activeOnly", activeOnly);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    @Transactional(readOnly = true)
    public ProviderDto findById(UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT id, clinic_id, first_name, last_name,
                   concat_ws(' ', last_name, first_name) AS full_name,
                   role, phone, email, active,
                   vat_number, fiscal_code, professional_register, register_number,
                   billing_address_street, billing_address_zip, billing_address_city, billing_address_province,
                   billing_pec, billing_iban, billing_sdi_code, invoice_prefix, photo_url,
                   (SELECT count(*) FROM %1$s.patients pt
                     WHERE pt.primary_provider_id = providers.id AND pt.clinic_id = :clinicId) AS assigned_patient_count
            FROM %1$s.providers
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s());
        List<ProviderDto> rows = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", providerId).addValue("clinicId", clinicId),
                (rs, n) -> mapRow(rs));
        return rows.isEmpty() ? null : rows.get(0);
    }

    @Transactional
    public ProviderDto create(CreateProviderRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO %s.providers
                (id, clinic_id, first_name, last_name, role, phone, email, active)
            VALUES
                (:id, :clinicId, :firstName, :lastName, :role::dentalcare.provider_role, :phone, :email, true)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("firstName", request.firstName())
                .addValue("lastName", request.lastName())
                .addValue("role", request.role())
                .addValue("phone", request.phone())
                .addValue("email", request.email()));
        return findById(id);
    }

    @Transactional
    public void updateProfile(UUID providerId, UpdateProviderProfileRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.providers
            SET first_name = :firstName,
                last_name  = :lastName,
                role       = :role::dentalcare.provider_role,
                phone      = :phone,
                email      = :email,
                active     = :active,
                updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", providerId)
                .addValue("clinicId", clinicId)
                .addValue("firstName", request.firstName())
                .addValue("lastName", request.lastName())
                .addValue("role", request.role())
                .addValue("phone", request.phone())
                .addValue("email", request.email())
                .addValue("active", request.active()));
    }

    @Transactional
    public void delete(UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("DELETE FROM " + s() + ".providers WHERE id = :id AND clinic_id = :clinicId",
            new MapSqlParameterSource()
                .addValue("id", providerId)
                .addValue("clinicId", clinicId));
    }

    /** Reassign all patients from one provider (or orphans when fromProviderId is null)
     *  to an active, non-admin provider in the current clinic. */
    @Transactional
    public int reassignPatients(UUID fromProviderId, UUID toProviderId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        if (toProviderId == null) {
            throw new IllegalArgumentException("Target provider is required");
        }
        if (toProviderId.equals(fromProviderId)) {
            throw new IllegalArgumentException("Target provider must differ from source provider");
        }

        List<Boolean> targetState = jdbc.query(
                "SELECT active, role = CAST('tenant_admin' AS dentalcare.provider_role) AS is_admin "
                        + "FROM " + s() + ".providers WHERE id = :id AND clinic_id = :clinicId",
                new MapSqlParameterSource().addValue("id", toProviderId).addValue("clinicId", clinicId),
                (rs, n) -> rs.getBoolean("active") && !rs.getBoolean("is_admin"));
        if (targetState.isEmpty()) {
            throw new IllegalArgumentException("Target provider not found");
        }
        if (!targetState.get(0)) {
            throw new IllegalArgumentException("Target provider must be active and not a tenant admin");
        }

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("toId", toProviderId)
                .addValue("clinicId", clinicId);

        String sql;
        if (fromProviderId == null) {
            sql = "UPDATE " + s() + ".patients SET primary_provider_id = :toId, updated_at = now() "
                    + "WHERE clinic_id = :clinicId AND primary_provider_id IS NULL";
        } else {
            sql = "UPDATE " + s() + ".patients SET primary_provider_id = :toId, updated_at = now() "
                    + "WHERE clinic_id = :clinicId AND primary_provider_id = :fromId";
            params.addValue("fromId", fromProviderId);
        }
        return jdbc.update(sql, params);
    }

    /** Soft activate/deactivate a provider in the current clinic. */
    @Transactional
    public void setActive(UUID providerId, boolean active) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.providers
            SET active = :active, updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("active", active)
                .addValue("id", providerId)
                .addValue("clinicId", clinicId));
    }

    @Transactional
    public void updateBilling(UUID providerId, UpdateProviderBillingRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.providers
            SET vat_number               = :vatNumber,
                fiscal_code              = :fiscalCode,
                professional_register    = :professionalRegister,
                register_number          = :registerNumber,
                billing_address_street   = :billingAddressStreet,
                billing_address_zip      = :billingAddressZip,
                billing_address_city     = :billingAddressCity,
                billing_address_province = :billingAddressProvince,
                billing_pec              = :billingPec,
                billing_iban             = :billingIban,
                billing_sdi_code         = :billingSdiCode,
                invoice_prefix           = :invoicePrefix,
                updated_at               = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", providerId)
                        .addValue("clinicId", clinicId)
                        .addValue("vatNumber", request.vatNumber())
                        .addValue("fiscalCode", request.fiscalCode())
                        .addValue("professionalRegister", request.professionalRegister())
                        .addValue("registerNumber", request.registerNumber())
                        .addValue("billingAddressStreet", request.billingAddressStreet())
                        .addValue("billingAddressZip", request.billingAddressZip())
                        .addValue("billingAddressCity", request.billingAddressCity())
                        .addValue("billingAddressProvince", request.billingAddressProvince())
                        .addValue("billingPec", request.billingPec())
                        .addValue("billingIban", request.billingIban())
                        .addValue("billingSdiCode", request.billingSdiCode())
                        .addValue("invoicePrefix", request.invoicePrefix()));
    }

    private ProviderDto mapRow(ResultSet rs) throws SQLException {
        return new ProviderDto(
                rs.getObject("id", UUID.class),
                rs.getObject("clinic_id", UUID.class),
                rs.getString("first_name"),
                rs.getString("last_name"),
                rs.getString("full_name"),
                rs.getString("role"),
                rs.getString("phone"),
                rs.getString("email"),
                rs.getBoolean("active"),
                rs.getString("vat_number"),
                rs.getString("fiscal_code"),
                rs.getString("professional_register"),
                rs.getString("register_number"),
                rs.getString("billing_address_street"),
                rs.getString("billing_address_zip"),
                rs.getString("billing_address_city"),
                rs.getString("billing_address_province"),
                rs.getString("billing_pec"),
                rs.getString("billing_iban"),
                rs.getString("billing_sdi_code"),
                rs.getString("invoice_prefix"),
                rs.getString("photo_url"),
                rs.getInt("assigned_patient_count")
        );
    }

    @Transactional
    public void updatePhoto(UUID providerId, String photoDataUrl) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.providers
            SET photo_url  = :photoUrl,
                updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("photoUrl", photoDataUrl == null || photoDataUrl.isBlank() ? null : photoDataUrl)
                .addValue("id", providerId)
                .addValue("clinicId", clinicId));
    }
}
