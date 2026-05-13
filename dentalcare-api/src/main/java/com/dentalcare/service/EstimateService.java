package com.dentalcare.service;

import com.dentalcare.dto.EstimateDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.UUID;

@Service
public class EstimateService {

    private final NamedParameterJdbcTemplate jdbc;

    public EstimateService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<EstimateDto> findAll(String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT estimate_id, estimate_number, version, estimate_status, estimate_title,
                   currency, subtotal_amount, discount_amount, taxable_amount,
                   vat_amount, total_amount,
                   patient_id, patient_full_name, patient_fiscal_code, patient_phone,
                   issued_at, sent_at, valid_until, accepted_at, rejected_at, estimate_created_at
            FROM dentalcare.v_patient_estimates_summary
            WHERE clinic_id = :clinicId
              AND (:status IS NULL OR estimate_status::text = :status)
            ORDER BY estimate_created_at DESC
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("status", (status == null || status.isBlank()) ? null : status);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    public List<EstimateDto> findByPatient(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT estimate_id, estimate_number, version, estimate_status, estimate_title,
                   currency, subtotal_amount, discount_amount, taxable_amount,
                   vat_amount, total_amount,
                   patient_id, patient_full_name, patient_fiscal_code, patient_phone,
                   issued_at, sent_at, valid_until, accepted_at, rejected_at, estimate_created_at
            FROM dentalcare.v_patient_estimates_summary
            WHERE clinic_id = :clinicId
              AND patient_id = :patientId
            ORDER BY estimate_created_at DESC
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId);
        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    private EstimateDto mapRow(ResultSet rs) throws SQLException {
        return new EstimateDto(
                rs.getObject("estimate_id", UUID.class),
                rs.getString("estimate_number"),
                rs.getObject("version", Integer.class),
                rs.getString("estimate_status"),
                rs.getString("estimate_title"),
                rs.getString("currency"),
                rs.getBigDecimal("subtotal_amount"),
                rs.getBigDecimal("discount_amount"),
                rs.getBigDecimal("taxable_amount"),
                rs.getBigDecimal("vat_amount"),
                rs.getBigDecimal("total_amount"),
                rs.getObject("patient_id", UUID.class),
                rs.getString("patient_full_name"),
                rs.getString("patient_fiscal_code"),
                rs.getString("patient_phone"),
                rs.getTimestamp("issued_at") != null
                        ? rs.getTimestamp("issued_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getTimestamp("sent_at") != null
                        ? rs.getTimestamp("sent_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getDate("valid_until") != null ? rs.getDate("valid_until").toLocalDate() : null,
                rs.getTimestamp("accepted_at") != null
                        ? rs.getTimestamp("accepted_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getTimestamp("rejected_at") != null
                        ? rs.getTimestamp("rejected_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null,
                rs.getTimestamp("estimate_created_at") != null
                        ? rs.getTimestamp("estimate_created_at").toInstant().atOffset(java.time.ZoneOffset.UTC) : null
        );
    }
}
