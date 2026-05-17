package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class RecallService {

    private final NamedParameterJdbcTemplate jdbc;

    public RecallService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    // ── List ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<RecallDto> findAll(String status, String priority) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);
        StringBuilder filter = new StringBuilder();

        if (status != null && !status.isBlank()) {
            filter.append(" AND r.status::text = :status");
            params.addValue("status", status);
        }
        if (priority != null && !priority.isBlank()) {
            filter.append(" AND r.priority::text = :priority");
            params.addValue("priority", priority);
        }

        String sql = "SELECT r.id, r.patient_id,"
                + " p.first_name || ' ' || p.last_name AS patient_full_name,"
                + " p.phone AS patient_phone,"
                + " r.recall_type, r.due_date,"
                + " r.status::text, r.priority::text,"
                + " r.notes, r.contact_count, r.last_contact_at,"
                + " sa.starts_at::date AS source_appointment_date,"
                + " r.created_at"
                + " FROM " + s() + ".patient_recalls r"
                + " JOIN " + s() + ".patients p ON p.id = r.patient_id"
                + " LEFT JOIN " + s() + ".appointments sa ON sa.id = r.source_appointment_id"
                + " WHERE r.clinic_id = :clinicId"
                + filter
                + " ORDER BY"
                + "     CASE r.priority::text WHEN 'alta' THEN 1 WHEN 'media' THEN 2 ELSE 3 END,"
                + "     r.due_date ASC";

        return jdbc.query(sql, params, (rs, n) -> mapRecallRow(rs));
    }

    // ── Create ────────────────────────────────────────────────────────────────

    @Transactional
    public RecallDto create(CreateRecallRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID recallId = UUID.randomUUID();

        String priorityExpr = (req.priority() != null && !req.priority().isBlank())
                ? "CAST(:priority AS " + s() + ".recall_priority)"
                : s() + ".compute_recall_priority(:dueDate)";

        jdbc.update("""
                INSERT INTO %s.patient_recalls (
                    id, clinic_id, patient_id, recall_type, due_date,
                    status, priority, notes, source_appointment_id
                ) VALUES (
                    :id, :clinicId, :patientId, :recallType, :dueDate,
                    'da_contattare'::%s.recall_status,
                    """.formatted(s(), s()) + priorityExpr + """
                    , :notes, :sourceAppointmentId
                )
                """,
                new MapSqlParameterSource()
                        .addValue("id", recallId)
                        .addValue("clinicId", clinicId)
                        .addValue("patientId", req.patientId())
                        .addValue("recallType", req.recallType())
                        .addValue("dueDate", req.dueDate())
                        .addValue("priority", req.priority())
                        .addValue("notes", req.notes())
                        .addValue("sourceAppointmentId", req.sourceAppointmentId()));

        return findById(recallId, clinicId);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @Transactional
    public RecallDto update(UUID id, UpdateRecallRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        jdbc.update("""
                UPDATE %s.patient_recalls
                SET status     = COALESCE(CAST(:status AS %s.recall_status), status),
                    priority   = COALESCE(CAST(:priority AS %s.recall_priority), priority),
                    recall_type = COALESCE(:recallType, recall_type),
                    due_date   = COALESCE(:dueDate, due_date),
                    notes      = :notes,
                    updated_at = now()
                WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s(), s(), s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId)
                        .addValue("status", req.status())
                        .addValue("priority", req.priority())
                        .addValue("recallType", req.recallType())
                        .addValue("dueDate", req.dueDate())
                        .addValue("notes", req.notes()));

        return findById(id, clinicId);
    }

    // ── Delete (soft) ─────────────────────────────────────────────────────────

    @Transactional
    public void delete(UUID id) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        jdbc.update("""
                UPDATE %s.patient_recalls
                SET status = 'annullato'::%s.recall_status,
                    updated_at = now()
                WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s(), s()),
                new MapSqlParameterSource()
                        .addValue("id", id)
                        .addValue("clinicId", clinicId));
    }

    // ── Generate recalls ──────────────────────────────────────────────────────

    @Transactional
    public GenerateRecallsResponse generateRecalls(int intervalMonths) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String lastVisitSql = """
                SELECT DISTINCT ON (patient_id)
                    id AS appointment_id,
                    patient_id,
                    starts_at::date AS last_visit_date
                FROM %s.appointments
                WHERE clinic_id = :clinicId
                  AND status::text IN ('completed', 'confirmed', 'in_progress')
                  AND starts_at < now() - make_interval(months => :intervalMonths)
                ORDER BY patient_id, starts_at DESC
                """.formatted(s());

        List<Map<String, Object>> lastVisits = jdbc.queryForList(lastVisitSql,
                new MapSqlParameterSource()
                        .addValue("clinicId", clinicId)
                        .addValue("intervalMonths", intervalMonths));

        int generated = 0;
        int skipped = 0;

        for (Map<String, Object> row : lastVisits) {
            UUID patientId = (UUID) row.get("patient_id");
            UUID appointmentId = (UUID) row.get("appointment_id");
            LocalDate lastVisitDate = ((java.sql.Date) row.get("last_visit_date")).toLocalDate();

            Long openCount = jdbc.queryForObject("""
                    SELECT COUNT(*) FROM %s.patient_recalls
                    WHERE clinic_id = :clinicId AND patient_id = :patientId
                      AND status::text NOT IN ('chiuso', 'annullato', 'confermato')
                    """.formatted(s()),
                    new MapSqlParameterSource()
                            .addValue("clinicId", clinicId)
                            .addValue("patientId", patientId),
                    Long.class);

            if (openCount != null && openCount > 0) {
                skipped++;
                continue;
            }

            LocalDate dueDate = lastVisitDate.plusMonths(intervalMonths);
            String priority = computePriority(dueDate);

            UUID recallId = UUID.randomUUID();
            jdbc.update("""
                    INSERT INTO %s.patient_recalls (
                        id, clinic_id, patient_id, recall_type, due_date,
                        status, priority, source_appointment_id
                    ) VALUES (
                        :id, :clinicId, :patientId, :recallType, :dueDate,
                        'da_contattare'::%s.recall_status,
                        CAST(:priority AS %s.recall_priority),
                        :sourceAppointmentId
                    )
                    """.formatted(s(), s(), s()),
                    new MapSqlParameterSource()
                            .addValue("id", recallId)
                            .addValue("clinicId", clinicId)
                            .addValue("patientId", patientId)
                            .addValue("recallType", "Controllo periodico")
                            .addValue("dueDate", dueDate)
                            .addValue("priority", priority)
                            .addValue("sourceAppointmentId", appointmentId));

            generated++;
        }

        String message = "Generati " + generated + " recall, saltati " + skipped + " (recall aperto già presente).";
        return new GenerateRecallsResponse(generated, skipped, message);
    }

    // ── Contacts ──────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<RecallContactDto> findContacts(UUID recallId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = """
                SELECT id, recall_id, contact_type::text, contact_at,
                       outcome::text, notes, created_by_provider_id, created_at
                FROM %s.recall_contacts
                WHERE recall_id = :recallId AND clinic_id = :clinicId
                ORDER BY contact_at DESC
                """.formatted(s());

        return jdbc.query(sql,
                new MapSqlParameterSource()
                        .addValue("recallId", recallId)
                        .addValue("clinicId", clinicId),
                (rs, n) -> mapContactRow(rs));
    }

    @Transactional
    public RecallContactDto addContact(UUID recallId, CreateRecallContactRequest req) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        UUID contactId = UUID.randomUUID();

        jdbc.update("""
                INSERT INTO %s.recall_contacts (
                    id, clinic_id, recall_id, contact_type, contact_at,
                    outcome, notes, created_by_provider_id
                ) VALUES (
                    :id, :clinicId, :recallId,
                    CAST(:contactType AS %s.recall_contact_type),
                    now(),
                    CAST(:outcome AS %s.recall_outcome),
                    :notes, :createdByProviderId
                )
                """.formatted(s(), s(), s()),
                new MapSqlParameterSource()
                        .addValue("id", contactId)
                        .addValue("clinicId", clinicId)
                        .addValue("recallId", recallId)
                        .addValue("contactType", req.contactType())
                        .addValue("outcome", req.outcome())
                        .addValue("notes", req.notes())
                        .addValue("createdByProviderId", req.createdByProviderId()));

        List<RecallContactDto> rows = jdbc.query("""
                SELECT id, recall_id, contact_type::text, contact_at,
                       outcome::text, notes, created_by_provider_id, created_at
                FROM %s.recall_contacts
                WHERE id = :id AND clinic_id = :clinicId
                """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("id", contactId)
                        .addValue("clinicId", clinicId),
                (rs, n) -> mapContactRow(rs));

        return rows.isEmpty() ? null : rows.get(0);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private RecallDto findById(UUID recallId, UUID clinicId) {
        String sql = "SELECT r.id, r.patient_id,"
                + " p.first_name || ' ' || p.last_name AS patient_full_name,"
                + " p.phone AS patient_phone,"
                + " r.recall_type, r.due_date,"
                + " r.status::text, r.priority::text,"
                + " r.notes, r.contact_count, r.last_contact_at,"
                + " sa.starts_at::date AS source_appointment_date,"
                + " r.created_at"
                + " FROM " + s() + ".patient_recalls r"
                + " JOIN " + s() + ".patients p ON p.id = r.patient_id"
                + " LEFT JOIN " + s() + ".appointments sa ON sa.id = r.source_appointment_id"
                + " WHERE r.id = :id AND r.clinic_id = :clinicId";

        List<RecallDto> rows = jdbc.query(sql,
                new MapSqlParameterSource()
                        .addValue("id", recallId)
                        .addValue("clinicId", clinicId),
                (rs, n) -> mapRecallRow(rs));

        return rows.isEmpty() ? null : rows.get(0);
    }

    private String computePriority(LocalDate dueDate) {
        LocalDate today = LocalDate.now();
        if (!dueDate.isAfter(today)) return "alta";
        if (!dueDate.isAfter(today.plusDays(30))) return "media";
        return "bassa";
    }

    private RecallDto mapRecallRow(ResultSet rs) throws SQLException {
        java.sql.Date lastContactSql = rs.getDate("last_contact_at");
        java.sql.Date sourceApptSql = rs.getDate("source_appointment_date");
        java.sql.Timestamp createdAtTs = rs.getTimestamp("created_at");

        return new RecallDto(
                rs.getObject("id", UUID.class),
                rs.getObject("patient_id", UUID.class),
                rs.getString("patient_full_name"),
                rs.getString("patient_phone"),
                rs.getString("recall_type"),
                rs.getDate("due_date") != null ? rs.getDate("due_date").toLocalDate() : null,
                rs.getString("status"),
                rs.getString("priority"),
                rs.getString("notes"),
                rs.getInt("contact_count"),
                lastContactSql != null ? lastContactSql.toLocalDate() : null,
                sourceApptSql != null ? sourceApptSql.toLocalDate() : null,
                createdAtTs != null ? createdAtTs.toInstant().atOffset(ZoneOffset.UTC) : null
        );
    }

    private RecallContactDto mapContactRow(ResultSet rs) throws SQLException {
        java.sql.Timestamp contactAtTs = rs.getTimestamp("contact_at");
        java.sql.Timestamp createdAtTs = rs.getTimestamp("created_at");

        return new RecallContactDto(
                rs.getObject("id", UUID.class),
                rs.getObject("recall_id", UUID.class),
                rs.getString("contact_type"),
                contactAtTs != null ? contactAtTs.toInstant().atOffset(ZoneOffset.UTC) : null,
                rs.getString("outcome"),
                rs.getString("notes"),
                rs.getObject("created_by_provider_id", UUID.class),
                createdAtTs != null ? createdAtTs.toInstant().atOffset(ZoneOffset.UTC) : null
        );
    }
}
