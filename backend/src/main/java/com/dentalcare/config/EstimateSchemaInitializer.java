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

    private void patchGlobalEnums() {
        // Idempotent: create enum with all values if not exists, then add any missing values
        try {
            jdbc.execute(
                "DO $$ BEGIN " +
                "IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace " +
                "WHERE t.typname = 'provider_role' AND n.nspname = 'dentalcare') THEN " +
                "CREATE TYPE dentalcare.provider_role AS ENUM " +
                "('dentist','hygienist','orthodontist','surgeon','assistant','admin','tenant_admin','other'); " +
                "END IF; END $$");
        } catch (Exception e) {
            log.warn("EstimateSchemaInitializer: patchGlobalEnums create failed: {}", e.getMessage());
        }
        for (String val : List.of("tenant_admin", "orthodontist", "surgeon", "assistant", "other")) {
            try {
                jdbc.execute("DO $$ BEGIN " +
                        "IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid " +
                        "WHERE t.typname = 'provider_role' AND e.enumlabel = '" + val + "') " +
                        "THEN ALTER TYPE dentalcare.provider_role ADD VALUE '" + val + "'; END IF; END $$");
            } catch (Exception e) {
                log.warn("EstimateSchemaInitializer: failed to add enum value {}: {}", val, e.getMessage());
            }
        }
    }

    private void applyTenantOperationalPatches() {
        patchGlobalEnums();

        Integer tenantsTableExists = jdbc.queryForObject(
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'dentalcare' AND table_name = 'tenants'",
                Integer.class);

        List<String> schemas;
        if (tenantsTableExists != null && tenantsTableExists > 0) {
            schemas = jdbc.queryForList(
                    "SELECT schema_name FROM dentalcare.tenants WHERE active = true",
                    String.class);
        } else {
            schemas = jdbc.queryForList(
                    "SELECT schema_name FROM information_schema.schemata WHERE schema_name ~ '^t_[0-9a-f]{8}$'",
                    String.class);
            log.warn("EstimateSchemaInitializer: dentalcare.tenants not found — discovered {} tenant schema(s) by pattern", schemas.size());
        }

        // AI enums — idempotent, created once in the global dentalcare schema
        jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_analysis_status AS ENUM ('PENDING','PROCESSING','COMPLETED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
        jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_review_status AS ENUM ('pending','reviewed','approved_for_training','excluded'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
        jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_label_source AS ENUM ('ai','human_corrected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");

        for (String schema : schemas) {
            Integer exists = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?",
                    Integer.class, schema);
            if (exists == null || exists == 0) {
                log.warn("EstimateSchemaInitializer: schema {} registered but does not exist — skipping", schema);
                continue;
            }
            runStep(schema, "clinics/patients/providers columns", () -> {
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS email TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS legal_name TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS vat_number TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS fiscal_code TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS phone TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS address_line1 TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS address_line2 TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS city TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS province TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS postal_code TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS country TEXT NOT NULL DEFAULT 'IT'");
                jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()");
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
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS password_temporary BOOLEAN NOT NULL DEFAULT false");
            });
            runStep(schema, "providers/role+phone", () -> {
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS phone TEXT");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now()");
                jdbc.execute("ALTER TABLE " + schema + ".providers ADD COLUMN IF NOT EXISTS role dentalcare.provider_role NOT NULL DEFAULT 'dentist'");
            });
            runStep(schema, "estimates+lines",  () -> patchEstimatesAndLinesSchema(schema));
            runStep(schema, "treatment_plan_items app-names", () -> patchTreatmentItemColumns(schema));
            runStep(schema, "app columns",      () -> patchAppColumns(schema));
            runStep(schema, "recalls",          () -> patchRecallsSchema(schema));
            runStep(schema, "products",         () -> patchProductsSchema(schema));
            runStep(schema, "v_clinic_dashboard",           () -> rebuildDashboardView(schema));
            runStep(schema, "v_agenda_daily",               () -> rebuildAgendaView(schema));
            runStep(schema, "v_patient_dashboard",          () -> rebuildPatientDashboardView(schema));
            runStep(schema, "v_patient_clinical_card",      () -> rebuildPatientClinicalCardView(schema));
            runStep(schema, "v_patient_estimates_summary",  () -> rebuildEstimatesSummaryView(schema));
            runStep(schema, "ai analyses tables",           () -> createAiTables(schema));
            log.debug("EstimateSchemaInitializer: patched schema {}", schema);
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

    /**
     * Converge treatment_plan_items / patient_anamnesis ai nomi colonna usati dall'app (service + viste):
     * plan_id→treatment_plan_id, service_catalog_id→service_id, tooth_fdi→tooth_number, notes→general_notes.
     * Necessario per schemi creati dal template V23 (nomi nuovi) — l'app usa i nomi storici.
     * Idempotente: rinomina solo se la sorgente esiste e la destinazione no.
     */
    private void patchTreatmentItemColumns(String schema) {
        // Drop viste dipendenti prima del rename; ricreate dagli step v_* successivi.
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_agenda_daily");
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_dashboard");
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_clinical_card");

        renameColToTarget(schema, "treatment_plan_items", "plan_id",            "treatment_plan_id");
        renameColToTarget(schema, "treatment_plan_items", "service_catalog_id", "service_id");
        renameColToTarget(schema, "treatment_plan_items", "tooth_fdi",          "tooth_number");
        renameColToTarget(schema, "patient_anamnesis",    "notes",              "general_notes");
    }

    /**
     * Aggiunge le colonne ricche usate dall'app ma assenti nel template create_tenant (V23).
     * Additivo/idempotente: ADD COLUMN IF NOT EXISTS. Converge i tenant nuovi allo schema canonico (demo).
     */
    private void patchAppColumns(String schema) {
        jdbc.execute("ALTER TABLE " + schema + ".appointments ADD COLUMN IF NOT EXISTS cancellation_reason text");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS entry_date date DEFAULT CURRENT_DATE NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS tooth_number text");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS service_code text");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS service_name text");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS clinical_notes text");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS materials_used text");
        jdbc.execute("ALTER TABLE " + schema + ".clinical_history_entries ADD COLUMN IF NOT EXISTS next_visit_notes text");
        jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS city_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".odontogram_teeth ADD COLUMN IF NOT EXISTS tooth_number text");
        jdbc.execute("ALTER TABLE " + schema + ".odontogram_teeth ADD COLUMN IF NOT EXISTS quadrant smallint");
        jdbc.execute("ALTER TABLE " + schema + ".odontogram_teeth ADD COLUMN IF NOT EXISTS is_deciduous boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".odontogram_teeth ADD COLUMN IF NOT EXISTS bridge_group_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".odontogram_teeth ADD COLUMN IF NOT EXISTS implant_ref text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS drug_use boolean");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS diabetes_type text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS immunodeficiency boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS thyroid_disease boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS tumor_history boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS autoimmune_disease boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS other_diseases text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS bruxism boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS mouth_breathing boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS nail_biting boolean DEFAULT false NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS pacifier_use boolean");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS signed_at timestamptz");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS signature_notes text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now() NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS appointment_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS uploaded_by_provider_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS description text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS file_name text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS file_size_bytes bigint");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS tooth_number text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS taken_at date");
        jdbc.execute("ALTER TABLE " + schema + ".patient_documents ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now() NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_recalls ADD COLUMN IF NOT EXISTS booked_appointment_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS address_line2 text");
        jdbc.execute("ALTER TABLE " + schema + ".service_catalog ADD COLUMN IF NOT EXISTS default_vat_rate numeric(5,2) DEFAULT 0 NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".suppliers ADD COLUMN IF NOT EXISTS contact_person text");
        jdbc.execute("ALTER TABLE " + schema + ".suppliers ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".tooth_conditions ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now() NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS provider_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS quadrant smallint");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS quantity numeric(10,2) DEFAULT 1 NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS planned_price numeric(12,2) DEFAULT 0 NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS planned_vat_rate numeric(5,2) DEFAULT 0 NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS clinical_notes text");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS priority integer DEFAULT 100 NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plan_items ADD COLUMN IF NOT EXISTS planned_date date");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plans ADD COLUMN IF NOT EXISTS name text DEFAULT 'Piano di cura'::text NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plans ADD COLUMN IF NOT EXISTS created_by_provider_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plans ADD COLUMN IF NOT EXISTS proposed_at timestamptz");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plans ADD COLUMN IF NOT EXISTS accepted_at timestamptz");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plans ADD COLUMN IF NOT EXISTS completed_at timestamptz");
        jdbc.execute("ALTER TABLE " + schema + ".treatment_plans ADD COLUMN IF NOT EXISTS rejected_at timestamptz");
        // patient_anamnesis_item_selections: template V23 ha un design diverso (anamnesis_id/anamnesis_item_id/detail_text);
        // l'app (AnamnesisService) usa clinic_id/patient_id/item_id. Aggiungo le colonne dell'app.
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS clinic_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS patient_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS item_id uuid");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS notes text");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS recorded_at timestamptz DEFAULT now() NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now() NOT NULL");
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS recorded_by_provider_id uuid");
    }

    /** Rinomina oldCol→newCol solo se oldCol esiste E newCol non esiste. */
    private void renameColToTarget(String schema, String table, String oldCol, String newCol) {
        Integer oldEx = jdbc.queryForObject(
                "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?",
                Integer.class, schema, table, oldCol);
        Integer newEx = jdbc.queryForObject(
                "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?",
                Integer.class, schema, table, newCol);
        if (oldEx != null && oldEx > 0 && (newEx == null || newEx == 0)) {
            jdbc.execute("ALTER TABLE " + schema + "." + table + " RENAME COLUMN " + oldCol + " TO " + newCol);
        }
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
        boolean hasAnamnesis = tableExists(schema, "patient_anamnesis");
        String alertCols = hasAnamnesis
            ? "  EXISTS (SELECT 1 FROM " + schema + ".patient_anamnesis pa2" +
              "    WHERE pa2.patient_id = p.id AND pa2.clinic_id = a.clinic_id AND pa2.is_current = true" +
              "    AND (pa2.allergy_penicillin OR pa2.allergy_latex OR pa2.allergy_anesthetic" +
              "         OR pa2.allergy_aspirin OR pa2.other_allergies IS NOT NULL)) AS has_allergy_alert," +
              "  EXISTS (SELECT 1 FROM " + schema + ".patient_anamnesis pa2" +
              "    WHERE pa2.patient_id = p.id AND pa2.clinic_id = a.clinic_id AND pa2.is_current = true" +
              "    AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates" +
              "         OR pa2.heart_disease)) AS has_medication_alert"
            : "  false AS has_allergy_alert," +
              "  false AS has_medication_alert";

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
            "  sc.name AS service_name," +
            "  sc.category AS service_category," +
            "  tpi.tooth_number AS tooth_number," +
            alertCols +
            " FROM " + schema + ".appointments a" +
            " LEFT JOIN " + schema + ".patients             p   ON p.id   = a.patient_id" +
            " LEFT JOIN " + schema + ".providers            pr  ON pr.id  = a.provider_id" +
            " LEFT JOIN " + schema + ".treatment_plan_items tpi ON tpi.id = a.treatment_plan_item_id" +
            " LEFT JOIN " + schema + ".service_catalog      sc  ON sc.id  = tpi.service_id"
        );
    }

    private boolean tableExists(String schema, String table) {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = ? AND table_name = ?",
                Integer.class, schema, table);
        return count != null && count > 0;
    }

    private void runStep(String schema, String step, Runnable action) {
        try {
            action.run();
        } catch (Exception e) {
            log.warn("EstimateSchemaInitializer: {} failed for schema {}: {}", step, schema, e.getMessage());
        }
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
            " LEFT JOIN " + schema + ".treatment_plan_items tpi ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = p.clinic_id" +
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
            "  pa.current_medications, pa.other_allergies," +
            "  pa.general_notes AS anamnesis_notes," +
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

    private void createAiTables(String schema) {
        jdbc.execute(("""
            CREATE TABLE IF NOT EXISTS %1$s.patient_document_analyses (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id uuid NOT NULL, patient_id uuid NOT NULL, document_id uuid NOT NULL,
                job_id text, status dentalcare.ai_analysis_status NOT NULL DEFAULT 'PENDING',
                model_fdi text, model_disease text, result_bucket text, result_object_key text,
                annotated_object_key text, detections_count integer NOT NULL DEFAULT 0,
                needs_review boolean NOT NULL DEFAULT false,
                review_status dentalcare.ai_review_status NOT NULL DEFAULT 'pending',
                reviewed_by_provider_id uuid, reviewed_at timestamptz, error_message text,
                requested_by_provider_id uuid,
                created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now())
            """).formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_document ON %1$s.patient_document_analyses (document_id)".formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_patient ON %1$s.patient_document_analyses (patient_id)".formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_job ON %1$s.patient_document_analyses (job_id)".formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_status ON %1$s.patient_document_analyses (status)".formatted(schema));
        jdbc.execute(("""
            CREATE TABLE IF NOT EXISTS %1$s.patient_document_labels (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                analysis_id uuid NOT NULL REFERENCES %1$s.patient_document_analyses (id) ON DELETE CASCADE,
                tooth_fdi text, disease text NOT NULL, disease_confidence numeric(5,4), fdi_confidence numeric(5,4),
                bbox_x1 integer NOT NULL, bbox_y1 integer NOT NULL, bbox_x2 integer NOT NULL, bbox_y2 integer NOT NULL,
                matching_method text NOT NULL, matching_score numeric(5,4),
                needs_review boolean NOT NULL DEFAULT false,
                source dentalcare.ai_label_source NOT NULL DEFAULT 'ai', action text,
                created_at timestamptz NOT NULL DEFAULT now())
            """).formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pdl_analysis ON %1$s.patient_document_labels (analysis_id)".formatted(schema));
        jdbc.execute("ALTER TABLE %1$s.tooth_conditions ADD COLUMN IF NOT EXISTS source varchar(10) NOT NULL DEFAULT 'manual'".formatted(schema));
        jdbc.execute("ALTER TABLE %1$s.tooth_conditions ADD COLUMN IF NOT EXISTS analysis_id uuid".formatted(schema));
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
