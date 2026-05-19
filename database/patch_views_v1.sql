-- Patch: add missing email column + create 3 views for tenant t_9d754153
SET search_path TO t_9d754153, dentalcare, public;

-- 1. Add email to patients if missing
ALTER TABLE patients ADD COLUMN IF NOT EXISTS email text;

-- 2. v_patient_dashboard
CREATE OR REPLACE VIEW v_patient_dashboard AS
SELECT
    p.id          AS patient_id,
    p.clinic_id,
    p.first_name  AS patient_first_name,
    p.last_name   AS patient_last_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code,
    p.birth_date,
    CASE WHEN p.birth_date IS NULL THEN NULL
         ELSE date_part('year', age(CURRENT_DATE, p.birth_date))::int
    END AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    COUNT(DISTINCT tp.id)                                                                       AS treatment_plans_count,
    COUNT(DISTINCT tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled'))     AS open_treatment_items_count,
    COALESCE(SUM(e.total_amount) FILTER (WHERE e.status::text = 'accepted'), 0)                AS accepted_estimates_amount
FROM patients p
LEFT JOIN treatment_plans      tp  ON tp.patient_id         = p.id  AND tp.clinic_id  = p.clinic_id
LEFT JOIN treatment_plan_items tpi ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = p.clinic_id
LEFT JOIN estimates            e   ON e.patient_id          = p.id  AND e.clinic_id   = p.clinic_id
GROUP BY p.id, p.clinic_id, p.first_name, p.last_name,
         p.fiscal_code, p.birth_date, p.phone, p.email, p.city, p.province;

-- 3. v_patient_clinical_card
CREATE OR REPLACE VIEW v_patient_clinical_card AS
SELECT
    p.id          AS patient_id,
    p.clinic_id,
    p.first_name,
    p.last_name,
    concat_ws(' ', p.last_name, p.first_name) AS full_name,
    p.birth_date,
    CASE WHEN p.birth_date IS NULL THEN NULL
         ELSE date_part('year', age(CURRENT_DATE, p.birth_date))::int
    END AS age_years,
    p.fiscal_code,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.notes       AS patient_notes,
    pa.blood_type,
    pa.smoker,
    pa.hypertension,
    pa.diabetes,
    pa.heart_disease,
    pa.taking_anticoagulants,
    pa.taking_bisphosphonates,
    pa.allergy_penicillin,
    pa.allergy_latex,
    pa.allergy_anesthetic,
    pa.other_allergies,
    pa.general_notes AS anamnesis_notes,
    pa.recorded_at   AS anamnesis_date,
    COUNT(DISTINCT a.id) AS total_appointments
FROM patients p
LEFT JOIN patient_anamnesis pa
       ON pa.patient_id = p.id AND pa.clinic_id = p.clinic_id AND pa.is_current = true
LEFT JOIN appointments a
       ON a.patient_id = p.id AND a.clinic_id = p.clinic_id
GROUP BY p.id, p.clinic_id, p.first_name, p.last_name,
         p.fiscal_code, p.birth_date, p.phone, p.email, p.city, p.province, p.notes,
         pa.blood_type, pa.smoker, pa.hypertension, pa.diabetes, pa.heart_disease,
         pa.taking_anticoagulants, pa.taking_bisphosphonates,
         pa.allergy_penicillin, pa.allergy_latex, pa.allergy_anesthetic,
         pa.other_allergies, pa.general_notes, pa.recorded_at;

-- 4. v_patient_estimates_summary
CREATE OR REPLACE VIEW v_patient_estimates_summary AS
SELECT
    e.id                                          AS estimate_id,
    e.clinic_id,
    e.patient_id,
    e.estimate_number,
    e.version,
    e.status::text                                AS estimate_status,
    e.title                                       AS estimate_title,
    e.currency,
    e.subtotal_amount,
    e.discount_amount,
    e.taxable_amount,
    e.vat_amount,
    e.total_amount,
    concat_ws(' ', p.last_name, p.first_name)    AS patient_full_name,
    p.fiscal_code                                 AS patient_fiscal_code,
    p.phone                                       AS patient_phone,
    e.issued_at,
    e.sent_at,
    e.valid_until,
    e.accepted_at,
    e.rejected_at,
    e.created_at                                  AS estimate_created_at,
    e.created_by_provider_id
FROM estimates e
LEFT JOIN patients p ON p.id = e.patient_id AND p.clinic_id = e.clinic_id;
