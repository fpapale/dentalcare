-- DentalCare PostgreSQL schema
-- Modello: Piano di cura clinico principale + Preventivo come snapshot economico/versionato
-- Uso consigliato:
--   createdb dentalcare
--   psql -d dentalcare -f dentalcare_schema.sql

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS dentalcare;
SET search_path TO dentalcare, public;

-- =========================================================
-- ENUM
-- =========================================================

DO $$ BEGIN
    CREATE TYPE treatment_plan_status AS ENUM (
        'draft',        -- bozza interna
        'proposed',     -- proposto al paziente
        'accepted',     -- accettato dal paziente
        'in_progress',  -- cure in corso
        'completed',    -- completato
        'rejected',     -- rifiutato
        'archived'      -- archiviato
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE treatment_item_status AS ENUM (
        'planned',      -- pianificato
        'accepted',     -- accettato
        'scheduled',    -- schedulato in agenda
        'completed',    -- eseguito
        'cancelled'     -- annullato
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE estimate_status AS ENUM (
        'draft',        -- bozza
        'sent',         -- inviato/consegnato
        'accepted',     -- accettato
        'rejected',     -- rifiutato
        'expired',      -- scaduto
        'cancelled'     -- annullato
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE provider_role AS ENUM (
        'dentist',
        'hygienist',
        'orthodontist',
        'surgeon',
        'assistant',
        'admin',
        'other'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================
-- FUNZIONI DI SERVIZIO
-- =========================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- ANAGRAFICHE DI BASE
-- =========================================================

CREATE TABLE IF NOT EXISTS clinics (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    legal_name      text,
    vat_number      text,
    fiscal_code     text,
    phone           text,
    email           citext,
    address_line1   text,
    address_line2   text,
    city            text,
    province        text,
    postal_code     text,
    country         text NOT NULL DEFAULT 'IT',
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT clinics_name_not_empty CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_clinics_vat_number
ON clinics (vat_number)
WHERE vat_number IS NOT NULL;

DROP TRIGGER IF EXISTS trg_clinics_updated_at ON clinics;

CREATE TRIGGER trg_clinics_updated_at
BEFORE UPDATE ON clinics
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS patients (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    first_name      text NOT NULL,
    last_name       text NOT NULL,
    fiscal_code     text,
    birth_date      date,
    phone           text,
    email           citext,
    address_line1   text,
    address_line2   text,
    city            text,
    province        text,
    postal_code     text,
    country         text NOT NULL DEFAULT 'IT',
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patients_first_name_not_empty CHECK (length(trim(first_name)) > 0),
    CONSTRAINT patients_last_name_not_empty CHECK (length(trim(last_name)) > 0),
    CONSTRAINT patients_unique_per_clinic UNIQUE (id, clinic_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_patients_clinic_fiscal_code
ON patients (clinic_id, fiscal_code)
WHERE fiscal_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_patients_clinic_name
ON patients (clinic_id, last_name, first_name);

CREATE INDEX IF NOT EXISTS ix_patients_clinic_phone
ON patients (clinic_id, phone)
WHERE phone IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_patients_clinic_email
ON patients (clinic_id, email)
WHERE email IS NOT NULL;

DROP TRIGGER IF EXISTS trg_patients_updated_at ON patients;

CREATE TRIGGER trg_patients_updated_at
BEFORE UPDATE ON patients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS providers (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    first_name      text NOT NULL,
    last_name       text NOT NULL,
    role            provider_role NOT NULL DEFAULT 'dentist',
    phone           text,
    email           citext,
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT providers_first_name_not_empty CHECK (length(trim(first_name)) > 0),
    CONSTRAINT providers_last_name_not_empty CHECK (length(trim(last_name)) > 0),
    CONSTRAINT providers_unique_per_clinic UNIQUE (id, clinic_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_providers_clinic_email
ON providers (clinic_id, email)
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_providers_clinic_active
ON providers (clinic_id, active);

DROP TRIGGER IF EXISTS trg_providers_updated_at ON providers;

CREATE TRIGGER trg_providers_updated_at
BEFORE UPDATE ON providers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- CATALOGO PRESTAZIONI / LISTINO
-- =========================================================

CREATE TABLE IF NOT EXISTS service_catalog (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    code                text NOT NULL,
    name                text NOT NULL,
    category            text,
    description         text,
    default_price       numeric(12,2) NOT NULL DEFAULT 0,
    default_vat_rate    numeric(5,2) NOT NULL DEFAULT 0,
    active              boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT service_catalog_code_not_empty CHECK (length(trim(code)) > 0),
    CONSTRAINT service_catalog_name_not_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT service_catalog_default_price_non_negative CHECK (default_price >= 0),
    CONSTRAINT service_catalog_default_vat_rate_range CHECK (default_vat_rate >= 0 AND default_vat_rate <= 100),
    CONSTRAINT service_catalog_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT ux_service_catalog_clinic_code UNIQUE (clinic_id, code)
);

CREATE INDEX IF NOT EXISTS ix_service_catalog_clinic_active_category
ON service_catalog (clinic_id, active, category);

DROP TRIGGER IF EXISTS trg_service_catalog_updated_at ON service_catalog;

CREATE TRIGGER trg_service_catalog_updated_at
BEFORE UPDATE ON service_catalog
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- PIANI DI CURA
-- =========================================================

CREATE TABLE IF NOT EXISTS treatment_plans (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid NOT NULL,
    name                    text NOT NULL DEFAULT 'Piano di cura',
    description             text,
    status                  treatment_plan_status NOT NULL DEFAULT 'draft',
    created_by_provider_id  uuid,
    proposed_at             timestamptz,
    accepted_at             timestamptz,
    completed_at            timestamptz,
    rejected_at             timestamptz,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT treatment_plans_name_not_empty CHECK (length(trim(name)) > 0),
    CONSTRAINT treatment_plans_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT fk_treatment_plans_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_treatment_plans_provider
        FOREIGN KEY (created_by_provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_treatment_plans_clinic_patient_status
ON treatment_plans (clinic_id, patient_id, status);

CREATE INDEX IF NOT EXISTS ix_treatment_plans_status_updated
ON treatment_plans (clinic_id, status, updated_at DESC);

DROP TRIGGER IF EXISTS trg_treatment_plans_updated_at ON treatment_plans;

CREATE TRIGGER trg_treatment_plans_updated_at
BEFORE UPDATE ON treatment_plans
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS treatment_plan_items (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    treatment_plan_id   uuid NOT NULL,
    service_id          uuid NOT NULL,
    provider_id         uuid,
    tooth_number        text,                 -- es. 16, 36, 11; lasciare NULL per prestazioni non legate a dente
    quadrant            smallint,             -- 1-4, opzionale
    surfaces            text[],               -- es. ARRAY['O','M','D']
    quantity            numeric(10,2) NOT NULL DEFAULT 1,
    planned_price       numeric(12,2) NOT NULL DEFAULT 0,
    planned_vat_rate    numeric(5,2) NOT NULL DEFAULT 0,
    clinical_notes      text,
    status              treatment_item_status NOT NULL DEFAULT 'planned',
    priority            integer NOT NULL DEFAULT 100,
    planned_date        date,
    completed_at        timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT treatment_plan_items_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT treatment_plan_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT treatment_plan_items_price_non_negative CHECK (planned_price >= 0),
    CONSTRAINT treatment_plan_items_vat_rate_range CHECK (planned_vat_rate >= 0 AND planned_vat_rate <= 100),
    CONSTRAINT treatment_plan_items_quadrant_range CHECK (quadrant IS NULL OR quadrant BETWEEN 1 AND 4),
    CONSTRAINT fk_treatment_plan_items_plan
        FOREIGN KEY (treatment_plan_id, clinic_id)
        REFERENCES treatment_plans(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_treatment_plan_items_service
        FOREIGN KEY (service_id, clinic_id)
        REFERENCES service_catalog(id, clinic_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_treatment_plan_items_provider
        FOREIGN KEY (provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_plan_status
ON treatment_plan_items (clinic_id, treatment_plan_id, status, priority);

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_service
ON treatment_plan_items (clinic_id, service_id);

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_provider
ON treatment_plan_items (clinic_id, provider_id)
WHERE provider_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_treatment_plan_items_updated_at ON treatment_plan_items;

CREATE TRIGGER trg_treatment_plan_items_updated_at
BEFORE UPDATE ON treatment_plan_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- PREVENTIVI
-- =========================================================

CREATE TABLE IF NOT EXISTS estimates (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id          uuid NOT NULL,
    treatment_plan_id   uuid,
    estimate_number     text NOT NULL,
    version             integer NOT NULL DEFAULT 1,
    status              estimate_status NOT NULL DEFAULT 'draft',
    title               text NOT NULL DEFAULT 'Preventivo',
    notes               text,
    currency            char(3) NOT NULL DEFAULT 'EUR',
    subtotal_amount     numeric(12,2) NOT NULL DEFAULT 0, -- somma righe prima degli sconti
    discount_amount     numeric(12,2) NOT NULL DEFAULT 0, -- somma sconti riga
    taxable_amount      numeric(12,2) NOT NULL DEFAULT 0, -- imponibile dopo sconti
    vat_amount          numeric(12,2) NOT NULL DEFAULT 0, -- iva totale, se applicata
    total_amount        numeric(12,2) NOT NULL DEFAULT 0, -- totale finale
    issued_at           timestamptz,
    sent_at             timestamptz,
    valid_until         date,
    accepted_at         timestamptz,
    rejected_at         timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT estimates_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT estimates_version_positive CHECK (version > 0),
    CONSTRAINT estimates_amounts_non_negative CHECK (
        subtotal_amount >= 0 AND
        discount_amount >= 0 AND
        taxable_amount >= 0 AND
        vat_amount >= 0 AND
        total_amount >= 0
    ),
    CONSTRAINT estimates_currency_upper CHECK (currency = upper(currency)),
    CONSTRAINT fk_estimates_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_estimates_treatment_plan
        FOREIGN KEY (treatment_plan_id, clinic_id)
        REFERENCES treatment_plans(id, clinic_id)
        ON DELETE RESTRICT,
    CONSTRAINT ux_estimates_clinic_number UNIQUE (clinic_id, estimate_number),
    CONSTRAINT ux_estimates_plan_version UNIQUE (clinic_id, treatment_plan_id, version)
);

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_patient_status
ON estimates (clinic_id, patient_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_plan_status
ON estimates (clinic_id, treatment_plan_id, status)
WHERE treatment_plan_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimates_updated_at ON estimates;

CREATE TRIGGER trg_estimates_updated_at
BEFORE UPDATE ON estimates
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS estimate_lines (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    estimate_id             uuid NOT NULL,
    treatment_plan_item_id  uuid,
    service_id              uuid,
    line_position           integer NOT NULL DEFAULT 1,
    description_snapshot    text NOT NULL,
    tooth_snapshot          text,
    quantity                numeric(10,2) NOT NULL DEFAULT 1,
    unit_price              numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount         numeric(12,2) NOT NULL DEFAULT 0,
    vat_rate                numeric(5,2) NOT NULL DEFAULT 0,
    line_subtotal           numeric(12,2) GENERATED ALWAYS AS (
        round(quantity * unit_price, 2)
    ) STORED,
    line_taxable            numeric(12,2) GENERATED ALWAYS AS (
        round(GREATEST(quantity * unit_price - discount_amount, 0), 2)
    ) STORED,
    line_vat_amount         numeric(12,2) GENERATED ALWAYS AS (
        round(GREATEST(quantity * unit_price - discount_amount, 0) * vat_rate / 100, 2)
    ) STORED,
    line_total              numeric(12,2) GENERATED ALWAYS AS (
        round(
            GREATEST(quantity * unit_price - discount_amount, 0) +
            GREATEST(quantity * unit_price - discount_amount, 0) * vat_rate / 100,
            2
        )
    ) STORED,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT estimate_lines_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT estimate_lines_description_not_empty CHECK (length(trim(description_snapshot)) > 0),
    CONSTRAINT estimate_lines_position_positive CHECK (line_position > 0),
    CONSTRAINT estimate_lines_quantity_positive CHECK (quantity > 0),
    CONSTRAINT estimate_lines_unit_price_non_negative CHECK (unit_price >= 0),
    CONSTRAINT estimate_lines_discount_non_negative CHECK (discount_amount >= 0),
    CONSTRAINT estimate_lines_vat_rate_range CHECK (vat_rate >= 0 AND vat_rate <= 100),
    CONSTRAINT fk_estimate_lines_estimate
        FOREIGN KEY (estimate_id, clinic_id)
        REFERENCES estimates(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_estimate_lines_treatment_item
        FOREIGN KEY (treatment_plan_item_id, clinic_id)
        REFERENCES treatment_plan_items(id, clinic_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_estimate_lines_service
        FOREIGN KEY (service_id, clinic_id)
        REFERENCES service_catalog(id, clinic_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_estimate_lines_estimate_position
ON estimate_lines (clinic_id, estimate_id, line_position);

CREATE INDEX IF NOT EXISTS ix_estimate_lines_treatment_item
ON estimate_lines (clinic_id, treatment_plan_item_id)
WHERE treatment_plan_item_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimate_lines_updated_at ON estimate_lines;

CREATE TRIGGER trg_estimate_lines_updated_at
BEFORE UPDATE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- TRIGGER: ricalcolo automatico dei totali del preventivo
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

    -- Se non ci sono righe, azzera il preventivo.
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
-- VISTE UTILI
-- =========================================================

CREATE OR REPLACE VIEW v_treatment_plan_summary AS
SELECT
    tp.id AS treatment_plan_id,
    tp.clinic_id,
    tp.patient_id,
    tp.name,
    tp.status,
    COUNT(tpi.id) AS items_count,
    COUNT(tpi.id) FILTER (WHERE tpi.status = 'completed') AS completed_items_count,
    COALESCE(round(SUM(tpi.quantity * tpi.planned_price), 2), 0) AS planned_total_amount,
    tp.created_at,
    tp.updated_at
FROM treatment_plans tp
LEFT JOIN treatment_plan_items tpi
    ON tpi.treatment_plan_id = tp.id
   AND tpi.clinic_id = tp.clinic_id
GROUP BY tp.id, tp.clinic_id, tp.patient_id, tp.name, tp.status, tp.created_at, tp.updated_at;

CREATE OR REPLACE VIEW v_patient_estimates AS
SELECT
    e.id AS estimate_id,
    e.clinic_id,
    e.patient_id,
    p.last_name,
    p.first_name,
    e.treatment_plan_id,
    e.estimate_number,
    e.version,
    e.status,
    e.currency,
    e.subtotal_amount,
    e.discount_amount,
    e.taxable_amount,
    e.vat_amount,
    e.total_amount,
    e.valid_until,
    e.created_at,
    e.updated_at
FROM estimates e
JOIN patients p
  ON p.id = e.patient_id
 AND p.clinic_id = e.clinic_id;

-- =========================================================
-- DATI DI ESEMPIO OPZIONALI
-- =========================================================

-- Esempio rapido:
-- INSERT INTO clinics (name, email, city) VALUES ('Studio Dentistico DentalCare', 'info@dentalcare.test', 'Roma');
-- INSERT INTO service_catalog (clinic_id, code, name, category, default_price)
-- SELECT id, 'IGIENE', 'Igiene orale professionale', 'Igiene', 80.00 FROM clinics WHERE name = 'Studio Dentistico DentalCare';
-- INSERT INTO service_catalog (clinic_id, code, name, category, default_price)
-- SELECT id, 'OTT-COMP', 'Otturazione in composito', 'Conservativa', 120.00 FROM clinics WHERE name = 'Studio Dentistico DentalCare';
-- INSERT INTO service_catalog (clinic_id, code, name, category, default_price)
-- SELECT id, 'COR-ZIR', 'Corona in zirconia', 'Protesi', 650.00 FROM clinics WHERE name = 'Studio Dentistico DentalCare';

COMMIT;
