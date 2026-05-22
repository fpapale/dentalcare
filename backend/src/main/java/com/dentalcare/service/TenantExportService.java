package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

@Service
public class TenantExportService {

    private static final Logger log = LoggerFactory.getLogger(TenantExportService.class);

    private final NamedParameterJdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public TenantExportService(NamedParameterJdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    public void exportToStream(OutputStream out) throws IOException {
        String schema = TenantContext.validatedSchema();
        log.info("Tenant export started for schema={}", schema);

        Map<String, Integer> rowCounts = new LinkedHashMap<>();

        try (ZipOutputStream zip = new ZipOutputStream(out, StandardCharsets.UTF_8)) {

            rowCounts.put("providers", writeCsv(zip, "data/providers.csv",
                    "SELECT id, first_name, last_name, email, role::text AS role, active " +
                            "FROM " + schema + ".providers ORDER BY last_name, first_name",
                    new String[]{"id", "first_name", "last_name", "email", "role", "active"}));

            rowCounts.put("patients", writeCsv(zip, "data/patients.csv",
                    "SELECT id, first_name, last_name, fiscal_code, birth_date, phone, city " +
                            "FROM " + schema + ".patients ORDER BY last_name, first_name",
                    new String[]{"id", "first_name", "last_name", "fiscal_code", "birth_date", "phone", "city"}));

            rowCounts.put("appointments", writeCsv(zip, "data/appointments.csv",
                    "SELECT id, patient_id, provider_id, starts_at, ends_at, status::text AS status, notes " +
                            "FROM " + schema + ".appointments ORDER BY starts_at",
                    new String[]{"id", "patient_id", "provider_id", "starts_at", "ends_at", "status", "notes"}));

            if (tableExists(schema, "invoices")) {
                rowCounts.put("invoices", writeCsv(zip, "data/invoices.csv",
                        "SELECT id, invoice_number, patient_id, status::text AS status, total_amount, issued_at " +
                                "FROM " + schema + ".invoices ORDER BY invoice_date DESC, invoice_number",
                        new String[]{"id", "invoice_number", "patient_id", "status", "total_amount", "issued_at"}));
            }

            rowCounts.put("treatment_plans", writeJson(zip, "clinical/treatment_plans.json",
                    "SELECT id, clinic_id, patient_id, name, description, status::text AS status, " +
                            "created_by_provider_id, proposed_at, accepted_at, completed_at, rejected_at, " +
                            "created_at, updated_at " +
                            "FROM " + schema + ".treatment_plans ORDER BY created_at DESC"));

            rowCounts.put("clinical_history", writeJson(zip, "clinical/clinical_history.json",
                    "SELECT id, clinic_id, patient_id, appointment_id, provider_id, entry_date, " +
                            "tooth_number, service_code, service_name, clinical_notes, materials_used, " +
                            "next_visit_notes, created_at, updated_at " +
                            "FROM " + schema + ".clinical_history_entries ORDER BY entry_date DESC"));

            writeSchemaJson(zip, schema, rowCounts);
            writeReadme(zip, schema);
        }

        log.info("Tenant export completed for schema={} counts={}", schema, rowCounts);
    }

    private boolean tableExists(String schema, String table) {
        try {
            Integer count = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM information_schema.tables " +
                            "WHERE table_schema = :schema AND table_name = :table",
                    new MapSqlParameterSource()
                            .addValue("schema", schema)
                            .addValue("table", table),
                    Integer.class);
            return count != null && count > 0;
        } catch (Exception e) {
            return false;
        }
    }

    private int writeCsv(ZipOutputStream zip, String entryName, String sql, String[] headers) throws IOException {
        zip.putNextEntry(new ZipEntry(entryName));
        PrintWriter writer = new PrintWriter(new OutputStreamWriter(zip, StandardCharsets.UTF_8));
        writer.println(String.join(",", headers));

        int[] count = {0};
        jdbc.query(sql, new MapSqlParameterSource(), rs -> {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < headers.length; i++) {
                if (i > 0) sb.append(',');
                try {
                    Object value = rs.getObject(headers[i]);
                    sb.append(csvEscape(value));
                } catch (SQLException e) {
                    // column missing — skip
                }
            }
            writer.println(sb.toString());
            count[0]++;
        });

        writer.flush();
        zip.closeEntry();
        return count[0];
    }

    private int writeJson(ZipOutputStream zip, String entryName, String sql) throws IOException {
        List<Map<String, Object>> rows = jdbc.query(sql, new MapSqlParameterSource(), (rs, n) -> rowToMap(rs));
        zip.putNextEntry(new ZipEntry(entryName));
        byte[] bytes = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(rows);
        zip.write(bytes);
        zip.closeEntry();
        return rows.size();
    }

    private Map<String, Object> rowToMap(ResultSet rs) throws SQLException {
        ResultSetMetaData md = rs.getMetaData();
        int cols = md.getColumnCount();
        Map<String, Object> map = new LinkedHashMap<>(cols);
        for (int i = 1; i <= cols; i++) {
            map.put(md.getColumnLabel(i), rs.getObject(i));
        }
        return map;
    }

    private void writeSchemaJson(ZipOutputStream zip, String schema, Map<String, Integer> rowCounts) throws IOException {
        String tenantName = "";
        try {
            tenantName = jdbc.queryForObject(
                    "SELECT name FROM dentalcare.tenants WHERE schema_name = :schema",
                    new MapSqlParameterSource("schema", schema),
                    String.class);
            if (tenantName == null) tenantName = "";
        } catch (Exception ignored) {
        }

        Map<String, Object> meta = new LinkedHashMap<>();
        meta.put("tenant", tenantName);
        meta.put("schema", schema);
        meta.put("exportDate", LocalDate.now().toString());
        meta.put("rowCounts", rowCounts);

        zip.putNextEntry(new ZipEntry("schema/schema.json"));
        zip.write(objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(meta));
        zip.closeEntry();
    }

    private void writeReadme(ZipOutputStream zip, String schema) throws IOException {
        String body = """
                # Tenant Export

                Schema: %s
                Data export: %s

                ## Struttura

                - `data/providers.csv` — utenti operativi (id, first_name, last_name, email, role, active)
                - `data/patients.csv` — anagrafica pazienti (id, first_name, last_name, fiscal_code, birth_date, phone, city)
                - `data/appointments.csv` — appuntamenti (id, patient_id, provider_id, starts_at, ends_at, status, notes)
                - `data/invoices.csv` — fatture (id, invoice_number, patient_id, status, total_amount, issued_at)
                - `clinical/treatment_plans.json` — piani di cura
                - `clinical/clinical_history.json` — voci di storico clinico
                - `schema/schema.json` — metadati export (tenant, schema, data, conteggi)

                ## Encoding

                Tutti i file sono UTF-8. I CSV usano la virgola come separatore e le doppie virgolette per i campi che contengono virgole, newline o doppie virgolette.
                """.formatted(schema, LocalDate.now());

        zip.putNextEntry(new ZipEntry("schema/README.md"));
        zip.write(body.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }

    private String csvEscape(Object value) {
        if (value == null) return "";
        String s;
        if (value instanceof java.sql.Array arr) {
            try {
                Object[] elements = (Object[]) arr.getArray();
                List<String> parts = new ArrayList<>(elements.length);
                for (Object e : elements) parts.add(String.valueOf(e));
                s = String.join("|", parts);
            } catch (SQLException e) {
                s = value.toString();
            }
        } else {
            s = value.toString();
        }
        boolean needsQuoting = s.indexOf(',') >= 0 || s.indexOf('"') >= 0
                || s.indexOf('\n') >= 0 || s.indexOf('\r') >= 0;
        if (needsQuoting) {
            return '"' + s.replace("\"", "\"\"") + '"';
        }
        return s;
    }
}
