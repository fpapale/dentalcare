package com.dentalcare.service;

import com.dentalcare.dto.ServiceDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class ServiceCatalogService {

    private final NamedParameterJdbcTemplate jdbc;

    public ServiceCatalogService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<ServiceDto> findAll() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT id, code, name, category, default_price
            FROM dentalcare.service_catalog
            WHERE clinic_id = :clinicId
              AND active = true
            ORDER BY category, name
            """;
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);
        return jdbc.query(sql, params, (rs, n) -> new ServiceDto(
                rs.getObject("id", UUID.class),
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getBigDecimal("default_price")
        ));
    }
}
