-- V5: Create estimate views, trigger and multi-estimate patch
-- Applied via Flyway baseline (V1-V4 already applied manually)

SET search_path TO dentalcare, public;

-- =========================================================
-- VIEW: riepilogo preventivi per paziente
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

-- Compatibility alias
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
-- TRIGGER: ricalcolo automatico totali preventivo
-- =========================================================

CREATE OR REPLACE FUNCTION recalc_estimate_totals(p_estimate_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE estimates e
    SET
        subtotal_amount = COALESCE(t.subtotal_amount, 0),
        discount_amount = COALESCE(t.discount_amount, 0),
        taxable_amount  = COALESCE(t.taxable_amount, 0),
        vat_amount      = COALESCE(t.vat_amount, 0),
        total_amount    = COALESCE(t.total_amount, 0),
        updated_at      = now()
    FROM (
        SELECT
            estimate_id,
            round(SUM(line_subtotal), 2)    AS subtotal_amount,
            round(SUM(discount_amount), 2)  AS discount_amount,
            round(SUM(line_taxable), 2)     AS taxable_amount,
            round(SUM(line_vat_amount), 2)  AS vat_amount,
            round(SUM(line_total), 2)       AS total_amount
        FROM estimate_lines
        WHERE estimate_id = p_estimate_id
        GROUP BY estimate_id
    ) t
    WHERE e.id = p_estimate_id
      AND e.id = t.estimate_id;

    UPDATE estimates e
    SET
        subtotal_amount = 0,
        discount_amount = 0,
        taxable_amount  = 0,
        vat_amount      = 0,
        total_amount    = 0,
        updated_at      = now()
    WHERE e.id = p_estimate_id
      AND NOT EXISTS (
          SELECT 1 FROM estimate_lines l WHERE l.estimate_id = p_estimate_id
      );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_recalc_estimate_totals()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM recalc_estimate_totals(NEW.estimate_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.estimate_id <> OLD.estimate_id THEN
            PERFORM recalc_estimate_totals(OLD.estimate_id);
            PERFORM recalc_estimate_totals(NEW.estimate_id);
        ELSE
            PERFORM recalc_estimate_totals(NEW.estimate_id);
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM recalc_estimate_totals(OLD.estimate_id);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_estimate_lines_recalc_totals ON estimate_lines;

CREATE TRIGGER trg_estimate_lines_recalc_totals
AFTER INSERT OR UPDATE OR DELETE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION trg_recalc_estimate_totals();

-- =========================================================
-- PATCH: multi-estimate per piano di cura
-- =========================================================

ALTER TABLE estimates
    DROP CONSTRAINT IF EXISTS ux_estimates_plan_version;

CREATE INDEX IF NOT EXISTS ix_estimates_treatment_plan
    ON estimates(clinic_id, treatment_plan_id)
    WHERE treatment_plan_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_estimate_lines_plan_item
    ON estimate_lines(clinic_id, treatment_plan_item_id)
    WHERE treatment_plan_item_id IS NOT NULL;
