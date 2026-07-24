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

        // Colonna globale per il soft-delete/grace-period del tenant (#47): scheduled_drop_at
        // valorizzata al confirm della cancellazione (active=false + scheduled_drop_at=now()+N gg);
        // il DROP SCHEMA reale avviene solo allo scadere, via TenantDeletionScheduler.
        if (tenantsTableExists != null && tenantsTableExists > 0) {
            try {
                jdbc.execute("ALTER TABLE dentalcare.tenants ADD COLUMN IF NOT EXISTS scheduled_drop_at timestamptz");
            } catch (Exception e) {
                log.warn("EstimateSchemaInitializer: failed to add dentalcare.tenants.scheduled_drop_at: {}", e.getMessage());
            }
        }

        // AI enums — idempotent, created once in the global dentalcare schema
        try {
            jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_analysis_status AS ENUM ('PENDING','PROCESSING','COMPLETED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
        } catch (Exception e) {
            log.warn("EstimateSchemaInitializer: AI enum ai_analysis_status creation skipped: {}", e.getMessage());
        }
        try {
            jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_review_status AS ENUM ('pending','reviewed','approved_for_training','excluded'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
        } catch (Exception e) {
            log.warn("EstimateSchemaInitializer: AI enum ai_review_status creation skipped: {}", e.getMessage());
        }
        try {
            jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_label_source AS ENUM ('ai','human_corrected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
        } catch (Exception e) {
            log.warn("EstimateSchemaInitializer: AI enum ai_label_source creation skipped: {}", e.getMessage());
        }

        for (String schema : schemas) {
            patchSchema(schema);
        }
    }

    /**
     * Applica tutte le patch idempotenti a un singolo schema tenant.
     * Chiamata sia dal loop di startup ({@link #applyTenantOperationalPatches()}) sia
     * subito dopo il provisioning di un nuovo tenant, così uno schema appena creato
     * risulta immediatamente allineato (birth_date_enc, foreign_patient, viste aggiornate)
     * senza dover attendere il prossimo riavvio del backend.
     */
    public void patchSchema(String schema) {
        Integer exists = jdbc.queryForObject(
                "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?",
                Integer.class, schema);
        if (exists == null || exists == 0) {
            log.warn("EstimateSchemaInitializer: schema {} registered but does not exist — skipping", schema);
            return;
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
            // #31 — orari studio configurabili per tenant. Nullable di proposito:
            // null = usa i default applicativi (AppointmentService.ScheduleConfig.defaults()).
            jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS work_start_time TIME");
            jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS work_end_time TIME");
            jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS slot_minutes INTEGER");
            jdbc.execute("ALTER TABLE " + schema + ".clinics ADD COLUMN IF NOT EXISTS working_days TEXT");
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
        runStep(schema, "service_categories", () -> {
            jdbc.execute("""
                CREATE TABLE IF NOT EXISTS %s.service_categories (
                    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                    clinic_id  uuid NOT NULL,
                    name       text NOT NULL,
                    sort_order integer NOT NULL DEFAULT 10,
                    active     boolean NOT NULL DEFAULT true,
                    created_at timestamptz NOT NULL DEFAULT now(),
                    updated_at timestamptz NOT NULL DEFAULT now()
                )""".formatted(schema));
            jdbc.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS ux_service_categories_clinic_name
                    ON %s.service_categories (clinic_id, lower(name))""".formatted(schema));
            jdbc.execute("""
                INSERT INTO %s.service_categories (clinic_id, name)
                    SELECT DISTINCT clinic_id, category FROM %s.service_catalog
                    WHERE category IS NOT NULL AND btrim(category) <> ''
                    ON CONFLICT (clinic_id, lower(name)) DO NOTHING""".formatted(schema, schema));
            // Ruoli abilitati a selezionare le prestazioni della categoria (CSV di
            // dentalcare.provider_role). Null/vuoto = nessun vincolo, categoria visibile a tutti.
            jdbc.execute("ALTER TABLE " + schema + ".service_categories ADD COLUMN IF NOT EXISTS allowed_roles TEXT");
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
        // Le colonne cifrate DEVONO esistere prima di ricostruire le viste che le referenziano
        // (le viste pazienti/preventivi ora espongono fiscal_code_enc/idx): altrimenti il CREATE VIEW
        // fallisce dopo il DROP e la vista resta cancellata fino al riavvio successivo.
        runStep(schema, "patients fiscal_code_enc/idx", () -> {
            jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS fiscal_code_enc text");
            jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS fiscal_code_idx text");
            jdbc.execute("CREATE INDEX IF NOT EXISTS idx_patients_fiscal_code_idx ON " + schema + ".patients (fiscal_code_idx)");
        });
        runStep(schema, "invoices patient_fiscal_code_enc", () ->
                jdbc.execute("ALTER TABLE " + schema + ".invoices ADD COLUMN IF NOT EXISTS patient_fiscal_code_enc text"));
        // DEVE precedere le viste v_patient_max_anamnesis_severity / v_agenda_daily / v_patient_clinical_card:
        // quelle referenziano anamnesis_items.severity e patient_anamnesis_item_selections.resolved_at. Su un
        // tenant non ancora convergente questi oggetti non esistono e il CREATE VIEW fallirebbe DOPO il DROP,
        // lasciando la vista cancellata fino al riavvio successivo (agenda/cartella paziente 500).
        runStep(schema, "anamnesis catalog + storico",  () -> patchAnamnesisCatalog(schema));
        runStep(schema, "v_clinic_dashboard",           () -> rebuildDashboardView(schema));
        runStep(schema, "v_patient_max_anamnesis_severity", () -> rebuildPatientMaxAnamnesisSeverityView(schema));
        runStep(schema, "v_agenda_daily",               () -> rebuildAgendaView(schema));
        runStep(schema, "v_patient_dashboard",          () -> rebuildPatientDashboardView(schema));
        runStep(schema, "v_patient_clinical_card",      () -> rebuildPatientClinicalCardView(schema));
        runStep(schema, "v_patient_estimates_summary",  () -> rebuildEstimatesSummaryView(schema));
        runStep(schema, "ai analyses tables",           () -> createAiTables(schema));
        runStep(schema, "ai_prompt_overrides",          () -> createAiPromptOverrides(schema));
        runStep(schema, "patients birth_date_enc", () ->
                jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS birth_date_enc text"));
        runStep(schema, "patients foreign_patient", () ->
                jdbc.execute("ALTER TABLE " + schema + ".patients ADD COLUMN IF NOT EXISTS foreign_patient boolean NOT NULL DEFAULT false"));
        log.debug("EstimateSchemaInitializer: patched schema {}", schema);
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
        // Il template V23 crea le colonne legacy anamnesis_id/anamnesis_item_id come NOT NULL (design diverso:
        // FK verso patient_anamnesis e dentalcare.anamnesis_items globale). L'app usa clinic_id/patient_id/item_id
        // e NON popola le legacy → su un tenant creato da V23 l'INSERT di savePatientAnamnesis violerebbe il NOT NULL.
        // Rilasso il vincolo (non-distruttivo: colonne e dati eventuali restano). Idempotente + guardato per colonna.
        jdbc.execute("""
            DO $do$ BEGIN
              IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = '%1$s'
                         AND table_name = 'patient_anamnesis_item_selections' AND column_name = 'anamnesis_id') THEN
                EXECUTE 'ALTER TABLE %1$s.patient_anamnesis_item_selections ALTER COLUMN anamnesis_id DROP NOT NULL';
              END IF;
              IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = '%1$s'
                         AND table_name = 'patient_anamnesis_item_selections' AND column_name = 'anamnesis_item_id') THEN
                EXECUTE 'ALTER TABLE %1$s.patient_anamnesis_item_selections ALTER COLUMN anamnesis_item_id DROP NOT NULL';
              END IF;
            END $do$;
            """.formatted(schema));
    }

    /**
     * Converge il catalogo anamnesi ({@code anamnesis_categories}/{@code anamnesis_items}) e lo storico
     * append-only ({@code patient_anamnesis_item_selections.resolved_at} + indice unico parziale) su un
     * singolo schema tenant. DEVE girare PRIMA delle viste che referenziano {@code anamnesis_items.severity}
     * e {@code ...resolved_at} (v_patient_max_anamnesis_severity, v_agenda_daily, v_patient_clinical_card):
     * {@code create_tenant()} (Flyway, congelato) non crea queste tabelle sui tenant esistenti/nuovi, quindi
     * la convergenza reale avviene qui — senza, il CREATE VIEW fallirebbe dopo il DROP lasciando le viste
     * cancellate (agenda + cartella paziente 500) e savePatientAnamnesis/getPatientAnamnesis romperebbero
     * sulla colonna resolved_at mancante.
     * <p>
     * Interamente idempotente: CREATE TABLE/INDEX IF NOT EXISTS, ADD/DROP ... IF (NOT) EXISTS, seed
     * count-guarded, FK aggiunta solo se assente e senza orfani. Eseguirlo due volte non produce errori
     * né duplica il seed. Colonne/PK/CHECK/indici identici a database/install.sql (template create_tenant).
     */
    private void patchAnamnesisCatalog(String schema) {
        // 1. Tabelle catalogo. PK/FK inline assumono i nomi default Postgres (anamnesis_categories_pkey,
        //    anamnesis_items_pkey, anamnesis_items_category_id_fkey), identici a install.sql.
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS %1$s.anamnesis_categories (
                id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
                code text,
                name text NOT NULL,
                description text,
                icon text DEFAULT 'medical_information'::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                CONSTRAINT anamnesis_categories_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
            )""".formatted(schema));
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS %1$s.anamnesis_items (
                id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
                category_id uuid NOT NULL REFERENCES %1$s.anamnesis_categories (id) ON DELETE CASCADE,
                code text NOT NULL,
                label text NOT NULL,
                description text,
                severity text DEFAULT 'normale'::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                has_detail boolean DEFAULT false NOT NULL,
                CONSTRAINT anamnesis_items_label_not_empty CHECK ((length(TRIM(BOTH FROM label)) > 0)),
                CONSTRAINT anamnesis_items_severity_check CHECK ((severity = ANY (ARRAY['normale'::text, 'grave'::text, 'severa'::text])))
            )""".formatted(schema));
        jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_anamnesis_categories_name ON %1$s.anamnesis_categories (name)".formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_anamnesis_items_category ON %1$s.anamnesis_items (category_id, sort_order)".formatted(schema));
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_anamnesis_items_category_sort ON %1$s.anamnesis_items (category_id, sort_order) WHERE (enabled = true)".formatted(schema));

        // 2. Seed 15 categorie / 87 voci — solo se le tabelle sono vuote (idempotente, mai duplica).
        Integer catCount = jdbc.queryForObject("SELECT COUNT(*) FROM " + schema + ".anamnesis_categories", Integer.class);
        if (catCount != null && catCount == 0) {
            jdbc.execute(ANAMNESIS_CATEGORIES_SEED.replace("{schema}", schema));
        }
        Integer itemCount = jdbc.queryForObject("SELECT COUNT(*) FROM " + schema + ".anamnesis_items", Integer.class);
        if (itemCount != null && itemCount == 0) {
            jdbc.execute(ANAMNESIS_ITEMS_SEED.replace("{schema}", schema));
        }

        // 3. Storico append-only: colonna resolved_at.
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS resolved_at timestamptz");

        // 4. Rimuove il vecchio vincolo unico pieno (legacy) e crea l'indice unico parziale sulle sole voci attive.
        jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_unique");
        jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_anamnesis_selections_active ON " + schema
                + ".patient_anamnesis_item_selections (clinic_id, patient_id, item_id) WHERE resolved_at IS NULL");

        // 5. FK item_id -> anamnesis_items per-tenant. Ripuntata SOLO se non può orfanare righe esistenti:
        //    nessuna selezione con item_id non presente nel catalogo per-tenant (i NULL sono ammessi dalla FK
        //    e non contano). Se esistessero selezioni che referenziano id non presenti (es. vecchi id globali
        //    dentalcare.anamnesis_items su un tenant reale con dati), NON tocchiamo la FK: il remap è manuale
        //    e supervisionato — vedi database/patch_anamnesis_tenant_migration.sql. Oggi non esistono tenant
        //    con pazienti reali (il demo t_9d754153 è già migrato), quindi il caso pratico è "tenant nuovo/vuoto".
        Integer orphans = jdbc.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".patient_anamnesis_item_selections s "
                + "WHERE s.item_id IS NOT NULL AND NOT EXISTS "
                + "(SELECT 1 FROM " + schema + ".anamnesis_items ai WHERE ai.id = s.item_id)",
                Integer.class);
        // Conta la FK SOLO se punta al catalogo per-tenant giusto. Su DB pre-rework la FK esiste ma
        // referenzia il catalogo GLOBALE dentalcare.anamnesis_items (vecchia create_tenant): gli item_id
        // per-tenant non ci sono → insert fallisce con FK violation. Il vecchio guard (mera esistenza)
        // la lasciava intatta. Ora la ripuntiamo: drop + re-add verso lo schema del tenant.
        Integer fkCorrect = jdbc.queryForObject(
                "SELECT COUNT(*) FROM pg_constraint c "
                + "JOIN pg_class ct ON ct.oid = c.conrelid "
                + "JOIN pg_namespace cn ON cn.oid = ct.relnamespace "
                + "JOIN pg_class rt ON rt.oid = c.confrelid "
                + "JOIN pg_namespace rn ON rn.oid = rt.relnamespace "
                + "WHERE cn.nspname = ? AND ct.relname = 'patient_anamnesis_item_selections' "
                + "AND c.conname = 'patient_anamnesis_item_selections_item_id_fkey' "
                + "AND rn.nspname = ? AND rt.relname = 'anamnesis_items'",
                Integer.class, schema, schema);
        // Ripunta la FK solo se nessuna riga verrebbe orfanata rispetto al catalogo per-tenant.
        // Se orphans>0 esistono selezioni che referenziano id non presenti per-tenant (es. vecchi id
        // globali su un tenant reale): remap manuale e supervisionato — vedi
        // database/patch_anamnesis_tenant_migration.sql. Non tocchiamo la FK in quel caso.
        if (orphans != null && orphans == 0 && (fkCorrect == null || fkCorrect == 0)) {
            jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections "
                    + "DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_item_id_fkey");
            jdbc.execute("ALTER TABLE " + schema + ".patient_anamnesis_item_selections "
                    + "ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey "
                    + "FOREIGN KEY (item_id) REFERENCES " + schema + ".anamnesis_items (id) ON DELETE CASCADE");
        }
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
        boolean hasCatalogSelections = tableExists(schema, "patient_anamnesis_item_selections")
                && tableExists(schema, "anamnesis_items");
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
        // Il ramo false (tenant senza catalogo/storico ancora convergente) è load-bearing, non decorativo:
        // mantiene valida la vista durante l'ordinamento di startup, prima che patchAnamnesisCatalog() giri.
        String catalogAlertCol = hasCatalogSelections
            ? ",  EXISTS (SELECT 1 FROM " + schema + ".patient_anamnesis_item_selections pais" +
              "    JOIN " + schema + ".anamnesis_items ai ON ai.id = pais.item_id" +
              "    WHERE pais.patient_id = p.id AND pais.clinic_id = a.clinic_id" +
              "    AND pais.resolved_at IS NULL AND ai.severity IN ('grave', 'severa')) AS has_catalog_alert"
            : ",  false AS has_catalog_alert";

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
            catalogAlertCol +
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
            "  p.fiscal_code_enc, p.fiscal_code_idx," +
            "  p.phone, p.email, p.city, p.province, p.active," +
            "  COUNT(DISTINCT tp.id) FILTER (WHERE tp.status NOT IN ('rejected','archived')) AS treatment_plans_count," +
            "  COUNT(DISTINCT tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled')) AS open_treatment_items_count," +
            "  COALESCE(SUM(e.total_amount) FILTER (WHERE e.status = 'accepted'), 0.00) AS accepted_estimates_amount" +
            " FROM " + schema + ".patients p" +
            " LEFT JOIN " + schema + ".treatment_plans tp ON tp.patient_id = p.id AND tp.clinic_id = p.clinic_id" +
            " LEFT JOIN " + schema + ".treatment_plan_items tpi ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = p.clinic_id" +
            " LEFT JOIN " + schema + ".estimates e ON e.patient_id = p.id AND e.clinic_id = p.clinic_id" +
            " GROUP BY p.id, p.clinic_id, p.first_name, p.last_name, p.fiscal_code_enc, p.fiscal_code_idx," +
            "          p.phone, p.email, p.city, p.province, p.active"
        );
    }

    private void rebuildPatientClinicalCardView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_clinical_card");
        boolean hasCatalogSeverity = tableExists(schema, "patient_anamnesis_item_selections")
                && tableExists(schema, "anamnesis_items");
        // Il ramo NULL::text (tenant senza catalogo/storico ancora convergente) è load-bearing, non decorativo:
        // mantiene valida la vista durante l'ordinamento di startup, prima che patchAnamnesisCatalog() giri.
        String catalogCol = hasCatalogSeverity
            ? ", mas.max_severity AS catalog_alert_severity"
            : ", NULL::text AS catalog_alert_severity";
        String catalogJoin = hasCatalogSeverity
            ? " LEFT JOIN " + schema + ".v_patient_max_anamnesis_severity mas" +
              "   ON mas.patient_id = p.id AND mas.clinic_id = p.clinic_id"
            : "";
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_patient_clinical_card AS " +
            "SELECT p.id AS patient_id, p.clinic_id," +
            "  p.first_name, p.last_name," +
            "  concat_ws(' ', p.last_name, p.first_name) AS full_name," +
            "  p.fiscal_code_enc, p.phone, p.email, p.city, p.province," +
            "  p.notes AS patient_notes, p.active," +
            "  pa.blood_type, pa.smoker, pa.hypertension, pa.diabetes, pa.heart_disease," +
            "  pa.taking_anticoagulants, pa.taking_bisphosphonates," +
            "  pa.allergy_penicillin, pa.allergy_latex, pa.allergy_anesthetic," +
            "  pa.current_medications, pa.other_allergies," +
            "  pa.general_notes AS anamnesis_notes," +
            "  pa.recorded_at AS anamnesis_date," +
            "  (SELECT COUNT(*) FROM " + schema + ".appointments a" +
            "   WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id) AS total_appointments" +
            catalogCol +
            " FROM " + schema + ".patients p" +
            " LEFT JOIN " + schema + ".patient_anamnesis pa" +
            "   ON pa.patient_id = p.id AND pa.clinic_id = p.clinic_id AND pa.is_current = true" +
            catalogJoin
        );
    }

    /** Vista di supporto: severita' massima (tra le voci attive del catalogo) per paziente. */
    private void rebuildPatientMaxAnamnesisSeverityView(String schema) {
        jdbc.execute("DROP VIEW IF EXISTS " + schema + ".v_patient_max_anamnesis_severity");
        if (!tableExists(schema, "patient_anamnesis_item_selections") || !tableExists(schema, "anamnesis_items")) {
            return;
        }
        jdbc.execute(
            "CREATE VIEW " + schema + ".v_patient_max_anamnesis_severity AS " +
            "SELECT s.clinic_id, s.patient_id," +
            "  MAX(CASE ai.severity WHEN 'severa' THEN 3 WHEN 'grave' THEN 2 ELSE 1 END) AS severity_rank," +
            "  (ARRAY['normale', 'grave', 'severa'])[MAX(CASE ai.severity" +
            "      WHEN 'severa' THEN 3 WHEN 'grave' THEN 2 ELSE 1 END)] AS max_severity" +
            " FROM " + schema + ".patient_anamnesis_item_selections s" +
            " JOIN " + schema + ".anamnesis_items ai ON ai.id = s.item_id" +
            " WHERE s.resolved_at IS NULL" +
            " GROUP BY s.clinic_id, s.patient_id"
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
            "  p.fiscal_code_enc AS patient_fiscal_code_enc," +
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
        // Set when the source document (RX) is deleted: the analysis is kept as AI provenance
        // but its image is gone. See PatientDocumentService.releaseAiArtifacts / 13-Audit-Trail.
        jdbc.execute("ALTER TABLE %1$s.patient_document_analyses ADD COLUMN IF NOT EXISTS document_deleted_at timestamptz".formatted(schema));
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
        jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_tooth_conditions_conflict ON %1$s.tooth_conditions (clinic_id, patient_id, tooth_fdi, surface)".formatted(schema));
    }

    /** Tabella override prompt AI per-studio (default globali in dentalcare.ai_prompts). */
    private void createAiPromptOverrides(String schema) {
        jdbc.execute(("""
            CREATE TABLE IF NOT EXISTS %1$s.ai_prompt_overrides (
                clinic_id uuid NOT NULL, prompt_key text NOT NULL, locale text NOT NULL,
                value text NOT NULL, updated_at timestamptz NOT NULL DEFAULT now(),
                PRIMARY KEY (clinic_id, prompt_key, locale))
            """).formatted(schema));
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

    // Seed del catalogo anamnesi (15 categorie / 87 voci), copia esatta di database/install.sql
    // (template create_tenant). Il token {schema} viene sostituito con lo schema tenant a runtime;
    // schema validato a monte (dentalcare.tenants / pattern ^t_[0-9a-f]{8}$), nessuna interpolazione utente.
    private static final String ANAMNESIS_CATEGORIES_SEED = """
        INSERT INTO {schema}.anamnesis_categories (code, name, sort_order) VALUES
            ('ALLERGIE', 'Allergie e Reazioni Avverse', 10),
            ('FARMACI', 'Farmaci e Terapie in Corso', 20),
            ('CARDIOVASCOLARE', 'Apparato Cardiovascolare', 30),
            ('RESPIRATORIO', 'Apparato Respiratorio', 40),
            ('ENDOCRINO', 'Apparato Endocrino-Metabolico', 50),
            ('RENALE_EPATICO', 'Apparato Renale ed Epatico', 60),
            ('GASTROINTESTINALE', 'Apparato Gastrointestinale', 70),
            ('NEUROLOGICO', 'Apparato Neurologico', 80),
            ('IMMUNO_ONCO_COAG', 'Immunologico, Oncologico e Coagulazione', 90),
            ('CHIRURGIA', 'Chirurgia Pregressa', 100),
            ('ABITUDINI', 'Abitudini di Vita e Parafunzioni', 110),
            ('FATTORI_RISCHIO', 'Fattori di Rischio Odontoiatrico', 120),
            ('COND_ORALI', 'Condizioni Croniche Odontoiatriche', 130),
            ('GRAVIDANZA', 'Gravidanza e Stato Ormonale', 140),
            ('PSICOLOGICO', 'Stato Psicologico e Comportamentale', 150)
        """;

    private static final String ANAMNESIS_ITEMS_SEED = """
        INSERT INTO {schema}.anamnesis_items (category_id, code, label, description, severity, sort_order) VALUES
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_PENICILLINA', 'Penicillina / Amoxicillina', 'Include tutte le betalattamine', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ANESTETICI', 'Anestetici locali', 'Articaina, mepivacaina, lidocaina', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_LATEX', 'Lattice', NULL, 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_FANS', 'Aspirina / FANS', NULL, 'grave', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_SULFAMIDICI', 'Sulfamidici', NULL, 'grave', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_SOLFITI', 'Solfiti', 'Metabisolfito, stabilizzante dell''anestetico con vasocostrittore — distinto dai sulfamidici', 'grave', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_CLOREXIDINA', 'Clorexidina', 'Uso quotidiano in collutori/gel — reazioni anafilattiche documentate', 'grave', 70),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ALTRI_ANTIBIOTICI', 'Altri antibiotici', 'Cefalosporine, clindamicina, macrolidi', 'grave', 80),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_BARBITURICI', 'Barbiturici / sedativi', 'Rilevante per sedazione cosciente', 'grave', 90),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_METALLI', 'Metalli', 'Nickel, oro, palladio, cromo-cobalto', 'normale', 100),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ACRILICI', 'Acrilici / resine', 'Metacrilato, protesi rimovibili', 'normale', 110),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_IODIO', 'Iodio / mezzi di contrasto', NULL, 'normale', 120),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTICOAGULANTI', 'Anticoagulanti orali', 'TAO, NAO (warfarin, dabigatran, rivaroxaban, apixaban)', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIAGGREGANTI', 'Antiaggreganti piastrinici', 'Aspirina, clopidogrel, ticagrelor', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_BISFOSFONATI', 'Bifosfonati', 'Alendronato, zoledronato — rischio MRONJ', 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_DENOSUMAB', 'Denosumab', 'Antiriassorbitivo anti-RANKL, stesso rischio MRONJ dei bifosfonati', 'grave', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIANGIOGENETICI', 'Antiangiogenetici', 'Bevacizumab e simili — rientrano nella definizione MRONJ', 'grave', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_CORTISONICI', 'Cortisonici sistemici', NULL, 'grave', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_IMMUNOSOPPRESSORI', 'Immunosoppressori', 'Ciclosporina, azatioprina, metotrexato', 'grave', 70),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIDIABETICI', 'Antidiabetici orali / insulina', NULL, 'grave', 80),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIIPERTENSIVI', 'Antiipertensivi', 'Interazione con vasocostrittore in anestesia locale', 'grave', 90),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_GENGIVOIPERPLASTICI', 'Farmaci con rischio iperplasia gengivale', 'Fenitoina, ciclosporina, nifedipina', 'normale', 100),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_XEROSTOMIZZANTI', 'Farmaci xerostomizzanti', 'Antidepressivi, antistaminici, diuretici', 'normale', 110),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ALTRI', 'Altra terapia farmacologica in corso', NULL, 'normale', 120),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_ENDOCARDITE', 'Endocardite infettiva pregressa', 'Massimo rischio, profilassi antibiotica obbligatoria (ESC 2023)', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_VALVOLARE', 'Protesi valvolare cardiaca', 'Profilassi antibiotica obbligatoria (ESC 2023 Classe I)', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_CONGENITA', 'Cardiopatia congenita', 'Non corretta o corretta con residui — profilassi obbligatoria', 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_PACEMAKER', 'Pacemaker / defibrillatore (ICD)', 'Non richiede profilassi endocardite, ma interferenza con elettrobisturi', 'grave', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_FIBRILLAZIONE', 'Fibrillazione atriale', 'Gestione anticoagulanti/rischio emostatico', 'grave', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_INFARTO', 'Infarto pregresso', NULL, 'grave', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_ANGINA', 'Angina pectoris', NULL, 'grave', 70),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_SCOMPENSO', 'Scompenso cardiaco', 'Insufficienza cardiaca congestizia', 'grave', 80),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_BYPASS', 'Bypass / angioplastica coronarica', 'Gestione antiaggreganti/sanguinamento — non indicazione a profilassi endocardite', 'grave', 90),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_IPERTENSIONE', 'Ipertensione arteriosa', NULL, 'normale', 100),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_ASMA', 'Asma bronchiale', NULL, 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_BPCO', 'BPCO', 'Broncopneumopatia cronica ostruttiva', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_APNEE', 'Apnee notturne', 'OSAS, rilevante per sedazione/postura', 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE1', 'Diabete tipo 1', 'Insulino-dipendente', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE2', 'Diabete tipo 2', 'Non insulino-dipendente', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE_NS', 'Diabete non specificato', 'Per triage rapido quando il tipo non è noto', 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_IPOTIROIDISMO', 'Ipotiroidismo', NULL, 'normale', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_IPERTIROIDISMO', 'Ipertiroidismo', 'Morbo di Basedow o adenoma tossico', 'grave', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_CUSHING', 'Sindrome di Cushing', 'Ipercortisolismo endogeno o iatrogeno', 'grave', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_OSTEOPOROSI', 'Osteoporosi', 'Il rischio MRONJ è tracciato separatamente sui farmaci (FAR_BISFOSFONATI/FAR_DENOSUMAB)', 'normale', 70),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'REN_INSUFFICIENZA', 'Insufficienza renale cronica', 'IRC o dialisi', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'EPA_EPATITE', 'Epatite B/C', 'Epatite virale cronica', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'EPA_CIRROSI', 'Cirrosi epatica', 'Rischio coagulativo differente dall''epatite semplice', 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_REFLUSSO', 'Reflusso gastroesofageo', NULL, 'normale', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_ULCERA', 'Ulcera peptica', 'Controindicazione relativa ai FANS', 'normale', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_CROHN', 'Morbo di Crohn', NULL, 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_EPILESSIA', 'Epilessia', NULL, 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_PARKINSON', 'Malattia di Parkinson', 'Gestione poltrona, tempi di trattamento, tremore', 'normale', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_SCLEROSI', 'Sclerosi multipla', NULL, 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_HIV', 'HIV / immunodeficienza', 'Alert per gestione clinica (farmaci, lesioni orali) — NON usare per vincoli di scheduling: le precauzioni universali si applicano a ogni paziente indipendentemente dallo stato noto', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_ONCOLOGICA', 'Patologia oncologica in trattamento', 'Chemioterapia o radioterapia in corso', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_COAGULOPATIA', 'Disturbi della coagulazione', 'Voce generica — vedi anche emofilia/trombocitopenia per casi specifici', 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_EMOFILIA', 'Emofilia', NULL, 'grave', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_TROMBOCITOPENIA', 'Trombocitopenia', NULL, 'grave', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_RADIOTERAPIA_TESTA_COLLO', 'Radioterapia testa-collo pregressa', 'Rischio osteoradionecrosi, analogo a MRONJ', 'grave', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_PROTESI_ARTICOLARI', 'Protesi articolari', 'Anca, ginocchio — dal 2024 AAOS allineato ADA: profilassi routinaria NON raccomandata nella maggioranza dei casi, valutazione caso per caso', 'normale', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_TRAPIANTO', 'Trapianto d''organo', 'Immunosoppressione, rischio infettivo', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_SPLENECTOMIA', 'Splenectomia / asplenia', 'Rischio infettivo (sepsi post-splenectomia) in procedure invasive', 'grave', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_ALTRO', 'Altri interventi chirurgici', NULL, 'normale', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_FUMATORE_ATTIVO', 'Fumatore attivo', 'Impatto su guarigione post-chirurgica e osteointegrazione implantare', 'normale', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_EX_FUMATORE', 'Ex fumatore', 'Rischio parodontale/oncologico residuo', 'normale', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_VAPING', 'Sigaretta elettronica / vaping', 'Xerostomia, infiammazione gengivale — voce distinta dal fumo tradizionale (ADA)', 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_ALCOL', 'Consumo regolare di alcolici', 'Più di 2 unità/giorno', 'normale', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_DROGHE', 'Uso di sostanze', 'Interazione con vasocostrittori/anestesia', 'grave', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_BRUXISMO', 'Bruxismo / digrignamento', NULL, 'normale', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_ONICOFAGIA', 'Onicofagia / morsicatura labbra', NULL, 'normale', 70),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_PIERCING', 'Piercing orale', NULL, 'normale', 80),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'FATTORI_RISCHIO'), 'FTR_SPORT_AGONISTICO', 'Sportivo agonista', 'Rischio trauma dento-alveolare, indicazione a paradenti/bite — non è un''abitudine di vita', 'normale', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_SENSIBILITA', 'Sensibilità dentinale', NULL, 'normale', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_SANGUINAMENTO', 'Sanguinamento gengivale', NULL, 'normale', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_MOBILITA', 'Mobilità dentale', NULL, 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_ALITOSI', 'Alitosi cronica', NULL, 'normale', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_ATM', 'Problemi ATM / dolore masticatorio', NULL, 'normale', 50),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_XEROSTOMIA', 'Secchezza orale', 'Xerostomia', 'normale', 60),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_AFTE', 'Afte ricorrenti', NULL, 'normale', 70),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_GRAVIDANZA', 'Gravidanza in corso', 'Indicare il trimestre nelle note', 'grave', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_ALLATTAMENTO', 'Allattamento', NULL, 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_ORMONI', 'Terapia ormonale', 'Pillola, HRT', 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_ANSIA_STUDIO', 'Ansia da studio dentistico', NULL, 'normale', 10),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_FOBIA_AGHI', 'Fobia degli aghi', 'Belonefobia — impatta somministrazione anestesia', 'grave', 20),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_GAG_REFLEX', 'Riflesso del vomito accentuato', 'Difficoltà a tenere la bocca aperta a lungo', 'normale', 30),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_SEDAZIONE_PREGRESSA', 'Sedazione cosciente pregressa', NULL, 'normale', 40),
            ((SELECT id FROM {schema}.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_ESPERIENZE_TRAUMATICHE', 'Esperienze odontoiatriche traumatiche pregresse', NULL, 'normale', 50)
        """;
}
