-- V7: Invoices module — providers billing info, invoices, invoice_lines

SET search_path TO dentalcare, public;

-- =========================================================
-- 1. EXTEND providers TABLE — billing / professional info
-- =========================================================

ALTER TABLE providers
    ADD COLUMN IF NOT EXISTS vat_number                text,
    ADD COLUMN IF NOT EXISTS fiscal_code               text,
    ADD COLUMN IF NOT EXISTS professional_register     text,
    ADD COLUMN IF NOT EXISTS register_number           text,
    ADD COLUMN IF NOT EXISTS billing_address_street    text,
    ADD COLUMN IF NOT EXISTS billing_address_zip       text,
    ADD COLUMN IF NOT EXISTS billing_address_city      text,
    ADD COLUMN IF NOT EXISTS billing_address_province  text,
    ADD COLUMN IF NOT EXISTS billing_pec               text,
    ADD COLUMN IF NOT EXISTS billing_iban              text,
    ADD COLUMN IF NOT EXISTS billing_sdi_code          text,
    ADD COLUMN IF NOT EXISTS invoice_prefix            text DEFAULT 'PARC';

-- =========================================================
-- 2. ENUMs
-- =========================================================

DO $$ BEGIN
    CREATE TYPE invoice_document_type AS ENUM (
        'fattura', 'ricevuta', 'parcella', 'nota_credito'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_status AS ENUM (
        'draft', 'issued', 'paid', 'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_issuer_type AS ENUM (
        'clinic', 'provider'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================
-- 3. invoices TABLE
-- =========================================================

CREATE TABLE IF NOT EXISTS invoices (
    id                  uuid                    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid                    NOT NULL
                            REFERENCES clinics(id) ON DELETE RESTRICT,

    invoice_number      text                    NOT NULL,
    document_type       invoice_document_type   NOT NULL DEFAULT 'fattura',
    invoice_date        date                    NOT NULL DEFAULT current_date,
    due_date            date,
    status              invoice_status          NOT NULL DEFAULT 'draft',

    issuer_type         invoice_issuer_type     NOT NULL DEFAULT 'clinic',
    provider_id         uuid,

    patient_id          uuid                    NOT NULL,
    estimate_id         uuid,

    -- issuer snapshot (captured at issue time)
    issuer_name         text,
    issuer_vat_number   text,
    issuer_fiscal_code  text,
    issuer_address      text,
    issuer_email        text,
    issuer_pec          text,
    issuer_sdi_code     text,
    issuer_iban         text,

    -- patient snapshot (captured at issue time)
    patient_full_name   text,
    patient_fiscal_code text,
    patient_address     text,
    patient_email       text,

    -- amounts
    subtotal_amount     numeric(12,2)           NOT NULL DEFAULT 0,
    discount_amount     numeric(12,2)           NOT NULL DEFAULT 0,
    taxable_amount      numeric(12,2)           NOT NULL DEFAULT 0,
    vat_amount          numeric(12,2)           NOT NULL DEFAULT 0,
    total_amount        numeric(12,2)           NOT NULL DEFAULT 0,
    currency            char(3)                 NOT NULL DEFAULT 'EUR',

    notes               text,
    payment_method      text,
    paid_at             timestamptz,
    issued_at           timestamptz,

    created_at          timestamptz             NOT NULL DEFAULT now(),
    updated_at          timestamptz             NOT NULL DEFAULT now(),

    CONSTRAINT invoices_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT ux_invoices_number         UNIQUE (clinic_id, invoice_number)
);

-- FK: provider (nullable, composite to enforce clinic isolation)
ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS fk_invoices_provider;
ALTER TABLE invoices
    ADD CONSTRAINT fk_invoices_provider
        FOREIGN KEY (provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
        DEFERRABLE INITIALLY DEFERRED;

-- FK: patient (composite)
ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS fk_invoices_patient;
ALTER TABLE invoices
    ADD CONSTRAINT fk_invoices_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE RESTRICT;

-- FK: estimate (nullable, composite)
ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS fk_invoices_estimate;
ALTER TABLE invoices
    ADD CONSTRAINT fk_invoices_estimate
        FOREIGN KEY (estimate_id, clinic_id)
        REFERENCES estimates(id, clinic_id)
        ON DELETE RESTRICT
        DEFERRABLE INITIALLY DEFERRED;

-- =========================================================
-- 4. invoice_lines TABLE
-- =========================================================

CREATE TABLE IF NOT EXISTS invoice_lines (
    id              uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid            NOT NULL
                        REFERENCES clinics(id) ON DELETE RESTRICT,
    invoice_id      uuid            NOT NULL,

    line_position   integer         NOT NULL DEFAULT 1,
    description     text            NOT NULL,
    tooth_info      text,

    quantity        numeric(10,2)   NOT NULL DEFAULT 1,
    unit_price      numeric(12,2)   NOT NULL DEFAULT 0,
    discount_amount numeric(12,2)   NOT NULL DEFAULT 0,
    vat_rate        numeric(5,2)    NOT NULL DEFAULT 0,

    -- STORED generated columns
    line_subtotal   numeric(12,2)   GENERATED ALWAYS AS (
                        round(quantity * unit_price, 2)
                    ) STORED,
    line_taxable    numeric(12,2)   GENERATED ALWAYS AS (
                        round(GREATEST(quantity * unit_price - discount_amount, 0), 2)
                    ) STORED,
    line_vat_amount numeric(12,2)   GENERATED ALWAYS AS (
                        round(GREATEST(quantity * unit_price - discount_amount, 0) * vat_rate / 100, 2)
                    ) STORED,
    line_total      numeric(12,2)   GENERATED ALWAYS AS (
                        round(GREATEST(quantity * unit_price - discount_amount, 0) * (1 + vat_rate / 100), 2)
                    ) STORED,

    created_at      timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT invoice_lines_unique_per_clinic UNIQUE (id, clinic_id)
);

-- FK: invoice (composite, cascade delete)
ALTER TABLE invoice_lines
    DROP CONSTRAINT IF EXISTS fk_invoice_lines_invoice;
ALTER TABLE invoice_lines
    ADD CONSTRAINT fk_invoice_lines_invoice
        FOREIGN KEY (invoice_id, clinic_id)
        REFERENCES invoices(id, clinic_id)
        ON DELETE CASCADE;

-- =========================================================
-- 5. INDEXES
-- =========================================================

CREATE INDEX IF NOT EXISTS ix_invoices_clinic_status
    ON invoices(clinic_id, status, invoice_date DESC);

CREATE INDEX IF NOT EXISTS ix_invoices_patient
    ON invoices(clinic_id, patient_id);

CREATE INDEX IF NOT EXISTS ix_invoices_estimate
    ON invoices(clinic_id, estimate_id)
    WHERE estimate_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_invoice_lines_invoice
    ON invoice_lines(clinic_id, invoice_id);

-- =========================================================
-- 6. updated_at TRIGGER on invoices
-- =========================================================

DROP TRIGGER IF EXISTS trg_invoices_set_updated_at ON invoices;

CREATE TRIGGER trg_invoices_set_updated_at
BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- 7. FUNCTION: recalc_invoice_totals
-- =========================================================

CREATE OR REPLACE FUNCTION recalc_invoice_totals(p_invoice_id uuid)
RETURNS void AS $$
BEGIN
    -- Aggregate from lines when at least one line exists
    UPDATE invoices i
    SET
        subtotal_amount = COALESCE(t.subtotal_amount, 0),
        discount_amount = COALESCE(t.discount_amount, 0),
        taxable_amount  = COALESCE(t.taxable_amount, 0),
        vat_amount      = COALESCE(t.vat_amount, 0),
        total_amount    = COALESCE(t.total_amount, 0),
        updated_at      = now()
    FROM (
        SELECT
            invoice_id,
            round(SUM(line_subtotal), 2)    AS subtotal_amount,
            round(SUM(discount_amount), 2)  AS discount_amount,
            round(SUM(line_taxable), 2)     AS taxable_amount,
            round(SUM(line_vat_amount), 2)  AS vat_amount,
            round(SUM(line_total), 2)       AS total_amount
        FROM invoice_lines
        WHERE invoice_id = p_invoice_id
        GROUP BY invoice_id
    ) t
    WHERE i.id = p_invoice_id
      AND i.id = t.invoice_id;

    -- Zero out totals when no lines remain
    UPDATE invoices i
    SET
        subtotal_amount = 0,
        discount_amount = 0,
        taxable_amount  = 0,
        vat_amount      = 0,
        total_amount    = 0,
        updated_at      = now()
    WHERE i.id = p_invoice_id
      AND NOT EXISTS (
          SELECT 1 FROM invoice_lines l WHERE l.invoice_id = p_invoice_id
      );
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 8. TRIGGER FUNCTION: trg_recalc_invoice_totals
-- =========================================================

CREATE OR REPLACE FUNCTION trg_recalc_invoice_totals()
RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM recalc_invoice_totals(NEW.invoice_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.invoice_id <> OLD.invoice_id THEN
            PERFORM recalc_invoice_totals(OLD.invoice_id);
            PERFORM recalc_invoice_totals(NEW.invoice_id);
        ELSE
            PERFORM recalc_invoice_totals(NEW.invoice_id);
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM recalc_invoice_totals(OLD.invoice_id);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 9. TRIGGER: trg_invoice_lines_recalc_totals
-- =========================================================

DROP TRIGGER IF EXISTS trg_invoice_lines_recalc_totals ON invoice_lines;

CREATE TRIGGER trg_invoice_lines_recalc_totals
AFTER INSERT OR UPDATE OR DELETE ON invoice_lines
FOR EACH ROW EXECUTE FUNCTION trg_recalc_invoice_totals();

-- =========================================================
-- VERIFY
-- =========================================================

SELECT
    (SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = 'dentalcare' AND table_name = 'providers'
          AND column_name = 'invoice_prefix')           AS providers_invoice_prefix_exists,
    (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'dentalcare' AND table_name = 'invoices')      AS invoices_table_exists,
    (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'dentalcare' AND table_name = 'invoice_lines') AS invoice_lines_table_exists,
    (SELECT COUNT(*) FROM information_schema.triggers
        WHERE trigger_schema = 'dentalcare'
          AND trigger_name   = 'trg_invoices_set_updated_at')               AS updated_at_trigger_exists,
    (SELECT COUNT(*) FROM information_schema.triggers
        WHERE trigger_schema = 'dentalcare'
          AND trigger_name   = 'trg_invoice_lines_recalc_totals')           AS recalc_trigger_exists;
