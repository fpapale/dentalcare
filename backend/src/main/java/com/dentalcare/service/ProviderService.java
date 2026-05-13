package com.dentalcare.service;

import com.dentalcare.dto.ProviderDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

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

    public List<ProviderDto> findAll(boolean activeOnly) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT id, first_name, last_name,
                   concat_ws(' ', last_name, first_name) AS full_name,
                   role, phone, email, active
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

    private ProviderDto mapRow(ResultSet rs) throws SQLException {
        return new ProviderDto(
                rs.getObject("id", UUID.class),
                rs.getString("first_name"),
                rs.getString("last_name"),
                rs.getString("full_name"),
                rs.getString("role"),
                rs.getString("phone"),
                rs.getString("email"),
                rs.getBoolean("active")
        );
    }
}
