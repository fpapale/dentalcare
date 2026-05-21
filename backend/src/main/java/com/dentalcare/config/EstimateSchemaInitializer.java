package com.dentalcare.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class EstimateSchemaInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(EstimateSchemaInitializer.class);
    private final JdbcTemplate jdbc;

    public EstimateSchemaInitializer(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        try {
            applyTenantOperationalPatches();
            log.info("EstimateSchemaInitializer: schema OK");
        } catch (Exception e) {
            log.error("EstimateSchemaInitializer failed", e);
        }
    }

    private void applyTenantOperationalPatches() {
        List<String> schemas = jdbc.queryForList(
                "SELECT schema_name FROM dentalcare.tenants WHERE active = true",
                String.class);

        for (String schema : schemas) {
            // verify schema actually exists in pg_catalog before patching
            Integer exists = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?",
                    Integer.class, schema);
            if (exists == null || exists == 0) {
                log.warn("EstimateSchemaInitializer: schema {} registered but does not exist — skipping", schema);
                continue;
            }
            try {
                jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true");
                jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS photo_url TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS photo_url TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS vat_number TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS fiscal_code TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS professional_register TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS register_number TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_address_street TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_address_zip TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_address_city TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_address_province TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_pec TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_iban TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS billing_sdi_code TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS invoice_prefix TEXT");
                rebuildDashboardView(schema);
                rebuildAgendaView(schema);
                log.debug("EstimateSchemaInitializer: patched schema {}", schema);
            } catch (Exception e) {
                log.warn("EstimateSchemaInitializer: patch failed for schema {}: {}", schema, e.getMessage());
            }
        }
    }

    private void rebuildAgendaView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_agenda_daily");
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_agenda_daily AS " +
            "SELECT a.id AS appointment_id, a.clinic_id, a.starts_at, a.ends_at, a.chair_label," +
            "  a.status::text AS appointment_status," +
            "  a.notes AS notes," +
            "  p.id AS patient_id," +
            "  concat_ws(' ', p.last_name, p.first_name) AS patient_full_name," +
            "  p.phone AS patient_phone," +
            "  p.email AS patient_email," +
            "  pr.id AS provider_id," +
            "  concat_ws(' ', pr.first_name, pr.last_name) AS provider_name," +
            "  pr.role::text AS provider_role," +
            "  pr.color_hex AS provider_color," +
            "  sc.name AS service_name," +
            "  sc.category AS service_category," +
            "  tpi.tooth_fdi AS tooth_number," +
            "  EXISTS (SELECT 1 FROM " + schema + ".patient_anamnesis pa2" +
            "    WHERE pa2.patient_id = p.id AND pa2.clinic_id = a.clinic_id AND pa2.is_current = true" +
            "    AND (pa2.allergy_penicillin OR pa2.allergy_latex OR pa2.allergy_anesthetic" +
            "         OR pa2.allergy_aspirin OR pa2.other_allergies IS NOT NULL)) AS has_allergy_alert," +
            "  EXISTS (SELECT 1 FROM " + schema + ".patient_anamnesis pa2" +
            "    WHERE pa2.patient_id = p.id AND pa2.clinic_id = a.clinic_id AND pa2.is_current = true" +
            "    AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates" +
            "         OR pa2.heart_disease OR pa2.pacemaker)) AS has_medication_alert" +
            " FROM " + schema + ".appointments a" +
            " LEFT JOIN " + schema + ".patients             p   ON p.id   = a.patient_id" +
            " LEFT JOIN " + schema + ".providers            pr  ON pr.id  = a.provider_id" +
            " LEFT JOIN " + schema + ".treatment_plan_items tpi ON tpi.id = a.treatment_plan_item_id" +
            " LEFT JOIN " + schema + ".service_catalog      sc  ON sc.id  = tpi.service_catalog_id"
        );
    }

    private void rebuildDashboardView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_clinic_dashboard");
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_clinic_dashboard AS " +
            "WITH patient_agg AS (" +
            "  SELECT clinic_id, COUNT(*) FILTER (WHERE active = true) AS patients_count" +
            "  FROM " + schema + ".patients GROUP BY clinic_id" +
            "), " +
            "provider_agg AS (" +
            "  SELECT clinic_id, COUNT(*) FILTER (WHERE active = true) AS active_providers_count" +
            "  FROM " + schema + ".providers GROUP BY clinic_id" +
            "), " +
            "plan_agg AS (" +
            "  SELECT clinic_id," +
            "    COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_treatment_plans_count" +
            "  FROM " + schema + ".treatment_plans GROUP BY clinic_id" +
            ") " +
            "SELECT c.id AS clinic_id, c.name AS clinic_name, c.city AS city," +
            "  COALESCE(pa.patients_count, 0) AS patients_count," +
            "  COALESCE(pra.active_providers_count, 0) AS active_providers_count," +
            "  COALESCE(tpa.in_progress_treatment_plans_count, 0) AS in_progress_treatment_plans_count" +
            " FROM " + schema + ".clinics c" +
            " LEFT JOIN patient_agg  pa  ON pa.clinic_id  = c.id" +
            " LEFT JOIN provider_agg pra ON pra.clinic_id = c.id" +
            " LEFT JOIN plan_agg     tpa ON tpa.clinic_id = c.id"
        );
    }
}
