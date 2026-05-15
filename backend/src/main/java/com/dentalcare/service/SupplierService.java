package com.dentalcare.service;

import com.dentalcare.dto.CreateSupplierRequest;
import com.dentalcare.dto.SupplierDto;
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
public class SupplierService {

    private final NamedParameterJdbcTemplate jdbc;

    public SupplierService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── List ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<SupplierDto> findAll(boolean includeInactive) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = "SELECT id, name, contact_person, phone, email, notes, is_active"
                + " FROM dentalcare.suppliers"
                + " WHERE clinic_id = :clinicId"
                + (includeInactive ? "" : " AND is_active = true")
                + " ORDER BY name";

        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId),
                (rs, n) -> mapRow(rs));
    }

    // ── Create ────────────────────────────────────────────────────────────────

    @Transactional
    public SupplierDto create(CreateSupplierRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();

        jdbc.update("""
                INSERT INTO dentalcare.suppliers
                    (id, clinic_id, name, contact_person, phone, email, notes, is_active)
                VALUES
                    (:id, :clinicId, :name, :contactPerson, :phone, :email, :notes, true)
                """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("name", req.name())
                        .addValue("contactPerson", req.contactPerson())
                        .addValue("phone", req.phone())
                        .addValue("email", req.email())
                        .addValue("notes", req.notes()));

        return findById(id, clinicId);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @Transactional
    public SupplierDto update(UUID id, CreateSupplierRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
                UPDATE dentalcare.suppliers
                SET name           = :name,
                    contact_person = :contactPerson,
                    phone          = :phone,
                    email          = :email,
                    notes          = :notes,
                    updated_at     = now()
                WHERE id = :id AND clinic_id = :clinicId
                """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("name", req.name())
                        .addValue("contactPerson", req.contactPerson())
                        .addValue("phone", req.phone())
                        .addValue("email", req.email())
                        .addValue("notes", req.notes()));

        if (rows == 0) {
            throw new ResourceNotFoundException("Supplier not found: " + id);
        }
        return findById(id, clinicId);
    }

    // ── Delete (soft) ─────────────────────────────────────────────────────────

    @Transactional
    public void delete(UUID id) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        int rows = jdbc.update("""
                UPDATE dentalcare.suppliers
                SET is_active  = false,
                    updated_at = now()
                WHERE id = :id AND clinic_id = :clinicId
                """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId));

        if (rows == 0) {
            throw new ResourceNotFoundException("Supplier not found: " + id);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private SupplierDto findById(UUID id, UUID clinicId) {
        List<SupplierDto> rows = jdbc.query(
                "SELECT id, name, contact_person, phone, email, notes, is_active"
                        + " FROM dentalcare.suppliers WHERE id = :id AND clinic_id = :clinicId",
                new MapSqlParameterSource().addValue("id", id).addValue("clinicId", clinicId),
                (rs, n) -> mapRow(rs));
        if (rows.isEmpty()) {
            throw new ResourceNotFoundException("Supplier not found: " + id);
        }
        return rows.get(0);
    }

    private SupplierDto mapRow(ResultSet rs) throws SQLException {
        return new SupplierDto(
                rs.getObject("id", UUID.class),
                rs.getString("name"),
                rs.getString("contact_person"),
                rs.getString("phone"),
                rs.getString("email"),
                rs.getString("notes"),
                rs.getBoolean("is_active")
        );
    }
}
