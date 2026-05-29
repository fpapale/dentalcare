package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.ZoneOffset;
import java.util.*;

@Service
public class TreatmentPlanService {

    private final NamedParameterJdbcTemplate jdbc;

    public TreatmentPlanService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    public List<TreatmentPlanSummaryDto> findByPatient(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT tp.id, tp.name, tp.status::text,
                   COUNT(tpi.id)                                                              AS total_items,
                   COUNT(tpi.id) FILTER (WHERE tpi.status = 'completed')                     AS completed_items,
                   COUNT(tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled')) AS open_items,
                   tp.created_at, tp.updated_at
            FROM %s.treatment_plans tp
            LEFT JOIN %s.treatment_plan_items tpi
                   ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = tp.clinic_id
            WHERE tp.clinic_id = :clinicId AND tp.patient_id = :patientId
            GROUP BY tp.id, tp.name, tp.status, tp.created_at, tp.updated_at
            ORDER BY tp.updated_at DESC
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
                (rs, n) -> mapSummary(rs));
    }

    public TreatmentPlanDto findById(UUID planId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String planSql = """
            SELECT tp.id, tp.name, tp.description, tp.status::text,
                   tp.patient_id,
                   concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
                   tp.created_by_provider_id,
                   concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
                   tp.created_at, tp.updated_at
            FROM %s.treatment_plans tp
            JOIN %s.patients p ON p.id = tp.patient_id AND p.clinic_id = tp.clinic_id
            LEFT JOIN %s.providers prov ON prov.id = tp.created_by_provider_id AND prov.clinic_id = tp.clinic_id
            WHERE tp.id = :planId AND tp.clinic_id = :clinicId
            """.formatted(s(), s(), s());
        List<TreatmentPlanDto> plans = jdbc.query(planSql,
                new MapSqlParameterSource().addValue("planId", planId).addValue("clinicId", clinicId),
                (rs, n) -> new TreatmentPlanDto(
                        rs.getObject("id", UUID.class),
                        rs.getString("name"),
                        rs.getString("description"),
                        rs.getString("status"),
                        rs.getObject("patient_id", UUID.class),
                        rs.getString("patient_full_name"),
                        rs.getObject("created_by_provider_id", UUID.class),
                        rs.getString("provider_name"),
                        rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                        rs.getTimestamp("updated_at") != null ? rs.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                        null
                ));
        if (plans.isEmpty()) return null;
        TreatmentPlanDto plan = plans.get(0);

        String itemsSql = """
            SELECT tpi.id, tpi.service_id, sc.name AS service_name, sc.category AS service_category,
                   sc.duration_minutes,
                   tpi.provider_id, concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
                   tpi.tooth_number, tpi.quadrant, tpi.planned_price,
                   tpi.status::text, tpi.priority, tpi.planned_date, tpi.clinical_notes,
                   tpi.created_at,
                   tc.condition AS odontogram_condition
            FROM %s.treatment_plan_items tpi
            JOIN %s.treatment_plans tp ON tp.id = tpi.treatment_plan_id AND tp.clinic_id = tpi.clinic_id
            JOIN %s.service_catalog sc ON sc.id = tpi.service_id AND sc.clinic_id = tpi.clinic_id
            LEFT JOIN %s.providers prov ON prov.id = tpi.provider_id AND prov.clinic_id = tpi.clinic_id
            LEFT JOIN %s.tooth_conditions tc
                ON tpi.tooth_number ~ '^[0-9]+$'
               AND CAST(tpi.tooth_number AS integer) = tc.tooth_fdi
               AND tc.surface = 'WHOLE'
               AND tc.patient_id = tp.patient_id
               AND tc.clinic_id = tpi.clinic_id
            WHERE tpi.treatment_plan_id = :planId AND tpi.clinic_id = :clinicId
            ORDER BY tpi.priority, tpi.created_at
            """.formatted(s(), s(), s(), s(), s());
        List<TreatmentPlanItemDto> items = jdbc.query(itemsSql,
                new MapSqlParameterSource().addValue("planId", planId).addValue("clinicId", clinicId),
                (rs, n) -> mapItem(rs));

        return new TreatmentPlanDto(plan.planId(), plan.name(), plan.description(), plan.status(),
                plan.patientId(), plan.patientFullName(), plan.createdByProviderId(),
                plan.createdByProviderName(), plan.createdAt(), plan.updatedAt(), items);
    }

    public UUID create(CreateTreatmentPlanRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();
        String sql = """
            INSERT INTO %s.treatment_plans
                (id, clinic_id, patient_id, name, description, status)
            VALUES (:id, :clinicId, :patientId, :name, :description, 'draft')
            """.formatted(s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("patientId", request.patientId())
                .addValue("name", request.name())
                .addValue("description", request.description()));
        return id;
    }

    public void updateStatus(UUID planId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE %s.treatment_plans
            SET status = CAST(:status AS %s.treatment_plan_status)
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s(), s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", planId)
                .addValue("clinicId", clinicId)
                .addValue("status", status));
    }

    public UUID addItem(UUID planId, AddTreatmentPlanItemRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        // Resolve default_price and duration if not provided
        BigDecimalHolder defaults = resolveServiceDefaults(request.serviceId(), clinicId);
        java.math.BigDecimal price = request.plannedPrice() != null ? request.plannedPrice() : defaults.price();

        UUID id = UUID.randomUUID();
        Integer quadrant = request.quadrant();
        if (quadrant != null && (quadrant < 1 || quadrant > 4)) quadrant = null;
        String sql = """
            INSERT INTO %s.treatment_plan_items
                (id, clinic_id, treatment_plan_id, service_id, provider_id,
                 tooth_number, quadrant, planned_price, status, priority, planned_date, clinical_notes)
            VALUES
                (:id, :clinicId, :planId, :serviceId, :providerId,
                 :toothNumber, :quadrant, :plannedPrice, 'planned',
                 :priority, :plannedDate, :clinicalNotes)
            """.formatted(s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("planId", planId)
                .addValue("serviceId", request.serviceId())
                .addValue("providerId", request.providerId())
                .addValue("toothNumber", request.toothNumber())
                .addValue("quadrant", quadrant)
                .addValue("plannedPrice", price)
                .addValue("priority", request.priority() != null ? request.priority() : 100)
                .addValue("plannedDate", request.plannedDate())
                .addValue("clinicalNotes", request.clinicalNotes()));
        return id;
    }

    public void updateItemStatus(UUID planId, UUID itemId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE %s.treatment_plan_items
            SET status = CAST(:status AS %s.treatment_item_status),
                completed_at = CASE WHEN :status = 'completed' THEN now() ELSE completed_at END
            WHERE id = :id AND treatment_plan_id = :planId AND clinic_id = :clinicId
            """.formatted(s(), s());
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", itemId)
                .addValue("planId", planId)
                .addValue("clinicId", clinicId)
                .addValue("status", status));
        if ("completed".equals(status)) {
            syncToothOnCompletion(planId, itemId, clinicId);
        }
    }

    @Transactional
    public UUID createFromOdontogram(CreatePlanFromOdontogramRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID planId = UUID.randomUUID();

        jdbc.update("""
            INSERT INTO %s.treatment_plans
                (id, clinic_id, patient_id, name, description, status)
            VALUES (:id, :clinicId, :patientId, :name, :description, 'draft')
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", planId)
                .addValue("clinicId", clinicId)
                .addValue("patientId", request.patientId())
                .addValue("name", request.name())
                .addValue("description", "Generato da odontogramma"));

        List<OdontogramPlanItemRequest> items = request.items();
        for (int i = 0; i < items.size(); i++) {
            OdontogramPlanItemRequest item = items.get(i);
            java.math.BigDecimal price = resolveServiceDefaults(item.serviceId(), clinicId).price();
            int rawQuadrant = item.toothFdi() / 10;
            Integer quadrant = (rawQuadrant >= 1 && rawQuadrant <= 4) ? rawQuadrant : null;
            jdbc.update("""
                INSERT INTO %s.treatment_plan_items
                    (id, clinic_id, treatment_plan_id, service_id, tooth_number, quadrant,
                     planned_price, status, priority, clinical_notes)
                VALUES
                    (:id, :clinicId, :planId, :serviceId, :toothNumber, :quadrant,
                     :plannedPrice, 'planned', :priority, :clinicalNotes)
                """.formatted(s()),
                new MapSqlParameterSource()
                    .addValue("id", UUID.randomUUID())
                    .addValue("clinicId", clinicId)
                    .addValue("planId", planId)
                    .addValue("serviceId", item.serviceId())
                    .addValue("toothNumber", String.valueOf(item.toothFdi()))
                    .addValue("quadrant", quadrant)
                    .addValue("plannedPrice", price)
                    .addValue("priority", (i + 1) * 10)
                    .addValue("clinicalNotes", item.clinicalNotes()));
        }
        return planId;
    }

    private void syncToothOnCompletion(UUID planId, UUID itemId, UUID clinicId) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT tpi.tooth_number, tp.patient_id
            FROM %s.treatment_plan_items tpi
            JOIN %s.treatment_plans tp
                ON tp.id = tpi.treatment_plan_id AND tp.clinic_id = tpi.clinic_id
            WHERE tpi.id = :itemId AND tpi.treatment_plan_id = :planId AND tpi.clinic_id = :clinicId
            """.formatted(s(), s()),
            new MapSqlParameterSource()
                .addValue("itemId", itemId)
                .addValue("planId", planId)
                .addValue("clinicId", clinicId));
        if (rows.isEmpty()) return;

        String toothStr = (String) rows.get(0).get("tooth_number");
        Object patientIdObj = rows.get(0).get("patient_id");
        if (toothStr == null || patientIdObj == null) return;

        int fdi;
        try { fdi = Integer.parseInt(toothStr.trim()); } catch (NumberFormatException e) { return; }

        UUID patientId = patientIdObj instanceof UUID u ? u : UUID.fromString(patientIdObj.toString());
        MapSqlParameterSource p = new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId)
                .addValue("fdi", fdi);

        int updated = jdbc.update("""
            UPDATE %s.tooth_conditions
            SET condition = 'extracted'
            WHERE clinic_id = :clinicId AND patient_id = :patientId AND tooth_fdi = :fdi
              AND surface = 'WHOLE' AND condition = 'to_extract'
            """.formatted(s()), p);
        if (updated > 0) return;

        jdbc.update("""
            UPDATE %s.tooth_conditions
            SET condition = 'filling'
            WHERE clinic_id = :clinicId AND patient_id = :patientId AND tooth_fdi = :fdi
              AND condition = 'cavity'
            """.formatted(s()), p);
    }

    public void deleteItem(UUID planId, UUID itemId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            DELETE FROM %s.treatment_plan_items
            WHERE id = :id AND treatment_plan_id = :planId AND clinic_id = :clinicId
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", itemId)
                .addValue("planId", planId)
                .addValue("clinicId", clinicId));
    }

    public void updateName(UUID planId, String name) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.treatment_plans
            SET name = :name, updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", planId)
                .addValue("clinicId", clinicId)
                .addValue("name", name));
    }

    public void deletePlan(UUID planId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            DELETE FROM %s.treatment_plans
            WHERE id = :planId AND clinic_id = :clinicId
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("planId", planId)
                .addValue("clinicId", clinicId));
    }

    private BigDecimalHolder resolveServiceDefaults(UUID serviceId, UUID clinicId) {
        String sql = "SELECT default_price FROM " + s() + ".service_catalog WHERE id = :id AND clinic_id = :clinicId";
        List<java.math.BigDecimal> prices = jdbc.queryForList(sql,
                new MapSqlParameterSource().addValue("id", serviceId).addValue("clinicId", clinicId),
                java.math.BigDecimal.class);
        return new BigDecimalHolder(prices.isEmpty() ? java.math.BigDecimal.ZERO : prices.get(0));
    }

    private record BigDecimalHolder(java.math.BigDecimal price) {}

    private TreatmentPlanSummaryDto mapSummary(ResultSet rs) throws SQLException {
        return new TreatmentPlanSummaryDto(
                rs.getObject("id", UUID.class),
                rs.getString("name"),
                rs.getString("status"),
                rs.getInt("total_items"),
                rs.getInt("completed_items"),
                rs.getInt("open_items"),
                rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("updated_at") != null ? rs.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC) : null
        );
    }

    private TreatmentPlanItemDto mapItem(ResultSet rs) throws SQLException {
        return new TreatmentPlanItemDto(
                rs.getObject("id", UUID.class),
                rs.getObject("service_id", UUID.class),
                rs.getString("service_name"),
                rs.getString("service_category"),
                rs.getObject("duration_minutes", Integer.class),
                rs.getObject("provider_id", UUID.class),
                rs.getString("provider_name"),
                rs.getString("tooth_number"),
                rs.getObject("quadrant", Integer.class),
                rs.getBigDecimal("planned_price"),
                rs.getString("status"),
                rs.getObject("priority", Integer.class),
                rs.getDate("planned_date") != null ? rs.getDate("planned_date").toLocalDate() : null,
                rs.getString("clinical_notes"),
                rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getString("odontogram_condition")
        );
    }
}
