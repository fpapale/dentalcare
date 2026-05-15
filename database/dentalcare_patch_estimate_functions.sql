-- Patch: add missing recalc_estimate_totals function and fix trigger
-- Apply to: dentalcarepro database on 192.168.0.173

SET search_path TO dentalcare, public;

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
