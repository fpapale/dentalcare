package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class EstimateService {

    private final NamedParameterJdbcTemplate jdbc;

    public EstimateService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── List ─────────────────────────────────────────────────────────────────

    public List<EstimateDto> findAll(String status, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);
        StringBuilder filter = new StringBuilder();
        if (status != null && !status.isBlank()) {
            filter.append(" AND estimate_status::text = :status");
            params.addValue("status", status);
        }
        if (providerId != null) {
            filter.append(" AND estimate_id IN ("
                    + "SELECT id FROM dentalcare.estimates"
                    + " WHERE clinic_id = :clinicId"
                    + " AND (created_by_provider_id = :providerId OR created_by_provider_id IS NULL))");
            params.addValue("providerId", providerId);
        }
        String sql = "SELECT estimate_id, estimate_number, version, estimate_status, estimate_title,"
                + " currency, subtotal_amount, discount_amount, taxable_amount,"
                + " vat_amount, total_amount,"
                + " patient_id, patient_full_name, patient_fiscal_code, patient_phone,"
                + " issued_at, sent_at, valid_until, accepted_at, rejected_at, estimate_created_at"
                + " FROM dentalcare.v_patient_estimates_summary"
                + " WHERE clinic_id = :clinicId"
                + filter
                + " ORDER BY estimate_created_at DESC";
        return jdbc.query(sql, params, (rs, n) -> mapSummaryRow(rs));
    }

    public List<EstimateDto> findByPatient(UUID patientId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT estimate_id, estimate_number, version, estimate_status, estimate_title,
                   currency, subtotal_amount, discount_amount, taxable_amount,
                   vat_amount, total_amount,
                   patient_id, patient_full_name, patient_fiscal_code, patient_phone,
                   issued_at, sent_at, valid_until, accepted_at, rejected_at, estimate_created_at
            FROM dentalcare.v_patient_estimates_summary
            WHERE clinic_id = :clinicId AND patient_id = :patientId
            ORDER BY estimate_created_at DESC
            """;
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
                (rs, n) -> mapSummaryRow(rs));
    }

    public List<EstimateDto> findByPlan(UUID planId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT e.id               AS estimate_id,
                   e.estimate_number,
                   e.version,
                   e.status::text     AS estimate_status,
                   e.title            AS estimate_title,
                   e.currency,
                   e.subtotal_amount, e.discount_amount, e.taxable_amount,
                   e.vat_amount, e.total_amount,
                   e.patient_id,
                   concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
                   NULL::text         AS patient_fiscal_code,
                   NULL::text         AS patient_phone,
                   e.issued_at, e.sent_at, e.valid_until, e.accepted_at, e.rejected_at,
                   e.created_at       AS estimate_created_at
            FROM dentalcare.estimates e
            JOIN dentalcare.patients p
              ON p.id = e.patient_id AND p.clinic_id = e.clinic_id
            WHERE e.clinic_id = :clinicId
              AND e.treatment_plan_id = :planId
              AND e.status NOT IN ('rejected', 'cancelled')
            ORDER BY e.created_at DESC
            """;
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("planId", planId),
                (rs, n) -> mapSummaryRow(rs));
    }

    // ── Detail ───────────────────────────────────────────────────────────────

    public EstimateDetailDto findById(UUID estimateId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = """
            SELECT e.id, e.estimate_number, e.version, e.status::text,
                   e.title, e.notes, e.currency,
                   e.subtotal_amount, e.discount_amount, e.taxable_amount, e.vat_amount, e.total_amount,
                   e.patient_id, concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
                   e.treatment_plan_id, tp.name AS treatment_plan_name,
                   e.issued_at, e.sent_at, e.valid_until, e.accepted_at, e.rejected_at, e.created_at
            FROM dentalcare.estimates e
            JOIN dentalcare.patients p ON p.id = e.patient_id AND p.clinic_id = e.clinic_id
            LEFT JOIN dentalcare.treatment_plans tp
                   ON tp.id = e.treatment_plan_id AND tp.clinic_id = e.clinic_id
            WHERE e.id = :id AND e.clinic_id = :clinicId
            """;
        List<EstimateDetailDto> headers = jdbc.query(sql,
                new MapSqlParameterSource().addValue("id", estimateId).addValue("clinicId", clinicId),
                (rs, n) -> mapHeaderRow(rs));
        if (headers.isEmpty()) return null;
        EstimateDetailDto h = headers.get(0);

        String linesSql = """
            SELECT el.id, el.line_position, el.service_id, sc.name AS service_name,
                   el.treatment_plan_item_id, el.description_snapshot, el.tooth_snapshot,
                   el.quantity, el.unit_price, el.discount_amount, el.vat_rate,
                   el.line_subtotal, el.line_taxable, el.line_vat_amount, el.line_total
            FROM dentalcare.estimate_lines el
            JOIN dentalcare.service_catalog sc ON sc.id = el.service_id AND sc.clinic_id = el.clinic_id
            WHERE el.estimate_id = :estimateId AND el.clinic_id = :clinicId
            ORDER BY el.line_position
            """;
        List<EstimateLineDto> lines = jdbc.query(linesSql,
                new MapSqlParameterSource().addValue("estimateId", estimateId).addValue("clinicId", clinicId),
                (rs, n) -> new EstimateLineDto(
                        rs.getObject("id", UUID.class),
                        rs.getInt("line_position"),
                        rs.getObject("service_id", UUID.class),
                        rs.getString("service_name"),
                        rs.getObject("treatment_plan_item_id", UUID.class),
                        rs.getString("description_snapshot"),
                        rs.getString("tooth_snapshot"),
                        rs.getBigDecimal("quantity"),
                        rs.getBigDecimal("unit_price"),
                        rs.getBigDecimal("discount_amount"),
                        rs.getBigDecimal("vat_rate"),
                        rs.getBigDecimal("line_subtotal"),
                        rs.getBigDecimal("line_taxable"),
                        rs.getBigDecimal("line_vat_amount"),
                        rs.getBigDecimal("line_total")
                ));

        return new EstimateDetailDto(
                h.estimateId(), h.estimateNumber(), h.version(), h.status(),
                h.title(), h.notes(), h.currency(),
                h.subtotalAmount(), h.discountAmount(), h.taxableAmount(), h.vatAmount(), h.totalAmount(),
                h.patientId(), h.patientFullName(), h.treatmentPlanId(), h.treatmentPlanName(),
                h.issuedAt(), h.sentAt(), h.validUntil(), h.acceptedAt(), h.rejectedAt(), h.createdAt(),
                lines);
    }

    // ── Create ───────────────────────────────────────────────────────────────

    @Transactional
    public UUID create(CreateEstimateRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID id = UUID.randomUUID();
        String number = generateEstimateNumber(clinicId);
        String title = (request.title() != null && !request.title().isBlank())
                ? request.title().trim() : "Preventivo";

        int version = 1;
        if (request.treatmentPlanId() != null) {
            Long count = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM dentalcare.estimates WHERE clinic_id = :cid AND treatment_plan_id = :planId",
                    new MapSqlParameterSource().addValue("cid", clinicId).addValue("planId", request.treatmentPlanId()),
                    Long.class);
            version = (count == null ? 0 : (int) (long) count) + 1;
        }

        jdbc.update("""
            INSERT INTO dentalcare.estimates
                (id, clinic_id, patient_id, treatment_plan_id, estimate_number, version,
                 title, notes, currency, status,
                 subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount,
                 valid_until, created_by_provider_id)
            VALUES
                (:id, :clinicId, :patientId, :planId, :number, :version,
                 :title, :notes, 'EUR', 'draft',
                 0, 0, 0, 0, 0, :validUntil, :providerId)
            """,
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", request.patientId())
                        .addValue("planId", request.treatmentPlanId())
                        .addValue("number", number)
                        .addValue("version", version)
                        .addValue("title", title)
                        .addValue("notes", request.notes())
                        .addValue("validUntil", request.validUntil())
                        .addValue("providerId", request.createdByProviderId()));
        return id;
    }

    // ── Update header ─────────────────────────────────────────────────────────

    public void updateHeader(UUID estimateId, UpdateEstimateHeaderRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String newTitle = (request.title() != null && !request.title().isBlank()) ? request.title().trim() : null;
        jdbc.update("""
            UPDATE dentalcare.estimates
            SET title      = COALESCE(:title, title),
                notes      = :notes,
                valid_until = :validUntil,
                updated_at  = now()
            WHERE id = :id AND clinic_id = :clinicId
            """,
                new MapSqlParameterSource()
                        .addValue("id", estimateId)
                        .addValue("clinicId", clinicId)
                        .addValue("title", newTitle)
                        .addValue("notes", request.notes())
                        .addValue("validUntil", request.validUntil()));
    }

    // ── Update status ─────────────────────────────────────────────────────────

    public void updateStatus(UUID estimateId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE dentalcare.estimates
            SET status     = CAST(:status AS dentalcare.estimate_status),
                sent_at    = CASE WHEN :status = 'sent'     AND sent_at IS NULL    THEN now() ELSE sent_at    END,
                accepted_at = CASE WHEN :status = 'accepted' AND accepted_at IS NULL THEN now() ELSE accepted_at END,
                rejected_at = CASE WHEN :status = 'rejected' AND rejected_at IS NULL THEN now() ELSE rejected_at END,
                updated_at  = now()
            WHERE id = :id AND clinic_id = :clinicId
            """,
                new MapSqlParameterSource()
                        .addValue("id", estimateId)
                        .addValue("clinicId", clinicId)
                        .addValue("status", status));
    }

    // ── Lines ─────────────────────────────────────────────────────────────────

    @Transactional
    public UUID addLine(UUID estimateId, AddEstimateLineRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        Long maxPos = jdbc.queryForObject(
                "SELECT COALESCE(MAX(line_position), 0) FROM dentalcare.estimate_lines WHERE estimate_id = :id AND clinic_id = :cid",
                new MapSqlParameterSource().addValue("id", estimateId).addValue("cid", clinicId),
                Long.class);
        int pos = request.linePosition() != null ? request.linePosition() : (int)(maxPos == null ? 0 : maxPos) + 10;

        List<Map<String, Object>> svcRows = jdbc.queryForList(
                "SELECT name, default_price FROM dentalcare.service_catalog WHERE id = :id AND clinic_id = :cid",
                new MapSqlParameterSource().addValue("id", request.serviceId()).addValue("cid", clinicId));
        String svcName = svcRows.isEmpty() ? "" : (String) svcRows.get(0).get("name");
        BigDecimal defaultPrice = svcRows.isEmpty() ? BigDecimal.ZERO : (BigDecimal) svcRows.get(0).get("default_price");

        String description = (request.descriptionOverride() != null) ? request.descriptionOverride() : svcName;
        BigDecimal unitPrice = request.unitPrice() != null ? request.unitPrice() : defaultPrice;
        BigDecimal qty = request.quantity() != null ? request.quantity() : BigDecimal.ONE;
        BigDecimal discount = request.discountAmount() != null ? request.discountAmount() : BigDecimal.ZERO;
        BigDecimal vatRate = request.vatRate() != null ? request.vatRate() : BigDecimal.ZERO;

        UUID lineId = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO dentalcare.estimate_lines
                (id, clinic_id, estimate_id, service_id, treatment_plan_item_id,
                 line_position, description_snapshot, tooth_snapshot,
                 quantity, unit_price, discount_amount, vat_rate)
            VALUES
                (:id, :clinicId, :estimateId, :serviceId, :planItemId,
                 :pos, :description, :tooth,
                 :qty, :unitPrice, :discount, :vatRate)
            """,
                new MapSqlParameterSource()
                        .addValue("id", lineId)
                        .addValue("clinicId", clinicId)
                        .addValue("estimateId", estimateId)
                        .addValue("serviceId", request.serviceId())
                        .addValue("planItemId", request.treatmentPlanItemId())
                        .addValue("pos", pos)
                        .addValue("description", description)
                        .addValue("tooth", request.toothSnapshot())
                        .addValue("qty", qty)
                        .addValue("unitPrice", unitPrice)
                        .addValue("discount", discount)
                        .addValue("vatRate", vatRate));
        return lineId;
    }

    public void deleteLine(UUID estimateId, UUID lineId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            DELETE FROM dentalcare.estimate_lines
            WHERE id = :id AND estimate_id = :estimateId AND clinic_id = :clinicId
            """,
                new MapSqlParameterSource()
                        .addValue("id", lineId)
                        .addValue("estimateId", estimateId)
                        .addValue("clinicId", clinicId));
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public void delete(UUID estimateId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            DELETE FROM dentalcare.estimates
            WHERE id = :id AND clinic_id = :clinicId
            """,
                new MapSqlParameterSource().addValue("id", estimateId).addValue("clinicId", clinicId));
    }

    // ── Plan coverage ────────────────────────────────────────────────────────

    public List<PlanItemCoverageDto> getPlanCoverage(UUID planId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT el.treatment_plan_item_id,
                   e.id            AS estimate_id,
                   e.estimate_number,
                   e.title         AS estimate_title,
                   e.status::text  AS estimate_status
            FROM dentalcare.estimate_lines el
            JOIN dentalcare.estimates e
              ON e.id = el.estimate_id AND e.clinic_id = el.clinic_id
            WHERE el.clinic_id = :clinicId
              AND e.treatment_plan_id = :planId
              AND el.treatment_plan_item_id IS NOT NULL
              AND e.status NOT IN ('cancelled', 'rejected')
            ORDER BY e.estimate_number, el.line_position
            """;
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("planId", planId),
                (rs, n) -> new PlanItemCoverageDto(
                        rs.getObject("treatment_plan_item_id", UUID.class),
                        rs.getObject("estimate_id", UUID.class),
                        rs.getString("estimate_number"),
                        rs.getString("estimate_title"),
                        rs.getString("estimate_status")
                ));
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String generateEstimateNumber(UUID clinicId) {
        int year = java.time.Year.now().getValue();
        String prefix = "EST";
        try {
            String city = jdbc.queryForObject(
                    "SELECT city FROM dentalcare.clinics WHERE id = :id",
                    new MapSqlParameterSource().addValue("id", clinicId), String.class);
            if (city != null && !city.isBlank()) {
                prefix = city.substring(0, Math.min(4, city.length())).toUpperCase();
            }
        } catch (Exception ignored) {}

        Long count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM dentalcare.estimates WHERE clinic_id = :cid AND EXTRACT(YEAR FROM created_at) = :yr",
                new MapSqlParameterSource().addValue("cid", clinicId).addValue("yr", year), Long.class);
        return String.format("%s-%d-%05d", prefix, year, (count == null ? 0 : count) + 1);
    }

    private EstimateDto mapSummaryRow(ResultSet rs) throws SQLException {
        return new EstimateDto(
                rs.getObject("estimate_id", UUID.class),
                rs.getString("estimate_number"),
                rs.getObject("version", Integer.class),
                rs.getString("estimate_status"),
                rs.getString("estimate_title"),
                rs.getString("currency"),
                rs.getBigDecimal("subtotal_amount"),
                rs.getBigDecimal("discount_amount"),
                rs.getBigDecimal("taxable_amount"),
                rs.getBigDecimal("vat_amount"),
                rs.getBigDecimal("total_amount"),
                rs.getObject("patient_id", UUID.class),
                rs.getString("patient_full_name"),
                rs.getString("patient_fiscal_code"),
                rs.getString("patient_phone"),
                rs.getTimestamp("issued_at") != null ? rs.getTimestamp("issued_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("sent_at") != null ? rs.getTimestamp("sent_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getDate("valid_until") != null ? rs.getDate("valid_until").toLocalDate() : null,
                rs.getTimestamp("accepted_at") != null ? rs.getTimestamp("accepted_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("rejected_at") != null ? rs.getTimestamp("rejected_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("estimate_created_at") != null ? rs.getTimestamp("estimate_created_at").toInstant().atOffset(ZoneOffset.UTC) : null
        );
    }

    private EstimateDetailDto mapHeaderRow(ResultSet rs) throws SQLException {
        return new EstimateDetailDto(
                rs.getObject("id", UUID.class),
                rs.getString("estimate_number"),
                rs.getObject("version", Integer.class),
                rs.getString("status"),
                rs.getString("title"),
                rs.getString("notes"),
                rs.getString("currency"),
                rs.getBigDecimal("subtotal_amount"),
                rs.getBigDecimal("discount_amount"),
                rs.getBigDecimal("taxable_amount"),
                rs.getBigDecimal("vat_amount"),
                rs.getBigDecimal("total_amount"),
                rs.getObject("patient_id", UUID.class),
                rs.getString("patient_full_name"),
                rs.getObject("treatment_plan_id", UUID.class),
                rs.getString("treatment_plan_name"),
                rs.getTimestamp("issued_at") != null ? rs.getTimestamp("issued_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("sent_at") != null ? rs.getTimestamp("sent_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getDate("valid_until") != null ? rs.getDate("valid_until").toLocalDate() : null,
                rs.getTimestamp("accepted_at") != null ? rs.getTimestamp("accepted_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("rejected_at") != null ? rs.getTimestamp("rejected_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("created_at") != null ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                null
        );
    }
}
