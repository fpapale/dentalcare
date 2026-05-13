-- DentalCare PostgreSQL views
-- Modello: Piano di cura clinico principale + Preventivo come snapshot economico/versionato
-- Uso consigliato:
--   psql -d dentalcare -f dentalcare_views.sql

BEGIN;

CREATE SCHEMA IF NOT EXISTS dentalcare;
SET search_path TO dentalcare, public;

-- =========================================================
-- Pulizia viste esistenti
-- =========================================================

DROP VIEW IF EXISTS v_clinic_dashboard CASCADE;
DROP VIEW IF EXISTS v_patient_dashboard CASCADE;
DROP VIEW IF EXISTS v_patient_treatment_plans CASCADE;
DROP VIEW IF EXISTS v_patient_estimates_summary CASCADE;
DROP VIEW IF EXISTS v_treatment_plan_items_detail CASCADE;
DROP VIEW IF EXISTS v_estimate_lines_detail CASCADE;
DROP VIEW IF EXISTS v_provider_workload CASCADE;
DROP VIEW IF EXISTS v_service_catalog_usage CASCADE;
DROP VIEW IF EXISTS v_treatment_plan_summary CASCADE;
DROP VIEW IF EXISTS v_patient_estimates CASCADE;

-- =========================================================
-- 1. Riepilogo piani di cura per paziente
--    Utile per schermata clinica del paziente e lista piani.
-- =========================================================

CREATE OR REPLACE VIEW v_patient_treatment_plans AS
WITH item_agg AS (
    SELECT
        clinic_id,
        treatment_plan_id,
        COUNT(*) AS treatment_items_count,
        COUNT(*) FILTER (WHERE status = 'planned') AS planned_items_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_items_count,
        COUNT(*) FILTER (WHERE status = 'scheduled') AS scheduled_items_count,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_items_count,
        COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_items_count,
        COALESCE(round(SUM(quantity * planned_price), 2), 0) AS planned_total_amount,
        COALESCE(round(SUM(quantity * planned_price) FILTER (WHERE status <> 'cancelled'), 2), 0) AS active_planned_total_amount,
        COALESCE(round(SUM(quantity * planned_price) FILTER (WHERE status = 'completed'), 2), 0) AS completed_total_amount
    FROM treatment_plan_items
    GROUP BY clinic_id, treatment_plan_id
), estimate_agg AS (
    SELECT
        clinic_id,
        treatment_plan_id,
        COUNT(*) AS estimates_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_estimates_count,
        COALESCE(round(SUM(total_amount) FILTER (WHERE status = 'accepted'), 2), 0) AS accepted_estimates_total_amount
    FROM estimates
    WHERE treatment_plan_id IS NOT NULL
    GROUP BY clinic_id, treatment_plan_id
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

    tp.id AS treatment_plan_id,
    tp.name AS treatment_plan_name,
    tp.description AS treatment_plan_description,
    tp.status AS treatment_plan_status,
    tp.proposed_at,
    tp.accepted_at,
    tp.completed_at,
    tp.rejected_at,
    tp.created_at AS treatment_plan_created_at,
    tp.updated_at AS treatment_plan_updated_at,

    concat_ws(' ', pr.last_name, pr.first_name) AS created_by_provider_name,
    pr.role AS created_by_provider_role,

    COALESCE(ia.treatment_items_count, 0) AS treatment_items_count,
    COALESCE(ia.planned_items_count, 0) AS planned_items_count,
    COALESCE(ia.accepted_items_count, 0) AS accepted_items_count,
    COALESCE(ia.scheduled_items_count, 0) AS scheduled_items_count,
    COALESCE(ia.completed_items_count, 0) AS completed_items_count,
    COALESCE(ia.cancelled_items_count, 0) AS cancelled_items_count,
    COALESCE(ia.planned_total_amount, 0) AS planned_total_amount,
    COALESCE(ia.active_planned_total_amount, 0) AS active_planned_total_amount,
    COALESCE(ia.completed_total_amount, 0) AS completed_total_amount,

    COALESCE(ea.estimates_count, 0) AS estimates_count,
    COALESCE(ea.accepted_estimates_count, 0) AS accepted_estimates_count,
    COALESCE(ea.accepted_estimates_total_amount, 0) AS accepted_estimates_total_amount
FROM clinics c
JOIN patients p
  ON p.clinic_id = c.id
JOIN treatment_plans tp
  ON tp.patient_id = p.id
 AND tp.clinic_id = p.clinic_id
LEFT JOIN providers pr
  ON pr.id = tp.created_by_provider_id
 AND pr.clinic_id = tp.clinic_id
LEFT JOIN item_agg ia
  ON ia.treatment_plan_id = tp.id
 AND ia.clinic_id = tp.clinic_id
LEFT JOIN estimate_agg ea
  ON ea.treatment_plan_id = tp.id
 AND ea.clinic_id = tp.clinic_id;

-- Compatibilità con la vista già presente nello schema base.
CREATE OR REPLACE VIEW v_treatment_plan_summary AS
SELECT
    treatment_plan_id,
    clinic_id,
    patient_id,
    treatment_plan_name AS name,
    treatment_plan_status AS status,
    treatment_items_count AS items_count,
    completed_items_count,
    planned_total_amount,
    treatment_plan_created_at AS created_at,
    treatment_plan_updated_at AS updated_at
FROM v_patient_treatment_plans;

-- =========================================================
-- 2. Riepilogo preventivi per paziente
--    Utile per lista preventivi, stato commerciale e scadenze.
-- =========================================================

CREATE OR REPLACE VIEW v_patient_estimates_summary AS
WITH line_agg AS (
    SELECT
        clinic_id,
        estimate_id,
        COUNT(*) AS estimate_lines_count
    FROM estimate_lines
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
    END AS days_to_expiry
FROM clinics c
JOIN patients p
  ON p.clinic_id = c.id
JOIN estimates e
  ON e.patient_id = p.id
 AND e.clinic_id = p.clinic_id
LEFT JOIN treatment_plans tp
  ON tp.id = e.treatment_plan_id
 AND tp.clinic_id = e.clinic_id
LEFT JOIN line_agg la
  ON la.estimate_id = e.id
 AND la.clinic_id = e.clinic_id;

-- Compatibilità con la vista già presente nello schema base.
CREATE OR REPLACE VIEW v_patient_estimates AS
SELECT
    estimate_id,
    clinic_id,
    patient_id,
    patient_last_name AS last_name,
    patient_first_name AS first_name,
    treatment_plan_id,
    estimate_number,
    version,
    estimate_status AS status,
    currency,
    subtotal_amount,
    discount_amount,
    taxable_amount,
    vat_amount,
    total_amount,
    valid_until,
    estimate_created_at AS created_at,
    estimate_updated_at AS updated_at
FROM v_patient_estimates_summary;

-- =========================================================
-- 3. Dettaglio trattamenti pianificati
--    Utile per odontogramma, piano clinico e pianificazione agenda.
-- =========================================================

CREATE OR REPLACE VIEW v_treatment_plan_items_detail AS
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    p.id AS patient_id,
    p.last_name AS patient_last_name,
    p.first_name AS patient_first_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,

    tp.id AS treatment_plan_id,
    tp.name AS treatment_plan_name,
    tp.status AS treatment_plan_status,

    tpi.id AS treatment_plan_item_id,
    tpi.status AS item_status,
    tpi.priority,
    tpi.planned_date,
    tpi.completed_at,
    tpi.tooth_number,
    tpi.quadrant,
    tpi.surfaces,
    array_to_string(tpi.surfaces, ',') AS surfaces_text,
    tpi.quantity,
    tpi.planned_price,
    tpi.planned_vat_rate,
    round(tpi.quantity * tpi.planned_price, 2) AS planned_line_subtotal,
    round((tpi.quantity * tpi.planned_price) * tpi.planned_vat_rate / 100, 2) AS planned_line_vat_amount,
    round((tpi.quantity * tpi.planned_price) * (1 + tpi.planned_vat_rate / 100), 2) AS planned_line_total,
    tpi.clinical_notes,

    sc.id AS service_id,
    sc.code AS service_code,
    sc.name AS service_name,
    sc.category AS service_category,
    sc.default_price AS service_default_price,

    prov.id AS provider_id,
    concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
    prov.role AS provider_role,

    tpi.created_at AS item_created_at,
    tpi.updated_at AS item_updated_at
FROM treatment_plan_items tpi
JOIN treatment_plans tp
  ON tp.id = tpi.treatment_plan_id
 AND tp.clinic_id = tpi.clinic_id
JOIN patients p
  ON p.id = tp.patient_id
 AND p.clinic_id = tp.clinic_id
JOIN clinics c
  ON c.id = tpi.clinic_id
JOIN service_catalog sc
  ON sc.id = tpi.service_id
 AND sc.clinic_id = tpi.clinic_id
LEFT JOIN providers prov
  ON prov.id = tpi.provider_id
 AND prov.clinic_id = tpi.clinic_id;

-- =========================================================
-- 4. Dettaglio righe preventivo
--    Utile per stampa preventivo, confronto prezzo listino/snapshot e audit.
-- =========================================================

CREATE OR REPLACE VIEW v_estimate_lines_detail AS
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    p.id AS patient_id,
    p.last_name AS patient_last_name,
    p.first_name AS patient_first_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,

    e.id AS estimate_id,
    e.estimate_number,
    e.version,
    e.status AS estimate_status,
    e.title AS estimate_title,
    e.currency,
    e.valid_until,
    e.total_amount AS estimate_total_amount,

    tp.id AS treatment_plan_id,
    tp.name AS treatment_plan_name,

    el.id AS estimate_line_id,
    el.line_position,
    el.description_snapshot,
    el.tooth_snapshot,
    el.quantity,
    el.unit_price,
    el.discount_amount,
    el.vat_rate,
    el.line_subtotal,
    el.line_taxable,
    el.line_vat_amount,
    el.line_total,

    sc.id AS service_id,
    sc.code AS service_code,
    sc.name AS service_name,
    sc.category AS service_category,
    sc.default_price AS service_default_price,

    tpi.id AS treatment_plan_item_id,
    tpi.status AS treatment_item_status,
    tpi.tooth_number AS current_tooth_number,
    tpi.planned_price AS current_planned_price,
    tpi.planned_vat_rate AS current_planned_vat_rate,

    CASE
        WHEN tpi.id IS NULL THEN false
        WHEN el.unit_price <> tpi.planned_price THEN true
        WHEN COALESCE(el.tooth_snapshot, '') <> COALESCE(tpi.tooth_number, '') THEN true
        ELSE false
    END AS differs_from_current_plan_item,

    el.created_at AS line_created_at,
    el.updated_at AS line_updated_at
FROM estimate_lines el
JOIN estimates e
  ON e.id = el.estimate_id
 AND e.clinic_id = el.clinic_id
JOIN patients p
  ON p.id = e.patient_id
 AND p.clinic_id = e.clinic_id
JOIN clinics c
  ON c.id = el.clinic_id
LEFT JOIN treatment_plans tp
  ON tp.id = e.treatment_plan_id
 AND tp.clinic_id = e.clinic_id
LEFT JOIN service_catalog sc
  ON sc.id = el.service_id
 AND sc.clinic_id = el.clinic_id
LEFT JOIN treatment_plan_items tpi
  ON tpi.id = el.treatment_plan_item_id
 AND tpi.clinic_id = el.clinic_id;

-- =========================================================
-- 5. Dashboard paziente
--    Utile per scheda paziente: situazione clinica + economica sintetica.
-- =========================================================

CREATE OR REPLACE VIEW v_patient_dashboard AS
WITH plan_agg AS (
    SELECT
        clinic_id,
        patient_id,
        COUNT(*) AS treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'draft') AS draft_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'proposed') AS proposed_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_treatment_plans_count,
        MAX(updated_at) AS last_treatment_plan_updated_at
    FROM treatment_plans
    GROUP BY clinic_id, patient_id
), item_agg AS (
    SELECT
        tp.clinic_id,
        tp.patient_id,
        COUNT(tpi.id) AS treatment_items_count,
        COUNT(tpi.id) FILTER (WHERE tpi.status = 'completed') AS completed_treatment_items_count,
        COUNT(tpi.id) FILTER (WHERE tpi.status IN ('planned', 'accepted', 'scheduled')) AS open_treatment_items_count,
        COALESCE(round(SUM(tpi.quantity * tpi.planned_price) FILTER (WHERE tpi.status <> 'cancelled'), 2), 0) AS planned_clinical_amount,
        COALESCE(round(SUM(tpi.quantity * tpi.planned_price) FILTER (WHERE tpi.status = 'completed'), 2), 0) AS completed_clinical_amount
    FROM treatment_plans tp
    LEFT JOIN treatment_plan_items tpi
      ON tpi.treatment_plan_id = tp.id
     AND tpi.clinic_id = tp.clinic_id
    GROUP BY tp.clinic_id, tp.patient_id
), estimate_agg AS (
    SELECT
        clinic_id,
        patient_id,
        COUNT(*) AS estimates_count,
        COUNT(*) FILTER (WHERE status = 'draft') AS draft_estimates_count,
        COUNT(*) FILTER (WHERE status = 'sent') AS sent_estimates_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_estimates_count,
        COUNT(*) FILTER (WHERE status = 'rejected') AS rejected_estimates_count,
        COUNT(*) FILTER (WHERE status = 'expired') AS expired_estimates_count,
        COALESCE(round(SUM(total_amount) FILTER (WHERE status = 'accepted'), 2), 0) AS accepted_estimates_amount,
        COALESCE(round(SUM(total_amount) FILTER (WHERE status = 'sent'), 2), 0) AS sent_estimates_amount,
        MAX(created_at) AS last_estimate_created_at
    FROM estimates
    GROUP BY clinic_id, patient_id
)
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    p.id AS patient_id,
    p.last_name AS patient_last_name,
    p.first_name AS patient_first_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code,
    p.birth_date,
    CASE
        WHEN p.birth_date IS NULL THEN NULL
        ELSE date_part('year', age(current_date, p.birth_date))::int
    END AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.created_at AS patient_created_at,

    COALESCE(pa.treatment_plans_count, 0) AS treatment_plans_count,
    COALESCE(pa.draft_treatment_plans_count, 0) AS draft_treatment_plans_count,
    COALESCE(pa.proposed_treatment_plans_count, 0) AS proposed_treatment_plans_count,
    COALESCE(pa.accepted_treatment_plans_count, 0) AS accepted_treatment_plans_count,
    COALESCE(pa.in_progress_treatment_plans_count, 0) AS in_progress_treatment_plans_count,
    COALESCE(pa.completed_treatment_plans_count, 0) AS completed_treatment_plans_count,

    COALESCE(ia.treatment_items_count, 0) AS treatment_items_count,
    COALESCE(ia.completed_treatment_items_count, 0) AS completed_treatment_items_count,
    COALESCE(ia.open_treatment_items_count, 0) AS open_treatment_items_count,
    COALESCE(ia.planned_clinical_amount, 0) AS planned_clinical_amount,
    COALESCE(ia.completed_clinical_amount, 0) AS completed_clinical_amount,

    COALESCE(ea.estimates_count, 0) AS estimates_count,
    COALESCE(ea.draft_estimates_count, 0) AS draft_estimates_count,
    COALESCE(ea.sent_estimates_count, 0) AS sent_estimates_count,
    COALESCE(ea.accepted_estimates_count, 0) AS accepted_estimates_count,
    COALESCE(ea.rejected_estimates_count, 0) AS rejected_estimates_count,
    COALESCE(ea.expired_estimates_count, 0) AS expired_estimates_count,
    COALESCE(ea.accepted_estimates_amount, 0) AS accepted_estimates_amount,
    COALESCE(ea.sent_estimates_amount, 0) AS sent_estimates_amount,
    ea.last_estimate_created_at,
    pa.last_treatment_plan_updated_at
FROM clinics c
JOIN patients p
  ON p.clinic_id = c.id
LEFT JOIN plan_agg pa
  ON pa.patient_id = p.id
 AND pa.clinic_id = p.clinic_id
LEFT JOIN item_agg ia
  ON ia.patient_id = p.id
 AND ia.clinic_id = p.clinic_id
LEFT JOIN estimate_agg ea
  ON ea.patient_id = p.id
 AND ea.clinic_id = p.clinic_id;

-- =========================================================
-- 6. Carico lavoro operatori
--    Utile per capire chi ha trattamenti pianificati/completati e valore associato.
-- =========================================================

CREATE OR REPLACE VIEW v_provider_workload AS
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    prov.id AS provider_id,
    prov.last_name AS provider_last_name,
    prov.first_name AS provider_first_name,
    concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
    prov.role AS provider_role,
    prov.active AS provider_active,

    COUNT(tpi.id) AS assigned_items_count,
    COUNT(tpi.id) FILTER (WHERE tpi.status = 'planned') AS planned_items_count,
    COUNT(tpi.id) FILTER (WHERE tpi.status = 'accepted') AS accepted_items_count,
    COUNT(tpi.id) FILTER (WHERE tpi.status = 'scheduled') AS scheduled_items_count,
    COUNT(tpi.id) FILTER (WHERE tpi.status = 'completed') AS completed_items_count,
    COUNT(tpi.id) FILTER (WHERE tpi.status = 'cancelled') AS cancelled_items_count,

    COALESCE(round(SUM(tpi.quantity * tpi.planned_price) FILTER (WHERE tpi.status <> 'cancelled'), 2), 0) AS assigned_amount,
    COALESCE(round(SUM(tpi.quantity * tpi.planned_price) FILTER (WHERE tpi.status = 'completed'), 2), 0) AS completed_amount,
    MIN(tpi.planned_date) FILTER (WHERE tpi.status IN ('planned', 'accepted', 'scheduled')) AS first_open_planned_date,
    MAX(tpi.completed_at) AS last_completed_at
FROM providers prov
JOIN clinics c
  ON c.id = prov.clinic_id
LEFT JOIN treatment_plan_items tpi
  ON tpi.provider_id = prov.id
 AND tpi.clinic_id = prov.clinic_id
GROUP BY
    c.id, c.name,
    prov.id, prov.last_name, prov.first_name, prov.role, prov.active;

-- =========================================================
-- 7. Utilizzo catalogo prestazioni
--    Utile per statistiche su prestazioni più pianificate/preventivate.
-- =========================================================

CREATE OR REPLACE VIEW v_service_catalog_usage AS
WITH planned_agg AS (
    SELECT
        clinic_id,
        service_id,
        COUNT(*) AS planned_usage_count,
        COALESCE(round(SUM(quantity), 2), 0) AS planned_quantity_total,
        COALESCE(round(SUM(quantity * planned_price), 2), 0) AS planned_amount_total
    FROM treatment_plan_items
    GROUP BY clinic_id, service_id
), estimate_line_agg AS (
    SELECT
        clinic_id,
        service_id,
        COUNT(*) AS estimate_line_usage_count,
        COALESCE(round(SUM(quantity), 2), 0) AS estimate_quantity_total,
        COALESCE(round(SUM(line_total), 2), 0) AS estimate_amount_total
    FROM estimate_lines
    WHERE service_id IS NOT NULL
    GROUP BY clinic_id, service_id
)
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    sc.id AS service_id,
    sc.code AS service_code,
    sc.name AS service_name,
    sc.category AS service_category,
    sc.default_price,
    sc.default_vat_rate,
    sc.active AS service_active,

    COALESCE(pa.planned_usage_count, 0) AS planned_usage_count,
    COALESCE(pa.planned_quantity_total, 0) AS planned_quantity_total,
    COALESCE(pa.planned_amount_total, 0) AS planned_amount_total,

    COALESCE(ela.estimate_line_usage_count, 0) AS estimate_line_usage_count,
    COALESCE(ela.estimate_quantity_total, 0) AS estimate_quantity_total,
    COALESCE(ela.estimate_amount_total, 0) AS estimate_amount_total
FROM service_catalog sc
JOIN clinics c
  ON c.id = sc.clinic_id
LEFT JOIN planned_agg pa
  ON pa.service_id = sc.id
 AND pa.clinic_id = sc.clinic_id
LEFT JOIN estimate_line_agg ela
  ON ela.service_id = sc.id
 AND ela.clinic_id = sc.clinic_id;

-- =========================================================
-- 8. Dashboard clinica
--    Utile per home amministrativa multi-studio.
-- =========================================================

CREATE OR REPLACE VIEW v_clinic_dashboard AS
WITH patient_agg AS (
    SELECT clinic_id, COUNT(*) AS patients_count
    FROM patients
    GROUP BY clinic_id
), provider_agg AS (
    SELECT clinic_id, COUNT(*) FILTER (WHERE active = true) AS active_providers_count
    FROM providers
    GROUP BY clinic_id
), service_agg AS (
    SELECT clinic_id, COUNT(*) FILTER (WHERE active = true) AS active_services_count
    FROM service_catalog
    GROUP BY clinic_id
), plan_agg AS (
    SELECT
        clinic_id,
        COUNT(*) AS treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'draft') AS draft_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'proposed') AS proposed_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_treatment_plans_count,
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_treatment_plans_count,
        MAX(updated_at) AS last_treatment_plan_updated_at
    FROM treatment_plans
    GROUP BY clinic_id
), estimate_agg AS (
    SELECT
        clinic_id,
        COUNT(*) AS estimates_count,
        COUNT(*) FILTER (WHERE status = 'draft') AS draft_estimates_count,
        COUNT(*) FILTER (WHERE status = 'sent') AS sent_estimates_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS accepted_estimates_count,
        COUNT(*) FILTER (WHERE status = 'rejected') AS rejected_estimates_count,
        COUNT(*) FILTER (WHERE status = 'expired') AS expired_estimates_count,
        COALESCE(round(SUM(total_amount) FILTER (WHERE status = 'accepted'), 2), 0) AS accepted_estimates_amount,
        COALESCE(round(SUM(total_amount) FILTER (WHERE status = 'sent'), 2), 0) AS sent_estimates_amount,
        MAX(created_at) AS last_estimate_created_at
    FROM estimates
    GROUP BY clinic_id
)
SELECT
    c.id AS clinic_id,
    c.name AS clinic_name,
    c.city,
    c.province,
    COALESCE(pa.patients_count, 0) AS patients_count,
    COALESCE(pra.active_providers_count, 0) AS active_providers_count,
    COALESCE(sa.active_services_count, 0) AS active_services_count,

    COALESCE(tpa.treatment_plans_count, 0) AS treatment_plans_count,
    COALESCE(tpa.draft_treatment_plans_count, 0) AS draft_treatment_plans_count,
    COALESCE(tpa.proposed_treatment_plans_count, 0) AS proposed_treatment_plans_count,
    COALESCE(tpa.accepted_treatment_plans_count, 0) AS accepted_treatment_plans_count,
    COALESCE(tpa.in_progress_treatment_plans_count, 0) AS in_progress_treatment_plans_count,
    COALESCE(tpa.completed_treatment_plans_count, 0) AS completed_treatment_plans_count,

    COALESCE(ea.estimates_count, 0) AS estimates_count,
    COALESCE(ea.draft_estimates_count, 0) AS draft_estimates_count,
    COALESCE(ea.sent_estimates_count, 0) AS sent_estimates_count,
    COALESCE(ea.accepted_estimates_count, 0) AS accepted_estimates_count,
    COALESCE(ea.rejected_estimates_count, 0) AS rejected_estimates_count,
    COALESCE(ea.expired_estimates_count, 0) AS expired_estimates_count,
    COALESCE(ea.accepted_estimates_amount, 0) AS accepted_estimates_amount,
    COALESCE(ea.sent_estimates_amount, 0) AS sent_estimates_amount,
    ea.last_estimate_created_at,
    tpa.last_treatment_plan_updated_at
FROM clinics c
LEFT JOIN patient_agg pa
  ON pa.clinic_id = c.id
LEFT JOIN provider_agg pra
  ON pra.clinic_id = c.id
LEFT JOIN service_agg sa
  ON sa.clinic_id = c.id
LEFT JOIN plan_agg tpa
  ON tpa.clinic_id = c.id
LEFT JOIN estimate_agg ea
  ON ea.clinic_id = c.id;

COMMIT;
