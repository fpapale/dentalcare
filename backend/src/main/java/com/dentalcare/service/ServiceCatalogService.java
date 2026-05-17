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

    private String s() { return TenantContext.validatedSchema(); }

    public List<ServiceDto> findAll() {
        return findAll(null);
    }

    public List<ServiceDto> findAll(Integer toothFdi) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);

        String toothFilter = "";
        if (toothFdi != null) {
            int digit = toothFdi % 10;
            boolean isDeciduous = toothFdi / 10 >= 5;
            params.addValue("digit", digit);
            params.addValue("isDeciduous", isDeciduous);
            toothFilter = """
                AND (min_tooth_digit IS NULL OR :digit >= min_tooth_digit)
                AND (max_tooth_digit IS NULL OR :digit <= max_tooth_digit)
                AND (:isDeciduous = false OR applicable_to_deciduous = true)
                """;
        }

        String sql = """
            SELECT id, code, name, category, default_price, duration_minutes
            FROM %s.service_catalog
            WHERE clinic_id = :clinicId
              AND active = true
            """.formatted(s()) + toothFilter + """
            ORDER BY category, name
            """;

        return jdbc.query(sql, params, (rs, n) -> new ServiceDto(
                rs.getObject("id", UUID.class),
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getBigDecimal("default_price"),
                rs.getObject("duration_minutes", Integer.class)
        ));
    }

    public List<ServiceDto> findConditionDefaults(String conditionName) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT sc.id, sc.code, sc.name, sc.category, sc.default_price, sc.duration_minutes
            FROM %s.condition_service_defaults csd
            JOIN %s.service_catalog sc ON sc.id = csd.service_id AND sc.clinic_id = csd.clinic_id
            WHERE csd.condition_name = :conditionName AND csd.clinic_id = :clinicId AND sc.active = true
            ORDER BY csd.sort_order
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("conditionName", conditionName).addValue("clinicId", clinicId),
                (rs, n) -> new ServiceDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("code"),
                        rs.getString("name"),
                        rs.getString("category"),
                        rs.getBigDecimal("default_price"),
                        rs.getObject("duration_minutes", Integer.class)
                ));
    }

    public List<ServiceDto> findBundleItems(UUID serviceId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT sc.id, sc.code, sc.name, sc.category, sc.default_price, sc.duration_minutes
            FROM %s.service_bundle_items sbi
            JOIN %s.service_catalog sc ON sc.id = sbi.child_service_id AND sc.clinic_id = sbi.clinic_id
            WHERE sbi.parent_service_id = :serviceId AND sbi.clinic_id = :clinicId AND sc.active = true
            ORDER BY sbi.sort_order
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("serviceId", serviceId).addValue("clinicId", clinicId),
                (rs, n) -> new ServiceDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("code"),
                        rs.getString("name"),
                        rs.getString("category"),
                        rs.getBigDecimal("default_price"),
                        rs.getObject("duration_minutes", Integer.class)
                ));
    }
}
