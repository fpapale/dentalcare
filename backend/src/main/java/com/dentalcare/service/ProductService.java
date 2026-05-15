package com.dentalcare.service;

import com.dentalcare.dto.CreateProductRequest;
import com.dentalcare.dto.ProductCategoryDto;
import com.dentalcare.dto.ProductDto;
import com.dentalcare.exception.ResourceNotFoundException;
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
public class ProductService {

    private final NamedParameterJdbcTemplate jdbc;

    public ProductService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── List ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ProductDto> findAll(boolean lowStockOnly) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = "SELECT product_id, category_id, category_name, supplier_id, supplier_name,"
                + " name, description, sku, unit,"
                + " min_stock_quantity, reorder_quantity, unit_cost,"
                + " current_stock, stock_status, is_active"
                + " FROM dentalcare.product_stock_v"
                + " WHERE clinic_id = :clinicId AND is_active = true"
                + (lowStockOnly ? " AND stock_status IN ('critico', 'basso')" : "")
                + " ORDER BY name";

        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId),
                (rs, n) -> mapProductRow(rs));
    }

    // ── Categories ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ProductCategoryDto> findCategories() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        return jdbc.query(
                "SELECT id, name FROM dentalcare.product_categories"
                        + " WHERE clinic_id = :clinicId ORDER BY name",
                new MapSqlParameterSource().addValue("clinicId", clinicId),
                (rs, n) -> new ProductCategoryDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("name")));
    }

    // ── Create ────────────────────────────────────────────────────────────────

    @Transactional
    public ProductDto create(CreateProductRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();

        jdbc.update("""
                INSERT INTO dentalcare.products
                    (id, clinic_id, category_id, supplier_id,
                     name, description, sku, unit,
                     min_stock_quantity, reorder_quantity, unit_cost, is_active)
                VALUES
                    (:id, :clinicId, :categoryId, :supplierId,
                     :name, :description, :sku, :unit,
                     :minStockQuantity, :reorderQuantity, :unitCost, true)
                """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("categoryId", req.categoryId())
                        .addValue("supplierId", req.supplierId())
                        .addValue("name", req.name())
                        .addValue("description", req.description())
                        .addValue("sku", req.sku())
                        .addValue("unit", req.unit())
                        .addValue("minStockQuantity", req.minStockQuantity())
                        .addValue("reorderQuantity", req.reorderQuantity())
                        .addValue("unitCost", req.unitCost()));

        return findFromView(id, clinicId);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @Transactional
    public ProductDto update(UUID id, CreateProductRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
                UPDATE dentalcare.products
                SET category_id        = :categoryId,
                    supplier_id        = :supplierId,
                    name               = :name,
                    description        = :description,
                    sku                = :sku,
                    unit               = :unit,
                    min_stock_quantity = :minStockQuantity,
                    reorder_quantity   = :reorderQuantity,
                    unit_cost          = :unitCost,
                    updated_at         = now()
                WHERE id = :id AND clinic_id = :clinicId
                """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("categoryId", req.categoryId())
                        .addValue("supplierId", req.supplierId())
                        .addValue("name", req.name())
                        .addValue("description", req.description())
                        .addValue("sku", req.sku())
                        .addValue("unit", req.unit())
                        .addValue("minStockQuantity", req.minStockQuantity())
                        .addValue("reorderQuantity", req.reorderQuantity())
                        .addValue("unitCost", req.unitCost()));

        if (rows == 0) {
            throw new ResourceNotFoundException("Product not found: " + id);
        }
        return findFromView(id, clinicId);
    }

    // ── Delete (soft) ─────────────────────────────────────────────────────────

    @Transactional
    public void delete(UUID id) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
                UPDATE dentalcare.products
                SET is_active  = false,
                    updated_at = now()
                WHERE id = :id AND clinic_id = :clinicId
                """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId));

        if (rows == 0) {
            throw new ResourceNotFoundException("Product not found: " + id);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private ProductDto findFromView(UUID id, UUID clinicId) {
        List<ProductDto> rows = jdbc.query(
                "SELECT product_id, category_id, category_name, supplier_id, supplier_name,"
                        + " name, description, sku, unit,"
                        + " min_stock_quantity, reorder_quantity, unit_cost,"
                        + " current_stock, stock_status, is_active"
                        + " FROM dentalcare.product_stock_v"
                        + " WHERE product_id = :id AND clinic_id = :clinicId",
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                (rs, n) -> mapProductRow(rs));
        if (rows.isEmpty()) {
            throw new ResourceNotFoundException("Product not found: " + id);
        }
        return rows.get(0);
    }

    private ProductDto mapProductRow(ResultSet rs) throws SQLException {
        return new ProductDto(
                rs.getObject("product_id", UUID.class),
                rs.getObject("category_id", UUID.class),
                rs.getString("category_name"),
                rs.getObject("supplier_id", UUID.class),
                rs.getString("supplier_name"),
                rs.getString("name"),
                rs.getString("description"),
                rs.getString("sku"),
                rs.getString("unit"),
                rs.getBigDecimal("min_stock_quantity"),
                rs.getBigDecimal("reorder_quantity"),
                rs.getBigDecimal("unit_cost"),
                rs.getBigDecimal("current_stock"),
                rs.getString("stock_status"),
                rs.getBoolean("is_active")
        );
    }
}
