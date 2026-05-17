package com.dentalcare.service;

import com.dentalcare.dto.CreateStockMovementRequest;
import com.dentalcare.dto.StockMovementDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

@Service
public class StockMovementService {

    private final NamedParameterJdbcTemplate jdbc;

    public StockMovementService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    // ── List ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<StockMovementDto> findAll(UUID productId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("clinicId", clinicId);

        StringBuilder filter = new StringBuilder();
        if (productId != null) {
            filter.append(" AND m.product_id = :productId");
            params.addValue("productId", productId);
        }

        String sql = "SELECT m.id, m.product_id, p.name AS product_name,"
                + " m.movement_type::text AS movement_type,"
                + " m.quantity, m.unit_cost, m.notes, m.reference_doc,"
                + " m.created_by_provider_id, m.created_at"
                + " FROM " + s() + ".stock_movements m"
                + " JOIN " + s() + ".products p ON p.id = m.product_id AND p.clinic_id = m.clinic_id"
                + " WHERE m.clinic_id = :clinicId"
                + filter
                + " ORDER BY m.created_at DESC LIMIT 200";

        return jdbc.query(sql, params, (rs, n) -> mapRow(rs));
    }

    // ── Create ────────────────────────────────────────────────────────────────

    @Transactional
    public StockMovementDto create(CreateStockMovementRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();

        jdbc.update("""
                INSERT INTO %s.stock_movements
                    (id, clinic_id, product_id, movement_type, quantity,
                     unit_cost, notes, reference_doc, created_by_provider_id)
                VALUES
                    (:id, :clinicId, :productId,
                     CAST(:movementType AS %s.stock_movement_type),
                     :quantity, :unitCost, :notes, :referenceDoc, :createdByProviderId)
                """.formatted(s(), s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("productId", req.productId())
                        .addValue("movementType", req.movementType())
                        .addValue("quantity", req.quantity())
                        .addValue("unitCost", req.unitCost())
                        .addValue("notes", req.notes())
                        .addValue("referenceDoc", req.referenceDoc())
                        .addValue("createdByProviderId", req.createdByProviderId()));

        List<StockMovementDto> rows = jdbc.query(
                "SELECT m.id, m.product_id, p.name AS product_name,"
                        + " m.movement_type::text AS movement_type,"
                        + " m.quantity, m.unit_cost, m.notes, m.reference_doc,"
                        + " m.created_by_provider_id, m.created_at"
                        + " FROM " + s() + ".stock_movements m"
                        + " JOIN " + s() + ".products p ON p.id = m.product_id AND p.clinic_id = m.clinic_id"
                        + " WHERE m.id = :id AND m.clinic_id = :clinicId",
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                (rs, n) -> mapRow(rs));

        return rows.get(0);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private StockMovementDto mapRow(ResultSet rs) throws SQLException {
        return new StockMovementDto(
                rs.getObject("id", UUID.class),
                rs.getObject("product_id", UUID.class),
                rs.getString("product_name"),
                rs.getString("movement_type"),
                rs.getBigDecimal("quantity"),
                rs.getBigDecimal("unit_cost"),
                rs.getString("notes"),
                rs.getString("reference_doc"),
                rs.getObject("created_by_provider_id", UUID.class),
                rs.getTimestamp("created_at") != null
                        ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC)
                        : null
        );
    }
}
