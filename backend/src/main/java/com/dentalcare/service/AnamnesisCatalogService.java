package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.exception.CatalogItemInUseException;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class AnamnesisCatalogService {

    private final NamedParameterJdbcTemplate jdbc;

    public AnamnesisCatalogService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    // ── Categories ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<CatalogCategoryDto> findAllCategories() {
        return jdbc.query("""
            SELECT c.id, c.code, c.name, c.description, c.icon, c.sort_order, c.enabled,
                   COUNT(i.id) AS items_count
            FROM %s.anamnesis_categories c
            LEFT JOIN %s.anamnesis_items i ON i.category_id = c.id
            GROUP BY c.id, c.code, c.name, c.description, c.icon, c.sort_order, c.enabled
            ORDER BY c.sort_order, c.name
            """.formatted(s(), s()),
            new MapSqlParameterSource(),
            (rs, n) -> new CatalogCategoryDto(
                    rs.getObject("id", UUID.class),
                    rs.getString("code"),
                    rs.getString("name"),
                    rs.getString("description"),
                    rs.getString("icon"),
                    rs.getInt("sort_order"),
                    rs.getBoolean("enabled"),
                    rs.getLong("items_count")
            ));
    }

    @Transactional
    public CatalogCategoryDto createCategory(CreateCatalogCategoryRequest req) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO %s.anamnesis_categories
                (id, code, name, description, icon, sort_order, enabled)
            VALUES (:id, :code, :name, :description, :icon, :sortOrder, true)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("code", req.code().toUpperCase().trim())
                .addValue("name", req.name())
                .addValue("description", req.description())
                .addValue("icon", req.icon())
                .addValue("sortOrder", req.sortOrder()));
        return findAllCategories().stream()
                .filter(c -> c.id().equals(id))
                .findFirst().orElseThrow();
    }

    @Transactional
    public void updateCategory(UUID id, UpdateCatalogCategoryRequest req) {
        jdbc.update("""
            UPDATE %s.anamnesis_categories
            SET name = :name, description = :description, icon = :icon,
                sort_order = :sortOrder, enabled = :enabled
            WHERE id = :id
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("name", req.name())
                .addValue("description", req.description())
                .addValue("icon", req.icon())
                .addValue("sortOrder", req.sortOrder())
                .addValue("enabled", req.enabled()));
    }

    @Transactional
    public void deleteCategory(UUID id) {
        long inUse = countPatientsUsingCategory(id);
        if (inUse > 0) {
            throw new CatalogItemInUseException(
                    "Impossibile eliminare: %d pazienti hanno una voce di questa categoria selezionata nell'anamnesi. Disabilita la categoria invece di eliminarla.".formatted(inUse));
        }
        jdbc.update("DELETE FROM %s.anamnesis_categories WHERE id = :id".formatted(s()),
            new MapSqlParameterSource("id", id));
    }

    private long countPatientsUsingCategory(UUID categoryId) {
        Long count = jdbc.queryForObject("""
            SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections s
            JOIN %s.anamnesis_items i ON i.id = s.item_id
            WHERE i.category_id = :categoryId AND s.resolved_at IS NULL
            """.formatted(s(), s()),
            new MapSqlParameterSource("categoryId", categoryId), Long.class);
        return count != null ? count : 0L;
    }

    // ── Items ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<CatalogItemDto> findItemsByCategory(UUID categoryId) {
        return jdbc.query("""
            SELECT id, category_id, code, label, description, severity, sort_order, enabled
            FROM %s.anamnesis_items
            WHERE category_id = :categoryId
            ORDER BY sort_order, label
            """.formatted(s()),
            new MapSqlParameterSource("categoryId", categoryId),
            (rs, n) -> new CatalogItemDto(
                    rs.getObject("id", UUID.class),
                    rs.getObject("category_id", UUID.class),
                    rs.getString("code"),
                    rs.getString("label"),
                    rs.getString("description"),
                    rs.getString("severity"),
                    rs.getInt("sort_order"),
                    rs.getBoolean("enabled")
            ));
    }

    @Transactional
    public CatalogItemDto createItem(CreateCatalogItemRequest req) {
        UUID id = UUID.randomUUID();
        String severity = req.severity() != null ? req.severity() : "normale";
        jdbc.update("""
            INSERT INTO %s.anamnesis_items
                (id, category_id, code, label, description, severity, sort_order, enabled)
            VALUES (:id, :categoryId, :code, :label, :description, :severity, :sortOrder, true)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("categoryId", req.categoryId())
                .addValue("code", req.code().toUpperCase().trim())
                .addValue("label", req.label())
                .addValue("description", req.description())
                .addValue("severity", severity)
                .addValue("sortOrder", req.sortOrder()));
        return findItemsByCategory(req.categoryId()).stream()
                .filter(i -> i.id().equals(id))
                .findFirst().orElseThrow();
    }

    @Transactional
    public void updateItem(UUID id, UpdateCatalogItemRequest req) {
        String severity = req.severity() != null ? req.severity() : "normale";
        jdbc.update("""
            UPDATE %s.anamnesis_items
            SET label = :label, description = :description, severity = :severity,
                sort_order = :sortOrder, enabled = :enabled
            WHERE id = :id
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("label", req.label())
                .addValue("description", req.description())
                .addValue("severity", severity)
                .addValue("sortOrder", req.sortOrder())
                .addValue("enabled", req.enabled()));
    }

    @Transactional
    public void deleteItem(UUID id) {
        long inUse = countPatientsUsingItem(id);
        if (inUse > 0) {
            throw new CatalogItemInUseException(
                    "Impossibile eliminare: %d pazienti hanno questa voce selezionata nell'anamnesi. Disabilita la voce invece di eliminarla.".formatted(inUse));
        }
        jdbc.update("DELETE FROM %s.anamnesis_items WHERE id = :id".formatted(s()),
            new MapSqlParameterSource("id", id));
    }

    private long countPatientsUsingItem(UUID itemId) {
        Long count = jdbc.queryForObject("""
            SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections
            WHERE item_id = :itemId AND resolved_at IS NULL
            """.formatted(s()),
            new MapSqlParameterSource("itemId", itemId), Long.class);
        return count != null ? count : 0L;
    }
}
