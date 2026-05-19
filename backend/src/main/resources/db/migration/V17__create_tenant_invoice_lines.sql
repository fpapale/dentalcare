-- V17: Create invoice_lines in the tenant schema with correct column names.
-- V16 altered dentalcare.invoice_lines (artifact from old V7 migration) instead
-- of t_9d754153.invoice_lines because the table did not exist in the tenant schema.
-- This migration drops/recreates the table explicitly in the tenant schema.

-- Drop artifact in dentalcare schema (safe — dentalcare.invoice_lines has no data)
DROP TABLE IF EXISTS dentalcare.invoice_lines CASCADE;

-- Drop tenant table if it exists with wrong schema (also safe — empty)
DROP TABLE IF EXISTS t_9d754153.invoice_lines CASCADE;

-- =============================================================================
-- Create invoice_lines in the correct tenant schema
-- =============================================================================

CREATE TABLE t_9d754153.invoice_lines (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    invoice_id       uuid          NOT NULL,
    clinic_id        uuid          NOT NULL,
    line_position    integer       NOT NULL DEFAULT 0,
    description      text          NOT NULL,
    tooth_info       text,
    quantity         numeric(12,4) NOT NULL DEFAULT 1,
    unit_price       numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount  numeric(12,2) NOT NULL DEFAULT 0,
    vat_rate         numeric(5,2)  NOT NULL DEFAULT 22,
    line_subtotal    numeric(12,2) NOT NULL DEFAULT 0,
    line_taxable     numeric(12,2) NOT NULL DEFAULT 0,
    line_vat_amount  numeric(12,2) NOT NULL DEFAULT 0,
    line_total       numeric(12,2) NOT NULL DEFAULT 0,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT invoice_lines_pkey PRIMARY KEY (id),
    CONSTRAINT invoice_lines_description_not_empty CHECK (length(trim(description)) > 0),
    CONSTRAINT fk_invoice_lines_invoice FOREIGN KEY (invoice_id)
        REFERENCES t_9d754153.invoices(id) ON DELETE CASCADE,
    CONSTRAINT fk_invoice_lines_clinic  FOREIGN KEY (clinic_id)
        REFERENCES t_9d754153.clinics(id)  ON DELETE RESTRICT
);

CREATE INDEX ix_invoice_lines_invoice ON t_9d754153.invoice_lines (invoice_id);
CREATE INDEX ix_invoice_lines_clinic  ON t_9d754153.invoice_lines (clinic_id);

-- =============================================================================
-- Trigger: compute line totals on insert/update
-- =============================================================================

SET search_path TO t_9d754153, dentalcare, public;

CREATE OR REPLACE FUNCTION trg_compute_invoice_line_totals()
RETURNS trigger AS $$
BEGIN
    NEW.line_subtotal   := (COALESCE(NEW.quantity, 1) * COALESCE(NEW.unit_price, 0))
                           - COALESCE(NEW.discount_amount, 0);
    NEW.line_taxable    := NEW.line_subtotal;
    NEW.line_vat_amount := ROUND(NEW.line_taxable * COALESCE(NEW.vat_rate, 0) / 100, 2);
    NEW.line_total      := NEW.line_taxable + NEW.line_vat_amount;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_invoice_line_compute_totals ON t_9d754153.invoice_lines;
CREATE TRIGGER trg_invoice_line_compute_totals
BEFORE INSERT OR UPDATE ON t_9d754153.invoice_lines
FOR EACH ROW EXECUTE FUNCTION trg_compute_invoice_line_totals();

-- =============================================================================
-- Trigger: update invoice header totals after line change
-- =============================================================================

CREATE OR REPLACE FUNCTION trg_update_invoice_totals_from_lines()
RETURNS trigger AS $$
DECLARE
    v_invoice_id uuid;
BEGIN
    v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
    UPDATE t_9d754153.invoices
    SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)   FROM t_9d754153.invoice_lines WHERE invoice_id = v_invoice_id), 0),
        discount_amount = COALESCE((SELECT SUM(discount_amount) FROM t_9d754153.invoice_lines WHERE invoice_id = v_invoice_id), 0),
        taxable_amount  = COALESCE((SELECT SUM(line_taxable)    FROM t_9d754153.invoice_lines WHERE invoice_id = v_invoice_id), 0),
        vat_amount      = COALESCE((SELECT SUM(line_vat_amount) FROM t_9d754153.invoice_lines WHERE invoice_id = v_invoice_id), 0),
        total_amount    = COALESCE((SELECT SUM(line_total)      FROM t_9d754153.invoice_lines WHERE invoice_id = v_invoice_id), 0),
        updated_at      = now()
    WHERE id = v_invoice_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_invoices_recalc_from_lines ON t_9d754153.invoice_lines;
CREATE TRIGGER trg_invoices_recalc_from_lines
AFTER INSERT OR UPDATE OR DELETE ON t_9d754153.invoice_lines
FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_totals_from_lines();

-- Trigger: updated_at
DROP TRIGGER IF EXISTS trg_invoice_lines_updated_at ON t_9d754153.invoice_lines;
CREATE TRIGGER trg_invoice_lines_updated_at
BEFORE UPDATE ON t_9d754153.invoice_lines
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();
