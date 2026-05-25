-- V17: Create invoice_lines in the tenant schema with correct column names.
-- If schema 't_9d754153' doesn't exist, all tenant-specific ops are skipped
-- (table will be created correctly by provisioning flow when tenant is provisioned).

-- Clean up artifact in dentalcare schema (always safe)
DROP TABLE IF EXISTS dentalcare.invoice_lines CASCADE;

-- =============================================================================
-- Tenant-schema operations: guarded by schema existence check
-- =============================================================================

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata WHERE schema_name = 't_9d754153'
    ) THEN
        RETURN;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS t_9d754153.invoice_lines CASCADE';

    EXECUTE $q$
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
            CONSTRAINT fk_invoice_lines_clinic FOREIGN KEY (clinic_id)
                REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT
        )
    $q$;

    EXECUTE 'CREATE INDEX ix_invoice_lines_invoice ON t_9d754153.invoice_lines (invoice_id)';
    EXECUTE 'CREATE INDEX ix_invoice_lines_clinic  ON t_9d754153.invoice_lines (clinic_id)';
END $$;

-- =============================================================================
-- Trigger functions (PL/pgSQL: table refs not validated at CREATE time — safe)
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

-- =============================================================================
-- Triggers: guarded by schema existence check
-- =============================================================================

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata WHERE schema_name = 't_9d754153'
    ) THEN
        RETURN;
    END IF;

    EXECUTE 'DROP TRIGGER IF EXISTS trg_invoice_line_compute_totals ON t_9d754153.invoice_lines';
    EXECUTE 'CREATE TRIGGER trg_invoice_line_compute_totals BEFORE INSERT OR UPDATE ON t_9d754153.invoice_lines FOR EACH ROW EXECUTE FUNCTION trg_compute_invoice_line_totals()';

    EXECUTE 'DROP TRIGGER IF EXISTS trg_invoices_recalc_from_lines ON t_9d754153.invoice_lines';
    EXECUTE 'CREATE TRIGGER trg_invoices_recalc_from_lines AFTER INSERT OR UPDATE OR DELETE ON t_9d754153.invoice_lines FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_totals_from_lines()';

    EXECUTE 'DROP TRIGGER IF EXISTS trg_invoice_lines_updated_at ON t_9d754153.invoice_lines';
    EXECUTE 'CREATE TRIGGER trg_invoice_lines_updated_at BEFORE UPDATE ON t_9d754153.invoice_lines FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at()';
END $$;
