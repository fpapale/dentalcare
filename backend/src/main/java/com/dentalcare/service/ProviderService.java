package com.dentalcare.service;

import com.dentalcare.dto.ProviderDto;
import com.dentalcare.dto.UpdateProviderBillingRequest;
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

    @Transactional(readOnly = true)
    public List<ProviderDto> findAll(boolean activeOnly) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT id, clinic_id, first_name, last_name,
                   concat_ws(' ', last_name, first_name) AS full_name,
                   role, phone, email, active,
                   vat_number, fiscal_code, professional_register, register_number,
                   billing_address_street, billing_address_zip, billing_address_city, billing_address_province,
                   billing_pec, billing_iban, billing_sdi_code, invoice_prefix
            FROM dentalcare.providers
            WHERE clinic_id = :clinicId
              AND (:activeOnly = false OR active = true)
            ORDER BY last_name, first_name
            """;
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
                   billing_pec, billing_iban, billing_sdi_code, invoice_prefix
            FROM dentalcare.providers
            WHERE id = :id AND clinic_id = :clinicId
            """;
        List<ProviderDto> rows = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", providerId).addValue("clinicId", clinicId),
                (rs, n) -> mapRow(rs));
        return rows.isEmpty() ? null : rows.get(0);
    }

    @Transactional
    public void updateBilling(UUID providerId, UpdateProviderBillingRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE dentalcare.providers
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
            """,
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
                rs.getString("invoice_prefix")
        );
    }
}
