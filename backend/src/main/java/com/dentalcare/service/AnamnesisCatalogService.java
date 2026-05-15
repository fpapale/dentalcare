package com.dentalcare.service;

import com.dentalcare.dto.*;
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

    // ── Categories ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<CatalogCategoryDto> findAllCategories() {
        return jdbc.query("""
            SELECT c.id, c.code, c.name, c.description, c.icon, c.sort_order, c.enabled,
                   COUNT(i.id) AS items_count
            FROM dentalcare.anamnesis_categories c
            LEFT JOIN dentalcare.anamnesis_items i ON i.category_id = c.id
            GROUP BY c.id, c.code, c.name, c.description, c.icon, c.sort_order, c.enabled
            ORDER BY c.sort_order, c.name
            """,
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
            INSERT INTO dentalcare.anamnesis_categories
                (id, code, name, description, icon, sort_order, enabled)
            VALUES (:id, :code, :name, :description, :icon, :sortOrder, true)
            """,
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
            UPDATE dentalcare.anamnesis_categories
            SET name = :name, description = :description, icon = :icon,
                sort_order = :sortOrder, enabled = :enabled
            WHERE id = :id
            """,
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
        jdbc.update("DELETE FROM dentalcare.anamnesis_categories WHERE id = :id",
            new MapSqlParameterSource("id", id));
    }

    // ── Items ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<CatalogItemDto> findItemsByCategory(UUID categoryId) {
        return jdbc.query("""
            SELECT id, category_id, code, label, description, is_alert, sort_order, enabled
            FROM dentalcare.anamnesis_items
            WHERE category_id = :categoryId
            ORDER BY sort_order, label
            """,
            new MapSqlParameterSource("categoryId", categoryId),
            (rs, n) -> new CatalogItemDto(
                    rs.getObject("id", UUID.class),
                    rs.getObject("category_id", UUID.class),
                    rs.getString("code"),
                    rs.getString("label"),
                    rs.getString("description"),
                    rs.getBoolean("is_alert"),
                    rs.getInt("sort_order"),
                    rs.getBoolean("enabled")
            ));
    }

    @Transactional
    public CatalogItemDto createItem(CreateCatalogItemRequest req) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO dentalcare.anamnesis_items
                (id, category_id, code, label, description, is_alert, sort_order, enabled)
            VALUES (:id, :categoryId, :code, :label, :description, :isAlert, :sortOrder, true)
            """,
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("categoryId", req.categoryId())
                .addValue("code", req.code().toUpperCase().trim())
                .addValue("label", req.label())
                .addValue("description", req.description())
                .addValue("isAlert", req.isAlert())
                .addValue("sortOrder", req.sortOrder()));
        return findItemsByCategory(req.categoryId()).stream()
                .filter(i -> i.id().equals(id))
                .findFirst().orElseThrow();
    }

    @Transactional
    public void updateItem(UUID id, UpdateCatalogItemRequest req) {
        jdbc.update("""
            UPDATE dentalcare.anamnesis_items
            SET label = :label, description = :description, is_alert = :isAlert,
                sort_order = :sortOrder, enabled = :enabled
            WHERE id = :id
            """,
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("label", req.label())
                .addValue("description", req.description())
                .addValue("isAlert", req.isAlert())
                .addValue("sortOrder", req.sortOrder())
                .addValue("enabled", req.enabled()));
    }

    @Transactional
    public void deleteItem(UUID id) {
        jdbc.update("DELETE FROM dentalcare.anamnesis_items WHERE id = :id",
            new MapSqlParameterSource("id", id));
    }
}
