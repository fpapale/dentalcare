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
                patchEstimatesAndLinesSchema(schema);
                patchRecallsSchema(schema);
                patchProductsSchema(schema);
                rebuildDashboardView(schema);
                rebuildAgendaView(schema);
                rebuildPatientDashboardView(schema);
                rebuildPatientClinicalCardView(schema);
                rebuildEstimatesSummaryView(schema);
                log.debug("EstimateSchemaInitializer: patched schema {}", schema);
            } catch (Exception e) {
                log.warn("EstimateSchemaInitializer: patch failed for schema {}: {}", schema, e.getMessage());
            }
        }
    }

    private void patchEstimatesAndLinesSchema(String schema) {
        // Drop views that depend on estimates/estimate_lines before renaming columns
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_estimates_summary");
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_dashboard");

        // estimates: rename legacy column names
        renameColIfExists(schema, "estimates", "subtotal",       "subtotal_amount");
        renameColIfExists(schema, "estimates", "discount_total", "discount_amount");
        renameColIfExists(schema, "estimates", "total",          "total_amount");
        renameColIfExists(schema, "estimates", "plan_id",        "treatment_plan_id");

        // estimates: add missing columns
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS estimate_number  TEXT");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS currency         TEXT NOT NULL DEFAULT 'EUR'");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS taxable_amount   NUMERIC(12,2) NOT NULL DEFAULT 0");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS vat_amount       NUMERIC(12,2) NOT NULL DEFAULT 0");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS issued_at        TIMESTAMPTZ");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS sent_at          TIMESTAMPTZ");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS accepted_at      TIMESTAMPTZ");
        jdbc.execute("ALTER TABLE " + schema + ".estimates ADD COLUMN IF NOT EXISTS rejected_at      TIMESTAMPTZ");

        // estimate_lines: rename legacy column names
        renameColIfExists(schema, "estimate_lines", "service_catalog_id", "service_id");
        renameColIfExists(schema, "estimate_lines", "description",        "description_snapshot");
        renameColIfExists(schema, "estimate_lines", "tooth_fdi",          "tooth_snapshot");
        renameColIfExists(schema, "estimate_lines", "discount_pct",       "discount_amount");

        // estimate_lines: add missing columns
        jdbc.execute("ALTER TABLE " + schema + ".estimate_lines ADD COLUMN IF NOT EXISTS line_position   INTEGER       NOT NULL DEFAULT 10");
        jdbc.execute("ALTER TABLE " + schema + ".estimate_lines ADD COLUMN IF NOT EXISTS vat_rate        NUMERIC(5,2)  NOT NULL DEFAULT 0");
        jdbc.execute("ALTER TABLE " + schema + ".estimate_lines ADD COLUMN IF NOT EXISTS line_subtotal   NUMERIC(12,2) NOT NULL DEFAULT 0");
        jdbc.execute("ALTER TABLE " + schema + ".estimate_lines ADD COLUMN IF NOT EXISTS line_taxable    NUMERIC(12,2) NOT NULL DEFAULT 0");
        jdbc.execute("ALTER TABLE " + schema + ".estimate_lines ADD COLUMN IF NOT EXISTS line_vat_amount NUMERIC(12,2) NOT NULL DEFAULT 0");

        // service_catalog: rename legacy column names
        renameColIfExists(schema, "service_catalog", "price",    "default_price");
        renameColIfExists(schema, "service_catalog", "is_active", "active");

        // service_bundle_items: rename legacy column names
        renameColIfExists(schema, "service_bundle_items", "bundle_service_id",    "parent_service_id");
        renameColIfExists(schema, "service_bundle_items", "component_service_id", "child_service_id");
        jdbc.execute("ALTER TABLE " + schema + ".service_bundle_items ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0");

        // condition_service_defaults: rename legacy column names
        renameColIfExists(schema, "condition_service_defaults", "condition",         "condition_name");
        renameColIfExists(schema, "condition_service_defaults", "service_catalog_id", "service_id");
    }

    private void patchProductsSchema(String schema) {
        // products: rename legacy column names
        renameColIfExists(schema, "products", "min_stock",   "min_stock_quantity");
        renameColIfExists(schema, "products", "price_unit",  "unit_cost");
        // products: add missing columns
        jdbc.execute("ALTER TABLE " + schema + ".products ADD COLUMN IF NOT EXISTS reorder_quantity NUMERIC(12,2) NOT NULL DEFAULT 0");
        // rebuild view after column renames
        rebuildProductStockView(schema);
    }

    private void rebuildProductStockView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".product_stock_v");
        jdbc.execute(
            "CREATE VIEW " + schema + ".product_stock_v AS " +
            "SELECT pr.clinic_id, pr.id AS product_id," +
            "  pr.category_id, pc.name AS category_name," +
            "  pr.supplier_id, s.name AS supplier_name," +
            "  pr.name, pr.description, pr.sku, pr.unit," +
            "  pr.min_stock_quantity, pr.reorder_quantity, pr.unit_cost, pr.is_active," +
            "  COALESCE(SUM(" +
            "    CASE sm.movement_type" +
            "      WHEN 'carico'    THEN sm.quantity" +
            "      WHEN 'rientro'   THEN sm.quantity" +
            "      WHEN 'scarico'   THEN -sm.quantity" +
            "      WHEN 'rettifica' THEN sm.quantity" +
            "      ELSE 0 END), 0) AS current_stock," +
            "  CASE" +
            "    WHEN COALESCE(SUM(CASE sm.movement_type" +
            "      WHEN 'carico' THEN sm.quantity WHEN 'rientro' THEN sm.quantity" +
            "      WHEN 'scarico' THEN -sm.quantity WHEN 'rettifica' THEN sm.quantity ELSE 0 END), 0) = 0" +
            "      THEN 'critico'" +
            "    WHEN COALESCE(SUM(CASE sm.movement_type" +
            "      WHEN 'carico' THEN sm.quantity WHEN 'rientro' THEN sm.quantity" +
            "      WHEN 'scarico' THEN -sm.quantity WHEN 'rettifica' THEN sm.quantity ELSE 0 END), 0) <= pr.min_stock_quantity" +
            "      THEN 'basso'" +
            "    ELSE 'ok' END AS stock_status" +
            " FROM " + schema + ".products pr" +
            " LEFT JOIN " + schema + ".product_categories pc ON pc.id = pr.category_id AND pc.clinic_id = pr.clinic_id" +
            " LEFT JOIN " + schema + ".suppliers          s  ON s.id  = pr.supplier_id  AND s.clinic_id  = pr.clinic_id" +
            " LEFT JOIN " + schema + ".stock_movements    sm ON sm.product_id = pr.id   AND sm.clinic_id = pr.clinic_id" +
            " GROUP BY pr.clinic_id, pr.id, pr.category_id, pc.name, pr.supplier_id, s.name," +
            "          pr.name, pr.description, pr.sku, pr.unit," +
            "          pr.min_stock_quantity, pr.reorder_quantity, pr.unit_cost, pr.is_active"
        );
    }

    private void patchRecallsSchema(String schema) {
        // patient_recalls: rename legacy column names
        renameColIfExists(schema, "patient_recalls", "appointment_id", "source_appointment_id");
        // patient_recalls: add missing columns
        jdbc.execute("ALTER TABLE " + schema + ".patient_recalls ADD COLUMN IF NOT EXISTS contact_count    INTEGER NOT NULL DEFAULT 0");
        jdbc.execute("ALTER TABLE " + schema + ".patient_recalls ADD COLUMN IF NOT EXISTS last_contact_at DATE");

        // recall_contacts: rename legacy column names
        renameColIfExists(schema, "recall_contacts", "contacted_by_provider_id", "created_by_provider_id");
        renameColIfExists(schema, "recall_contacts", "contacted_at",             "contact_at");
    }

    private void renameColIfExists(String schema, String table, String oldCol, String newCol) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?",
                Integer.class, schema, table, oldCol);
        if (count != null && count > 0) {
            jdbc.execute("ALTER TABLE " + schema + "." + table + " RENAME COLUMN " + oldCol + " TO " + newCol);
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

    private void rebuildPatientDashboardView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_dashboard");
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_patient_dashboard AS " +
            "SELECT p.id AS patient_id, p.clinic_id," +
            "  p.first_name AS patient_first_name," +
            "  p.last_name  AS patient_last_name," +
            "  concat_ws(' ', p.last_name, p.first_name) AS patient_full_name," +
            "  p.fiscal_code, p.birth_date," +
            "  CASE WHEN p.birth_date IS NULL THEN NULL" +
            "       ELSE date_part('year', age(CURRENT_DATE, p.birth_date))::int END AS age_years," +
            "  p.phone, p.email, p.city, p.province, p.active," +
            "  COUNT(DISTINCT tp.id) FILTER (WHERE tp.status NOT IN ('rejected','archived')) AS treatment_plans_count," +
            "  COUNT(DISTINCT tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled')) AS open_treatment_items_count," +
            "  COALESCE(SUM(e.total_amount) FILTER (WHERE e.status = 'accepted'), 0.00) AS accepted_estimates_amount" +
            " FROM " + schema + ".patients p" +
            " LEFT JOIN " + schema + ".treatment_plans tp ON tp.patient_id = p.id AND tp.clinic_id = p.clinic_id" +
            " LEFT JOIN " + schema + ".treatment_plan_items tpi ON tpi.plan_id = tp.id AND tpi.clinic_id = p.clinic_id" +
            " LEFT JOIN " + schema + ".estimates e ON e.patient_id = p.id AND e.clinic_id = p.clinic_id" +
            " GROUP BY p.id, p.clinic_id, p.first_name, p.last_name, p.fiscal_code," +
            "          p.birth_date, p.phone, p.email, p.city, p.province, p.active"
        );
    }

    private void rebuildPatientClinicalCardView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_clinical_card");
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_patient_clinical_card AS " +
            "SELECT p.id AS patient_id, p.clinic_id," +
            "  p.first_name, p.last_name," +
            "  concat_ws(' ', p.last_name, p.first_name) AS full_name," +
            "  p.birth_date," +
            "  CASE WHEN p.birth_date IS NULL THEN NULL" +
            "       ELSE date_part('year', age(CURRENT_DATE, p.birth_date))::int END AS age_years," +
            "  p.fiscal_code, p.phone, p.email, p.city, p.province," +
            "  p.notes AS patient_notes, p.active," +
            "  pa.blood_type, pa.smoker, pa.hypertension, pa.diabetes, pa.heart_disease," +
            "  pa.taking_anticoagulants, pa.taking_bisphosphonates," +
            "  pa.allergy_penicillin, pa.allergy_latex, pa.allergy_anesthetic," +
            "  pa.current_medications, pa.other_allergies, pa.pacemaker," +
            "  pa.notes AS anamnesis_notes," +
            "  pa.recorded_at AS anamnesis_date," +
            "  (SELECT COUNT(*) FROM " + schema + ".appointments a" +
            "   WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id) AS total_appointments" +
            " FROM " + schema + ".patients p" +
            " LEFT JOIN " + schema + ".patient_anamnesis pa" +
            "   ON pa.patient_id = p.id AND pa.clinic_id = p.clinic_id AND pa.is_current = true"
        );
    }

    private void rebuildEstimatesSummaryView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_estimates_summary");
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_patient_estimates_summary AS " +
            "SELECT e.id AS estimate_id, e.clinic_id, e.patient_id, e.created_by_provider_id," +
            "  e.version," +
            "  e.status::text  AS estimate_status," +
            "  e.title         AS estimate_title," +
            "  e.estimate_number," +
            "  e.currency," +
            "  e.subtotal_amount," +
            "  e.discount_amount," +
            "  e.taxable_amount," +
            "  e.vat_amount," +
            "  e.total_amount," +
            "  concat_ws(' ', p.last_name, p.first_name) AS patient_full_name," +
            "  p.fiscal_code AS patient_fiscal_code," +
            "  p.phone       AS patient_phone," +
            "  e.issued_at, e.sent_at, e.valid_until, e.accepted_at, e.rejected_at," +
            "  e.created_at  AS estimate_created_at" +
            " FROM " + schema + ".estimates e" +
            " LEFT JOIN " + schema + ".patients p ON p.id = e.patient_id AND p.clinic_id = e.clinic_id"
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
