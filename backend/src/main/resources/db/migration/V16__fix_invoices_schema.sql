-- V16: Fix invoices and invoice_lines schema in tenant schema.
-- The original tenant-schema-template.sql used old column names that diverged
-- from InvoiceService expectations. This migration brings the live tenant
-- schema in sync with the current InvoiceService queries.

SET search_path TO t_9d754153, dentalcare, public;

-- =============================================================================
-- 1. INVOICES — rename old columns, add missing columns
-- =============================================================================

-- Rename subtotal → subtotal_amount
DO $$ BEGIN
    ALTER TABLE invoices RENAME COLUMN subtotal TO subtotal_amount;
EXCEPTION WHEN undefined_column THEN NULL;
            WHEN duplicate_column THEN NULL;
END $$;

-- Rename vat_total → vat_amount
DO $$ BEGIN
    ALTER TABLE invoices RENAME COLUMN vat_total TO vat_amount;
EXCEPTION WHEN undefined_column THEN NULL;
            WHEN duplicate_column THEN NULL;
END $$;

-- Rename total → total_amount
DO $$ BEGIN
    ALTER TABLE invoices RENAME COLUMN total TO total_amount;
EXCEPTION WHEN undefined_column THEN NULL;
            WHEN duplicate_column THEN NULL;
END $$;

-- Add columns missing from the old template schema
ALTER TABLE invoices
    ADD COLUMN IF NOT EXISTS invoice_number      text,
    ADD COLUMN IF NOT EXISTS patient_full_name   text,
    ADD COLUMN IF NOT EXISTS patient_fiscal_code text,
    ADD COLUMN IF NOT EXISTS patient_address     text,
    ADD COLUMN IF NOT EXISTS patient_email       text,
    ADD COLUMN IF NOT EXISTS issuer_name         text,
    ADD COLUMN IF NOT EXISTS issuer_vat_number   text,
    ADD COLUMN IF NOT EXISTS issuer_fiscal_code  text,
    ADD COLUMN IF NOT EXISTS issuer_address      text,
    ADD COLUMN IF NOT EXISTS issuer_email        text,
    ADD COLUMN IF NOT EXISTS issuer_pec          text,
    ADD COLUMN IF NOT EXISTS issuer_sdi_code     text,
    ADD COLUMN IF NOT EXISTS issuer_iban         text,
    ADD COLUMN IF NOT EXISTS discount_amount     numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS taxable_amount      numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS currency            char(3)       NOT NULL DEFAULT 'EUR',
    ADD COLUMN IF NOT EXISTS payment_method      text,
    ADD COLUMN IF NOT EXISTS paid_at             timestamptz,
    ADD COLUMN IF NOT EXISTS issued_at           timestamptz;

-- Ensure subtotal_amount and vat_amount exist (if rename already happened earlier)
ALTER TABLE invoices
    ADD COLUMN IF NOT EXISTS subtotal_amount numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS vat_amount      numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_amount    numeric(12,2) NOT NULL DEFAULT 0;

-- Ensure provider_id FK is present (old schema used ON DELETE SET NULL)
DO $$ BEGIN
    ALTER TABLE invoices ADD COLUMN provider_id uuid REFERENCES providers(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- Drop old partial unique index; add non-partial one used by InvoiceService
DROP INDEX IF EXISTS ux_invoices_clinic_number;

DO $$ BEGIN
    ALTER TABLE invoices ADD CONSTRAINT ux_invoices_number UNIQUE (clinic_id, invoice_number);
EXCEPTION WHEN duplicate_object THEN NULL;  -- constraint already exists
END $$;

-- =============================================================================
-- 2. INVOICE_LINES — rename position, add missing columns, rebuild triggers
-- =============================================================================

-- Drop old aggregate trigger that referenced wrong column names
DROP TRIGGER IF EXISTS trg_recalc_invoice_totals ON invoice_lines;
DROP FUNCTION IF EXISTS recalc_invoice_totals();

-- Rename position → line_position
DO $$ BEGIN
    ALTER TABLE invoice_lines RENAME COLUMN position TO line_position;
EXCEPTION WHEN undefined_column THEN NULL;
            WHEN duplicate_column THEN NULL;
END $$;

ALTER TABLE invoice_lines
    ADD COLUMN IF NOT EXISTS line_position    integer       NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS tooth_info       text,
    ADD COLUMN IF NOT EXISTS discount_amount  numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS line_subtotal    numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS line_taxable     numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS line_vat_amount  numeric(12,2) NOT NULL DEFAULT 0;

-- Ensure line_total exists (it was in old schema already)
ALTER TABLE invoice_lines
    ADD COLUMN IF NOT EXISTS line_total numeric(12,2) NOT NULL DEFAULT 0;

-- Ensure quantity and unit_price are numeric (old schema used integer quantity)
-- Cast is safe because existing rows are 0 or positive integers.
DO $$ BEGIN
    ALTER TABLE invoice_lines ALTER COLUMN quantity TYPE numeric(12,4) USING quantity::numeric;
EXCEPTION WHEN others THEN NULL;
END $$;

-- =============================================================================
-- 3. Trigger: compute line-level totals before insert/update
-- =============================================================================

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

DROP TRIGGER IF EXISTS trg_invoice_line_compute_totals ON invoice_lines;
CREATE TRIGGER trg_invoice_line_compute_totals
BEFORE INSERT OR UPDATE ON invoice_lines
FOR EACH ROW EXECUTE FUNCTION trg_compute_invoice_line_totals();

-- =============================================================================
-- 4. Trigger: update invoice header totals after line changes
-- =============================================================================

CREATE OR REPLACE FUNCTION trg_update_invoice_totals_from_lines()
RETURNS trigger AS $$
DECLARE
    v_invoice_id uuid;
BEGIN
    v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
    UPDATE invoices
    SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)    FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        discount_amount = COALESCE((SELECT SUM(discount_amount)  FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        taxable_amount  = COALESCE((SELECT SUM(line_taxable)     FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        vat_amount      = COALESCE((SELECT SUM(line_vat_amount)  FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        total_amount    = COALESCE((SELECT SUM(line_total)       FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        updated_at      = now()
    WHERE id = v_invoice_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_invoices_recalc_from_lines ON invoice_lines;
CREATE TRIGGER trg_invoices_recalc_from_lines
AFTER INSERT OR UPDATE OR DELETE ON invoice_lines
FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_totals_from_lines();
