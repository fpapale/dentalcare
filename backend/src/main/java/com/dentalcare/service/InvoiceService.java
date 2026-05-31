package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class InvoiceService {

    private final NamedParameterJdbcTemplate jdbc;

    public InvoiceService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final Set<String> ADMIN_ROLES = Set.of("ROLE_ADMIN", "ROLE_TENANT_ADMIN", "ROLE_SECRETARY");

    private String s() { return TenantContext.validatedSchema(); }

    /** Returns the JWT providerId of the caller, or null if not resolvable. */
    private UUID callerProviderId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) return null;
        try { return UUID.fromString(auth.getPrincipal().toString()); } catch (IllegalArgumentException e) { return null; }
    }

    /** True when the caller is a medical role (doctor, hygienist, …) — must see only own records. */
    private boolean callerIsMedical() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return false;
        return auth.getAuthorities().stream()
                .noneMatch(a -> ADMIN_ROLES.contains(a.getAuthority()));
    }

    // ── List ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<InvoiceDto> findAll(String status, UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);
        StringBuilder filter = new StringBuilder();

        if (status != null && !status.isBlank()) {
            filter.append(" AND i.status::text = :status");
            params.addValue("status", status);
        }
        // Medical users see only their own invoices regardless of request param
        if (callerIsMedical()) {
            providerId = callerProviderId();
        }
        if (providerId != null) {
            filter.append(" AND i.provider_id = :providerId");
            params.addValue("providerId", providerId);
        }

        String sql = "SELECT i.id, i.invoice_number, i.document_type::text, i.invoice_date, i.due_date,"
                + " i.status::text, i.issuer_type::text,"
                + " concat_ws(' ', p.last_name, p.first_name) AS provider_full_name,"
                + " i.patient_full_name, i.estimate_id,"
                + " e.estimate_number, i.total_amount, i.currency, i.created_at"
                + " FROM " + s() + ".invoices i"
                + " LEFT JOIN " + s() + ".providers p ON p.id = i.provider_id AND p.clinic_id = i.clinic_id"
                + " LEFT JOIN " + s() + ".estimates e ON e.id = i.estimate_id AND e.clinic_id = i.clinic_id"
                + " WHERE i.clinic_id = :clinicId"
                + filter
                + " ORDER BY i.created_at DESC";

        return jdbc.query(sql, params, (rs, n) -> mapSummaryRow(rs));
    }

    // ── Detail ───────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public InvoiceDetailDto findById(UUID invoiceId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        UUID callerId = callerIsMedical() ? callerProviderId() : null;
        final String providerFilter = callerId != null ? " AND i.provider_id = :callerId" : "";
        MapSqlParameterSource detailParams = new MapSqlParameterSource()
                .addValue("id", invoiceId)
                .addValue("clinicId", clinicId);
        if (callerId != null) detailParams.addValue("callerId", callerId);

        String sql = """
            SELECT i.id, i.invoice_number, i.document_type::text, i.invoice_date, i.due_date,
                   i.status::text, i.issuer_type::text,
                   concat_ws(' ', p.last_name, p.first_name) AS provider_full_name,
                   i.patient_full_name, i.estimate_id,
                   e.estimate_number,
                   i.subtotal_amount, i.discount_amount, i.taxable_amount, i.vat_amount, i.total_amount,
                   i.currency,
                   i.issuer_name, i.issuer_vat_number, i.issuer_fiscal_code, i.issuer_address,
                   i.issuer_email, i.issuer_pec, i.issuer_sdi_code, i.issuer_iban,
                   i.patient_fiscal_code, i.patient_address, i.patient_email,
                   i.notes, i.payment_method, i.paid_at, i.issued_at, i.created_at
            FROM %s.invoices i
            LEFT JOIN %s.providers p ON p.id = i.provider_id AND p.clinic_id = i.clinic_id
            LEFT JOIN %s.estimates e ON e.id = i.estimate_id AND e.clinic_id = i.clinic_id
            WHERE i.id = :id AND i.clinic_id = :clinicId%s
            """.formatted(s(), s(), s(), providerFilter);

        List<InvoiceDetailDto> headers = jdbc.query(sql, detailParams,
                (rs, n) -> mapDetailRow(rs, List.of()));

        if (headers.isEmpty()) return null;
        InvoiceDetailDto h = headers.get(0);

        String linesSql = """
            SELECT id, line_position, description, tooth_info,
                   quantity, unit_price, discount_amount, vat_rate,
                   line_subtotal, line_taxable, line_vat_amount, line_total
            FROM %s.invoice_lines
            WHERE invoice_id = :invoiceId AND clinic_id = :clinicId
            ORDER BY line_position
            """.formatted(s());
        List<InvoiceLineDto> lines = jdbc.query(linesSql,
                new MapSqlParameterSource().addValue("invoiceId", invoiceId).addValue("clinicId", clinicId),
                (rs, n) -> mapLineRow(rs));

        return new InvoiceDetailDto(
                h.id(), h.invoiceNumber(), h.documentType(), h.invoiceDate(), h.dueDate(),
                h.status(), h.issuerType(), h.providerFullName(), h.patientFullName(),
                h.estimateId(), h.estimateNumber(),
                h.subtotalAmount(), h.discountAmount(), h.taxableAmount(), h.vatAmount(), h.totalAmount(),
                h.currency(),
                h.issuerName(), h.issuerVatNumber(), h.issuerFiscalCode(), h.issuerAddress(),
                h.issuerEmail(), h.issuerPec(), h.issuerSdiCode(), h.issuerIban(),
                h.patientFiscalCode(), h.patientAddress(), h.patientEmail(),
                h.notes(), h.paymentMethod(), h.paidAt(), h.issuedAt(), h.createdAt(),
                lines);
    }

    // ── Create from estimate ──────────────────────────────────────────────────

    @Transactional
    public UUID createFromEstimate(CreateInvoiceFromEstimateRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID estimateId = request.estimateId();

        // Load estimate + patient
        String estimateSql = """
            SELECT e.id, e.estimate_number, e.patient_id, e.currency,
                   e.subtotal_amount, e.discount_amount, e.taxable_amount, e.vat_amount, e.total_amount,
                   concat_ws(' ', pat.last_name, pat.first_name) AS patient_full_name,
                   pat.fiscal_code::text AS patient_fiscal_code,
                   pat.email::text AS patient_email,
                   concat_ws(', ', pat.address_line1, pat.city) AS patient_address
            FROM %s.estimates e
            JOIN %s.patients pat ON pat.id = e.patient_id AND pat.clinic_id = e.clinic_id
            WHERE e.id = :estimateId AND e.clinic_id = :clinicId
            """.formatted(s(), s());
        List<Map<String, Object>> estRows = jdbc.queryForList(estimateSql,
                new MapSqlParameterSource().addValue("estimateId", estimateId).addValue("clinicId", clinicId));
        if (estRows.isEmpty()) {
            throw new IllegalArgumentException("Estimate not found: " + estimateId);
        }
        Map<String, Object> est = estRows.get(0);

        // Resolve issuer
        String issuerType = request.issuerType();
        String issuerName;
        String issuerVatNumber;
        String issuerFiscalCode;
        String issuerAddress;
        String issuerEmail;
        String issuerPec;
        String issuerSdiCode;
        String issuerIban;
        String invoicePrefix;

        if ("provider".equals(issuerType) && request.providerId() != null) {
            String provSql = """
                SELECT concat_ws(' ', first_name, last_name) AS full_name,
                       vat_number, fiscal_code,
                       concat_ws(', ', billing_address_street, billing_address_zip, billing_address_city) AS billing_address,
                       email::text, billing_pec, billing_sdi_code, billing_iban,
                       COALESCE(invoice_prefix, 'PARC') AS invoice_prefix
                FROM %s.providers
                WHERE id = :pid AND clinic_id = :clinicId
                """.formatted(s());
            List<Map<String, Object>> provRows = jdbc.queryForList(provSql,
                    new MapSqlParameterSource().addValue("pid", request.providerId()).addValue("clinicId", clinicId));
            if (provRows.isEmpty()) {
                throw new IllegalArgumentException("Provider not found: " + request.providerId());
            }
            Map<String, Object> prov = provRows.get(0);
            issuerName = str(prov.get("full_name"));
            issuerVatNumber = str(prov.get("vat_number"));
            issuerFiscalCode = str(prov.get("fiscal_code"));
            issuerAddress = str(prov.get("billing_address"));
            issuerEmail = str(prov.get("email"));
            issuerPec = str(prov.get("billing_pec"));
            issuerSdiCode = str(prov.get("billing_sdi_code"));
            issuerIban = str(prov.get("billing_iban"));
            invoicePrefix = str(prov.get("invoice_prefix"));
        } else {
            String clinicSql = """
                SELECT COALESCE(legal_name, name) AS issuer_name,
                       vat_number::text, fiscal_code::text,
                       concat_ws(', ', address_line1, postal_code, city) AS address,
                       email::text
                FROM %s.clinics
                WHERE id = :clinicId
                """.formatted(s());
            List<Map<String, Object>> clinicRows = jdbc.queryForList(clinicSql,
                    new MapSqlParameterSource().addValue("clinicId", clinicId));
            Map<String, Object> clinic = clinicRows.isEmpty() ? Map.of() : clinicRows.get(0);
            issuerName = str(clinic.get("issuer_name"));
            issuerVatNumber = str(clinic.get("vat_number"));
            issuerFiscalCode = str(clinic.get("fiscal_code"));
            issuerAddress = str(clinic.get("address"));
            issuerEmail = str(clinic.get("email"));
            issuerPec = null;
            issuerSdiCode = null;
            issuerIban = null;
            invoicePrefix = "FATT";
        }

        String docType = (request.documentType() != null && !request.documentType().isBlank())
                ? request.documentType() : "fattura";

        String invoiceNumber = generateInvoiceNumber(clinicId, invoicePrefix);

        UUID invoiceId = UUID.randomUUID();
        UUID patientId = (UUID) est.get("patient_id");

        jdbc.update(
            "INSERT INTO " + s() + ".invoices ("
            + " id, clinic_id, invoice_number, document_type, invoice_date, due_date,"
            + " status, issuer_type, provider_id, patient_id, estimate_id,"
            + " issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,"
            + " issuer_email, issuer_pec, issuer_sdi_code, issuer_iban,"
            + " patient_full_name, patient_fiscal_code, patient_address, patient_email,"
            + " subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount,"
            + " currency, notes, payment_method"
            + ") VALUES ("
            + " :id, :clinicId, :invoiceNumber,"
            + " CAST(:documentType AS dentalcare.invoice_document_type),"
            + " CURRENT_DATE, :dueDate,"
            + " CAST('draft' AS dentalcare.invoice_status),"
            + " CAST(:issuerType AS dentalcare.invoice_issuer_type),"
            + " :providerId, :patientId, :estimateId,"
            + " :issuerName, :issuerVatNumber, :issuerFiscalCode, :issuerAddress,"
            + " :issuerEmail, :issuerPec, :issuerSdiCode, :issuerIban,"
            + " :patientFullName, :patientFiscalCode, :patientAddress, :patientEmail,"
            + " :subtotalAmount, :discountAmount, :taxableAmount, :vatAmount, :totalAmount,"
            + " :currency, :notes, :paymentMethod"
            + ")",
                new MapSqlParameterSource()
                        .addValue("id", invoiceId)
                        .addValue("clinicId", clinicId)
                        .addValue("invoiceNumber", invoiceNumber)
                        .addValue("documentType", docType)
                        .addValue("dueDate", request.dueDate())
                        .addValue("issuerType", issuerType)
                        .addValue("providerId", request.providerId())
                        .addValue("patientId", patientId)
                        .addValue("estimateId", estimateId)
                        .addValue("issuerName", issuerName)
                        .addValue("issuerVatNumber", issuerVatNumber)
                        .addValue("issuerFiscalCode", issuerFiscalCode)
                        .addValue("issuerAddress", issuerAddress)
                        .addValue("issuerEmail", issuerEmail)
                        .addValue("issuerPec", issuerPec)
                        .addValue("issuerSdiCode", issuerSdiCode)
                        .addValue("issuerIban", issuerIban)
                        .addValue("patientFullName", est.get("patient_full_name"))
                        .addValue("patientFiscalCode", est.get("patient_fiscal_code"))
                        .addValue("patientAddress", est.get("patient_address"))
                        .addValue("patientEmail", est.get("patient_email"))
                        .addValue("subtotalAmount", est.get("subtotal_amount"))
                        .addValue("discountAmount", est.get("discount_amount"))
                        .addValue("taxableAmount", est.get("taxable_amount"))
                        .addValue("vatAmount", est.get("vat_amount"))
                        .addValue("totalAmount", est.get("total_amount"))
                        .addValue("currency", est.get("currency"))
                        .addValue("notes", request.notes())
                        .addValue("paymentMethod", request.paymentMethod()));

        // Copy estimate lines to invoice lines
        String estLinesSql = """
            SELECT id, line_position, description_snapshot, tooth_snapshot,
                   quantity, unit_price, discount_amount, vat_rate
            FROM %s.estimate_lines
            WHERE estimate_id = :estimateId AND clinic_id = :clinicId
            ORDER BY line_position
            """.formatted(s());
        List<Map<String, Object>> estLines = jdbc.queryForList(estLinesSql,
                new MapSqlParameterSource().addValue("estimateId", estimateId).addValue("clinicId", clinicId));

        for (Map<String, Object> line : estLines) {
            UUID lineId = UUID.randomUUID();
            jdbc.update("""
                INSERT INTO %s.invoice_lines (
                    id, clinic_id, invoice_id, line_position,
                    description, tooth_info,
                    quantity, unit_price, discount_amount, vat_rate
                ) VALUES (
                    :id, :clinicId, :invoiceId, :linePosition,
                    :description, :toothInfo,
                    :quantity, :unitPrice, :discountAmount, :vatRate
                )
                """.formatted(s()),
                    new MapSqlParameterSource()
                            .addValue("id", lineId)
                            .addValue("clinicId", clinicId)
                            .addValue("invoiceId", invoiceId)
                            .addValue("linePosition", line.get("line_position"))
                            .addValue("description", line.get("description_snapshot"))
                            .addValue("toothInfo", line.get("tooth_snapshot"))
                            .addValue("quantity", line.get("quantity"))
                            .addValue("unitPrice", line.get("unit_price"))
                            .addValue("discountAmount", line.get("discount_amount"))
                            .addValue("vatRate", line.get("vat_rate")));
        }

        return invoiceId;
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @Transactional
    public void update(UUID invoiceId, UpdateInvoiceRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.invoices
            SET document_type  = COALESCE(CAST(:documentType AS dentalcare.invoice_document_type), document_type),
                invoice_date   = COALESCE(:invoiceDate, invoice_date),
                due_date       = :dueDate,
                notes          = :notes,
                payment_method = :paymentMethod,
                updated_at     = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s(), s()),
                new MapSqlParameterSource()
                        .addValue("id", invoiceId)
                        .addValue("clinicId", clinicId)
                        .addValue("documentType", request.documentType())
                        .addValue("invoiceDate", request.invoiceDate())
                        .addValue("dueDate", request.dueDate())
                        .addValue("notes", request.notes())
                        .addValue("paymentMethod", request.paymentMethod()));
    }

    // ── Update status ─────────────────────────────────────────────────────────

    @Transactional
    public void updateStatus(UUID invoiceId, String status) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            UPDATE %s.invoices
            SET status     = CAST(:status AS dentalcare.invoice_status),
                issued_at  = CASE WHEN :status = 'issued' AND issued_at IS NULL THEN now() ELSE issued_at END,
                paid_at    = CASE WHEN :status = 'paid'   AND paid_at IS NULL   THEN now() ELSE paid_at   END,
                updated_at = now()
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s(), s()),
                new MapSqlParameterSource()
                        .addValue("id", invoiceId)
                        .addValue("clinicId", clinicId)
                        .addValue("status", status));
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    @Transactional
    public void delete(UUID invoiceId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String currentStatus = jdbc.queryForObject(
                "SELECT status::text FROM " + s() + ".invoices WHERE id = :id AND clinic_id = :clinicId",
                new MapSqlParameterSource().addValue("id", invoiceId).addValue("clinicId", clinicId),
                String.class);
        if (!"draft".equals(currentStatus)) {
            throw new IllegalStateException("Cannot delete invoice in status: " + currentStatus);
        }
        jdbc.update("""
            DELETE FROM %s.invoices
            WHERE id = :id AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource().addValue("id", invoiceId).addValue("clinicId", clinicId));
    }

    // ── Lines ─────────────────────────────────────────────────────────────────

    @Transactional
    public UUID addLine(UUID invoiceId, AddInvoiceLineRequest request) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        Long maxPos = jdbc.queryForObject(
                "SELECT COALESCE(MAX(line_position), 0) FROM " + s() + ".invoice_lines WHERE invoice_id = :id AND clinic_id = :cid",
                new MapSqlParameterSource().addValue("id", invoiceId).addValue("cid", clinicId),
                Long.class);
        int pos = (int) (maxPos == null ? 0 : maxPos) + 10;

        BigDecimal qty = request.quantity() != null ? request.quantity() : BigDecimal.ONE;
        BigDecimal unitPrice = request.unitPrice() != null ? request.unitPrice() : BigDecimal.ZERO;
        BigDecimal discount = request.discountAmount() != null ? request.discountAmount() : BigDecimal.ZERO;
        BigDecimal vatRate = request.vatRate() != null ? request.vatRate() : BigDecimal.ZERO;

        UUID lineId = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO %s.invoice_lines (
                id, clinic_id, invoice_id, line_position,
                description, tooth_info,
                quantity, unit_price, discount_amount, vat_rate
            ) VALUES (
                :id, :clinicId, :invoiceId, :pos,
                :description, :toothInfo,
                :qty, :unitPrice, :discount, :vatRate
            )
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", lineId)
                        .addValue("clinicId", clinicId)
                        .addValue("invoiceId", invoiceId)
                        .addValue("pos", pos)
                        .addValue("description", request.description())
                        .addValue("toothInfo", request.toothInfo())
                        .addValue("qty", qty)
                        .addValue("unitPrice", unitPrice)
                        .addValue("discount", discount)
                        .addValue("vatRate", vatRate));
        return lineId;
    }

    @Transactional
    public void deleteLine(UUID invoiceId, UUID lineId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
            DELETE FROM %s.invoice_lines
            WHERE id = :id AND invoice_id = :invoiceId AND clinic_id = :clinicId
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", lineId)
                        .addValue("invoiceId", invoiceId)
                        .addValue("clinicId", clinicId));
    }

    // ── Email link helper ─────────────────────────────────────────────────────

    public String getEmailLink(UUID invoiceId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT invoice_number, patient_email FROM " + s() + ".invoices WHERE id = :id AND clinic_id = :clinicId",
                new MapSqlParameterSource().addValue("id", invoiceId).addValue("clinicId", clinicId));
        if (rows.isEmpty()) return null;
        String number = (String) rows.get(0).get("invoice_number");
        String email = (String) rows.get(0).get("patient_email");
        if (email == null || email.isBlank()) return null;
        return "mailto:" + email + "?subject=Fattura+" + number + "&body=Gentile+paziente%2C+in+allegato+la+fattura+" + number + ".";
    }

    private static String str(Object o) {
        if (o == null) return null;
        if (o instanceof String s) return s;
        return o.toString();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private String generateInvoiceNumber(UUID clinicId, String prefix) {
        int year = java.time.Year.now().getValue();
        Long count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM " + s() + ".invoices WHERE clinic_id = :cid AND EXTRACT(YEAR FROM created_at) = :yr",
                new MapSqlParameterSource().addValue("cid", clinicId).addValue("yr", year),
                Long.class);
        return String.format("%s-%d-%05d", prefix, year, (count == null ? 0 : count) + 1);
    }

    private InvoiceDto mapSummaryRow(ResultSet rs) throws SQLException {
        return new InvoiceDto(
                rs.getObject("id", UUID.class),
                rs.getString("invoice_number"),
                rs.getString("document_type"),
                rs.getDate("invoice_date") != null ? rs.getDate("invoice_date").toLocalDate() : null,
                rs.getDate("due_date") != null ? rs.getDate("due_date").toLocalDate() : null,
                rs.getString("status"),
                rs.getString("issuer_type"),
                rs.getString("provider_full_name"),
                rs.getString("patient_full_name"),
                rs.getObject("estimate_id", UUID.class),
                rs.getString("estimate_number"),
                rs.getBigDecimal("total_amount"),
                rs.getString("currency"),
                rs.getTimestamp("created_at") != null
                        ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null
        );
    }

    private InvoiceDetailDto mapDetailRow(ResultSet rs, List<InvoiceLineDto> lines) throws SQLException {
        return new InvoiceDetailDto(
                rs.getObject("id", UUID.class),
                rs.getString("invoice_number"),
                rs.getString("document_type"),
                rs.getDate("invoice_date") != null ? rs.getDate("invoice_date").toLocalDate() : null,
                rs.getDate("due_date") != null ? rs.getDate("due_date").toLocalDate() : null,
                rs.getString("status"),
                rs.getString("issuer_type"),
                rs.getString("provider_full_name"),
                rs.getString("patient_full_name"),
                rs.getObject("estimate_id", UUID.class),
                rs.getString("estimate_number"),
                rs.getBigDecimal("subtotal_amount"),
                rs.getBigDecimal("discount_amount"),
                rs.getBigDecimal("taxable_amount"),
                rs.getBigDecimal("vat_amount"),
                rs.getBigDecimal("total_amount"),
                rs.getString("currency"),
                rs.getString("issuer_name"),
                rs.getString("issuer_vat_number"),
                rs.getString("issuer_fiscal_code"),
                rs.getString("issuer_address"),
                rs.getString("issuer_email"),
                rs.getString("issuer_pec"),
                rs.getString("issuer_sdi_code"),
                rs.getString("issuer_iban"),
                rs.getString("patient_fiscal_code"),
                rs.getString("patient_address"),
                rs.getString("patient_email"),
                rs.getString("notes"),
                rs.getString("payment_method"),
                rs.getTimestamp("paid_at") != null
                        ? rs.getTimestamp("paid_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("issued_at") != null
                        ? rs.getTimestamp("issued_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getTimestamp("created_at") != null
                        ? rs.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC) : null,
                lines
        );
    }

    private InvoiceLineDto mapLineRow(ResultSet rs) throws SQLException {
        return new InvoiceLineDto(
                rs.getObject("id", UUID.class),
                rs.getInt("line_position"),
                rs.getString("description"),
                rs.getString("tooth_info"),
                rs.getBigDecimal("quantity"),
                rs.getBigDecimal("unit_price"),
                rs.getBigDecimal("discount_amount"),
                rs.getBigDecimal("vat_rate"),
                rs.getBigDecimal("line_subtotal"),
                rs.getBigDecimal("line_taxable"),
                rs.getBigDecimal("line_vat_amount"),
                rs.getBigDecimal("line_total")
        );
    }
}
