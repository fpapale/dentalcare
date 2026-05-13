package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

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

    public List<TreatmentPlanSummaryDto> findByPatient(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT tp.id, tp.name, tp.status::text,
                   COUNT(tpi.id)                                                              AS total_items,
                   COUNT(tpi.id) FILTER (WHERE tpi.status = 'completed')                     AS completed_items,
                   COUNT(tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled')) AS open_items,
                   tp.created_at, tp.updated_at
            FROM dentalcare.treatment_plans tp
            LEFT JOIN dentalcare.treatment_plan_items tpi
                   ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = tp.clinic_id
            WHERE tp.clinic_id = :clinicId AND tp.patient_id = :patientId
            GROUP BY tp.id, tp.name, tp.status, tp.created_at, tp.updated_at
            ORDER BY tp.updated_at DESC
            """;
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
            FROM dentalcare.treatment_plans tp
            JOIN dentalcare.patients p ON p.id = tp.patient_id AND p.clinic_id = tp.clinic_id
            LEFT JOIN dentalcare.providers prov ON prov.id = tp.created_by_provider_id AND prov.clinic_id = tp.clinic_id
            WHERE tp.id = :planId AND tp.clinic_id = :clinicId
            """;
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
                   tpi.created_at
            FROM dentalcare.treatment_plan_items tpi
            JOIN dentalcare.service_catalog sc ON sc.id = tpi.service_id AND sc.clinic_id = tpi.clinic_id
            LEFT JOIN dentalcare.providers prov ON prov.id = tpi.provider_id AND prov.clinic_id = tpi.clinic_id
            WHERE tpi.treatment_plan_id = :planId AND tpi.clinic_id = :clinicId
            ORDER BY tpi.priority, tpi.created_at
            """;
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
            INSERT INTO dentalcare.treatment_plans
                (id, clinic_id, patient_id, name, description, status)
            VALUES (:id, :clinicId, :patientId, :name, :description, 'draft')
            """;
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
            UPDATE dentalcare.treatment_plans
            SET status = CAST(:status AS dentalcare.treatment_plan_status)
            WHERE id = :id AND clinic_id = :clinicId
            """;
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
        String sql = """
            INSERT INTO dentalcare.treatment_plan_items
                (id, clinic_id, treatment_plan_id, service_id, provider_id,
                 tooth_number, quadrant, planned_price, status, priority, planned_date, clinical_notes)
            VALUES
                (:id, :clinicId, :planId, :serviceId, :providerId,
                 :toothNumber, :quadrant, :plannedPrice, 'planned',
                 :priority, :plannedDate, :clinicalNotes)
            """;
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("clinicId", clinicId)
                .addValue("planId", planId)
                .addValue("serviceId", request.serviceId())
                .addValue("providerId", request.providerId())
                .addValue("toothNumber", request.toothNumber())
                .addValue("quadrant", request.quadrant())
                .addValue("plannedPrice", price)
                .addValue("priority", request.priority() != null ? request.priority() : 100)
                .addValue("plannedDate", request.plannedDate())
                .addValue("clinicalNotes", request.clinicalNotes()));
        return id;
    }

    public void updateItemStatus(UUID planId, UUID itemId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            UPDATE dentalcare.treatment_plan_items
            SET status = CAST(:status AS dentalcare.treatment_item_status),
                completed_at = CASE WHEN :status = 'completed' THEN now() ELSE completed_at END
            WHERE id = :id AND treatment_plan_id = :planId AND clinic_id = :clinicId
            """;
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", itemId)
                .addValue("planId", planId)
                .addValue("clinicId", clinicId)
                .addValue("status", status));
    }

    public void deleteItem(UUID planId, UUID itemId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            DELETE FROM dentalcare.treatment_plan_items
            WHERE id = :id AND treatment_plan_id = :planId AND clinic_id = :clinicId
            """;
        jdbc.update(sql, new MapSqlParameterSource()
                .addValue("id", itemId)
                .addValue("planId", planId)
                .addValue("clinicId", clinicId));
    }

    private BigDecimalHolder resolveServiceDefaults(UUID serviceId, UUID clinicId) {
        String sql = "SELECT default_price FROM dentalcare.service_catalog WHERE id = :id AND clinic_id = :clinicId";
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
                rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null
        );
    }
}
