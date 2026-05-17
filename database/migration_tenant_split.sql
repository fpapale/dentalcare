-- =============================================================================
-- DentalCare - Tenant Schema Split Migration
-- Goal: split dentalcare schema into applicative (dentalcare) + tenant (t_9d754153)
-- Demo clinic UUID: 9d754153-6579-4b7e-a56b-025f00299cd9
-- Idempotent - safe to run multiple times
-- =============================================================================

BEGIN;

SET search_path TO dentalcare, public;

-- =============================================================================
-- PART 1: Applicative tables in dentalcare
-- =============================================================================

CREATE TABLE IF NOT EXISTS dentalcare.tenants (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    schema_name     text NOT NULL UNIQUE,
    email           text,
    phone           text,
    plan            text NOT NULL DEFAULT 'base',
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dentalcare.tenant_clinics (
    clinic_id   uuid PRIMARY KEY,
    tenant_id   uuid NOT NULL REFERENCES dentalcare.tenants(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Seed demo tenant
INSERT INTO dentalcare.tenants (id, name, schema_name, email, plan)
VALUES (
    'a0000001-0000-0000-0000-000000000001'::uuid,
    'Studio Demo DentalCare',
    't_9d754153',
    'demo@dentalcare.it',
    'professional'
)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- PART 2: Create tenant schema
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS t_9d754153;

-- =============================================================================
-- PART 3: Drop views in dentalcare (reference tables that will be moved)
--         Must happen BEFORE moving tables, otherwise ALTER TABLE SET SCHEMA
--         will fail due to dependent view objects.
-- =============================================================================

DROP VIEW IF EXISTS dentalcare.v_patient_estimates_summary CASCADE;
DROP VIEW IF EXISTS dentalcare.v_patient_dashboard CASCADE;
DROP VIEW IF EXISTS dentalcare.v_patient_clinical_card CASCADE;
DROP VIEW IF EXISTS dentalcare.v_agenda_daily CASCADE;
DROP VIEW IF EXISTS dentalcare.v_treatment_plan_summary CASCADE;
DROP VIEW IF EXISTS dentalcare.v_patient_estimates CASCADE;
DROP VIEW IF EXISTS dentalcare.product_stock_v CASCADE;
DROP VIEW IF EXISTS dentalcare.v_agenda_week CASCADE;
DROP VIEW IF EXISTS dentalcare.v_appointment_slots CASCADE;
DROP VIEW IF EXISTS dentalcare.v_patient_treatment_plans CASCADE;
DROP VIEW IF EXISTS dentalcare.v_treatment_plan_items_detail CASCADE;
DROP VIEW IF EXISTS dentalcare.v_estimate_lines_detail CASCADE;
DROP VIEW IF EXISTS dentalcare.v_provider_workload CASCADE;
DROP VIEW IF EXISTS dentalcare.v_service_catalog_usage CASCADE;
DROP VIEW IF EXISTS dentalcare.v_clinic_dashboard CASCADE;
DROP VIEW IF EXISTS dentalcare.v_treatment_items_odontogram CASCADE;

-- =============================================================================
-- PART 4: Move operational tables - Round 1 (no FK dependencies on moved tables)
-- =============================================================================

-- clinics
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'clinics') THEN
    ALTER TABLE dentalcare.clinics SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 2: FK to clinics
-- =============================================================================

-- patients
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'patients') THEN
    ALTER TABLE dentalcare.patients SET SCHEMA t_9d754153;
  END IF;
END $$;

-- providers
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'providers') THEN
    ALTER TABLE dentalcare.providers SET SCHEMA t_9d754153;
  END IF;
END $$;

-- service_catalog
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'service_catalog') THEN
    ALTER TABLE dentalcare.service_catalog SET SCHEMA t_9d754153;
  END IF;
END $$;

-- appointments
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'appointments') THEN
    ALTER TABLE dentalcare.appointments SET SCHEMA t_9d754153;
  END IF;
END $$;

-- suppliers
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'suppliers') THEN
    ALTER TABLE dentalcare.suppliers SET SCHEMA t_9d754153;
  END IF;
END $$;

-- product_categories
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'product_categories') THEN
    ALTER TABLE dentalcare.product_categories SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 3: FK to patients/providers/service_catalog
-- =============================================================================

-- treatment_plans
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'treatment_plans') THEN
    ALTER TABLE dentalcare.treatment_plans SET SCHEMA t_9d754153;
  END IF;
END $$;

-- patient_recalls
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'patient_recalls') THEN
    ALTER TABLE dentalcare.patient_recalls SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 4: FK to treatment_plans
-- =============================================================================

-- treatment_plan_items
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'treatment_plan_items') THEN
    ALTER TABLE dentalcare.treatment_plan_items SET SCHEMA t_9d754153;
  END IF;
END $$;

-- estimates
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'estimates') THEN
    ALTER TABLE dentalcare.estimates SET SCHEMA t_9d754153;
  END IF;
END $$;

-- invoices
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'invoices') THEN
    ALTER TABLE dentalcare.invoices SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 5: FK to estimates/treatment_plan_items
-- =============================================================================

-- estimate_lines
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'estimate_lines') THEN
    ALTER TABLE dentalcare.estimate_lines SET SCHEMA t_9d754153;
  END IF;
END $$;

-- invoice_items
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'invoice_items') THEN
    ALTER TABLE dentalcare.invoice_items SET SCHEMA t_9d754153;
  END IF;
END $$;

-- recall_contacts
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'recall_contacts') THEN
    ALTER TABLE dentalcare.recall_contacts SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 6: FK to products
-- =============================================================================

-- products
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'products') THEN
    ALTER TABLE dentalcare.products SET SCHEMA t_9d754153;
  END IF;
END $$;

-- stock_movements
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'stock_movements') THEN
    ALTER TABLE dentalcare.stock_movements SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 7: Other clinical tables (FK to patients/providers - after they moved)
-- =============================================================================

-- patient_anamnesis
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'patient_anamnesis') THEN
    ALTER TABLE dentalcare.patient_anamnesis SET SCHEMA t_9d754153;
  END IF;
END $$;

-- patient_anamnesis_item_selections
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'patient_anamnesis_item_selections') THEN
    ALTER TABLE dentalcare.patient_anamnesis_item_selections SET SCHEMA t_9d754153;
  END IF;
END $$;

-- odontogram_teeth
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'odontogram_teeth') THEN
    ALTER TABLE dentalcare.odontogram_teeth SET SCHEMA t_9d754153;
  END IF;
END $$;

-- clinical_history_entries
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'clinical_history_entries') THEN
    ALTER TABLE dentalcare.clinical_history_entries SET SCHEMA t_9d754153;
  END IF;
END $$;

-- patient_documents
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'patient_documents') THEN
    ALTER TABLE dentalcare.patient_documents SET SCHEMA t_9d754153;
  END IF;
END $$;

-- service_bundle_items
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'service_bundle_items') THEN
    ALTER TABLE dentalcare.service_bundle_items SET SCHEMA t_9d754153;
  END IF;
END $$;

-- condition_service_defaults
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'condition_service_defaults') THEN
    ALTER TABLE dentalcare.condition_service_defaults SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- Round 8: Optional tables (IF EXISTS guard)
-- =============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'tooth_conditions') THEN
    ALTER TABLE dentalcare.tooth_conditions SET SCHEMA t_9d754153;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'tooth_records') THEN
    ALTER TABLE dentalcare.tooth_records SET SCHEMA t_9d754153;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'clinical_records') THEN
    ALTER TABLE dentalcare.clinical_records SET SCHEMA t_9d754153;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'odontogram_records') THEN
    ALTER TABLE dentalcare.odontogram_records SET SCHEMA t_9d754153;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'patient_allergy') THEN
    ALTER TABLE dentalcare.patient_allergy SET SCHEMA t_9d754153;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'geo_holidays') THEN
    ALTER TABLE dentalcare.geo_holidays SET SCHEMA t_9d754153;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'dentalcare' AND tablename = 'service_bundles') THEN
    ALTER TABLE dentalcare.service_bundles SET SCHEMA t_9d754153;
  END IF;
END $$;

-- =============================================================================
-- PART 5: Seed tenant_clinics from moved clinics table
-- =============================================================================

INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id)
SELECT c.id, t.id
FROM t_9d754153.clinics c
CROSS JOIN dentalcare.tenants t
WHERE t.schema_name = 't_9d754153'
ON CONFLICT DO NOTHING;

-- =============================================================================
-- PART 6: Recreate views in t_9d754153 schema
-- =============================================================================

-- ----------------------------------------------------------------------------
-- v_patient_dashboard
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW t_9d754153.v_patient_dashboard AS
SELECT
    c.id AS clinic_id,
    p.id AS patient_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code,
    p.birth_date,
    EXTRACT(YEAR FROM age(p.birth_date))::integer AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.notes AS patient_notes,
    (SELECT SUM(e.total_amount)
     FROM t_9d754153.estimates e
     WHERE e.patient_id = p.id
       AND e.clinic_id = p.clinic_id
       AND e.status = 'accepted') AS accepted_estimates_amount,
    (SELECT COUNT(*)
     FROM t_9d754153.treatment_plans tp
     WHERE tp.patient_id = p.id
       AND tp.clinic_id = p.clinic_id) AS treatment_plans_count,
    (SELECT COUNT(*)
     FROM t_9d754153.treatment_plan_items tpi
     JOIN t_9d754153.treatment_plans tp2 ON tp2.id = tpi.treatment_plan_id
     WHERE tp2.patient_id = p.id
       AND tpi.clinic_id = p.clinic_id
       AND tpi.status IN ('planned', 'accepted', 'scheduled')) AS open_treatment_items_count
FROM t_9d754153.clinics c
JOIN t_9d754153.patients p ON p.clinic_id = c.id;

-- ----------------------------------------------------------------------------
-- v_patient_clinical_card
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW t_9d754153.v_patient_clinical_card AS
SELECT
    c.id AS clinic_id,
    p.id AS patient_id,
    p.first_name,
    p.last_name,
    concat_ws(' ', p.last_name, p.first_name) AS full_name,
    p.fiscal_code,
    p.birth_date,
    EXTRACT(YEAR FROM age(p.birth_date))::integer AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.notes AS patient_notes,
    p.blood_type,
    p.smoker,
    p.hypertension,
    p.diabetes,
    p.heart_disease,
    p.taking_anticoagulants,
    p.taking_bisphosphonates,
    p.allergy_penicillin,
    p.allergy_latex,
    p.allergy_anesthetic,
    p.other_allergies,
    p.anamnesis_notes,
    p.anamnesis_date,
    (SELECT COUNT(*)
     FROM t_9d754153.appointments a
     WHERE a.patient_id = p.id
       AND a.clinic_id = p.clinic_id) AS total_appointments
FROM t_9d754153.clinics c
JOIN t_9d754153.patients p ON p.clinic_id = c.id;

-- ----------------------------------------------------------------------------
-- product_stock_v
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW t_9d754153.product_stock_v AS
SELECT
    p.id AS product_id,
    p.clinic_id,
    p.name,
    p.sku,
    p.unit,
    p.min_stock_quantity,
    p.reorder_quantity,
    p.unit_cost,
    p.description,
    p.active,
    p.category_id,
    pc.name AS category_name,
    s.name AS supplier_name,
    p.supplier_id,
    COALESCE(SUM(
        CASE
            WHEN sm.movement_type IN ('carico', 'rientro') THEN sm.quantity
            WHEN sm.movement_type IN ('scarico')           THEN -sm.quantity
            WHEN sm.movement_type = 'rettifica'            THEN sm.quantity
            ELSE 0
        END
    ), 0) AS current_stock,
    CASE
        WHEN COALESCE(SUM(
            CASE
                WHEN sm.movement_type IN ('carico', 'rientro') THEN sm.quantity
                WHEN sm.movement_type IN ('scarico')           THEN -sm.quantity
                WHEN sm.movement_type = 'rettifica'            THEN sm.quantity
                ELSE 0
            END
        ), 0) = 0 THEN 'critico'
        WHEN COALESCE(SUM(
            CASE
                WHEN sm.movement_type IN ('carico', 'rientro') THEN sm.quantity
                WHEN sm.movement_type IN ('scarico')           THEN -sm.quantity
                WHEN sm.movement_type = 'rettifica'            THEN sm.quantity
                ELSE 0
            END
        ), 0) <= p.min_stock_quantity THEN 'basso'
        ELSE 'ok'
    END AS stock_status
FROM t_9d754153.products p
LEFT JOIN t_9d754153.product_categories pc
       ON pc.id = p.category_id AND pc.clinic_id = p.clinic_id
LEFT JOIN t_9d754153.suppliers s
       ON s.id = p.supplier_id AND s.clinic_id = p.clinic_id
LEFT JOIN t_9d754153.stock_movements sm
       ON sm.product_id = p.id AND sm.clinic_id = p.clinic_id
GROUP BY
    p.id, p.clinic_id, p.name, p.sku, p.unit, p.min_stock_quantity,
    p.reorder_quantity, p.unit_cost, p.description, p.active, p.category_id,
    pc.name, s.name, p.supplier_id;

-- ----------------------------------------------------------------------------
-- v_agenda_daily
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW t_9d754153.v_agenda_daily AS
SELECT
    a.id AS appointment_id,
    a.clinic_id,
    a.starts_at,
    a.ends_at,
    a.chair_label,
    a.status AS appointment_status,
    a.notes,
    a.patient_id,
    concat_ws(' ', pat.last_name, pat.first_name) AS patient_full_name,
    pat.phone AS patient_phone,
    a.provider_id,
    concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
    prov.role::text AS provider_role,
    sc.name AS service_name,
    sc.category AS service_category,
    a.tooth_number,
    (pat.allergy_penicillin OR pat.allergy_latex OR pat.allergy_anesthetic
     OR pat.other_allergies IS NOT NULL) AS has_allergy_alert,
    (pat.taking_anticoagulants OR pat.taking_bisphosphonates) AS has_medication_alert
FROM t_9d754153.appointments a
JOIN t_9d754153.patients pat
     ON pat.id = a.patient_id AND pat.clinic_id = a.clinic_id
JOIN t_9d754153.providers prov
     ON prov.id = a.provider_id AND prov.clinic_id = a.clinic_id
LEFT JOIN t_9d754153.service_catalog sc
     ON sc.id = a.service_id AND sc.clinic_id = a.clinic_id;

-- ----------------------------------------------------------------------------
-- v_patient_estimates_summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW t_9d754153.v_patient_estimates_summary AS
WITH line_agg AS (
    SELECT clinic_id, estimate_id, COUNT(*) AS estimate_lines_count
    FROM t_9d754153.estimate_lines
    GROUP BY clinic_id, estimate_id
)
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    p.id AS patient_id,
    p.last_name AS patient_last_name,
    p.first_name AS patient_first_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code AS patient_fiscal_code,
    p.phone AS patient_phone,
    p.email AS patient_email,
    e.id AS estimate_id,
    e.estimate_number,
    e.version,
    e.status AS estimate_status,
    e.title AS estimate_title,
    e.currency,
    e.subtotal_amount,
    e.discount_amount,
    e.taxable_amount,
    e.vat_amount,
    e.total_amount,
    e.total_amount AS total_net,
    e.issued_at,
    e.sent_at,
    e.valid_until,
    e.accepted_at,
    e.rejected_at,
    e.created_at AS estimate_created_at,
    e.updated_at AS estimate_updated_at,
    tp.id AS treatment_plan_id,
    tp.name AS treatment_plan_name,
    tp.status AS treatment_plan_status,
    COALESCE(la.estimate_lines_count, 0) AS estimate_lines_count,
    CASE
        WHEN e.valid_until IS NULL THEN false
        WHEN e.status IN ('accepted', 'rejected', 'cancelled') THEN false
        WHEN e.valid_until < current_date THEN true
        ELSE false
    END AS is_expired_by_date,
    CASE
        WHEN e.valid_until IS NULL THEN NULL
        ELSE e.valid_until - current_date
    END AS days_to_expiry,
    e.created_by_provider_id
FROM t_9d754153.clinics c
JOIN t_9d754153.patients p ON p.clinic_id = c.id
JOIN t_9d754153.estimates e ON e.patient_id = p.id AND e.clinic_id = p.clinic_id
LEFT JOIN t_9d754153.treatment_plans tp
       ON tp.id = e.treatment_plan_id AND tp.clinic_id = e.clinic_id
LEFT JOIN line_agg la ON la.estimate_id = e.id AND la.clinic_id = e.clinic_id;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT
    'tenants'        AS check_item,
    COUNT(*)::text   AS result
FROM dentalcare.tenants
UNION ALL
SELECT
    'tenant_clinics',
    COUNT(*)::text
FROM dentalcare.tenant_clinics
UNION ALL
SELECT
    't_9d754153 tables',
    COUNT(*)::text
FROM pg_tables
WHERE schemaname = 't_9d754153'
UNION ALL
SELECT
    'dentalcare remaining operational tables',
    COUNT(*)::text
FROM pg_tables
WHERE schemaname = 'dentalcare'
  AND tablename NOT IN ('tenants', 'tenant_clinics', 'anamnesis_categories', 'anamnesis_items');

COMMIT;
