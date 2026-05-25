-- V16: Fix invoices schema in tenant schema.
-- If invoices doesn't exist: create it fresh with correct column names.
-- If invoices exists with old column names: rename + add missing columns.
-- invoice_lines is handled entirely by V17.

SET search_path TO t_9d754153, dentalcare, public;

-- =============================================================================
-- 0. Enum types in dentalcare schema (idempotent)
-- =============================================================================

DO $$ BEGIN
    CREATE TYPE dentalcare.invoice_document_type AS ENUM ('fattura', 'ricevuta', 'nota_credito');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE dentalcare.invoice_status AS ENUM (
        'draft', 'issued', 'sent', 'paid', 'cancelled', 'overdue'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE dentalcare.invoice_issuer_type AS ENUM ('clinic', 'provider');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- 1. Create invoices if not exists (fresh install with correct schema)
-- =============================================================================

CREATE TABLE IF NOT EXISTS invoices (
    id                  uuid                             NOT NULL DEFAULT gen_random_uuid(),
    clinic_id           uuid                             NOT NULL,
    patient_id          uuid,
    provider_id         uuid,
    invoice_number      text,
    document_type       dentalcare.invoice_document_type NOT NULL DEFAULT 'fattura',
    invoice_date        date                             NOT NULL DEFAULT CURRENT_DATE,
    due_date            date,
    status              dentalcare.invoice_status        NOT NULL DEFAULT 'draft',
    issuer_type         dentalcare.invoice_issuer_type   NOT NULL DEFAULT 'clinic',
    estimate_id         uuid,
    issuer_name         text,
    issuer_vat_number   text,
    issuer_fiscal_code  text,
    issuer_address      text,
    issuer_email        text,
    issuer_pec          text,
    issuer_sdi_code     text,
    issuer_iban         text,
    patient_full_name   text,
    patient_fiscal_code text,
    patient_address     text,
    patient_email       text,
    subtotal_amount     numeric(12,2)                    NOT NULL DEFAULT 0,
    discount_amount     numeric(12,2)                    NOT NULL DEFAULT 0,
    taxable_amount      numeric(12,2)                    NOT NULL DEFAULT 0,
    vat_amount          numeric(12,2)                    NOT NULL DEFAULT 0,
    total_amount        numeric(12,2)                    NOT NULL DEFAULT 0,
    currency            char(3)                          NOT NULL DEFAULT 'EUR',
    notes               text,
    payment_method      text,
    paid_at             timestamptz,
    issued_at           timestamptz,
    created_at          timestamptz                      NOT NULL DEFAULT now(),
    updated_at          timestamptz                      NOT NULL DEFAULT now(),
    CONSTRAINT invoices_pkey PRIMARY KEY (id)
);

-- =============================================================================
-- 2. For existing tables with old column names: rename (safe no-ops)
-- =============================================================================

DO $$ BEGIN
    ALTER TABLE invoices RENAME COLUMN subtotal TO subtotal_amount;
EXCEPTION WHEN undefined_column THEN NULL;
         WHEN undefined_table  THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE invoices RENAME COLUMN vat_total TO vat_amount;
EXCEPTION WHEN undefined_column THEN NULL;
         WHEN undefined_table  THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE invoices RENAME COLUMN total TO total_amount;
EXCEPTION WHEN undefined_column THEN NULL;
         WHEN undefined_table  THEN NULL;
END $$;

-- =============================================================================
-- 3. Add missing columns (IF NOT EXISTS: safe for both old and new tables)
-- =============================================================================

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

ALTER TABLE invoices
    ADD COLUMN IF NOT EXISTS subtotal_amount numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS vat_amount      numeric(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_amount    numeric(12,2) NOT NULL DEFAULT 0;

DO $$ BEGIN
    ALTER TABLE invoices ADD COLUMN provider_id uuid REFERENCES providers(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- =============================================================================
-- 4. Unique constraint and indexes
-- =============================================================================

DROP INDEX IF EXISTS ux_invoices_clinic_number;

DO $$ BEGIN
    ALTER TABLE invoices ADD CONSTRAINT ux_invoices_number UNIQUE (clinic_id, invoice_number);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS ix_invoices_clinic  ON invoices (clinic_id);
CREATE INDEX IF NOT EXISTS ix_invoices_patient ON invoices (clinic_id, patient_id);
