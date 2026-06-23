--
-- PostgreSQL database dump
--

\restrict lNAdE5IhYi17M1sN2xgfhCuIzN8zuHt8fQas73pWLY45tqDAQ4azNGnYO7YJ260

-- Dumped from database version 15.18 (Debian 15.18-0+deb12u1)
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: dentalcare; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA dentalcare;


--
-- Name: t_9d754153; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA t_9d754153;


--
-- Name: appointment_status; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.appointment_status AS ENUM (
    'scheduled',
    'confirmed',
    'presente',
    'in_progress',
    'completed',
    'cancelled',
    'no_show'
);


--
-- Name: document_type; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.document_type AS ENUM (
    'rx_endorale',
    'rx_panoramica',
    'cbct',
    'foto_clinica',
    'foto_extraorale',
    'documento_amministrativo',
    'consenso_informato',
    'referto',
    'altro'
);


--
-- Name: estimate_status; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.estimate_status AS ENUM (
    'draft',
    'sent',
    'accepted',
    'rejected',
    'expired',
    'cancelled'
);


--
-- Name: invoice_document_type; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.invoice_document_type AS ENUM (
    'fattura',
    'ricevuta',
    'parcella',
    'nota_credito'
);


--
-- Name: invoice_issuer_type; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.invoice_issuer_type AS ENUM (
    'clinic',
    'provider'
);


--
-- Name: invoice_status; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.invoice_status AS ENUM (
    'draft',
    'issued',
    'paid',
    'cancelled'
);


--
-- Name: provider_role; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.provider_role AS ENUM (
    'dentist',
    'hygienist',
    'orthodontist',
    'surgeon',
    'assistant',
    'admin',
    'other',
    'tenant_admin',
    'secretary'
);


--
-- Name: recall_contact_type; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.recall_contact_type AS ENUM (
    'telefono',
    'sms',
    'email',
    'whatsapp'
);


--
-- Name: recall_outcome; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.recall_outcome AS ENUM (
    'risposto',
    'non_risposto',
    'messaggio_lasciato',
    'confermato',
    'rifiutato'
);


--
-- Name: recall_priority; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.recall_priority AS ENUM (
    'alta',
    'media',
    'bassa'
);


--
-- Name: recall_status; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.recall_status AS ENUM (
    'da_contattare',
    'contattato',
    'in_attesa',
    'confermato',
    'chiuso',
    'annullato'
);


--
-- Name: stock_movement_type; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.stock_movement_type AS ENUM (
    'carico',
    'scarico',
    'rettifica',
    'rientro'
);


--
-- Name: tooth_condition; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.tooth_condition AS ENUM (
    'healthy',
    'caries',
    'filling',
    'crown',
    'missing',
    'implant',
    'devitalized',
    'fracture',
    'to_extract',
    'bridge_anchor'
);


--
-- Name: treatment_item_status; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.treatment_item_status AS ENUM (
    'planned',
    'accepted',
    'scheduled',
    'completed',
    'cancelled'
);


--
-- Name: treatment_plan_status; Type: TYPE; Schema: dentalcare; Owner: -
--

CREATE TYPE dentalcare.treatment_plan_status AS ENUM (
    'draft',
    'proposed',
    'accepted',
    'in_progress',
    'completed',
    'rejected',
    'archived'
);


--
-- Name: compute_recall_priority(date); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.compute_recall_priority(p_due_date date) RETURNS dentalcare.recall_priority
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    IF p_due_date < current_date THEN
        RETURN 'alta'::dentalcare.recall_priority;
    ELSIF p_due_date <= current_date + interval '30 days' THEN
        RETURN 'media'::dentalcare.recall_priority;
    ELSE
        RETURN 'bassa'::dentalcare.recall_priority;
    END IF;
END;
$$;


--
-- Name: create_tenant(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, text, text); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.create_tenant(p_tenant_id uuid, p_clinic_id uuid, p_schema text, p_studio_name text, p_email text, p_phone text, p_plan text, p_vat text, p_address text, p_city text, p_province text, p_admin_first text, p_admin_last text, p_admin_email text, p_admin_pw_hash text) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$
DECLARE
    l_admin_id uuid := gen_random_uuid();
    l_ddl      text;
BEGIN
    IF p_schema !~ '^t_[0-9a-f]{8}$' THEN
        RAISE EXCEPTION 'Invalid schema name: %', p_schema;
    END IF;
    IF EXISTS (SELECT 1 FROM dentalcare.tenants WHERE schema_name = p_schema) THEN
        RAISE EXCEPTION 'Schema already registered: %', p_schema;
    END IF;
    IF p_admin_pw_hash IS NULL OR length(p_admin_pw_hash) = 0 THEN
        RAISE EXCEPTION 'admin password hash required';
    END IF;

    -- 1) schema
    EXECUTE format('CREATE SCHEMA %I', p_schema);

    -- 2) tutto il DDL dello schema (tabelle, viste, funzioni, trigger)
    l_ddl := 'SET LOCAL search_path TO ' || quote_ident(p_schema) || ', dentalcare, public;
'
    ||
$ddl$

-- =============================================================================
-- FUNZIONE DI SERVIZIO
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 1. CLINICS
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinics (
    id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name             text        NOT NULL,
    legal_name       text,
    vat_number       text,
    fiscal_code      text,
    phone            text,
    email            citext,
    address_line1    text,
    address_line2    text,
    city             text,
    province         text,
    postal_code      text,
    country          text        NOT NULL DEFAULT 'IT',
    timezone         text        NOT NULL DEFAULT 'Europe/Rome',
    opening_time     time        NOT NULL DEFAULT '08:00',
    closing_time     time        NOT NULL DEFAULT '20:00',
    slot_minutes     integer     NOT NULL DEFAULT 30 CHECK (slot_minutes > 0),
    invoice_prefix   text        NOT NULL DEFAULT 'FC',
    invoice_counter  integer     NOT NULL DEFAULT 0 CHECK (invoice_counter >= 0),
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT clinics_name_not_empty CHECK (length(trim(name)) > 0)
) TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_clinics_updated_at ON clinics;
CREATE TRIGGER trg_clinics_updated_at
BEFORE UPDATE ON clinics
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 2. PATIENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patients (
    id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id     uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    first_name    text    NOT NULL,
    last_name     text    NOT NULL,
    fiscal_code   text,
    birth_date    date,
    gender        char(1) CHECK (gender IN ('M', 'F', 'X')),
    phone         text,
    email         citext,
    address_line1 text,
    city          text,
    province      text,
    postal_code   text,
    country       text    NOT NULL DEFAULT 'IT',
    notes         text,
    primary_provider_id uuid,
    active        boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patients_first_name_not_empty CHECK (length(trim(first_name)) > 0),
    CONSTRAINT patients_last_name_not_empty  CHECK (length(trim(last_name)) > 0),
    CONSTRAINT patients_id_clinic_uq         UNIQUE (id, clinic_id)
) TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS ux_patients_clinic_fiscal_code
    ON patients (clinic_id, fiscal_code)
    TABLESPACE pg_default
    WHERE fiscal_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_patients_clinic_name
    ON patients (clinic_id, last_name, first_name)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_patients_updated_at ON patients;
CREATE TRIGGER trg_patients_updated_at
BEFORE UPDATE ON patients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 3. PROVIDERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS providers (
    id                   uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id            uuid          NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    first_name           text          NOT NULL,
    last_name            text          NOT NULL,
    role                 provider_role NOT NULL,
    specialization       text,
    fiscal_code          text,
    phone                text,
    email                citext,
    license_number       text,
    color_hex            char(7)       NOT NULL DEFAULT '#4F46E5',
    active               boolean       NOT NULL DEFAULT true,
    vat_number           text,
    billing_address      text,
    billing_city         text,
    billing_province     text,
    billing_postal_code  text,
    billing_country      text          NOT NULL DEFAULT 'IT',
    password_hash        text,
    password_temporary   boolean       NOT NULL DEFAULT false,
    created_at           timestamptz   NOT NULL DEFAULT now(),
    updated_at           timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT providers_first_name_not_empty CHECK (length(trim(first_name)) > 0),
    CONSTRAINT providers_last_name_not_empty  CHECK (length(trim(last_name)) > 0),
    CONSTRAINT providers_color_hex_format     CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    CONSTRAINT providers_id_clinic_uq         UNIQUE (id, clinic_id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_providers_clinic_role_active
    ON providers (clinic_id, role)
    TABLESPACE pg_default
    WHERE active = true;

DROP TRIGGER IF EXISTS trg_providers_updated_at ON providers;
CREATE TRIGGER trg_providers_updated_at
BEFORE UPDATE ON providers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Medico di riferimento del paziente (FK aggiunta qui: providers creata sopra)
ALTER TABLE patients
    DROP CONSTRAINT IF EXISTS patients_primary_provider_id_fkey;
ALTER TABLE patients
    ADD CONSTRAINT patients_primary_provider_id_fkey
        FOREIGN KEY (primary_provider_id) REFERENCES providers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_patients_primary_provider
    ON patients (clinic_id, primary_provider_id)
    TABLESPACE pg_default
    WHERE primary_provider_id IS NOT NULL;

-- =============================================================================
-- 4. SERVICE_CATALOG
-- =============================================================================

CREATE TABLE IF NOT EXISTS service_catalog (
    id                       uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id                uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    code                     text    NOT NULL,
    name                     text    NOT NULL,
    description              text,
    category                 text,
    default_price            numeric(12,2) NOT NULL DEFAULT 0 CHECK (default_price >= 0),
    duration_minutes         integer NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
    min_tooth_digit          integer,
    max_tooth_digit          integer,
    applicable_to_deciduous  boolean NOT NULL DEFAULT true,
    is_active                boolean NOT NULL DEFAULT true,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT service_catalog_code_not_empty CHECK (length(trim(code)) > 0),
    CONSTRAINT service_catalog_name_not_empty CHECK (length(trim(name)) > 0),
    UNIQUE (clinic_id, code)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_service_catalog_clinic_active_cat
    ON service_catalog (clinic_id, is_active, category)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_service_catalog_updated_at ON service_catalog;
CREATE TRIGGER trg_service_catalog_updated_at
BEFORE UPDATE ON service_catalog
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 5. TREATMENT_PLANS
-- =============================================================================

CREATE TABLE IF NOT EXISTS treatment_plans (
    id          uuid                   PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id   uuid                   NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id  uuid                   NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    provider_id uuid                   REFERENCES providers(id) ON DELETE SET NULL,
    title       text                   NOT NULL DEFAULT 'Piano di cura',
    description text,
    status      treatment_plan_status  NOT NULL DEFAULT 'draft',
    version     integer                NOT NULL DEFAULT 1 CHECK (version > 0),
    notes       text,
    created_at  timestamptz            NOT NULL DEFAULT now(),
    updated_at  timestamptz            NOT NULL DEFAULT now(),
    CONSTRAINT treatment_plans_title_not_empty CHECK (length(trim(title)) > 0)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_treatment_plans_clinic_patient
    ON treatment_plans (clinic_id, patient_id, status)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_treatment_plans_updated_at ON treatment_plans;
CREATE TRIGGER trg_treatment_plans_updated_at
BEFORE UPDATE ON treatment_plans
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 6. TREATMENT_PLAN_ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS treatment_plan_items (
    id                  uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid                  NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    plan_id             uuid                  NOT NULL REFERENCES treatment_plans(id) ON DELETE CASCADE,
    service_catalog_id  uuid                  REFERENCES service_catalog(id) ON DELETE SET NULL,
    tooth_fdi           text,
    surfaces            text[],
    description         text                  NOT NULL,
    price               numeric(12,2)         NOT NULL DEFAULT 0 CHECK (price >= 0),
    status              treatment_item_status NOT NULL DEFAULT 'planned',
    sort_order          integer               NOT NULL DEFAULT 0,
    completed_at        timestamptz,
    created_at          timestamptz           NOT NULL DEFAULT now(),
    updated_at          timestamptz           NOT NULL DEFAULT now(),
    CONSTRAINT treatment_plan_items_description_not_empty CHECK (length(trim(description)) > 0)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_plan
    ON treatment_plan_items (plan_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_clinic_status
    ON treatment_plan_items (clinic_id, status)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_treatment_plan_items_updated_at ON treatment_plan_items;
CREATE TRIGGER trg_treatment_plan_items_updated_at
BEFORE UPDATE ON treatment_plan_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 7. APPOINTMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS appointments (
    id                      uuid               PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid               NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid               REFERENCES patients(id) ON DELETE SET NULL,
    provider_id             uuid               REFERENCES providers(id) ON DELETE SET NULL,
    treatment_plan_item_id  uuid               REFERENCES treatment_plan_items(id) ON DELETE SET NULL,
    chair_label             text,
    starts_at               timestamptz        NOT NULL,
    ends_at                 timestamptz        NOT NULL,
    status                  appointment_status NOT NULL DEFAULT 'scheduled',
    notes                   text,
    created_at              timestamptz        NOT NULL DEFAULT now(),
    updated_at              timestamptz        NOT NULL DEFAULT now(),
    CONSTRAINT appointments_dates_valid CHECK (ends_at > starts_at)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_starts
    ON appointments (clinic_id, starts_at)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_provider_starts
    ON appointments (clinic_id, provider_id, starts_at)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_patient
    ON appointments (clinic_id, patient_id)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 8. ESTIMATES
-- =============================================================================

CREATE TABLE IF NOT EXISTS estimates (
    id                      uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid            REFERENCES patients(id) ON DELETE SET NULL,
    provider_id             uuid            REFERENCES providers(id) ON DELETE SET NULL,
    created_by_provider_id  uuid            REFERENCES providers(id) ON DELETE SET NULL,
    treatment_plan_id       uuid            REFERENCES treatment_plans(id) ON DELETE SET NULL,
    estimate_number         text,
    version                 integer         NOT NULL DEFAULT 1 CHECK (version > 0),
    status                  estimate_status NOT NULL DEFAULT 'draft',
    title                   text,
    notes                   text,
    currency                text            NOT NULL DEFAULT 'EUR',
    valid_until             date,
    subtotal_amount         numeric(12,2)   NOT NULL DEFAULT 0 CHECK (subtotal_amount >= 0),
    discount_amount         numeric(12,2)   NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    taxable_amount          numeric(12,2)   NOT NULL DEFAULT 0 CHECK (taxable_amount >= 0),
    vat_amount              numeric(12,2)   NOT NULL DEFAULT 0 CHECK (vat_amount >= 0),
    total_amount            numeric(12,2)   NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    issued_at               timestamptz,
    sent_at                 timestamptz,
    accepted_at             timestamptz,
    rejected_at             timestamptz,
    created_at              timestamptz     NOT NULL DEFAULT now(),
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    CONSTRAINT estimates_id_clinic_uq       UNIQUE (id, clinic_id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_patient
    ON estimates (clinic_id, patient_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_status
    ON estimates (clinic_id, status)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_provider
    ON estimates (clinic_id, created_by_provider_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_plan
    ON estimates (clinic_id, treatment_plan_id)
    TABLESPACE pg_default
    WHERE treatment_plan_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimates_updated_at ON estimates;
CREATE TRIGGER trg_estimates_updated_at
BEFORE UPDATE ON estimates
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 9. ESTIMATE_LINES
-- =============================================================================

CREATE TABLE IF NOT EXISTS estimate_lines (
    id                      uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    estimate_id             uuid          NOT NULL REFERENCES estimates(id) ON DELETE CASCADE,
    clinic_id               uuid          NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    treatment_plan_item_id  uuid          REFERENCES treatment_plan_items(id) ON DELETE SET NULL,
    service_id              uuid          REFERENCES service_catalog(id) ON DELETE SET NULL,
    description_snapshot    text          NOT NULL,
    tooth_snapshot          text,
    surfaces                text[],
    line_position           integer       NOT NULL DEFAULT 10,
    quantity                integer       NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price              numeric(12,2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    discount_amount         numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    vat_rate                numeric(5,2)  NOT NULL DEFAULT 0,
    line_subtotal           numeric(12,2) NOT NULL DEFAULT 0 CHECK (line_subtotal >= 0),
    line_taxable            numeric(12,2) NOT NULL DEFAULT 0 CHECK (line_taxable >= 0),
    line_vat_amount         numeric(12,2) NOT NULL DEFAULT 0 CHECK (line_vat_amount >= 0),
    line_total              numeric(12,2) NOT NULL DEFAULT 0 CHECK (line_total >= 0),
    created_at              timestamptz   NOT NULL DEFAULT now(),
    updated_at              timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT estimate_lines_description_not_empty CHECK (length(trim(description_snapshot)) > 0)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_estimate_lines_estimate
    ON estimate_lines (estimate_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_estimate_lines_plan_item
    ON estimate_lines (clinic_id, treatment_plan_item_id)
    TABLESPACE pg_default
    WHERE treatment_plan_item_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimate_lines_updated_at ON estimate_lines;
CREATE TRIGGER trg_estimate_lines_updated_at
BEFORE UPDATE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 10. INVOICES
-- =============================================================================

CREATE TABLE IF NOT EXISTS invoices (
    id                  uuid                          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id           uuid                          NOT NULL,
    invoice_number      text,
    document_type       invoice_document_type         NOT NULL DEFAULT 'fattura',
    invoice_date        date                          NOT NULL DEFAULT CURRENT_DATE,
    due_date            date,
    status              invoice_status                NOT NULL DEFAULT 'draft',
    issuer_type         invoice_issuer_type           NOT NULL DEFAULT 'clinic',
    provider_id         uuid,
    patient_id          uuid                          NOT NULL,
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
    subtotal_amount     numeric(12,2)                 NOT NULL DEFAULT 0,
    discount_amount     numeric(12,2)                 NOT NULL DEFAULT 0,
    taxable_amount      numeric(12,2)                 NOT NULL DEFAULT 0,
    vat_amount          numeric(12,2)                 NOT NULL DEFAULT 0,
    total_amount        numeric(12,2)                 NOT NULL DEFAULT 0,
    currency            char(3)                       NOT NULL DEFAULT 'EUR',
    notes               text,
    payment_method      text,
    paid_at             timestamptz,
    issued_at           timestamptz,
    created_at          timestamptz                   NOT NULL DEFAULT now(),
    updated_at          timestamptz                   NOT NULL DEFAULT now(),
    CONSTRAINT invoices_pkey PRIMARY KEY (id),
    CONSTRAINT invoices_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT ux_invoices_number UNIQUE (clinic_id, invoice_number)
) TABLESPACE pg_default;

ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS invoices_clinic_id_fkey;
ALTER TABLE invoices
    ADD CONSTRAINT invoices_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS fk_invoices_patient;
ALTER TABLE invoices
    ADD CONSTRAINT fk_invoices_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS fk_invoices_provider;
ALTER TABLE invoices
    ADD CONSTRAINT fk_invoices_provider
        FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE invoices
    DROP CONSTRAINT IF EXISTS fk_invoices_estimate;
ALTER TABLE invoices
    ADD CONSTRAINT fk_invoices_estimate
        FOREIGN KEY (estimate_id, clinic_id) REFERENCES estimates(id, clinic_id)
        ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE INDEX IF NOT EXISTS ix_invoices_clinic_status
    ON invoices (clinic_id, status, invoice_date DESC)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_invoices_patient
    ON invoices (clinic_id, patient_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_invoices_estimate
    ON invoices (clinic_id, estimate_id)
    TABLESPACE pg_default
    WHERE estimate_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_invoices_provider
    ON invoices (clinic_id, provider_id)
    TABLESPACE pg_default
    WHERE provider_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_invoices_set_updated_at ON invoices;
CREATE TRIGGER trg_invoices_set_updated_at
BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 11. INVOICE_LINES
-- =============================================================================

CREATE TABLE IF NOT EXISTS invoice_lines (
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
    CONSTRAINT invoice_lines_description_not_empty CHECK (length(trim(description)) > 0)
) TABLESPACE pg_default;

ALTER TABLE invoice_lines
    DROP CONSTRAINT IF EXISTS fk_invoice_lines_invoice;
ALTER TABLE invoice_lines
    ADD CONSTRAINT fk_invoice_lines_invoice
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;

ALTER TABLE invoice_lines
    DROP CONSTRAINT IF EXISTS fk_invoice_lines_clinic;
ALTER TABLE invoice_lines
    ADD CONSTRAINT fk_invoice_lines_clinic
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_invoice_lines_invoice
    ON invoice_lines (invoice_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_invoice_lines_clinic
    ON invoice_lines (clinic_id)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_invoice_lines_updated_at ON invoice_lines;
CREATE TRIGGER trg_invoice_lines_updated_at
BEFORE UPDATE ON invoice_lines
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 12. PATIENT_ANAMNESIS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_anamnesis (
    id                       uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id                uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id               uuid    NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    recorded_by_provider_id  uuid    REFERENCES providers(id) ON DELETE SET NULL,
    blood_type               text,
    smoker                   boolean NOT NULL DEFAULT false,
    cigarettes_per_day       integer,
    alcohol_use              text,
    hypertension             boolean NOT NULL DEFAULT false,
    diabetes                 boolean NOT NULL DEFAULT false,
    heart_disease            boolean NOT NULL DEFAULT false,
    coagulopathy             boolean NOT NULL DEFAULT false,
    taking_anticoagulants    boolean NOT NULL DEFAULT false,
    taking_bisphosphonates   boolean NOT NULL DEFAULT false,
    taking_cortisone         boolean NOT NULL DEFAULT false,
    current_medications      text,
    allergy_penicillin       boolean NOT NULL DEFAULT false,
    allergy_latex            boolean NOT NULL DEFAULT false,
    allergy_anesthetic       boolean NOT NULL DEFAULT false,
    allergy_aspirin          boolean NOT NULL DEFAULT false,
    other_allergies          text,
    pregnancy                boolean NOT NULL DEFAULT false,
    pacemaker                boolean NOT NULL DEFAULT false,
    hepatitis                boolean NOT NULL DEFAULT false,
    hiv_positive             boolean NOT NULL DEFAULT false,
    osteoporosis             boolean NOT NULL DEFAULT false,
    asthma                   boolean NOT NULL DEFAULT false,
    epilepsy                 boolean NOT NULL DEFAULT false,
    kidney_disease           boolean NOT NULL DEFAULT false,
    notes                    text,
    is_current               boolean NOT NULL DEFAULT true,
    recorded_at              timestamptz NOT NULL DEFAULT now(),
    created_at               timestamptz NOT NULL DEFAULT now()
) TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_anamnesis_current
    ON patient_anamnesis (clinic_id, patient_id)
    TABLESPACE pg_default
    WHERE is_current = true;

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_patient
    ON patient_anamnesis (clinic_id, patient_id)
    TABLESPACE pg_default;

-- =============================================================================
-- 13. PATIENT_ANAMNESIS_ITEM_SELECTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_anamnesis_item_selections (
    id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    anamnesis_id      uuid    NOT NULL REFERENCES patient_anamnesis(id) ON DELETE CASCADE,
    anamnesis_item_id uuid    NOT NULL REFERENCES dentalcare.anamnesis_items(id),
    detail_text       text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (anamnesis_id, anamnesis_item_id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_item_selections_anamnesis
    ON patient_anamnesis_item_selections (anamnesis_id)
    TABLESPACE pg_default;

-- =============================================================================
-- 14. ODONTOGRAM_TEETH
-- =============================================================================

CREATE TABLE IF NOT EXISTS odontogram_teeth (
    id                      uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid            NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    tooth_fdi               text            NOT NULL,
    condition               tooth_condition NOT NULL DEFAULT 'healthy',
    surfaces                text[],
    notes                   text,
    recorded_at             timestamptz     NOT NULL DEFAULT now(),
    recorded_by_provider_id uuid            REFERENCES providers(id) ON DELETE SET NULL,
    created_at              timestamptz     NOT NULL DEFAULT now(),
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    UNIQUE (clinic_id, patient_id, tooth_fdi)
) TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_odontogram_teeth_updated_at ON odontogram_teeth;
CREATE TRIGGER trg_odontogram_teeth_updated_at
BEFORE UPDATE ON odontogram_teeth
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 15. TOOTH_CONDITIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS tooth_conditions (
    id           uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id    uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id   uuid            NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    provider_id  uuid            REFERENCES providers(id) ON DELETE SET NULL,
    tooth_fdi    text            NOT NULL,
    surface      text,
    condition    tooth_condition NOT NULL,
    detected_at  date            NOT NULL DEFAULT CURRENT_DATE,
    resolved_at  date,
    notes        text,
    created_at   timestamptz     NOT NULL DEFAULT now()
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_tooth_conditions_clinic_patient
    ON tooth_conditions (clinic_id, patient_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_tooth_conditions_clinic_tooth
    ON tooth_conditions (clinic_id, tooth_fdi)
    TABLESPACE pg_default;

-- =============================================================================
-- 16. CLINICAL_HISTORY_ENTRIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical_history_entries (
    id             uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id      uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id     uuid    NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    provider_id    uuid    REFERENCES providers(id) ON DELETE SET NULL,
    appointment_id uuid    REFERENCES appointments(id) ON DELETE SET NULL,
    entry_type     text    NOT NULL DEFAULT 'note',
    title          text,
    body           text    NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT clinical_history_entries_body_not_empty CHECK (length(trim(body)) > 0)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_clinical_history_entries_clinic_patient
    ON clinical_history_entries (clinic_id, patient_id)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_clinical_history_entries_updated_at ON clinical_history_entries;
CREATE TRIGGER trg_clinical_history_entries_updated_at
BEFORE UPDATE ON clinical_history_entries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 17. PATIENT_DOCUMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_documents (
    id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id     uuid          NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id    uuid          NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    provider_id   uuid          REFERENCES providers(id) ON DELETE SET NULL,
    document_type document_type NOT NULL DEFAULT 'altro',
    title         text          NOT NULL,
    file_path     text,
    mime_type     text,
    size_bytes    bigint,
    notes         text,
    created_at    timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT patient_documents_title_not_empty CHECK (length(trim(title)) > 0)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_patient_documents_clinic_patient
    ON patient_documents (clinic_id, patient_id)
    TABLESPACE pg_default;

-- =============================================================================
-- 18. SUPPLIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS suppliers (
    id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id    uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    name         text    NOT NULL,
    contact_name text,
    phone        text,
    email        citext,
    address      text,
    vat_number   text,
    notes        text,
    active       boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT suppliers_name_not_empty CHECK (length(trim(name)) > 0)
) TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_suppliers_updated_at ON suppliers;
CREATE TRIGGER trg_suppliers_updated_at
BEFORE UPDATE ON suppliers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 19. PRODUCT_CATEGORIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS product_categories (
    id         uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id  uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    name       text    NOT NULL,
    color_hex  char(7) NOT NULL DEFAULT '#6B7280',
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (clinic_id, name)
) TABLESPACE pg_default;

-- =============================================================================
-- 20. PRODUCTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS products (
    id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id         uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    supplier_id       uuid    REFERENCES suppliers(id) ON DELETE SET NULL,
    category_id       uuid    REFERENCES product_categories(id) ON DELETE SET NULL,
    sku               text,
    name              text    NOT NULL,
    description       text,
    unit              text    NOT NULL DEFAULT 'pz',
    min_stock_quantity numeric(12,2) NOT NULL DEFAULT 0 CHECK (min_stock_quantity >= 0),
    reorder_quantity   numeric(12,2) NOT NULL DEFAULT 0 CHECK (reorder_quantity >= 0),
    unit_cost          numeric(12,2) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
    is_active          boolean NOT NULL DEFAULT true,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT products_name_not_empty CHECK (length(trim(name)) > 0)
) TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS ux_products_clinic_sku
    ON products (clinic_id, sku)
    TABLESPACE pg_default
    WHERE sku IS NOT NULL;

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 21. STOCK_MOVEMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS stock_movements (
    id                     uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id              uuid                NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    product_id             uuid                NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    movement_type          stock_movement_type NOT NULL,
    quantity               integer             NOT NULL CHECK (quantity != 0),
    unit_cost              numeric(12,2)       NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
    reference_doc          text,
    notes                  text,
    moved_at               timestamptz         NOT NULL DEFAULT now(),
    created_by_provider_id uuid                REFERENCES providers(id) ON DELETE SET NULL,
    created_at             timestamptz         NOT NULL DEFAULT now()
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_stock_movements_clinic_product
    ON stock_movements (clinic_id, product_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_stock_movements_clinic_moved_at
    ON stock_movements (clinic_id, moved_at)
    TABLESPACE pg_default;

-- =============================================================================
-- 22. SERVICE_BUNDLE_ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS service_bundle_items (
    id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id         uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    parent_service_id uuid    NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    child_service_id  uuid    NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    quantity          integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
    sort_order        integer NOT NULL DEFAULT 0,
    created_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (parent_service_id, child_service_id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_service_bundle_items_bundle
    ON service_bundle_items (clinic_id, parent_service_id)
    TABLESPACE pg_default;

-- =============================================================================
-- 23. CONDITION_SERVICE_DEFAULTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS condition_service_defaults (
    id               uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id        uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    condition_name   tooth_condition NOT NULL,
    service_id       uuid            NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    sort_order       integer         NOT NULL DEFAULT 0,
    created_at       timestamptz     NOT NULL DEFAULT now(),
    UNIQUE (clinic_id, condition_name, service_id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_condition_service_defaults_condition
    ON condition_service_defaults (clinic_id, condition_name)
    TABLESPACE pg_default;

-- =============================================================================
-- 24. PATIENT_RECALLS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_recalls (
    id                      uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid            NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    provider_id             uuid            REFERENCES providers(id) ON DELETE SET NULL,
    source_appointment_id   uuid            REFERENCES appointments(id) ON DELETE SET NULL,
    recall_type             text            NOT NULL DEFAULT 'Controllo periodico',
    status                  recall_status   NOT NULL DEFAULT 'da_contattare',
    priority                recall_priority NOT NULL DEFAULT 'media',
    due_date                date            NOT NULL,
    contact_count           integer         NOT NULL DEFAULT 0,
    last_contact_at         date,
    completed_at            timestamptz,
    notes                   text,
    created_at              timestamptz     NOT NULL DEFAULT now(),
    updated_at              timestamptz     NOT NULL DEFAULT now()
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_patient_recalls_clinic_status
    ON patient_recalls (clinic_id, status)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_patient_recalls_clinic_patient
    ON patient_recalls (clinic_id, patient_id)
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_patient_recalls_clinic_due_date
    ON patient_recalls (clinic_id, due_date)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_patient_recalls_updated_at ON patient_recalls;
CREATE TRIGGER trg_patient_recalls_updated_at
BEFORE UPDATE ON patient_recalls
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 25. RECALL_CONTACTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS recall_contacts (
    id                       uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
    recall_id                uuid                NOT NULL REFERENCES patient_recalls(id) ON DELETE CASCADE,
    clinic_id                uuid                NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    contact_type             recall_contact_type NOT NULL,
    outcome                  recall_outcome,
    created_by_provider_id   uuid                REFERENCES providers(id) ON DELETE SET NULL,
    contact_at               timestamptz         NOT NULL DEFAULT now(),
    notes                    text,
    created_at               timestamptz         NOT NULL DEFAULT now()
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_recall_contacts_recall
    ON recall_contacts (recall_id)
    TABLESPACE pg_default;

-- =============================================================================
-- 26. AI_CONVERSATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id   uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id  uuid    REFERENCES patients(id) ON DELETE SET NULL,
    provider_id uuid    REFERENCES providers(id) ON DELETE SET NULL,
    title       text,
    messages    jsonb   NOT NULL DEFAULT '[]',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS ix_ai_conversations_clinic
    ON ai_conversations (clinic_id)
    TABLESPACE pg_default;

DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at ON ai_conversations;
CREATE TRIGGER trg_ai_conversations_updated_at
BEFORE UPDATE ON ai_conversations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- FUNZIONI DI CALCOLO AUTOMATICO
-- =============================================================================

CREATE OR REPLACE FUNCTION recalc_estimate_totals()
RETURNS trigger AS $$
DECLARE
    v_estimate_id uuid;
BEGIN
    PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
    v_estimate_id := COALESCE(NEW.estimate_id, OLD.estimate_id);
    UPDATE estimates
    SET
        subtotal       = COALESCE((SELECT SUM(unit_price * quantity)                       FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
        discount_total = COALESCE((SELECT SUM(unit_price * quantity * discount_pct / 100)  FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
        total          = COALESCE((SELECT SUM(line_total)                                  FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
        updated_at     = now()
    WHERE id = v_estimate_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recalc_estimate_totals ON estimate_lines;
CREATE TRIGGER trg_recalc_estimate_totals
AFTER INSERT OR UPDATE OR DELETE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION recalc_estimate_totals();

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

CREATE OR REPLACE FUNCTION trg_update_invoice_totals_from_lines()
RETURNS trigger AS $$
DECLARE
    v_invoice_id uuid;
BEGIN
    PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
    v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
    UPDATE invoices
    SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)   FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        discount_amount = COALESCE((SELECT SUM(discount_amount) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        taxable_amount  = COALESCE((SELECT SUM(line_taxable)    FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        vat_amount      = COALESCE((SELECT SUM(line_vat_amount) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        total_amount    = COALESCE((SELECT SUM(line_total)      FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        updated_at      = now()
    WHERE id = v_invoice_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_invoices_recalc_from_lines ON invoice_lines;
CREATE TRIGGER trg_invoices_recalc_from_lines
AFTER INSERT OR UPDATE OR DELETE ON invoice_lines
FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_totals_from_lines();

CREATE OR REPLACE FUNCTION compute_recall_priority(p_due_date date)
RETURNS recall_priority AS $$
BEGIN
    IF p_due_date < CURRENT_DATE THEN
        RETURN 'urgent';
    ELSIF p_due_date <= CURRENT_DATE + 7 THEN
        RETURN 'high';
    ELSIF p_due_date <= CURRENT_DATE + 30 THEN
        RETURN 'medium';
    ELSE
        RETURN 'low';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_recall_on_contact()
RETURNS trigger AS $$
BEGIN
    PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
    IF NEW.outcome = 'booked' THEN
        UPDATE patient_recalls
        SET status     = 'booked'::recall_status,
            updated_at = now()
        WHERE id = NEW.recall_id;
    ELSIF NEW.outcome IN ('refused', 'already_booked', 'scheduled_later') THEN
        UPDATE patient_recalls
        SET status       = 'completed'::recall_status,
            completed_at = now(),
            updated_at   = now()
        WHERE id = NEW.recall_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_recall_on_contact ON recall_contacts;
CREATE TRIGGER trg_update_recall_on_contact
AFTER INSERT ON recall_contacts
FOR EACH ROW EXECUTE FUNCTION update_recall_on_contact();

-- =============================================================================
-- DIAGNOSI, PRESCRIZIONI, CHAT (allineamento con migrazioni V13/V14/V22)
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_diagnoses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       UUID NOT NULL,
    patient_id      UUID NOT NULL,
    provider_id     UUID NOT NULL,
    tooth_number    VARCHAR(10),
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    icd_code        VARCHAR(20),
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
    diagnosed_at    DATE NOT NULL DEFAULT CURRENT_DATE,
    resolved_at     DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_patient_diagnoses_patient ON patient_diagnoses (clinic_id, patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_diagnoses_status  ON patient_diagnoses (clinic_id, patient_id, status);

CREATE TABLE IF NOT EXISTS patient_prescriptions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       UUID NOT NULL,
    patient_id      UUID NOT NULL,
    provider_id     UUID NOT NULL,
    drug_name       VARCHAR(255) NOT NULL,
    dosage          VARCHAR(100),
    frequency       VARCHAR(100),
    duration        VARCHAR(100),
    notes           TEXT,
    prescribed_at   DATE NOT NULL DEFAULT CURRENT_DATE,
    expires_at      DATE,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_patient_prescriptions_patient ON patient_prescriptions (clinic_id, patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_prescriptions_active  ON patient_prescriptions (clinic_id, patient_id, active);

CREATE TABLE IF NOT EXISTS chat_sessions (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id   UUID        NOT NULL,
    title         TEXT        NOT NULL,
    message_count INT         NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID        NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role       TEXT        NOT NULL CHECK (role IN ('user', 'assistant')),
    content    TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS chat_messages_session_idx  ON chat_messages(session_id);
CREATE INDEX IF NOT EXISTS chat_sessions_provider_idx ON chat_sessions(provider_id, created_at DESC);

-- =============================================================================
-- VISTE
-- =============================================================================

CREATE OR REPLACE VIEW v_patient_dashboard AS
SELECT
    p.id         AS patient_id,
    p.clinic_id,
    p.first_name AS patient_first_name,
    p.last_name  AS patient_last_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code,
    p.birth_date,
    CASE WHEN p.birth_date IS NULL THEN NULL
         ELSE date_part('year', age(CURRENT_DATE, p.birth_date))::int END AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.active,
    COUNT(DISTINCT tp.id)  FILTER (WHERE tp.status NOT IN ('rejected','archived'))              AS treatment_plans_count,
    COUNT(DISTINCT tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled'))      AS open_treatment_items_count,
    COALESCE(SUM(e.total_amount)  FILTER (WHERE e.status = 'accepted'), 0.00)                  AS accepted_estimates_amount
FROM patients p
LEFT JOIN treatment_plans      tp  ON tp.patient_id  = p.id  AND tp.clinic_id  = p.clinic_id
LEFT JOIN treatment_plan_items tpi ON tpi.plan_id    = tp.id AND tpi.clinic_id = p.clinic_id
LEFT JOIN estimates            e   ON e.patient_id   = p.id  AND e.clinic_id   = p.clinic_id
GROUP BY p.id, p.clinic_id, p.first_name, p.last_name, p.fiscal_code,
         p.birth_date, p.phone, p.email, p.city, p.province, p.active;

CREATE OR REPLACE VIEW v_patient_clinical_card AS
SELECT
    p.id          AS patient_id,
    p.clinic_id,
    p.first_name,
    p.last_name,
    concat_ws(' ', p.last_name, p.first_name) AS full_name,
    p.birth_date,
    CASE WHEN p.birth_date IS NULL THEN NULL
         ELSE date_part('year', age(CURRENT_DATE, p.birth_date))::int END AS age_years,
    p.fiscal_code,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.notes AS patient_notes,
    p.active,
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
    pa.current_medications,
    pa.other_allergies,
    pa.pacemaker,
    pa.notes       AS anamnesis_notes,
    pa.recorded_at AS anamnesis_date,
    (SELECT COUNT(*) FROM appointments a
     WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id) AS total_appointments
FROM patients p
LEFT JOIN patient_anamnesis pa
       ON pa.patient_id = p.id
      AND pa.clinic_id  = p.clinic_id
      AND pa.is_current = true;

CREATE OR REPLACE VIEW product_stock_v AS
SELECT
    pr.clinic_id,
    pr.id        AS product_id,
    pr.name      AS product_name,
    pr.sku,
    pr.unit,
    pr.min_stock_quantity,
    pc.name      AS category_name,
    s.name       AS supplier_name,
    COALESCE(SUM(
        CASE sm.movement_type
            WHEN 'carico'    THEN sm.quantity
            WHEN 'rientro'   THEN sm.quantity
            WHEN 'scarico'   THEN -sm.quantity
            WHEN 'rettifica' THEN sm.quantity
            ELSE 0
        END
    ), 0) AS current_stock,
    pr.min_stock_quantity AS min_stock_threshold,
    pr.is_active,
    CASE
        WHEN COALESCE(SUM(CASE sm.movement_type
                WHEN 'carico' THEN sm.quantity WHEN 'rientro' THEN sm.quantity
                WHEN 'scarico' THEN -sm.quantity WHEN 'rettifica' THEN sm.quantity ELSE 0
             END), 0) = 0                           THEN 'critico'
        WHEN COALESCE(SUM(CASE sm.movement_type
                WHEN 'carico' THEN sm.quantity WHEN 'rientro' THEN sm.quantity
                WHEN 'scarico' THEN -sm.quantity WHEN 'rettifica' THEN sm.quantity ELSE 0
             END), 0) <= pr.min_stock_quantity       THEN 'basso'
        ELSE 'ok'
    END AS stock_status
FROM products pr
LEFT JOIN product_categories pc ON pc.id = pr.category_id AND pc.clinic_id = pr.clinic_id
LEFT JOIN suppliers          s  ON s.id  = pr.supplier_id  AND s.clinic_id  = pr.clinic_id
LEFT JOIN stock_movements    sm ON sm.product_id = pr.id   AND sm.clinic_id = pr.clinic_id
GROUP BY pr.clinic_id, pr.id, pr.name, pr.sku, pr.unit, pr.min_stock_quantity,
         pc.name, s.name, pr.is_active;

DROP VIEW IF EXISTS v_agenda_daily;
CREATE VIEW v_agenda_daily AS
SELECT
    a.id                                      AS appointment_id,
    a.clinic_id,
    a.starts_at,
    a.ends_at,
    a.chair_label,
    a.status::text                            AS appointment_status,
    a.notes                                   AS notes,
    p.id                                      AS patient_id,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.phone                                   AS patient_phone,
    p.email                                   AS patient_email,
    pr.id                                     AS provider_id,
    concat_ws(' ', pr.first_name, pr.last_name) AS provider_name,
    pr.role::text                             AS provider_role,
    pr.color_hex                              AS provider_color,
    sc.name                                   AS service_name,
    sc.category                               AS service_category,
    tpi.tooth_fdi                             AS tooth_number,
    EXISTS (
        SELECT 1 FROM patient_anamnesis pa2
        WHERE pa2.patient_id = p.id AND pa2.clinic_id = a.clinic_id AND pa2.is_current = true
          AND (pa2.allergy_penicillin OR pa2.allergy_latex OR pa2.allergy_anesthetic
               OR pa2.allergy_aspirin OR pa2.other_allergies IS NOT NULL)
    ) AS has_allergy_alert,
    EXISTS (
        SELECT 1 FROM patient_anamnesis pa2
        WHERE pa2.patient_id = p.id AND pa2.clinic_id = a.clinic_id AND pa2.is_current = true
          AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates
               OR pa2.heart_disease OR pa2.pacemaker)
    ) AS has_medication_alert
FROM appointments a
LEFT JOIN patients             p   ON p.id   = a.patient_id
LEFT JOIN providers            pr  ON pr.id  = a.provider_id
LEFT JOIN treatment_plan_items tpi ON tpi.id = a.treatment_plan_item_id
LEFT JOIN service_catalog      sc  ON sc.id  = tpi.service_catalog_id;

DROP VIEW IF EXISTS v_patient_estimates_summary;
CREATE VIEW v_patient_estimates_summary AS
SELECT
    e.id                    AS estimate_id,
    e.clinic_id,
    e.patient_id,
    e.created_by_provider_id,
    e.version,
    e.status::text          AS estimate_status,
    e.title                 AS estimate_title,
    e.estimate_number,
    e.currency,
    e.subtotal_amount,
    e.discount_amount,
    e.taxable_amount,
    e.vat_amount,
    e.total_amount,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code           AS patient_fiscal_code,
    p.phone                 AS patient_phone,
    e.issued_at,
    e.sent_at,
    e.valid_until,
    e.accepted_at,
    e.rejected_at,
    e.created_at            AS estimate_created_at
FROM estimates e
LEFT JOIN patients p ON p.id = e.patient_id AND p.clinic_id = e.clinic_id;

DROP VIEW IF EXISTS v_clinic_dashboard;
CREATE VIEW v_clinic_dashboard AS
WITH patient_agg AS (
    SELECT clinic_id,
           COUNT(*) FILTER (WHERE active = true) AS patients_count
    FROM patients GROUP BY clinic_id
),
provider_agg AS (
    SELECT clinic_id,
           COUNT(*) FILTER (WHERE active = true) AS active_providers_count
    FROM providers GROUP BY clinic_id
),
plan_agg AS (
    SELECT clinic_id,
           COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_treatment_plans_count
    FROM treatment_plans GROUP BY clinic_id
)
SELECT
    c.id                                                   AS clinic_id,
    c.name                                                 AS clinic_name,
    c.city                                                 AS city,
    COALESCE(pa.patients_count,                       0)   AS patients_count,
    COALESCE(pra.active_providers_count,              0)   AS active_providers_count,
    COALESCE(tpa.in_progress_treatment_plans_count,   0)   AS in_progress_treatment_plans_count
FROM clinics c
LEFT JOIN patient_agg  pa  ON pa.clinic_id  = c.id
LEFT JOIN provider_agg pra ON pra.clinic_id = c.id
LEFT JOIN plan_agg     tpa ON tpa.clinic_id = c.id;
$ddl$;
    EXECUTE l_ddl;

    -- 3) record tenant (schema dentalcare condiviso)
    INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active)
    VALUES (p_tenant_id, p_studio_name, p_schema, p_email, p_phone,
            COALESCE(NULLIF(p_plan, ''), 'professional'), true);

    -- 4) clinic nello schema del tenant
    EXECUTE format(
        'INSERT INTO %I.clinics (id, name, legal_name, vat_number, fiscal_code, phone, email, '
        || 'address_line1, city, province, country, timezone) '
        || 'VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,''IT'',''Europe/Rome'')', p_schema)
    USING p_clinic_id, p_studio_name, p_studio_name, p_vat, p_vat, p_phone, p_email,
          p_address, p_city, p_province;

    -- 5) mappa clinic <-> tenant
    INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id)
    VALUES (p_clinic_id, p_tenant_id);

    -- 6) admin provider
    EXECUTE format(
        'INSERT INTO %I.providers (id, clinic_id, first_name, last_name, email, role, active, password_hash) '
        || 'VALUES ($1,$2,$3,$4,$5,''tenant_admin''::dentalcare.provider_role,true,$6)', p_schema)
    USING l_admin_id, p_clinic_id, p_admin_first, p_admin_last, p_admin_email, p_admin_pw_hash;

    RETURN l_admin_id;
END
$_$;


--
-- Name: recalc_estimate_totals(uuid); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.recalc_estimate_totals(p_estimate_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE dentalcare.estimates e
    SET subtotal_amount = COALESCE(t.subtotal_amount, 0),
        discount_amount = COALESCE(t.discount_amount, 0),
        taxable_amount  = COALESCE(t.taxable_amount, 0),
        vat_amount      = COALESCE(t.vat_amount, 0),
        total_amount    = COALESCE(t.total_amount, 0),
        updated_at      = now()
    FROM (
        SELECT estimate_id,
               round(SUM(line_subtotal), 2)   AS subtotal_amount,
               round(SUM(discount_amount), 2) AS discount_amount,
               round(SUM(line_taxable), 2)    AS taxable_amount,
               round(SUM(line_vat_amount), 2) AS vat_amount,
               round(SUM(line_total), 2)      AS total_amount
        FROM dentalcare.estimate_lines
        WHERE estimate_id = p_estimate_id
        GROUP BY estimate_id
    ) t
    WHERE e.id = p_estimate_id AND e.id = t.estimate_id;

    UPDATE dentalcare.estimates
    SET subtotal_amount = 0, discount_amount = 0, taxable_amount = 0,
        vat_amount = 0, total_amount = 0, updated_at = now()
    WHERE id = p_estimate_id
      AND NOT EXISTS (
          SELECT 1 FROM dentalcare.estimate_lines WHERE estimate_id = p_estimate_id
      );
END;
$$;


--
-- Name: recalc_invoice_totals(uuid); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.recalc_invoice_totals(p_invoice_id uuid) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO 'dentalcare'
    AS $$
BEGIN
    UPDATE invoices i
    SET subtotal_amount = COALESCE(t.subtotal_amount, 0),
        discount_amount = COALESCE(t.discount_amount, 0),
        taxable_amount  = COALESCE(t.taxable_amount, 0),
        vat_amount      = COALESCE(t.vat_amount, 0),
        total_amount    = COALESCE(t.total_amount, 0),
        updated_at      = now()
    FROM (
        SELECT invoice_id,
               round(SUM(line_subtotal), 2)   AS subtotal_amount,
               round(SUM(discount_amount), 2) AS discount_amount,
               round(SUM(line_taxable), 2)    AS taxable_amount,
               round(SUM(line_vat_amount), 2) AS vat_amount,
               round(SUM(line_total), 2)      AS total_amount
        FROM invoice_lines
        WHERE invoice_id = p_invoice_id
        GROUP BY invoice_id
    ) t
    WHERE i.id = p_invoice_id AND i.id = t.invoice_id;

    UPDATE invoices SET subtotal_amount=0, discount_amount=0,
        taxable_amount=0, vat_amount=0, total_amount=0, updated_at=now()
    WHERE id = p_invoice_id
      AND NOT EXISTS (SELECT 1 FROM invoice_lines WHERE invoice_id = p_invoice_id);
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


--
-- Name: trg_recalc_estimate_totals(); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.trg_recalc_estimate_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM dentalcare.recalc_estimate_totals(NEW.estimate_id);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.estimate_id <> OLD.estimate_id THEN
            PERFORM dentalcare.recalc_estimate_totals(OLD.estimate_id);
        END IF;
        PERFORM dentalcare.recalc_estimate_totals(NEW.estimate_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM dentalcare.recalc_estimate_totals(OLD.estimate_id);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: trg_recalc_invoice_totals(); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.trg_recalc_invoice_totals() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'dentalcare'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM dentalcare.recalc_invoice_totals(NEW.invoice_id); RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.invoice_id <> OLD.invoice_id THEN
            PERFORM dentalcare.recalc_invoice_totals(OLD.invoice_id);
        END IF;
        PERFORM dentalcare.recalc_invoice_totals(NEW.invoice_id); RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM dentalcare.recalc_invoice_totals(OLD.invoice_id); RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;


--
-- Name: update_recall_on_contact(); Type: FUNCTION; Schema: dentalcare; Owner: -
--

CREATE FUNCTION dentalcare.update_recall_on_contact() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE dentalcare.patient_recalls
    SET contact_count   = contact_count + 1,
        last_contact_at = NEW.contact_at::date,
        status          = CASE
                            WHEN NEW.outcome::text = 'confermato' THEN 'confermato'::dentalcare.recall_status
                            WHEN status::text = 'da_contattare'   THEN 'contattato'::dentalcare.recall_status
                            ELSE status
                          END,
        updated_at      = now()
    WHERE id = NEW.recall_id;
    RETURN NEW;
END;
$$;


--
-- Name: recalc_estimate_totals(); Type: FUNCTION; Schema: t_9d754153; Owner: -
--

CREATE FUNCTION t_9d754153.recalc_estimate_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            DECLARE
                v_estimate_id uuid;
            BEGIN
                PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
                v_estimate_id := COALESCE(NEW.estimate_id, OLD.estimate_id);
                UPDATE estimates
                SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)   FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    discount_amount = COALESCE((SELECT SUM(discount_amount) FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    taxable_amount  = COALESCE((SELECT SUM(line_taxable)    FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    vat_amount      = COALESCE((SELECT SUM(line_vat_amount) FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    total_amount    = COALESCE((SELECT SUM(line_total)      FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    updated_at      = now()
                WHERE id = v_estimate_id;
                RETURN NULL;
            END;
            $$;


--
-- Name: trg_compute_invoice_line_totals(); Type: FUNCTION; Schema: t_9d754153; Owner: -
--

CREATE FUNCTION t_9d754153.trg_compute_invoice_line_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.line_subtotal   := (COALESCE(NEW.quantity, 1) * COALESCE(NEW.unit_price, 0))
                           - COALESCE(NEW.discount_amount, 0);
    NEW.line_taxable    := NEW.line_subtotal;
    NEW.line_vat_amount := ROUND(NEW.line_taxable * COALESCE(NEW.vat_rate, 0) / 100, 2);
    NEW.line_total      := NEW.line_taxable + NEW.line_vat_amount;
    RETURN NEW;
END;
$$;


--
-- Name: trg_update_invoice_totals_from_lines(); Type: FUNCTION; Schema: t_9d754153; Owner: -
--

CREATE FUNCTION t_9d754153.trg_update_invoice_totals_from_lines() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            DECLARE
                v_invoice_id uuid;
            BEGIN
                PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
                v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
                UPDATE invoices
                SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)   FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    discount_amount = COALESCE((SELECT SUM(discount_amount) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    taxable_amount  = COALESCE((SELECT SUM(line_taxable)    FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    vat_amount      = COALESCE((SELECT SUM(line_vat_amount) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    total_amount    = COALESCE((SELECT SUM(line_total)      FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    updated_at      = now()
                WHERE id = v_invoice_id;
                RETURN NULL;
            END;
            $$;


--
-- Name: update_recall_on_contact(); Type: FUNCTION; Schema: t_9d754153; Owner: -
--

CREATE FUNCTION t_9d754153.update_recall_on_contact() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
                IF NEW.outcome = 'booked' THEN
                    UPDATE patient_recalls
                    SET status     = 'booked'::dentalcare.recall_status,
                        updated_at = now()
                    WHERE id = NEW.recall_id;
                ELSIF NEW.outcome IN ('refused', 'already_booked', 'scheduled_later') THEN
                    UPDATE patient_recalls
                    SET status       = 'completed'::dentalcare.recall_status,
                        completed_at = now(),
                        updated_at   = now()
                    WHERE id = NEW.recall_id;
                END IF;
                RETURN NEW;
            END;
            $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: anamnesis_categories; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.anamnesis_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text,
    name text NOT NULL,
    description text,
    icon text DEFAULT 'medical_information'::text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT anamnesis_categories_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: anamnesis_items; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.anamnesis_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    description text,
    is_alert boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    has_detail boolean DEFAULT false NOT NULL,
    CONSTRAINT anamnesis_items_label_not_empty CHECK ((length(TRIM(BOTH FROM label)) > 0))
);


--
-- Name: cities; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.cities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    region_id uuid NOT NULL,
    name text NOT NULL,
    province_code character(2),
    postal_code text,
    is_capital boolean DEFAULT false NOT NULL
);


--
-- Name: flyway_schema_history; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.flyway_schema_history (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


--
-- Name: national_holidays; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.national_holidays (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    state_id uuid NOT NULL,
    name text NOT NULL,
    is_recurring boolean DEFAULT true NOT NULL,
    month smallint,
    day smallint,
    holiday_date date,
    is_fixed boolean,
    CONSTRAINT chk_holiday_def CHECK ((((is_recurring = true) AND (month IS NOT NULL) AND (day IS NOT NULL) AND (holiday_date IS NULL)) OR ((is_recurring = false) AND (holiday_date IS NOT NULL) AND (month IS NULL) AND (day IS NULL))))
);


--
-- Name: regions; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.regions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    state_id uuid NOT NULL,
    code character varying(5) NOT NULL,
    name text NOT NULL
);


--
-- Name: states; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.states (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character(2) NOT NULL,
    name text NOT NULL
);


--
-- Name: tenant_clinics; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.tenant_clinics (
    clinic_id uuid NOT NULL,
    tenant_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tenants; Type: TABLE; Schema: dentalcare; Owner: -
--

CREATE TABLE dentalcare.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    schema_name text NOT NULL,
    email text,
    phone text,
    plan text DEFAULT 'base'::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_conversations; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.ai_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid,
    provider_id uuid,
    title text,
    messages jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: appointments; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.appointments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    treatment_plan_item_id uuid,
    chair_label text DEFAULT 'Poltrona 1'::text NOT NULL,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    status dentalcare.appointment_status DEFAULT 'scheduled'::dentalcare.appointment_status NOT NULL,
    notes text,
    cancellation_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT appointments_dates_valid CHECK ((ends_at > starts_at))
);


--
-- Name: chat_messages; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chat_messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text])))
);


--
-- Name: chat_sessions; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.chat_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_id uuid NOT NULL,
    title text NOT NULL,
    message_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: clinical_history_entries; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.clinical_history_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    appointment_id uuid,
    provider_id uuid NOT NULL,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    tooth_number text,
    service_code text,
    service_name text,
    clinical_notes text NOT NULL,
    materials_used text,
    next_visit_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: clinics; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.clinics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    legal_name text,
    vat_number text,
    fiscal_code text,
    phone text,
    address_line1 text,
    address_line2 text,
    city text,
    province text,
    postal_code text,
    country text DEFAULT 'IT'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    city_id uuid,
    email text,
    CONSTRAINT clinics_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: condition_service_defaults; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.condition_service_defaults (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    condition_name text NOT NULL,
    service_id uuid NOT NULL,
    sort_order integer DEFAULT 10 NOT NULL
);


--
-- Name: estimate_lines; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.estimate_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    estimate_id uuid NOT NULL,
    treatment_plan_item_id uuid,
    service_id uuid,
    line_position integer DEFAULT 1 NOT NULL,
    description_snapshot text NOT NULL,
    tooth_snapshot text,
    quantity numeric(10,2) DEFAULT 1 NOT NULL,
    unit_price numeric(12,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(12,2) DEFAULT 0 NOT NULL,
    vat_rate numeric(5,2) DEFAULT 0 NOT NULL,
    line_subtotal numeric(12,2) GENERATED ALWAYS AS (round((quantity * unit_price), 2)) STORED,
    line_taxable numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(((quantity * unit_price) - discount_amount), (0)::numeric), 2)) STORED,
    line_vat_amount numeric(12,2) GENERATED ALWAYS AS (round(((GREATEST(((quantity * unit_price) - discount_amount), (0)::numeric) * vat_rate) / (100)::numeric), 2)) STORED,
    line_total numeric(12,2) GENERATED ALWAYS AS (round((GREATEST(((quantity * unit_price) - discount_amount), (0)::numeric) + ((GREATEST(((quantity * unit_price) - discount_amount), (0)::numeric) * vat_rate) / (100)::numeric)), 2)) STORED,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT estimate_lines_description_not_empty CHECK ((length(TRIM(BOTH FROM description_snapshot)) > 0)),
    CONSTRAINT estimate_lines_discount_non_negative CHECK ((discount_amount >= (0)::numeric)),
    CONSTRAINT estimate_lines_position_positive CHECK ((line_position > 0)),
    CONSTRAINT estimate_lines_quantity_positive CHECK ((quantity > (0)::numeric)),
    CONSTRAINT estimate_lines_unit_price_non_negative CHECK ((unit_price >= (0)::numeric)),
    CONSTRAINT estimate_lines_vat_rate_range CHECK (((vat_rate >= (0)::numeric) AND (vat_rate <= (100)::numeric)))
);


--
-- Name: estimates; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.estimates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    treatment_plan_id uuid,
    estimate_number text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    status dentalcare.estimate_status DEFAULT 'draft'::dentalcare.estimate_status NOT NULL,
    title text DEFAULT 'Preventivo'::text NOT NULL,
    notes text,
    currency character(3) DEFAULT 'EUR'::bpchar NOT NULL,
    subtotal_amount numeric(12,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(12,2) DEFAULT 0 NOT NULL,
    taxable_amount numeric(12,2) DEFAULT 0 NOT NULL,
    vat_amount numeric(12,2) DEFAULT 0 NOT NULL,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    issued_at timestamp with time zone,
    sent_at timestamp with time zone,
    valid_until date,
    accepted_at timestamp with time zone,
    rejected_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_provider_id uuid,
    CONSTRAINT estimates_amounts_non_negative CHECK (((subtotal_amount >= (0)::numeric) AND (discount_amount >= (0)::numeric) AND (taxable_amount >= (0)::numeric) AND (vat_amount >= (0)::numeric) AND (total_amount >= (0)::numeric))),
    CONSTRAINT estimates_currency_upper CHECK (((currency)::text = upper((currency)::text))),
    CONSTRAINT estimates_version_positive CHECK ((version > 0))
);


--
-- Name: invoice_lines; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.invoice_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    clinic_id uuid NOT NULL,
    line_position integer DEFAULT 0 NOT NULL,
    description text NOT NULL,
    tooth_info text,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    unit_price numeric(12,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(12,2) DEFAULT 0 NOT NULL,
    vat_rate numeric(5,2) DEFAULT 22 NOT NULL,
    line_subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    line_taxable numeric(12,2) DEFAULT 0 NOT NULL,
    line_vat_amount numeric(12,2) DEFAULT 0 NOT NULL,
    line_total numeric(12,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT invoice_lines_description_not_empty CHECK ((length(TRIM(BOTH FROM description)) > 0))
);


--
-- Name: invoices; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    invoice_number text NOT NULL,
    document_type dentalcare.invoice_document_type DEFAULT 'fattura'::dentalcare.invoice_document_type NOT NULL,
    invoice_date date DEFAULT CURRENT_DATE NOT NULL,
    due_date date,
    status dentalcare.invoice_status DEFAULT 'draft'::dentalcare.invoice_status NOT NULL,
    issuer_type dentalcare.invoice_issuer_type DEFAULT 'clinic'::dentalcare.invoice_issuer_type NOT NULL,
    provider_id uuid,
    patient_id uuid NOT NULL,
    estimate_id uuid,
    issuer_name text,
    issuer_vat_number text,
    issuer_fiscal_code text,
    issuer_address text,
    issuer_email text,
    issuer_pec text,
    issuer_sdi_code text,
    issuer_iban text,
    patient_full_name text,
    patient_fiscal_code text,
    patient_address text,
    patient_email text,
    subtotal_amount numeric(12,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(12,2) DEFAULT 0 NOT NULL,
    taxable_amount numeric(12,2) DEFAULT 0 NOT NULL,
    vat_amount numeric(12,2) DEFAULT 0 NOT NULL,
    total_amount numeric(12,2) DEFAULT 0 NOT NULL,
    currency character(3) DEFAULT 'EUR'::bpchar NOT NULL,
    notes text,
    payment_method text,
    paid_at timestamp with time zone,
    issued_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: odontogram_teeth; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.odontogram_teeth (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    tooth_number text NOT NULL,
    quadrant smallint NOT NULL,
    is_deciduous boolean DEFAULT false NOT NULL,
    condition dentalcare.tooth_condition DEFAULT 'healthy'::dentalcare.tooth_condition NOT NULL,
    surfaces text[],
    bridge_group_id uuid,
    implant_ref text,
    notes text,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by_provider_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT odontogram_teeth_quadrant_check CHECK (((quadrant >= 1) AND (quadrant <= 4)))
);


--
-- Name: patient_anamnesis; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patient_anamnesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by_provider_id uuid,
    blood_type text,
    smoker boolean,
    cigarettes_per_day smallint,
    alcohol_use boolean,
    drug_use boolean,
    hypertension boolean DEFAULT false NOT NULL,
    diabetes boolean DEFAULT false NOT NULL,
    diabetes_type text,
    heart_disease boolean DEFAULT false NOT NULL,
    coagulopathy boolean DEFAULT false NOT NULL,
    immunodeficiency boolean DEFAULT false NOT NULL,
    osteoporosis boolean DEFAULT false NOT NULL,
    thyroid_disease boolean DEFAULT false NOT NULL,
    epilepsy boolean DEFAULT false NOT NULL,
    hepatitis boolean DEFAULT false NOT NULL,
    hiv_positive boolean DEFAULT false NOT NULL,
    tumor_history boolean DEFAULT false NOT NULL,
    autoimmune_disease boolean DEFAULT false NOT NULL,
    other_diseases text,
    taking_anticoagulants boolean DEFAULT false NOT NULL,
    taking_bisphosphonates boolean DEFAULT false NOT NULL,
    taking_cortisone boolean DEFAULT false NOT NULL,
    current_medications text,
    allergy_penicillin boolean DEFAULT false NOT NULL,
    allergy_latex boolean DEFAULT false NOT NULL,
    allergy_anesthetic boolean DEFAULT false NOT NULL,
    allergy_aspirin boolean DEFAULT false NOT NULL,
    other_allergies text,
    bruxism boolean DEFAULT false NOT NULL,
    mouth_breathing boolean DEFAULT false NOT NULL,
    nail_biting boolean DEFAULT false NOT NULL,
    pacifier_use boolean,
    notes text,
    signed_at timestamp with time zone,
    signature_notes text,
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: patient_anamnesis_item_selections; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patient_anamnesis_item_selections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    item_id uuid NOT NULL,
    notes text,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by_provider_id uuid
);


--
-- Name: patient_diagnoses; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patient_diagnoses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    tooth_number character varying(10),
    title character varying(255) NOT NULL,
    description text,
    icd_code character varying(20),
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    diagnosed_at date DEFAULT CURRENT_DATE NOT NULL,
    resolved_at date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: patient_documents; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patient_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    appointment_id uuid,
    uploaded_by_provider_id uuid,
    document_type dentalcare.document_type DEFAULT 'altro'::dentalcare.document_type NOT NULL,
    title text NOT NULL,
    description text,
    file_name text NOT NULL,
    file_path text NOT NULL,
    file_size_bytes bigint,
    mime_type text,
    tooth_number text,
    taken_at date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT patient_documents_file_name_not_empty CHECK ((length(TRIM(BOTH FROM file_name)) > 0)),
    CONSTRAINT patient_documents_title_not_empty CHECK ((length(TRIM(BOTH FROM title)) > 0))
);


--
-- Name: patient_prescriptions; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patient_prescriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    drug_name character varying(255) NOT NULL,
    dosage character varying(100),
    frequency character varying(100),
    duration character varying(100),
    notes text,
    prescribed_at date DEFAULT CURRENT_DATE NOT NULL,
    expires_at date,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: patient_recalls; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patient_recalls (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    recall_type text DEFAULT 'Controllo periodico'::text NOT NULL,
    due_date date NOT NULL,
    status dentalcare.recall_status DEFAULT 'da_contattare'::dentalcare.recall_status NOT NULL,
    priority dentalcare.recall_priority DEFAULT 'media'::dentalcare.recall_priority NOT NULL,
    notes text,
    source_appointment_id uuid,
    booked_appointment_id uuid,
    last_contact_at date,
    contact_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: patients; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.patients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    fiscal_code text,
    birth_date date,
    phone text,
    address_line1 text,
    address_line2 text,
    city text,
    province text,
    postal_code text,
    country text DEFAULT 'IT'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    photo_url text,
    email text,
    active boolean DEFAULT true NOT NULL,
    primary_provider_id uuid,
    CONSTRAINT patients_first_name_not_empty CHECK ((length(TRIM(BOTH FROM first_name)) > 0)),
    CONSTRAINT patients_last_name_not_empty CHECK ((length(TRIM(BOTH FROM last_name)) > 0))
);


--
-- Name: product_categories; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.product_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    name text NOT NULL
);


--
-- Name: products; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    category_id uuid,
    supplier_id uuid,
    name text NOT NULL,
    description text,
    sku text,
    unit text DEFAULT 'pz'::text NOT NULL,
    min_stock_quantity numeric(10,2) DEFAULT 0 NOT NULL,
    reorder_quantity numeric(10,2) DEFAULT 0 NOT NULL,
    unit_cost numeric(12,2),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stock_movements; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.stock_movements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    product_id uuid NOT NULL,
    movement_type dentalcare.stock_movement_type NOT NULL,
    quantity numeric(10,2) NOT NULL,
    unit_cost numeric(12,2),
    notes text,
    reference_doc text,
    created_by_provider_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: suppliers; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.suppliers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    name text NOT NULL,
    contact_person text,
    phone text,
    email text,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: product_stock_v; Type: VIEW; Schema: t_9d754153; Owner: -
--

CREATE VIEW t_9d754153.product_stock_v AS
 SELECT pr.clinic_id,
    pr.id AS product_id,
    pr.category_id,
    pc.name AS category_name,
    pr.supplier_id,
    s.name AS supplier_name,
    pr.name,
    pr.description,
    pr.sku,
    pr.unit,
    pr.min_stock_quantity,
    pr.reorder_quantity,
    pr.unit_cost,
    pr.is_active,
    COALESCE(sum(
        CASE sm.movement_type
            WHEN 'carico'::dentalcare.stock_movement_type THEN sm.quantity
            WHEN 'rientro'::dentalcare.stock_movement_type THEN sm.quantity
            WHEN 'scarico'::dentalcare.stock_movement_type THEN (- sm.quantity)
            WHEN 'rettifica'::dentalcare.stock_movement_type THEN sm.quantity
            ELSE (0)::numeric
        END), (0)::numeric) AS current_stock,
        CASE
            WHEN (COALESCE(sum(
            CASE sm.movement_type
                WHEN 'carico'::dentalcare.stock_movement_type THEN sm.quantity
                WHEN 'rientro'::dentalcare.stock_movement_type THEN sm.quantity
                WHEN 'scarico'::dentalcare.stock_movement_type THEN (- sm.quantity)
                WHEN 'rettifica'::dentalcare.stock_movement_type THEN sm.quantity
                ELSE (0)::numeric
            END), (0)::numeric) = (0)::numeric) THEN 'critico'::text
            WHEN (COALESCE(sum(
            CASE sm.movement_type
                WHEN 'carico'::dentalcare.stock_movement_type THEN sm.quantity
                WHEN 'rientro'::dentalcare.stock_movement_type THEN sm.quantity
                WHEN 'scarico'::dentalcare.stock_movement_type THEN (- sm.quantity)
                WHEN 'rettifica'::dentalcare.stock_movement_type THEN sm.quantity
                ELSE (0)::numeric
            END), (0)::numeric) <= pr.min_stock_quantity) THEN 'basso'::text
            ELSE 'ok'::text
        END AS stock_status
   FROM (((t_9d754153.products pr
     LEFT JOIN t_9d754153.product_categories pc ON (((pc.id = pr.category_id) AND (pc.clinic_id = pr.clinic_id))))
     LEFT JOIN t_9d754153.suppliers s ON (((s.id = pr.supplier_id) AND (s.clinic_id = pr.clinic_id))))
     LEFT JOIN t_9d754153.stock_movements sm ON (((sm.product_id = pr.id) AND (sm.clinic_id = pr.clinic_id))))
  GROUP BY pr.clinic_id, pr.id, pr.category_id, pc.name, pr.supplier_id, s.name, pr.name, pr.description, pr.sku, pr.unit, pr.min_stock_quantity, pr.reorder_quantity, pr.unit_cost, pr.is_active;


--
-- Name: providers; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    role dentalcare.provider_role DEFAULT 'dentist'::dentalcare.provider_role NOT NULL,
    phone text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    vat_number text,
    fiscal_code text,
    professional_register text,
    register_number text,
    billing_address_street text,
    billing_address_zip text,
    billing_address_city text,
    billing_address_province text,
    billing_pec text,
    billing_iban text,
    billing_sdi_code text,
    invoice_prefix text DEFAULT 'PARC'::text,
    photo_url text,
    email text,
    password_hash text,
    password_temporary boolean DEFAULT false NOT NULL,
    CONSTRAINT providers_first_name_not_empty CHECK ((length(TRIM(BOTH FROM first_name)) > 0)),
    CONSTRAINT providers_last_name_not_empty CHECK ((length(TRIM(BOTH FROM last_name)) > 0))
);


--
-- Name: recall_contacts; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.recall_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    recall_id uuid NOT NULL,
    contact_type dentalcare.recall_contact_type DEFAULT 'telefono'::dentalcare.recall_contact_type NOT NULL,
    contact_at timestamp with time zone DEFAULT now() NOT NULL,
    outcome dentalcare.recall_outcome NOT NULL,
    notes text,
    created_by_provider_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: service_bundle_items; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.service_bundle_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    parent_service_id uuid NOT NULL,
    child_service_id uuid NOT NULL,
    sort_order integer DEFAULT 10 NOT NULL
);


--
-- Name: service_catalog; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.service_catalog (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    category text,
    description text,
    default_price numeric(12,2) DEFAULT 0 NOT NULL,
    default_vat_rate numeric(5,2) DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    duration_minutes integer,
    min_tooth_digit integer,
    max_tooth_digit integer,
    applicable_to_deciduous boolean DEFAULT true NOT NULL,
    CONSTRAINT service_catalog_code_not_empty CHECK ((length(TRIM(BOTH FROM code)) > 0)),
    CONSTRAINT service_catalog_default_price_non_negative CHECK ((default_price >= (0)::numeric)),
    CONSTRAINT service_catalog_default_vat_rate_range CHECK (((default_vat_rate >= (0)::numeric) AND (default_vat_rate <= (100)::numeric))),
    CONSTRAINT service_catalog_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: tooth_conditions; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.tooth_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    tooth_fdi smallint NOT NULL,
    surface character varying(10) NOT NULL,
    condition character varying(50) NOT NULL,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: treatment_plan_items; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.treatment_plan_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    service_catalog_id uuid NOT NULL,
    provider_id uuid,
    tooth_fdi text,
    quadrant smallint,
    surfaces text[],
    quantity numeric(10,2) DEFAULT 1 NOT NULL,
    planned_price numeric(12,2) DEFAULT 0 NOT NULL,
    planned_vat_rate numeric(5,2) DEFAULT 0 NOT NULL,
    clinical_notes text,
    status dentalcare.treatment_item_status DEFAULT 'planned'::dentalcare.treatment_item_status NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    planned_date date,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT treatment_plan_items_price_non_negative CHECK ((planned_price >= (0)::numeric)),
    CONSTRAINT treatment_plan_items_quadrant_range CHECK (((quadrant IS NULL) OR ((quadrant >= 1) AND (quadrant <= 4)))),
    CONSTRAINT treatment_plan_items_quantity_positive CHECK ((quantity > (0)::numeric)),
    CONSTRAINT treatment_plan_items_vat_rate_range CHECK (((planned_vat_rate >= (0)::numeric) AND (planned_vat_rate <= (100)::numeric)))
);


--
-- Name: treatment_plans; Type: TABLE; Schema: t_9d754153; Owner: -
--

CREATE TABLE t_9d754153.treatment_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    name text DEFAULT 'Piano di cura'::text NOT NULL,
    description text,
    status dentalcare.treatment_plan_status DEFAULT 'draft'::dentalcare.treatment_plan_status NOT NULL,
    created_by_provider_id uuid,
    proposed_at timestamp with time zone,
    accepted_at timestamp with time zone,
    completed_at timestamp with time zone,
    rejected_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT treatment_plans_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


--
-- Name: v_agenda_daily; Type: VIEW; Schema: t_9d754153; Owner: -
--

CREATE VIEW t_9d754153.v_agenda_daily AS
 SELECT a.id AS appointment_id,
    a.clinic_id,
    a.starts_at,
    a.ends_at,
    a.chair_label,
    (a.status)::text AS appointment_status,
    a.notes,
    p.id AS patient_id,
    concat_ws(' '::text, p.last_name, p.first_name) AS patient_full_name,
    p.phone AS patient_phone,
    p.email AS patient_email,
    pr.id AS provider_id,
    concat_ws(' '::text, pr.first_name, pr.last_name) AS provider_name,
    (pr.role)::text AS provider_role,
    sc.name AS service_name,
    sc.category AS service_category,
    tpi.tooth_fdi AS tooth_number,
    (EXISTS ( SELECT 1
           FROM t_9d754153.patient_anamnesis pa2
          WHERE ((pa2.patient_id = p.id) AND (pa2.clinic_id = a.clinic_id) AND (pa2.is_current = true) AND (pa2.allergy_penicillin OR pa2.allergy_latex OR pa2.allergy_anesthetic OR pa2.allergy_aspirin OR (pa2.other_allergies IS NOT NULL))))) AS has_allergy_alert,
    (EXISTS ( SELECT 1
           FROM t_9d754153.patient_anamnesis pa2
          WHERE ((pa2.patient_id = p.id) AND (pa2.clinic_id = a.clinic_id) AND (pa2.is_current = true) AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates OR pa2.heart_disease)))) AS has_medication_alert
   FROM ((((t_9d754153.appointments a
     LEFT JOIN t_9d754153.patients p ON ((p.id = a.patient_id)))
     LEFT JOIN t_9d754153.providers pr ON ((pr.id = a.provider_id)))
     LEFT JOIN t_9d754153.treatment_plan_items tpi ON ((tpi.id = a.treatment_plan_item_id)))
     LEFT JOIN t_9d754153.service_catalog sc ON ((sc.id = tpi.service_catalog_id)));


--
-- Name: v_clinic_dashboard; Type: VIEW; Schema: t_9d754153; Owner: -
--

CREATE VIEW t_9d754153.v_clinic_dashboard AS
 WITH patient_agg AS (
         SELECT patients.clinic_id,
            count(*) FILTER (WHERE (patients.active = true)) AS patients_count
           FROM t_9d754153.patients
          GROUP BY patients.clinic_id
        ), provider_agg AS (
         SELECT providers.clinic_id,
            count(*) FILTER (WHERE (providers.active = true)) AS active_providers_count
           FROM t_9d754153.providers
          GROUP BY providers.clinic_id
        ), plan_agg AS (
         SELECT treatment_plans.clinic_id,
            count(*) FILTER (WHERE (treatment_plans.status = 'in_progress'::dentalcare.treatment_plan_status)) AS in_progress_treatment_plans_count
           FROM t_9d754153.treatment_plans
          GROUP BY treatment_plans.clinic_id
        )
 SELECT c.id AS clinic_id,
    c.name AS clinic_name,
    c.city,
    COALESCE(pa.patients_count, (0)::bigint) AS patients_count,
    COALESCE(pra.active_providers_count, (0)::bigint) AS active_providers_count,
    COALESCE(tpa.in_progress_treatment_plans_count, (0)::bigint) AS in_progress_treatment_plans_count
   FROM (((t_9d754153.clinics c
     LEFT JOIN patient_agg pa ON ((pa.clinic_id = c.id)))
     LEFT JOIN provider_agg pra ON ((pra.clinic_id = c.id)))
     LEFT JOIN plan_agg tpa ON ((tpa.clinic_id = c.id)));


--
-- Name: v_patient_clinical_card; Type: VIEW; Schema: t_9d754153; Owner: -
--

CREATE VIEW t_9d754153.v_patient_clinical_card AS
 SELECT p.id AS patient_id,
    p.clinic_id,
    p.first_name,
    p.last_name,
    concat_ws(' '::text, p.last_name, p.first_name) AS full_name,
    p.birth_date,
        CASE
            WHEN (p.birth_date IS NULL) THEN NULL::integer
            ELSE (date_part('year'::text, age((CURRENT_DATE)::timestamp with time zone, (p.birth_date)::timestamp with time zone)))::integer
        END AS age_years,
    p.fiscal_code,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.notes AS patient_notes,
    p.active,
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
    pa.current_medications,
    pa.other_allergies,
    pa.notes AS anamnesis_notes,
    pa.recorded_at AS anamnesis_date,
    ( SELECT count(*) AS count
           FROM t_9d754153.appointments a
          WHERE ((a.patient_id = p.id) AND (a.clinic_id = p.clinic_id))) AS total_appointments
   FROM (t_9d754153.patients p
     LEFT JOIN t_9d754153.patient_anamnesis pa ON (((pa.patient_id = p.id) AND (pa.clinic_id = p.clinic_id) AND (pa.is_current = true))));


--
-- Name: v_patient_dashboard; Type: VIEW; Schema: t_9d754153; Owner: -
--

CREATE VIEW t_9d754153.v_patient_dashboard AS
 SELECT p.id AS patient_id,
    p.clinic_id,
    p.first_name AS patient_first_name,
    p.last_name AS patient_last_name,
    concat_ws(' '::text, p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code,
    p.birth_date,
        CASE
            WHEN (p.birth_date IS NULL) THEN NULL::integer
            ELSE (date_part('year'::text, age((CURRENT_DATE)::timestamp with time zone, (p.birth_date)::timestamp with time zone)))::integer
        END AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.active,
    count(DISTINCT tp.id) FILTER (WHERE (tp.status <> ALL (ARRAY['rejected'::dentalcare.treatment_plan_status, 'archived'::dentalcare.treatment_plan_status]))) AS treatment_plans_count,
    count(DISTINCT tpi.id) FILTER (WHERE (tpi.status = ANY (ARRAY['planned'::dentalcare.treatment_item_status, 'accepted'::dentalcare.treatment_item_status, 'scheduled'::dentalcare.treatment_item_status]))) AS open_treatment_items_count,
    COALESCE(sum(e.total_amount) FILTER (WHERE (e.status = 'accepted'::dentalcare.estimate_status)), 0.00) AS accepted_estimates_amount
   FROM (((t_9d754153.patients p
     LEFT JOIN t_9d754153.treatment_plans tp ON (((tp.patient_id = p.id) AND (tp.clinic_id = p.clinic_id))))
     LEFT JOIN t_9d754153.treatment_plan_items tpi ON (((tpi.plan_id = tp.id) AND (tpi.clinic_id = p.clinic_id))))
     LEFT JOIN t_9d754153.estimates e ON (((e.patient_id = p.id) AND (e.clinic_id = p.clinic_id))))
  GROUP BY p.id, p.clinic_id, p.first_name, p.last_name, p.fiscal_code, p.birth_date, p.phone, p.email, p.city, p.province, p.active;


--
-- Name: v_patient_estimates_summary; Type: VIEW; Schema: t_9d754153; Owner: -
--

CREATE VIEW t_9d754153.v_patient_estimates_summary AS
 SELECT e.id AS estimate_id,
    e.clinic_id,
    e.patient_id,
    e.created_by_provider_id,
    e.version,
    (e.status)::text AS estimate_status,
    e.title AS estimate_title,
    e.estimate_number,
    e.currency,
    e.subtotal_amount,
    e.discount_amount,
    e.taxable_amount,
    e.vat_amount,
    e.total_amount,
    concat_ws(' '::text, p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code AS patient_fiscal_code,
    p.phone AS patient_phone,
    e.issued_at,
    e.sent_at,
    e.valid_until,
    e.accepted_at,
    e.rejected_at,
    e.created_at AS estimate_created_at
   FROM (t_9d754153.estimates e
     LEFT JOIN t_9d754153.patients p ON (((p.id = e.patient_id) AND (p.clinic_id = e.clinic_id))));


--
-- Data for Name: anamnesis_categories; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.anamnesis_categories (id, code, name, description, icon, sort_order, enabled, created_at) FROM stdin;
a1000000-0000-0000-0000-000000000001	ALLERGIE	Allergie & Reazioni	Allergie a farmaci, materiali e sostanze	warning	10	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000002	FARMACI	Farmaci in Uso	Terapie farmacologiche in corso	medication	20	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000003	PATOLOGIE	Patologie Sistemiche	Malattie sistemiche e condizioni croniche	favorite	30	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000004	CHIRURGIA	Interventi Chirurgici	Anamnesi chirurgica pregressa	healing	40	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000005	ABITUDINI	Abitudini Viziate	Fumo, alcol e abitudini para-funzionali	smoking_rooms	50	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000006	COND_ORALI	Condizioni Odontoiatriche	Sintomi e condizioni del cavo orale	dentistry	60	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000007	SINTOMI	Sintomi Attuali	Motivo della visita e sintomi in corso	personal_injury	70	t	2026-05-06 13:36:02.017471+00
a1000000-0000-0000-0000-000000000008	ORMONI	Gravidanza & Stato Ormonale	Gravidanza, allattamento, terapia ormonale	pregnant_woman	80	t	2026-05-06 13:36:02.017471+00
00000010-0000-0000-0000-000000000001	\N	Malattie Sistemiche	\N	medical_information	10	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000002	\N	Farmaci e Terapie	\N	medical_information	20	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000003	\N	Allergie	\N	medical_information	30	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000004	\N	Abitudini di Vita	\N	medical_information	40	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000005	\N	Apparato Cardiovascolare	\N	medical_information	50	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000006	\N	Apparato Respiratorio	\N	medical_information	60	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000007	\N	Apparato Gastrointestinale	\N	medical_information	70	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000008	\N	Apparato Endocrino	\N	medical_information	80	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000009	\N	Gravidanza e Ginecologia	\N	medical_information	90	t	2026-05-25 20:27:19.549879+00
00000010-0000-0000-0000-000000000010	\N	Stato Psicologico	\N	medical_information	100	t	2026-05-25 20:27:19.549879+00
\.


--
-- Data for Name: anamnesis_items; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled, created_at, has_detail) FROM stdin;
b1000000-0000-0000-0001-000000000001	a1000000-0000-0000-0000-000000000001	ALLERG_PENICILLINA	Allergia a Penicillina / Amoxicillina	Include tutte le betalattamine	t	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0001-000000000002	a1000000-0000-0000-0000-000000000001	ALLERG_ANESTETICI	Allergia agli Anestetici Locali	Articaina, mepivacaina, lidocaina	t	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0001-000000000003	a1000000-0000-0000-0000-000000000001	ALLERG_LATEX	Allergia al Lattice	\N	t	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0001-000000000004	a1000000-0000-0000-0000-000000000001	ALLERG_ASPIRINA	Allergia ad Aspirina / FANS	\N	t	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0001-000000000005	a1000000-0000-0000-0000-000000000001	ALLERG_SULFAMIDICI	Allergia ai Sulfamidici	\N	f	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0001-000000000006	a1000000-0000-0000-0000-000000000001	ALLERG_NICKEL	Allergia al Nickel	\N	f	60	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0001-000000000007	a1000000-0000-0000-0000-000000000001	ALLERG_METACRILATO	Allergia al Metacrilato	Materiali da restauro / protesi	f	70	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000001	a1000000-0000-0000-0000-000000000002	FARMACI_ANTICOAG	Anticoagulanti (TAO, EBPM, NAO)	Warfarin, Eparina, Dabigatran, Rivaroxaban	t	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000002	a1000000-0000-0000-0000-000000000002	FARMACI_ANTIAGG	Antiaggreganti (Aspirina, Clopidogrel)	\N	t	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000003	a1000000-0000-0000-0000-000000000002	FARMACI_BISFOSFONATI	Bifosfonati (Alendronato, Zolendronato)	Rischio ONJ - ONM	t	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000004	a1000000-0000-0000-0000-000000000002	FARMACI_ANTIDIABT	Antidiabetici / Insulina	\N	f	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000005	a1000000-0000-0000-0000-000000000002	FARMACI_ANTIIPERT	Antiipertensivi	\N	f	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000006	a1000000-0000-0000-0000-000000000002	FARMACI_CORTISONICI	Cortisonici Sistemici	\N	t	60	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000007	a1000000-0000-0000-0000-000000000002	FARMACI_IMMUNOSOPP	Immunosoppressori	\N	t	70	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0002-000000000008	a1000000-0000-0000-0000-000000000002	FARMACI_ALTRI	Altra terapia farmacologica in corso	\N	f	80	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000001	a1000000-0000-0000-0000-000000000003	PAT_IPERTENSIONE	Ipertensione Arteriosa	\N	f	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000002	a1000000-0000-0000-0000-000000000003	PAT_CARDIOPATIA	Cardiopatia / Patologie Cardiache	Valvole, pace-maker, infarto pregresso	t	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000003	a1000000-0000-0000-0000-000000000003	PAT_DIABETE	Diabete Mellito	\N	f	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000004	a1000000-0000-0000-0000-000000000003	PAT_ASMA	Asma Bronchiale / BPCO	\N	f	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000005	a1000000-0000-0000-0000-000000000003	PAT_EPATOPATIA	Epatopatia (Epatite, Cirrosi)	\N	t	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000006	a1000000-0000-0000-0000-000000000003	PAT_NEFROPATIA	Nefropatia / Insufficienza Renale	\N	t	60	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000007	a1000000-0000-0000-0000-000000000003	PAT_EPILESSIA	Epilessia	\N	t	70	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000008	a1000000-0000-0000-0000-000000000003	PAT_OSTEOPOROSI	Osteoporosi	\N	f	80	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000009	a1000000-0000-0000-0000-000000000003	PAT_COAGULOP	Disturbi della Coagulazione	\N	t	90	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000010	a1000000-0000-0000-0000-000000000003	PAT_IMMUNODEF	Immunodeficienza (HIV, terapie oncologiche)	\N	t	100	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000011	a1000000-0000-0000-0000-000000000003	PAT_ONCOLOGICA	Patologia Oncologica in trattamento	\N	t	110	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000012	a1000000-0000-0000-0000-000000000003	PAT_TIROIDEA	Patologia Tiroidea	\N	f	120	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0003-000000000013	a1000000-0000-0000-0000-000000000003	PAT_REFLUSSO	Reflusso Gastroesofageo	\N	f	130	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0004-000000000001	a1000000-0000-0000-0000-000000000004	CHIR_CARDIOCH	Cardiochirurgia / Valvole Cardiache	Profilassi antibiotica richiesta	t	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0004-000000000002	a1000000-0000-0000-0000-000000000004	CHIR_ENDOPROT	Protesi Articolari (Anca, Ginocchio)	\N	t	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0004-000000000003	a1000000-0000-0000-0000-000000000004	CHIR_BYPASS	Bypass / Angioplastica	\N	t	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0004-000000000004	a1000000-0000-0000-0000-000000000004	CHIR_TRAPIANTO	Trapianto d'Organo	\N	t	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0004-000000000005	a1000000-0000-0000-0000-000000000004	CHIR_ALTRO	Altri Interventi Chirurgici	\N	f	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0005-000000000001	a1000000-0000-0000-0000-000000000005	ABT_FUMO	Fumatore	\N	f	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0005-000000000002	a1000000-0000-0000-0000-000000000005	ABT_ALCOL	Consumo Alcolici	\N	f	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0005-000000000003	a1000000-0000-0000-0000-000000000005	ABT_DROGHE	Uso di Sostanze	\N	t	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0005-000000000004	a1000000-0000-0000-0000-000000000005	ABT_BRUXISMO	Bruxismo / Digrignamento	\N	f	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0005-000000000005	a1000000-0000-0000-0000-000000000005	ABT_ONICOFAGIA	Onicofagia / Morsicatura Labbra	\N	f	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0005-000000000006	a1000000-0000-0000-0000-000000000005	ABT_PIERCING	Piercing Orale	\N	f	60	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000001	a1000000-0000-0000-0000-000000000006	COND_SENSIB	Sensibilità Dentinale	\N	f	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000002	a1000000-0000-0000-0000-000000000006	COND_SANGU	Sanguinamento Gengivale	\N	f	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000003	a1000000-0000-0000-0000-000000000006	COND_MOBIL	Mobilità Dentale	\N	f	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000004	a1000000-0000-0000-0000-000000000006	COND_ALITOSI	Alitosi	\N	f	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000005	a1000000-0000-0000-0000-000000000006	COND_APNEA	Apnea Notturna / Russamento	\N	f	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000006	a1000000-0000-0000-0000-000000000006	COND_ATM	Problemi ATM / Dolore Masticatorio	\N	f	60	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000007	a1000000-0000-0000-0000-000000000006	COND_XEROSTOMIA	Secchezza Orale (Xerostomia)	\N	f	70	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0006-000000000008	a1000000-0000-0000-0000-000000000006	COND_AFTE	Afte Ricorrenti	\N	f	80	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0007-000000000001	a1000000-0000-0000-0000-000000000007	SINT_DOLORE	Dolore Dentale	\N	f	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0007-000000000002	a1000000-0000-0000-0000-000000000007	SINT_GONFIORE	Gonfiore / Tumefazione	\N	t	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0007-000000000003	a1000000-0000-0000-0000-000000000007	SINT_FRATTURA	Dente Rotto / Fratturato	\N	f	30	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0007-000000000004	a1000000-0000-0000-0000-000000000007	SINT_CADUTA	Perdita di Otturazione / Corona	\N	f	40	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0007-000000000005	a1000000-0000-0000-0000-000000000007	SINT_SENSIB_TERM	Sensibilità al Caldo / Freddo	\N	f	50	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0007-000000000006	a1000000-0000-0000-0000-000000000007	SINT_URGENZA	Urgenza Odontogena	\N	t	60	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0008-000000000001	a1000000-0000-0000-0000-000000000008	GRAV_GRAVIDANZA	Gravidanza in Corso	Indicare il trimestre nelle note	t	10	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0008-000000000002	a1000000-0000-0000-0000-000000000008	GRAV_ALLATTAMENTO	Allattamento	\N	t	20	t	2026-05-06 13:36:02.017471+00	f
b1000000-0000-0000-0008-000000000003	a1000000-0000-0000-0000-000000000008	GRAV_ORMONI	Terapia Ormonale (Pillola, HRT)	\N	f	30	t	2026-05-06 13:36:02.017471+00	f
00000011-0000-0000-0000-000000000001	00000010-0000-0000-0000-000000000001	SIS_01	Ipertensione arteriosa	Pressione sistolica cronicamente elevata	f	10	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000002	00000010-0000-0000-0000-000000000001	SIS_02	Diabete di tipo 1	Diabete mellito insulino-dipendente	f	20	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000003	00000010-0000-0000-0000-000000000001	SIS_03	Diabete di tipo 2	Diabete mellito non insulino-dipendente	f	30	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000004	00000010-0000-0000-0000-000000000001	SIS_04	Cardiopatia	Malattia cardiaca di qualsiasi tipo	f	40	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000005	00000010-0000-0000-0000-000000000001	SIS_05	Epatite B/C	Epatite virale cronica B o C	f	50	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000006	00000010-0000-0000-0000-000000000001	SIS_06	HIV / AIDS	Sieropositivo o malattia conclamata	f	60	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000007	00000010-0000-0000-0000-000000000001	SIS_07	Osteoporosi	Riduzione della densita' ossea	f	70	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000008	00000010-0000-0000-0000-000000000001	SIS_08	Epilessia	Disturbo epilettico diagnosticato	f	80	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000009	00000010-0000-0000-0000-000000000001	SIS_09	Insufficienza renale	IRC o dialisi	f	90	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000010	00000010-0000-0000-0000-000000000001	SIS_10	Asma bronchiale	Asma diagnosticata o in terapia	f	100	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000011	00000010-0000-0000-0000-000000000002	FAR_01	Anticoagulanti orali	Warfarin, NAO (rivaroxaban, apixaban)	f	10	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000012	00000010-0000-0000-0000-000000000002	FAR_02	Antiaggreganti piastrinici	Aspirina, clopidogrel, ticagrelor	f	20	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000013	00000010-0000-0000-0000-000000000002	FAR_03	Bifosfonati	Alendronato, zoledronato e simili	f	30	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000014	00000010-0000-0000-0000-000000000002	FAR_04	Cortisonici	Steroidi sistemici (prednisone, desametasone)	f	40	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000015	00000010-0000-0000-0000-000000000002	FAR_05	Immunosoppressori	Ciclosporina, azatioprina, metotrexato	f	50	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000016	00000010-0000-0000-0000-000000000002	FAR_06	Antipertensivi	ACE-inibitori, sartani, beta-bloccanti	f	60	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000017	00000010-0000-0000-0000-000000000002	FAR_07	Insulina	Terapia insulinica per diabete	f	70	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000021	00000010-0000-0000-0000-000000000003	ALL_01	Penicillina / Amoxicillina	Allergia ad antibiotici betalattamici	f	10	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000022	00000010-0000-0000-0000-000000000003	ALL_02	Lattice	Allergia al lattice (guanti, presidi)	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000023	00000010-0000-0000-0000-000000000003	ALL_03	Anestetici locali	Lidocaina, articaina e simili	f	30	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000024	00000010-0000-0000-0000-000000000003	ALL_04	Aspirina / FANS	Ibuprofene, diclofenac, ketoprofene	f	40	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000025	00000010-0000-0000-0000-000000000003	ALL_05	Nichel	Allergia al nichel (metalli per protesi)	f	50	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000026	00000010-0000-0000-0000-000000000003	ALL_06	Metalli dentali	Allergia a oro, palladio, amalgama	f	60	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000027	00000010-0000-0000-0000-000000000003	ALL_07	Acrilici	Allergia a resine acriliche (protesi rimovibili)	f	70	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000031	00000010-0000-0000-0000-000000000004	ABT_01	Fumatore attivo	Fumo di sigaretta o sigaro	f	10	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000032	00000010-0000-0000-0000-000000000004	ABT_02	Ex fumatore	Ha smesso di fumare	f	20	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000033	00000010-0000-0000-0000-000000000004	ABT_03	Consumo regolare di alcolici	Piu' di 2 unita' alcoliche/giorno	f	30	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000034	00000010-0000-0000-0000-000000000004	ABT_04	Bruxismo	Digrignamento notturno o diurno	f	40	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000035	00000010-0000-0000-0000-000000000004	ABT_05	Sportivo agonista	Sport agonistici con rischio trauma	f	50	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000041	00000010-0000-0000-0000-000000000005	CAR_01	Pacemaker / ICD	Portatore di pacemaker o defibrillatore	f	10	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000042	00000010-0000-0000-0000-000000000005	CAR_02	Protesi valvolare cardiaca	Valvola meccanica o biologica	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000043	00000010-0000-0000-0000-000000000005	CAR_03	Infarto pregresso	Episodio infartuale nella storia clinica	f	30	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000044	00000010-0000-0000-0000-000000000005	CAR_04	Angina pectoris	Angina stabile o instabile	f	40	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000045	00000010-0000-0000-0000-000000000005	CAR_05	Insufficienza cardiaca	Scompenso cardiaco congestizio	f	50	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000051	00000010-0000-0000-0000-000000000006	RES_01	Asma bronchiale	In terapia con broncodilatatori	f	10	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000052	00000010-0000-0000-0000-000000000006	RES_02	BPCO	Broncopneumopatia cronica ostruttiva	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000053	00000010-0000-0000-0000-000000000006	RES_03	Apnee notturne	OSAS con o senza CPAP	f	30	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000061	00000010-0000-0000-0000-000000000007	GAS_01	Reflusso gastroesofageo	GERD in terapia o sintomatico	f	10	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000062	00000010-0000-0000-0000-000000000007	GAS_02	Ulcera peptica	Ulcera gastrica o duodenale	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000063	00000010-0000-0000-0000-000000000007	GAS_03	Morbo di Crohn	Malattia infiammatoria intestinale	f	30	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000071	00000010-0000-0000-0000-000000000008	END_01	Ipotiroidismo	Tiroidite cronica o ipotiroidismo idiopatico	f	10	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000072	00000010-0000-0000-0000-000000000008	END_02	Ipertiroidismo	Morbo di Basedow o adenoma tossico	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000073	00000010-0000-0000-0000-000000000008	END_03	Sindrome di Cushing	Ipercortisolismo endogeno o iatrogeno	f	30	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000081	00000010-0000-0000-0000-000000000009	GRA_01	Gravidanza in corso	Specificare trimestre	f	10	t	2026-05-25 20:27:19.549879+00	t
00000011-0000-0000-0000-000000000082	00000010-0000-0000-0000-000000000009	GRA_02	Allattamento	Periodo di allattamento al seno	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000091	00000010-0000-0000-0000-000000000010	PSI_01	Ansia da studio dentistico	Ansia clinicamente significativa	f	10	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000092	00000010-0000-0000-0000-000000000010	PSI_02	Fobia degli aghi	Belonefobia / fobia iniezioni	f	20	t	2026-05-25 20:27:19.549879+00	f
00000011-0000-0000-0000-000000000093	00000010-0000-0000-0000-000000000010	PSI_03	Claustrofobia	Difficolta' con bocca aperta / dentale chiuso	f	30	t	2026-05-25 20:27:19.549879+00	f
\.


--
-- Data for Name: cities; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.cities (id, region_id, name, province_code, postal_code, is_capital) FROM stdin;
00000003-0000-0000-0000-000000000001	00000002-0000-0000-0000-000000000012	Roma	RM	00100	t
00000003-0000-0000-0000-000000000002	00000002-0000-0000-0000-000000000003	Milano	MI	20100	t
00000003-0000-0000-0000-000000000003	00000002-0000-0000-0000-000000000015	Napoli	NA	80100	t
00000003-0000-0000-0000-000000000004	00000002-0000-0000-0000-000000000016	Bari	BA	70100	t
00000003-0000-0000-0000-000000000005	00000002-0000-0000-0000-000000000009	Firenze	FI	50100	t
00000003-0000-0000-0000-000000000006	00000002-0000-0000-0000-000000000005	Venezia	VE	30100	t
00000003-0000-0000-0000-000000000007	00000002-0000-0000-0000-000000000005	Verona	VR	37100	f
00000003-0000-0000-0000-000000000008	00000002-0000-0000-0000-000000000002	Torino	TO	10100	t
00000003-0000-0000-0000-000000000009	00000002-0000-0000-0000-000000000007	Genova	GE	16100	t
00000003-0000-0000-0000-000000000010	00000002-0000-0000-0000-000000000008	Bologna	BO	40100	t
00000003-0000-0000-0000-000000000011	00000002-0000-0000-0000-000000000019	Palermo	PA	90100	t
00000003-0000-0000-0000-000000000012	00000002-0000-0000-0000-000000000020	Cagliari	CA	09100	t
\.


--
-- Data for Name: flyway_schema_history; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) FROM stdin;
4	4	service duration	BASELINE	V4__service_duration.sql	0	postgres	2026-05-18 21:47:53.395079	0	t
1	1	init schema	SQL	V1__init_schema.sql	-619930894	postgres	2026-05-18 21:47:53.395079	100	t
2	2	tooth conditions	SQL	V2__tooth_conditions.sql	-803108541	postgres	2026-05-18 21:47:53.395079	100	t
5	5	estimates views and patch	SQL	V5__estimates_views_and_patch.sql	1739990681	postgres	2026-05-18 21:47:53.395079	100	t
6	6	estimates provider column	SQL	V6__estimates_provider_column.sql	1634814579	postgres	2026-05-18 21:47:53.395079	100	t
7	7	invoices	SQL	V7__invoices.sql	1664324053	postgres	2026-05-18 21:47:53.395079	100	t
8	8	inventory	SQL	V8__inventory.sql	2129219223	postgres	2026-05-18 21:47:53.395079	100	t
9	9	recalls	SQL	V9__recalls.sql	2091619633	postgres	2026-05-18 21:47:53.395079	100	t
10	10	inventory seed	SQL	V10__inventory_seed.sql	-503713383	postgres	2026-05-18 21:47:53.395079	100	t
12	12	providers email	SQL	V12__providers_email.sql	-2001566407	postgres	2026-05-19 10:19:11.059689	149	t
13	13	patient diagnoses	SQL	V13__patient_diagnoses.sql	1170292070	postgres	2026-05-19 14:55:27.618526	306	t
14	14	patient prescriptions	SQL	V14__patient_prescriptions.sql	-1920508479	postgres	2026-05-19 14:55:28.518558	289	t
3	3	geo holidays	SQL	V3__geo_holidays.sql	-21960847	postgres	2026-05-18 21:47:53.395079	100	t
11	11	schema updates	SQL	V11__schema_updates.sql	-746141274	postgres	2026-05-18 21:47:53.395079	100	t
15	15	appointment status presente	SQL	V15__appointment_status_presente.sql	-1230221787	postgres	2026-05-19 20:08:51.852914	122	t
16	16	fix invoices schema	SQL	V16__fix_invoices_schema.sql	1677844431	postgres	2026-05-20 01:27:08.520772	937	t
17	17	create tenant invoice lines	SQL	V17__create_tenant_invoice_lines.sql	874400948	postgres	2026-05-20 01:34:49.282095	721	t
18	18	providers password hash	SQL	V18__providers_password_hash.sql	356955503	postgres	2026-05-21 21:31:27.346573	167	t
19	19	clinics billing columns	SQL	V19__clinics_billing_columns.sql	-724843636	postgres	2026-05-27 22:47:36.310081	185	t
20	20	providers role phone	SQL	V20__providers_role_phone.sql	111531480	postgres	2026-05-27 22:47:37.044053	356	t
21	21	add secretary role	SQL	V21__add_secretary_role.sql	412188291	postgres	2026-06-01 12:36:56.062472	108	t
22	22	chat history	SQL	V22__chat_history.sql	-462917725	postgres	2026-06-09 18:49:00.281122	214	t
23	23	create tenant function	SQL	V23__create_tenant_function.sql	-1198410848	postgres	2026-06-17 14:20:17.11953	18	t
24	24	tenant admin provisioning	SQL	V24__tenant_admin_provisioning.sql	642976385	postgres	2026-06-17 17:09:33.355319	20	t
\.


--
-- Data for Name: national_holidays; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.national_holidays (id, state_id, name, is_recurring, month, day, holiday_date, is_fixed) FROM stdin;
6268262f-24e7-4d25-b197-5220c9a1d6ca	00000001-0000-0000-0000-000000000001	Capodanno	t	1	1	\N	f
d208ad13-d339-4085-8dd3-02b86ad989be	00000001-0000-0000-0000-000000000001	Epifania	t	1	6	\N	f
1af480fd-9899-4a57-9928-55b771ff57f1	00000001-0000-0000-0000-000000000001	Festa della Liberazione	t	4	25	\N	f
bc64c7f1-847e-4583-b2d1-202cd0b0104c	00000001-0000-0000-0000-000000000001	Festa del Lavoro	t	5	1	\N	f
e25b6616-c5f3-4dea-8c70-95c82712146b	00000001-0000-0000-0000-000000000001	Festa della Repubblica	t	6	2	\N	f
cb10bc4c-e2aa-4de4-807f-80d73e10994b	00000001-0000-0000-0000-000000000001	Ferragosto	t	8	15	\N	f
581061ed-1eb2-4ab4-8577-6433b689d5f6	00000001-0000-0000-0000-000000000001	Tutti i Santi	t	11	1	\N	f
33ddefb2-020c-43d2-945f-3b798a657f17	00000001-0000-0000-0000-000000000001	Immacolata Concezione	t	12	8	\N	f
1e98454a-2b3a-4edc-80c9-f9f12bf45f2f	00000001-0000-0000-0000-000000000001	Natale	t	12	25	\N	f
f1716ff4-13a2-4345-91ee-070e52000f0f	00000001-0000-0000-0000-000000000001	Santo Stefano	t	12	26	\N	f
88033d23-757c-4a04-a404-7fbe4b0f1fa2	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2024-03-31	t
3ce6b0e2-52a1-454f-ba33-c0a8ff2316e6	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2024-04-01	t
3bca1250-f30f-4dd9-9460-4f70e22cabb9	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2025-04-20	t
93a21877-7e30-454f-bfc1-da34824399d8	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2025-04-21	t
5a5944b4-2d35-4f07-9aba-03ba2ac71348	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2026-04-05	t
c02bcf84-98a5-4a43-a3c8-d83a3966067e	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2026-04-06	t
eff8fc09-a88e-46a2-a531-00a53a075ae1	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2027-03-28	t
f2c3d539-d951-4a38-be41-dbd1f2424beb	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2027-03-29	t
90be453c-f4d4-4816-a66f-a372cb088a6c	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2028-04-16	t
169e6fe9-5e54-4a8b-9e7d-0b8fd5fefa36	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2028-04-17	t
6333867b-cf6e-4646-be30-6ec1660646e2	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2029-04-01	t
f2bc3ee1-37c1-4ce0-9dad-dc071180ed41	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2029-04-02	t
646e71b2-4909-4867-9790-f39c0b566ca3	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2030-04-21	t
a0dfbbc7-4752-4cc7-8e7e-588bd22e93dc	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2030-04-22	t
3889cca8-2284-4550-9860-1fa396b91956	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2031-04-13	t
ff3eff6a-ec35-4a05-84c8-0d59a18153e5	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2031-04-14	t
5b1e35a3-a950-4cd0-ad06-ba6db77b0503	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2032-03-28	t
01fd3b2a-bebd-49ce-85f4-d563365a6e34	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2032-03-29	t
326ddcd4-c96f-4ddc-b83a-4c8c8c6a8b32	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2033-04-17	t
106d0c62-fd42-4438-b45a-290f25275c70	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2033-04-18	t
24e79be2-473f-496c-9e23-72d91858b134	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2034-04-09	t
5183d883-681a-49a2-a305-538d40168ff7	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2034-04-10	t
88baff83-2b02-4500-85cf-573ccc6cf47b	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2035-03-25	t
d66f67f5-738e-474c-8d4d-a0f8be6287e6	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2035-03-26	t
4e4e088d-37eb-4962-bcfb-0b907eed7f39	00000001-0000-0000-0000-000000000001	Pasqua	f	\N	\N	2036-04-13	f
fefb9a51-df77-4428-b972-d06c4fea6c01	00000001-0000-0000-0000-000000000001	Pasquetta	f	\N	\N	2036-04-14	f
140601b9-fa49-48ff-bfad-1246c3a48a9d	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2025-01-01	t
47c5fc35-5533-44b8-b739-96936c957b74	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2025-01-06	t
81e301f0-1356-4d53-8fe6-295a19f8b842	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2025-04-25	t
377957c8-6c1a-494a-8082-629213be760f	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2025-05-01	t
127a9ce5-9a48-4b2e-838c-60df81d13da5	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2025-06-02	t
79afa779-1a4e-4b00-b397-d10981a6080b	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2025-08-15	t
4c6a83c8-5d7b-4627-8bf0-c7885ab5f9b3	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2025-11-01	t
2413c6c5-5d46-4c7e-9ee9-626c7978b3ff	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2025-12-08	t
77dcdb32-e258-4265-8fee-08dcb55d7351	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2025-12-25	t
e3e08ef2-4bd4-4724-ba9b-4968df278781	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2025-12-26	t
4430a0c6-70ea-4ad4-8984-b6f89d3ea7ba	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2026-01-01	t
6f14e8c4-e525-4dd6-98a2-8bd9033cc67a	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2026-01-06	t
8e7d301a-216c-4f64-b16c-f7225161c0a9	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2026-04-25	t
503d2734-6b73-4700-9eaf-339d1ffbf58c	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2026-05-01	t
10d96c27-17b7-4908-a408-cdf78cc477a7	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2026-06-02	t
5e066415-0bad-4466-aaca-0e3f357de650	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2026-08-15	t
7e5fbeb9-c073-4948-9b49-191639fd5367	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2026-11-01	t
9c033e07-45da-4094-a96c-99520791e95e	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2026-12-08	t
f9b8de9f-b254-42dc-98cb-5e590ab9ccb9	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2026-12-25	t
82df22e3-b128-48d9-9aa1-7b4cfa626894	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2026-12-26	t
ddb8c5a7-7ad0-42f6-b1f1-b953141db593	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2027-01-01	t
9bec3504-4148-4d84-9f42-50ca31b994ee	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2027-01-06	t
71e5b378-3476-473b-9c6e-3212bf4f8cd5	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2027-04-25	t
fc439c8b-63a3-48d4-8d02-221ffe4908fa	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2027-05-01	t
5e571f06-ee7a-47b8-ac92-4af14352b087	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2027-06-02	t
5147529b-8520-4379-87eb-4e42ada73a6f	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2027-08-15	t
396ecf87-7bb4-4c2b-8628-23d84cdb97f5	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2027-11-01	t
d94ed63c-2bc4-491e-a094-e4c2769dcb6f	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2027-12-08	t
018634a4-ce87-41e4-a336-8b971b38e3d0	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2027-12-25	t
09835967-c868-4d8d-a515-038e5b0517d6	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2027-12-26	t
6e14e756-af5f-4d4e-9bb3-449712e5ecbf	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2028-01-01	t
f2bc8d76-1c00-4e4e-900b-1230a6739ecd	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2028-01-06	t
6ffc81c9-5bd2-4ca2-be3e-396005924e77	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2028-04-25	t
09d0cd2b-5a87-4a09-b707-b8c038534f9d	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2028-05-01	t
78a167b6-82d7-4cbe-a6a1-4966a8ed212e	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2028-06-02	t
f62d53c7-3eab-4651-99a5-d829ff9c982e	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2028-08-15	t
c4ce7d41-7e69-4dd6-82bf-3a7509d2a0af	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2028-11-01	t
ad3257d4-9755-445e-bdbc-0677c491913c	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2028-12-08	t
7601a6d4-63b3-497a-a46d-62832bbbd056	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2028-12-25	t
451bf1b0-393c-49da-9103-40dd14cd4864	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2028-12-26	t
4f5078da-e260-48e9-b06e-e37295878b19	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2029-01-01	t
6a220940-891d-4817-b888-c6a119d1cd44	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2029-01-06	t
e44bd69b-5464-417e-8da2-e8aa03be1326	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2029-04-25	t
57e9b7d3-9d3f-4b04-b4c2-5da51e93fe42	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2029-05-01	t
4c8e7922-be38-40e5-9598-4d312983566c	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2029-06-02	t
ff7c2616-1872-401b-8fa8-9dc19d76cd13	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2029-08-15	t
d842743e-8db3-4f59-bfe7-57924f5e5047	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2029-11-01	t
e52a7fc6-5391-4dd9-ba7a-9a3cea0c4555	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2029-12-08	t
de13cdd1-4698-4c30-b7ac-e5cbde008170	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2029-12-25	t
83287f8b-e072-40ba-8dd2-9a8a6b6e7b3f	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2029-12-26	t
6b8e6b3d-b51b-4bf1-a2ff-02cba8450987	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2030-01-01	t
b143f46d-bf96-4b52-8af5-8d73f15f2525	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2030-01-06	t
8aae833e-830e-4754-9c98-de3d620589f6	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2030-04-25	t
787c8cf7-6ec9-4dc6-be45-12c28d45b8c7	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2030-05-01	t
65d7d692-bfd8-44a2-b93a-1769235918a8	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2030-06-02	t
57bcc9e2-e3ef-425e-bf80-e3cdcd70afeb	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2030-08-15	t
5593568d-1f49-4815-9b5b-9a56fbe817cc	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2030-11-01	t
bd80404c-6c5b-452e-9c5e-4c6e21fce2d4	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2030-12-08	t
8484c9a2-99d8-4ff7-9168-28e1d66d0e3f	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2030-12-25	t
b51c6f89-a1b7-4e70-8c0b-f953bde6dc94	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2030-12-26	t
9f3b54c4-771f-4b30-8ca9-ca0b8f6d4236	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2031-01-01	t
f2ea7d91-dcf3-403d-9a79-f09b329db419	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2031-01-06	t
99856904-4691-4cfd-82af-56cc6d9cc6e8	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2031-04-25	t
7cda1676-903b-4cd9-8e87-32d27f87deac	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2031-05-01	t
5205a19b-691f-46af-aa1f-3e35d6041487	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2031-06-02	t
db8f8f6e-6cbf-47c3-9b63-1c16d35185e0	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2031-08-15	t
cfd10f16-8dcb-4079-9429-cf6d9f18a02b	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2031-11-01	t
d4732b9e-7acf-4aee-a073-5e435716c3d3	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2031-12-08	t
871c0e73-a4c1-47fc-8cae-1c2696dfb623	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2031-12-25	t
55ce2343-8249-4944-84cb-b9691ed8435d	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2031-12-26	t
0725bf9f-5134-4a2b-bc8c-3f3cf0c89ece	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2032-01-01	t
33ca83c6-048f-4dbb-a99e-44687b899cf8	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2032-01-06	t
15d890ec-8ced-46f6-b98a-cd91e27f24de	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2032-04-25	t
c641c789-fb31-49ad-9afe-a0e1335209df	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2032-05-01	t
82445355-3cc3-4c2e-8e90-eea1f216bcb5	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2032-06-02	t
c6a3ebf7-14ae-4226-9fc7-fc1a9975593e	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2032-08-15	t
0561319d-6121-4e51-9fac-a4894a4405e7	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2032-11-01	t
f0deff07-fdf0-4f2e-9aff-ffb3df4740f9	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2032-12-08	t
a7deb8e7-62b8-4618-8ab3-55e0b7d4b85d	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2032-12-25	t
e265429d-07ed-4fe9-9905-7cb8fff84cbb	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2032-12-26	t
983ef370-56a1-4db2-926a-10253752b974	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2033-01-01	t
d45c12de-c94a-4774-b72a-faf8c8eb4b3b	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2033-01-06	t
d671bb84-2d5a-4794-90d4-9e6520220089	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2033-04-25	t
24821db7-4d29-4af8-8be2-adff4e38e816	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2033-05-01	t
aacd2b54-ab7f-4a0e-8d28-f12e9ce3a118	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2033-06-02	t
513cee97-fb21-413c-a70f-15dfedacd644	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2033-08-15	t
bc9566b9-1558-4726-8383-8a239d489c67	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2033-11-01	t
0f467dfa-9751-4d4c-a044-c093fe30d536	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2033-12-08	t
7ab3f15e-a860-4794-9f82-02c8cc3bbed8	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2033-12-25	t
88092b49-f711-4345-91ff-220b7837e26b	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2033-12-26	t
a08e5947-6adb-430c-8a84-c6ee3d942217	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2034-01-01	t
da2e458a-5239-4e4a-8d94-b44795092af5	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2034-01-06	t
c32386e6-3055-421c-9acb-1091182590e1	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2034-04-25	t
35415685-8a3d-42da-af35-c35f7d10b414	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2034-05-01	t
c692133b-81d7-4491-b13e-b88b91dab56c	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2034-06-02	t
2aa63edf-970b-4213-940c-d5bcf910e6f9	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2034-08-15	t
2c0df721-7abc-4b74-8c40-28c360265390	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2034-11-01	t
8adc28c9-c3c4-4b93-98ab-f9b53a5b6ecd	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2034-12-08	t
7d634407-a93d-437f-a227-88ae04b92567	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2034-12-25	t
faba1af0-e81c-49a5-a8cf-cb7551c9156c	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2034-12-26	t
2292176f-9974-4732-8709-a77cb5f178b0	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2035-01-01	t
4e1b2558-49c4-4271-97bd-8fa642d31d3c	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2035-01-06	t
c8ded605-3428-4bb0-921d-d7336fb44dd5	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2035-04-25	t
32baeeba-2381-4e71-b24b-b9ac1cfac944	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2035-05-01	t
3ae2d4d8-ed8a-4760-8f6b-c03e1c16a1e6	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2035-06-02	t
3f014de0-6264-45b7-88eb-d58d57272cb1	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2035-08-15	t
2fcea781-b6fa-4925-8b13-ee1746315f55	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2035-11-01	t
0cc45b5b-d153-40c0-ae60-48cb1958c9d7	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2035-12-08	t
930e6c72-4abb-457d-a539-58efb6549017	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2035-12-25	t
9c10f8b5-c906-4dff-aa37-1760cfed2b8c	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2035-12-26	t
d79f7dcd-9c3d-4c44-ba2b-84dfc8e94f1f	00000001-0000-0000-0000-000000000001	Capodanno	f	\N	\N	2036-01-01	t
7beb41e2-cb09-4b2c-b118-19fa6338df0e	00000001-0000-0000-0000-000000000001	Epifania	f	\N	\N	2036-01-06	t
37c6308e-d79d-478a-8cb2-639a23493f68	00000001-0000-0000-0000-000000000001	Festa della Liberazione	f	\N	\N	2036-04-25	t
252a3971-433d-441d-b7bd-488730b81f80	00000001-0000-0000-0000-000000000001	Festa del Lavoro	f	\N	\N	2036-05-01	t
b26dec9a-96e8-496c-be31-48b2be913b9b	00000001-0000-0000-0000-000000000001	Festa della Repubblica	f	\N	\N	2036-06-02	t
d26b5bae-0acd-4d63-8de0-ea3f5d68fe1c	00000001-0000-0000-0000-000000000001	Ferragosto	f	\N	\N	2036-08-15	t
45873251-0047-4dd9-a0d4-4718c7ec5f34	00000001-0000-0000-0000-000000000001	Ognissanti	f	\N	\N	2036-11-01	t
72ae03d8-849d-4cbd-b867-768686e34280	00000001-0000-0000-0000-000000000001	Immacolata Concezione	f	\N	\N	2036-12-08	t
c76fa94c-cd1c-4ec1-be48-5c66b806cf4a	00000001-0000-0000-0000-000000000001	Natale	f	\N	\N	2036-12-25	t
4d0cc877-02cc-44f5-b995-d54d3280d654	00000001-0000-0000-0000-000000000001	Santo Stefano	f	\N	\N	2036-12-26	t
\.


--
-- Data for Name: regions; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.regions (id, state_id, code, name) FROM stdin;
00000002-0000-0000-0000-000000000001	00000001-0000-0000-0000-000000000001	VDA	Valle d'Aosta
00000002-0000-0000-0000-000000000002	00000001-0000-0000-0000-000000000001	PMN	Piemonte
00000002-0000-0000-0000-000000000003	00000001-0000-0000-0000-000000000001	LOM	Lombardia
00000002-0000-0000-0000-000000000004	00000001-0000-0000-0000-000000000001	TAA	Trentino-Alto Adige
00000002-0000-0000-0000-000000000005	00000001-0000-0000-0000-000000000001	VEN	Veneto
00000002-0000-0000-0000-000000000006	00000001-0000-0000-0000-000000000001	FVG	Friuli-Venezia Giulia
00000002-0000-0000-0000-000000000007	00000001-0000-0000-0000-000000000001	LIG	Liguria
00000002-0000-0000-0000-000000000008	00000001-0000-0000-0000-000000000001	EMR	Emilia-Romagna
00000002-0000-0000-0000-000000000009	00000001-0000-0000-0000-000000000001	TOS	Toscana
00000002-0000-0000-0000-000000000010	00000001-0000-0000-0000-000000000001	UMB	Umbria
00000002-0000-0000-0000-000000000011	00000001-0000-0000-0000-000000000001	MAR	Marche
00000002-0000-0000-0000-000000000012	00000001-0000-0000-0000-000000000001	LAZ	Lazio
00000002-0000-0000-0000-000000000013	00000001-0000-0000-0000-000000000001	ABR	Abruzzo
00000002-0000-0000-0000-000000000014	00000001-0000-0000-0000-000000000001	MOL	Molise
00000002-0000-0000-0000-000000000015	00000001-0000-0000-0000-000000000001	CAM	Campania
00000002-0000-0000-0000-000000000016	00000001-0000-0000-0000-000000000001	PUG	Puglia
00000002-0000-0000-0000-000000000017	00000001-0000-0000-0000-000000000001	BAS	Basilicata
00000002-0000-0000-0000-000000000018	00000001-0000-0000-0000-000000000001	CAL	Calabria
00000002-0000-0000-0000-000000000019	00000001-0000-0000-0000-000000000001	SIC	Sicilia
00000002-0000-0000-0000-000000000020	00000001-0000-0000-0000-000000000001	SAR	Sardegna
\.


--
-- Data for Name: states; Type: TABLE DATA; Schema: dentalcare; Owner: -
--

COPY dentalcare.states (id, code, name) FROM stdin;
00000001-0000-0000-0000-000000000001	IT	Italia
\.


--
-- Data for Name: ai_conversations; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.ai_conversations (id, clinic_id, patient_id, provider_id, title, messages, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.appointments (id, clinic_id, patient_id, provider_id, treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes, cancellation_reason, created_at, updated_at) FROM stdin;
321a42e9-fa3c-4d62-ae3a-73e222de6bf7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-02-23 09:00:00+00	2026-02-23 09:45:00+00	no_show	Paziente non presentato	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
66c411b9-388a-44a4-8601-84d1dab953ca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-02-23 10:30:00+00	2026-02-23 11:30:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
79073776-a015-49e1-8753-8f0ef9d6eaa7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-02-23 14:30:00+00	2026-02-23 15:15:00+00	cancelled	Cancellato per emergenza studio	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1518137-d3f9-45e5-b445-e19fb3a7806a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-02-23 16:00:00+00	2026-02-23 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
54d456fb-ba63-4a7f-8075-c16bd016f94d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-02-24 09:00:00+00	2026-02-24 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
03f40408-c0b2-4b2d-92c6-cfb167557d6f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-02-24 10:30:00+00	2026-02-24 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
61ee1af9-ed92-406d-bb32-2f95d162313a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-02-24 14:30:00+00	2026-02-24 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3174cf7f-d233-4a0f-b564-8d4a7fdf768c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-02-24 16:00:00+00	2026-02-24 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
401c5f71-f04b-4727-9247-87968b150d6a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-02-25 09:00:00+00	2026-02-25 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7abd6da4-97d5-4d25-a9a7-82e32a996d4d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-02-25 10:30:00+00	2026-02-25 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4c3cc790-add1-443c-b07e-72ec8d40db3c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-02-25 14:30:00+00	2026-02-25 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f054877c-c5c5-4f16-8490-abf4c6762394	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-02-25 16:00:00+00	2026-02-25 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
577772c3-d916-450a-a0b4-bcf030087753	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-02-26 09:00:00+00	2026-02-26 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
514c0dd3-15d1-4952-9b4f-705d75a2f217	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-02-26 10:30:00+00	2026-02-26 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
41a4bd75-b0c9-4670-bdf7-631e1ff7c2d1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-02-26 14:30:00+00	2026-02-26 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9ee02881-3b27-4c2b-a955-3ad131a6cd1a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-02-26 16:00:00+00	2026-02-26 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7838de1e-b92b-4499-b40d-0c9e2c65ec94	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-02-27 09:00:00+00	2026-02-27 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
60c9e11e-1359-4286-84dc-ba1ec6c41e38	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-02-27 10:30:00+00	2026-02-27 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
48e16be0-39c7-4a7b-915f-655293f10c67	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-02-27 14:30:00+00	2026-02-27 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ac0b12aa-b316-4aed-a68a-e3b60195f276	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-02-27 16:00:00+00	2026-02-27 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e5f65a13-8646-4e9c-858c-5eaa7136ab59	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-02 09:00:00+00	2026-03-02 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
90f3974a-79f7-41c7-8fbd-1dc162fc5ed3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-02 10:30:00+00	2026-03-02 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7c5cbd36-778e-4518-8d97-11f82d1a8d9f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-02 14:30:00+00	2026-03-02 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
dcdb3939-9348-400d-a3a7-19a537aae2b7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-02 16:00:00+00	2026-03-02 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
69874963-0531-4452-a15f-bdf9d0fab29f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-03 09:00:00+00	2026-03-03 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1282423c-017b-4a07-915c-aefbbaece0b8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-03 10:30:00+00	2026-03-03 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
dc769e41-15a6-4c25-b68d-80de68bafd30	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-03 14:30:00+00	2026-03-03 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
456f74b8-1858-46d0-a322-a2da8e423b00	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-03 16:00:00+00	2026-03-03 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
63882ec2-7768-4606-bdf0-be26fc8d95fe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-04 09:00:00+00	2026-03-04 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
009dc156-267c-4f5b-9dc0-aef67085c519	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-04 10:30:00+00	2026-03-04 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9952e17b-421b-45fd-8e5f-dd963077eb70	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-04 14:30:00+00	2026-03-04 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
384049b9-753b-4e55-bb7e-34674c857ee9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-04 16:00:00+00	2026-03-04 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1b3ca51b-b63c-4b2f-ac58-ec216538d0f6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-05 09:00:00+00	2026-03-05 09:45:00+00	cancelled	Annullato per indisponibilità	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
19abcb4b-3ad9-4e45-b2b9-503669ad936f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-05 10:30:00+00	2026-03-05 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3329d9a7-bc4a-4d35-a123-94cb7ac0dd1f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-05 14:30:00+00	2026-03-05 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d5913a01-613c-43b4-b9b5-c4cc3c46c980	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-05 16:00:00+00	2026-03-05 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
829d520c-1f96-42db-8ff5-9db31cb9df4c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-06 09:00:00+00	2026-03-06 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f2ca71e8-abcf-4f0b-b5ae-0fb259d62ea7	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Poltrona 1	2026-06-04 08:30:00+00	2026-06-04 09:30:00+00	scheduled	Corona in zirconia — notenote	\N	2026-05-29 17:32:19.998727+00	2026-05-29 17:32:19.998727+00
8df25033-884e-4d72-b222-849f0665b45a	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-03 08:00:00+00	2026-06-03 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
59cf3d99-b211-448c-91cd-18113ee279a7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-03 10:00:00+00	2026-06-03 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1ef0e716-c4a7-4ed9-93bc-e763f452bd34	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-03 13:00:00+00	2026-06-03 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
262e08f3-bfeb-4592-8396-77a31521ee62	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-03 15:00:00+00	2026-06-03 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3b109934-68ea-43ca-b2f4-b6087071e95b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-03 07:00:00+00	2026-06-03 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
adbf4afc-3a34-49f0-a885-9575003755d9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-03 09:00:00+00	2026-06-03 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
42e85c0d-4e5b-4c8b-bad2-306526e1c259	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-03 12:00:00+00	2026-06-03 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c6b98988-dfed-4425-8d66-55719fbebd07	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-03 08:00:00+00	2026-06-03 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
556e2ac2-b461-4e20-84a2-0b584d6b97b7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-03 10:00:00+00	2026-06-03 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
006d2842-99cc-461f-9a70-0bd853fc6cc2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-03 13:00:00+00	2026-06-03 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5c4a01d4-eec3-4b48-aff3-bf9a2a304c78	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-03 15:00:00+00	2026-06-03 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
91317601-466e-46ef-903e-5c6b67832a84	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-03 07:00:00+00	2026-06-03 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
64ad6c48-bdb5-4357-9e42-11ac7f145a9e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-03 12:00:00+00	2026-06-03 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3b919926-83f8-4805-9505-3e5523c7c869	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-03 14:00:00+00	2026-06-03 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c45de181-05be-439f-a9e6-53142e70c1fb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-04 07:00:00+00	2026-06-04 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c0676dd1-83ca-4ada-b030-8dddebcd0116	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-04 09:00:00+00	2026-06-04 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9767d523-d63f-4136-b204-0065211b6e9d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-04 12:00:00+00	2026-06-04 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
42af3b1c-133f-45a6-b4f5-32be80a2079a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-04 14:00:00+00	2026-06-04 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
de7a9cc4-342f-4d20-8ac7-99d6862fc37f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-04 08:00:00+00	2026-06-04 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8f6f3a6f-9241-431b-bd7b-c6b6ddab9833	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-04 10:00:00+00	2026-06-04 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
019e22b6-bbb1-4912-bd45-67a331ee16d3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-04 13:00:00+00	2026-06-04 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9a8c51f6-e8bd-48af-b0ac-28ed05b0c47d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-04 15:00:00+00	2026-06-04 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
355122b4-9db6-4824-a548-d437b12da5eb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-04 12:00:00+00	2026-06-04 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
42825c62-e51d-43b3-aceb-ec73da02d14e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-04 14:00:00+00	2026-06-04 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cfa609f4-d1c3-4db3-898a-4c19210500df	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-04 08:00:00+00	2026-06-04 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
af8ce3b6-a3cf-4220-a6c7-2befe2aa698e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-06 10:30:00+00	2026-03-06 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7c7d8ce6-dc3d-4d1e-a125-900c78241ec2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-06 14:30:00+00	2026-03-06 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a5203779-d838-4070-b442-0a1219bf1f4b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-06 16:00:00+00	2026-03-06 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
aebc3080-8884-42e3-b23a-de594227adc1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-09 09:00:00+00	2026-03-09 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0b927bed-0c19-46ce-9fd5-8e23be80fa2b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-09 10:30:00+00	2026-03-09 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c1734083-ab2e-4362-bc4b-e37ce8960c6d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-09 14:30:00+00	2026-03-09 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a29abb3c-5b7c-4b14-a2e9-f1696f2be89d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-09 16:00:00+00	2026-03-09 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
80e84574-29a4-4dc7-8f28-6de6e135a91d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-10 09:00:00+00	2026-03-10 09:45:00+00	no_show	Paziente non presentato	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
090dd876-73a7-4068-b315-947ae9e2fb18	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-10 10:30:00+00	2026-03-10 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9c8ff470-c9e2-4c9b-be77-db40abbd27f4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-10 14:30:00+00	2026-03-10 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5d9d3ee7-0203-4adc-ac7c-2da46f7e2c09	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-04 10:00:00+00	2026-06-04 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f877b62b-13c9-46c5-b866-40f57da2764c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-04 13:00:00+00	2026-06-04 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ac281e17-7434-4f93-afb9-585cd7b19a63	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-04 15:00:00+00	2026-06-04 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b8f17135-6b9e-45fb-bf9c-c76d075f245a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-05 08:00:00+00	2026-06-05 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
05309dab-64a4-4529-9441-601b112e8a09	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-05 13:00:00+00	2026-06-05 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
069a60ff-4b80-4404-bba0-d3682f3a0ffe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-05 07:00:00+00	2026-06-05 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9e595903-a948-4a4c-b616-4b49c51b7720	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-05 09:00:00+00	2026-06-05 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9a1acf5b-da1a-45e1-824f-fe72843ddbdb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-05 12:00:00+00	2026-06-05 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a010b74c-989b-434b-aed3-21909e215f72	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-05 14:00:00+00	2026-06-05 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e5000b6a-8266-40c1-9c6f-79749d59c928	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-05 08:00:00+00	2026-06-05 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ff7ad933-168d-49a3-bc92-1bc27b4fb8d0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-05 10:00:00+00	2026-06-05 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e8515bb5-5fc5-4dec-a532-a198671e8db9	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-05 13:00:00+00	2026-06-05 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
332e071b-f854-4af5-aa95-f7ea08d1b322	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-05 15:00:00+00	2026-06-05 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
53afcabd-5508-42e1-b679-2f72cc289efc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-05 07:00:00+00	2026-06-05 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c0de73d2-b6a6-4c3d-97ac-82768a72fc8c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-05 12:00:00+00	2026-06-05 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6daad1fd-2ee6-4d65-998d-9295a1812c1f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-05 14:00:00+00	2026-06-05 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9aca403e-4b5c-4504-aa79-df733a157c3f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-08 07:00:00+00	2026-06-08 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9033572a-8463-4db3-b804-c6facade39a9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-08 09:00:00+00	2026-06-08 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
84d3cc87-0996-4852-adb2-59f177215b1d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-08 14:00:00+00	2026-06-08 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a67e2356-3f29-4222-9ca1-e55e31f0c2bb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-08 08:00:00+00	2026-06-08 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
20887331-407a-4172-9df8-c48a45e0ad04	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-08 10:00:00+00	2026-06-08 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
446464b8-586e-4ca2-9cb5-4004deadcaf8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-08 13:00:00+00	2026-06-08 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
369c04c8-6060-4160-b923-8f6788542e39	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-08 15:00:00+00	2026-06-08 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1dd2d956-a3e2-44c7-8a1d-ccedd781557f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-08 07:00:00+00	2026-06-08 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4db95266-43c8-489d-ab81-92b108aec270	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-08 09:00:00+00	2026-06-08 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
190546ed-cd7e-4c5c-a0f8-a51114ffbbb1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-08 12:00:00+00	2026-06-08 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cb608df5-85c1-4c77-88ac-b8a801582cbc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-08 14:00:00+00	2026-06-08 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4541bd4c-ed70-431a-a48b-6a292d6bbadb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-08 08:00:00+00	2026-06-08 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
92345e78-5b92-436d-a138-c1af7fe41ff1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-08 13:00:00+00	2026-06-08 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0b98cc14-3676-4935-8049-6d47c2d273e6	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-08 15:00:00+00	2026-06-08 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
dc1e7468-7436-49fa-8bf8-ee89ea2fdd4e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-09 08:00:00+00	2026-06-09 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b5339529-4be7-4629-85e9-6419a5f42dda	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-09 10:00:00+00	2026-06-09 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
88b44805-8784-4b7d-ad19-50914ab2f2aa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-09 07:00:00+00	2026-06-09 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
80190c9a-62c3-4888-a18a-7577a0676a95	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-09 09:00:00+00	2026-06-09 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7ad42650-eba0-4ed6-b90b-508b2a6c0661	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-09 12:00:00+00	2026-06-09 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f47d3e71-7270-4e96-83b1-bfa2c3ba2028	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-09 08:00:00+00	2026-06-09 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0490f450-3d09-4162-8d88-d7a224350cf7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-09 10:00:00+00	2026-06-09 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
555c9d69-5553-4633-b8d0-eae2b872e9f7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-09 13:00:00+00	2026-06-09 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f3c5e5d2-d919-4d93-8d98-7ab574901f67	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-09 15:00:00+00	2026-06-09 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0a800e6c-4994-48b5-b3bb-f5a81302cbc2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-09 07:00:00+00	2026-06-09 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a0e4c488-56d8-4e0a-b0c7-d1549bb8fa80	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-09 09:00:00+00	2026-06-09 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9be5f9cf-94ea-40a8-bb63-69448c82b8ce	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-09 12:00:00+00	2026-06-09 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
598425d7-10ee-4fdb-9d3e-6ea97ee8ae19	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-09 14:00:00+00	2026-06-09 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0b3690f0-4d46-4d00-b6c4-6d690b759623	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-10 07:00:00+00	2026-06-10 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ed5795de-9f9f-4998-b85b-1f50a89378e7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-10 09:00:00+00	2026-06-10 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
35a39bb8-bf0f-4403-80a7-2a43180d9504	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-10 14:00:00+00	2026-06-10 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a5e10e09-09d0-4b37-a20d-32632371cc49	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-10 08:00:00+00	2026-06-10 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0a468142-b45e-4a5b-ba87-65b40ec6bcad	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-10 10:00:00+00	2026-06-10 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cd8edfdd-14ea-478c-be6f-4bf83a1c5037	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-10 13:00:00+00	2026-06-10 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f6039f76-9ecc-41d8-a058-e2179f427f15	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-10 15:00:00+00	2026-06-10 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
40f2b4ab-4536-4d58-bf17-7748ef85e673	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-10 09:00:00+00	2026-06-10 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
da05e645-8f39-407a-aa3c-48fd7d3fe35f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-10 12:00:00+00	2026-06-10 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d5c79390-ca64-454d-93da-4e25448684f5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-10 14:00:00+00	2026-06-10 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
097a7f8b-5258-44d1-af19-0a555584eefc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-10 07:00:00+00	2026-06-10 08:00:00+00	confirmed	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:05:42.922513+00
3a0c748d-7197-45f7-8e69-b3b8263820ad	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-09 15:00:00+00	2026-06-09 15:30:00+00	confirmed	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:05:44.284529+00
092e321c-177a-4be9-a063-41b6a230d57e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-10 08:00:00+00	2026-06-10 09:00:00+00	confirmed	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-09 16:53:47.349845+00
5073f282-1c01-4433-98dd-e4258971b938	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-08 12:00:00+00	2026-06-08 13:00:00+00	cancelled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-09 16:53:54.10148+00
c2530375-1c07-41e4-8114-22851f9a5274	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-09 14:00:00+00	2026-06-09 15:00:00+00	cancelled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-09 16:53:52.65699+00
90bd3e74-e553-4c1a-98dc-5e56685b7814	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-10 12:00:00+00	2026-06-10 13:00:00+00	cancelled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-17 11:03:18.107677+00
72f6803d-9102-4150-b840-c03227d835db	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-08 10:00:00+00	2026-06-08 10:30:00+00	cancelled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-17 11:03:19.814977+00
c04b9cc0-7ba7-4b91-a350-5c187a956b94	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-10 10:00:00+00	2026-06-10 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3f270e81-ba41-4dd4-84ef-1c92ee4a4283	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-10 13:00:00+00	2026-06-10 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
99acff7b-8e86-4df0-afad-622bf4b4fa24	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-10 15:00:00+00	2026-06-10 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9285ce8f-5217-4fee-9653-0fbc5277a683	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-11 08:00:00+00	2026-06-11 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
834f51b2-c981-4de7-af62-9a14a2b523cd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-11 13:00:00+00	2026-06-11 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2b0a7be0-8e0d-4ade-ae30-26a74398ae9a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-11 15:00:00+00	2026-06-11 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d51e0b08-a1b0-4b25-94ab-9db3e52142bf	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-11 07:00:00+00	2026-06-11 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f7120527-7748-4e3b-bb00-310c15eb50ae	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-11 09:00:00+00	2026-06-11 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
aa7ab092-5857-456d-84b6-4a061b19249d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-11 12:00:00+00	2026-06-11 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
da39af61-bd51-4ee7-933f-beeecfb13fb8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-10 16:00:00+00	2026-03-10 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
058300e3-48b2-4118-9ed2-9a9f115bd093	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-11 09:00:00+00	2026-03-11 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
45d2766c-bfa9-442f-9400-952a7b6f1c12	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-11 10:30:00+00	2026-03-11 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
571e2cc7-73fa-4141-803b-1a18a67fddbe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-11 14:30:00+00	2026-03-11 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
640b964e-65b2-4f4d-a5ee-302abe90a22b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-11 16:00:00+00	2026-03-11 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
aa51df6f-b39c-4ff9-b950-d6770170f234	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-12 09:00:00+00	2026-03-12 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
185217e3-a247-46e3-975a-dc6388626029	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-12 10:30:00+00	2026-03-12 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3cc96f29-11f6-4d82-8636-11def0d4db70	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-12 14:30:00+00	2026-03-12 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
34777e80-c058-471a-aed1-cd79ccae2667	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-12 16:00:00+00	2026-03-12 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
dcf6e6cf-2fa9-4707-a661-bdbf0dc6055e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-13 09:00:00+00	2026-03-13 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d06ba4b4-ab29-4de3-bca0-b2a4cf387fc0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-13 10:30:00+00	2026-03-13 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bc861753-0f8a-478c-8427-b488df6184c9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-13 14:30:00+00	2026-03-13 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5bea0e0a-a4b1-42ac-bd0e-3e09b01349cb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-13 16:00:00+00	2026-03-13 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9b2b387c-ffc5-4afe-8649-5b41dd83dde3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-16 09:00:00+00	2026-03-16 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2198994f-9928-442d-86a8-db5ff89cbb5e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-16 10:30:00+00	2026-03-16 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1d743b96-a6bf-4c22-9a61-90a8a59909de	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-16 14:30:00+00	2026-03-16 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4572352e-e9e0-4fea-a621-cb968850c998	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-16 16:00:00+00	2026-03-16 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d9ebc8b1-bdd1-49f2-8460-99a2c8aa3fb1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-17 09:00:00+00	2026-03-17 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9f23a44c-ebbb-4c15-be2d-45f75b66d11f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-17 10:30:00+00	2026-03-17 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
54ec9d25-6bc3-4ced-b89d-9ee4e311b47d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-17 14:30:00+00	2026-03-17 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
00093499-6346-4c94-82f0-c604292de8ef	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-17 16:00:00+00	2026-03-17 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c12d7e63-f4fd-47f2-a4b2-8b32dccf0af4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-18 09:00:00+00	2026-03-18 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0c5eb6cc-4217-41c8-bb3b-98b5adab6d26	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-18 10:30:00+00	2026-03-18 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
55391575-b78f-4cbe-98cd-a26e03434158	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-18 14:30:00+00	2026-03-18 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a0039e72-36c9-45e3-9589-d9bdb029a744	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-18 16:00:00+00	2026-03-18 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
991dc6e5-8070-4321-b352-9935bbbc00a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-19 09:00:00+00	2026-03-19 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7610a38e-b974-487d-829a-1cb648904225	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-19 10:30:00+00	2026-03-19 11:30:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3fee9187-ae20-4793-b4a4-da031dfb9766	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-19 14:30:00+00	2026-03-19 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e9025cfa-af9e-4204-8fb1-c0be56e4c0fb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-19 16:00:00+00	2026-03-19 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e334d307-1d35-4952-87f7-72f45e089257	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-20 09:00:00+00	2026-03-20 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9d091127-47b5-4626-a931-d44ffce3d8ea	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-11 08:00:00+00	2026-06-11 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
848ca6d2-7855-4166-bdb0-e78d0e1adddf	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-11 10:00:00+00	2026-06-11 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0f83a4c0-230e-4c8d-91d1-ffb72c852ad2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-11 14:00:00+00	2026-06-11 15:00:00+00	cancelled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-17 11:03:16.286942+00
bfdbd747-bc33-4387-a682-3abfa2377239	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-20 10:30:00+00	2026-03-20 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
953b4ba7-ecc4-44ff-a22d-f705491a42af	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-20 14:30:00+00	2026-03-20 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
801b7967-6e81-49b7-98c6-86a51551139c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-20 16:00:00+00	2026-03-20 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4783b431-abf8-49b6-9b4d-959457656787	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-23 09:00:00+00	2026-03-23 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ca40d254-b7c0-4e39-a4b5-07b64cf34721	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-23 10:30:00+00	2026-03-23 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bd63435c-7b40-4e6c-88b6-71de8ceb88de	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-23 14:30:00+00	2026-03-23 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ede58154-c3da-4013-bb9e-6561756615e5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-23 16:00:00+00	2026-03-23 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bce0d032-4988-4e96-952d-f29481921317	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-24 09:00:00+00	2026-03-24 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ce0c8294-7074-4a36-adad-2dc450acebfe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-24 10:30:00+00	2026-03-24 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e41301ea-ceeb-4ba7-8ec2-b357f19214fb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-24 14:30:00+00	2026-03-24 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6b02ca3c-1e4e-44ef-9acc-dd1ce7650fca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-24 16:00:00+00	2026-03-24 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
190bc4a4-ca72-4183-9785-8ed56b417570	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-25 09:00:00+00	2026-03-25 09:45:00+00	no_show	Paziente non presentato	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0ff12376-30d9-47f9-a9e5-7a59e2cedad8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-25 10:30:00+00	2026-03-25 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8ddf201d-e324-414d-8d6d-ee57f7415fc2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-25 14:30:00+00	2026-03-25 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7552fb35-185e-4374-ab67-e73d23dc0a2b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-25 16:00:00+00	2026-03-25 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f061b149-1389-4849-ab61-a6a56260b713	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-26 09:00:00+00	2026-03-26 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bd30e915-225c-4ea4-b794-25c7ca2717b5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-26 10:30:00+00	2026-03-26 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ea05c8fa-0324-4aba-8926-6cfae8e0b9b4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-26 14:30:00+00	2026-03-26 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7484a007-6835-4a8b-bff3-f913a8c3b1a6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-26 16:00:00+00	2026-03-26 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bdbaa037-ea8c-4cbe-bb8e-6e75fc3ed5a5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-27 09:00:00+00	2026-03-27 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a157c0af-b164-4311-a74c-600df170d49c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-27 10:30:00+00	2026-03-27 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
86bdd8ab-4eba-42be-9198-a12d64e53b3e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-27 14:30:00+00	2026-03-27 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4a0d6faa-d5b4-4a3d-bee4-a022d437249b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-27 16:00:00+00	2026-03-27 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e87fabab-4d56-4170-848c-b9d8165f112c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-30 09:00:00+00	2026-03-30 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
95d9a8fc-ce65-4e3b-bac7-80c9d9af6b89	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-30 10:30:00+00	2026-03-30 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c764128a-127d-439b-9d22-419a06140879	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-30 14:30:00+00	2026-03-30 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
20c9e302-3b01-464e-aaad-98dec8a05409	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-30 16:00:00+00	2026-03-30 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
93b57753-3739-4b6e-ae5e-4560a16e8276	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-03-31 09:00:00+00	2026-03-31 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2358359c-3ae3-49c2-86e2-6b5e87741b5f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-03-31 10:30:00+00	2026-03-31 11:30:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ac4592b2-467f-4803-94f9-9b18e5f99706	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-03-31 14:30:00+00	2026-03-31 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
eab5f783-036e-4d34-b586-899de0585112	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-03-31 16:00:00+00	2026-03-31 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
61da84e1-98fc-4351-815a-3f46980ad066	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-01 09:00:00+00	2026-04-01 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ee589bf8-9715-4f0c-ae3d-1ffac27bfcd7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-01 10:30:00+00	2026-04-01 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b59d2da4-696b-416e-a921-8e8e58bc0d60	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-01 14:30:00+00	2026-04-01 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a307bf23-c4c0-44a5-b824-5233a8d31273	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-01 16:00:00+00	2026-04-01 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
53690300-35a5-4201-8fa5-1bc28947b0a4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-02 09:00:00+00	2026-04-02 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
36048a93-c4e3-4907-96ed-1f09f9459e32	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-02 10:30:00+00	2026-04-02 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f6ee0390-fc4d-4891-9b38-c4e7c8a851ac	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-02 14:30:00+00	2026-04-02 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1f54e275-382b-4e01-a5d3-a5985add62db	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-02 16:00:00+00	2026-04-02 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
28dbb851-91c8-4b1a-9098-03a54e2320d4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-03 09:00:00+00	2026-04-03 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
97a3db8f-d08e-40e9-b792-33d260de93f2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-03 10:30:00+00	2026-04-03 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
521281a4-4513-4112-b16a-650c09b628a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-03 14:30:00+00	2026-04-03 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d7d6b23d-c476-4bb9-b324-4fd5c03f7bee	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-03 16:00:00+00	2026-04-03 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
df05cfa7-3f63-48ea-b6f7-f9806860f2e9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-06 09:00:00+00	2026-04-06 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
980e7380-c2d3-4819-be2b-0b3d9bba8d24	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-06 10:30:00+00	2026-04-06 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bf2bd046-f175-4d22-a7a8-76b5f35b21cb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-06 14:30:00+00	2026-04-06 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
67756960-1f79-44e1-92c1-0b8a27cf6828	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-06 16:00:00+00	2026-04-06 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
68acd2c2-0f25-4064-badf-893bcf667598	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-07 09:00:00+00	2026-04-07 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6dc511f9-bd79-4e8e-91b1-53b3620c9f9c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-07 10:30:00+00	2026-04-07 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d98412c3-9884-478d-b35f-d332a3f68996	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-07 14:30:00+00	2026-04-07 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
33e994af-4d8a-4913-8614-04e53e4eca89	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-07 16:00:00+00	2026-04-07 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3421dcbf-972e-41ee-a1de-32eb8d5f14a4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-08 09:00:00+00	2026-04-08 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
27bddeb7-b3cc-484c-86dd-e01f3776a0be	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-08 10:30:00+00	2026-04-08 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6fcfb0bf-58c6-4284-b2d6-66b85077f16c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-08 14:30:00+00	2026-04-08 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
506a943e-c915-4c0c-8f21-c895cbdbc528	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-08 16:00:00+00	2026-04-08 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
79917fc0-3086-46cb-8b66-54a35bfd5c7a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-09 09:00:00+00	2026-04-09 09:45:00+00	no_show	Paziente non presentato	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
61165bba-80b0-4f32-a734-8ab5e46c9edc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-09 10:30:00+00	2026-04-09 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a11dc95e-7e8a-44cf-a1b4-da0a31d6e41f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-09 14:30:00+00	2026-04-09 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f014bb29-1f39-4922-bfea-d025044918fb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-09 16:00:00+00	2026-04-09 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1099fec2-f9af-4ccd-a6b2-59c72ebbc057	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-10 09:00:00+00	2026-04-10 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7642d932-53b0-4602-9de4-24c85f16fa79	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-10 10:30:00+00	2026-04-10 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
90538b01-b079-48d8-80bd-fc8d1ea7b1b1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-10 14:30:00+00	2026-04-10 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
87781dde-56d2-48db-801e-4e67989e93e4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-10 16:00:00+00	2026-04-10 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5e75888b-b57a-45d7-822e-4ec0171e07fc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-13 09:00:00+00	2026-04-13 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
43c74b1a-8ee1-44cd-871f-2dae5a9f8155	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-13 10:30:00+00	2026-04-13 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1407305a-b71c-44ee-9e69-6e00b4f33272	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-13 14:30:00+00	2026-04-13 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c53b282b-4f3e-4db2-8fbf-7dcd0315ad7f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-13 16:00:00+00	2026-04-13 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ed55aaa9-0bf6-4a4f-b8d0-eb663ea98ebb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-14 09:00:00+00	2026-04-14 09:45:00+00	cancelled	Annullato per indisponibilità	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2a8f071e-3855-4022-93b7-cece5c1a54c5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-14 10:30:00+00	2026-04-14 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6375dbf5-dad0-4621-ac83-1681aae72bf5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-14 14:30:00+00	2026-04-14 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
387bc8af-7761-417a-b57e-dead8301adb9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-14 16:00:00+00	2026-04-14 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
dc5cc10b-eea4-418f-ac7f-00c8e1fc56d8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-15 09:00:00+00	2026-04-15 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f5eac87e-5b05-442a-b58e-14cafdfadb6b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-15 10:30:00+00	2026-04-15 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4eddd918-e0dc-43f4-8d60-b50f7f8a9027	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-15 14:30:00+00	2026-04-15 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f3c27823-89e0-4bc2-bd8d-9e49a933b02c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-15 16:00:00+00	2026-04-15 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3655c0da-e854-408f-9f19-d43281767c92	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-16 09:00:00+00	2026-04-16 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a9288ab4-3de1-436d-a9f4-cfe4d31323db	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-16 10:30:00+00	2026-04-16 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a7bfaa14-ca9b-4841-832b-5281111f795c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-16 14:30:00+00	2026-04-16 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5602e2d2-10d6-42d8-bac7-1803c541f531	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-16 16:00:00+00	2026-04-16 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ae485326-30a4-4540-8112-29f2134ee43d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-17 09:00:00+00	2026-04-17 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
cfa4e9fe-1a4b-4449-b794-adc46701aee8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-17 10:30:00+00	2026-04-17 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2e5abbf8-888e-4c05-b155-5c2b274d1f9b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-17 14:30:00+00	2026-04-17 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
70ba73d9-2dfa-4392-b07a-e540c3f57db7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-17 16:00:00+00	2026-04-17 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1caf8852-5991-4556-a6f3-b8dcbc02be39	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-20 09:00:00+00	2026-04-20 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
97ced84f-0719-430b-bd70-580efb0018a5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-20 10:30:00+00	2026-04-20 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b4f7f9ea-8faf-419d-bf40-0d50687cad7b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-20 14:30:00+00	2026-04-20 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d44a2c0a-1c23-4ff6-9c6f-a5b2831632b4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-20 16:00:00+00	2026-04-20 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bda5dd0d-7924-4069-baf7-f4c1a659276b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-21 09:00:00+00	2026-04-21 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1e889314-a4f5-4642-a326-9dcc268a03d9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-21 10:30:00+00	2026-04-21 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
89df02f9-277a-46f6-8722-c151ffdb157d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-21 14:30:00+00	2026-04-21 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
74eebb16-b453-4965-986f-07b5acfc9e6e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-21 16:00:00+00	2026-04-21 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6e53d7db-1f37-420c-a9a4-6ce0ce81d712	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-22 09:00:00+00	2026-04-22 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6fee4c03-230c-4fd8-97ae-2fd4b176f0a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-22 10:30:00+00	2026-04-22 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ae4ae4a0-434f-43f5-ba0d-ad955506b7dd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-22 14:30:00+00	2026-04-22 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
36e1e516-fa6e-477d-95de-67124ee447a6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-22 16:00:00+00	2026-04-22 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
89945290-67f4-49c4-89f1-52aa62f3dd63	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-23 09:00:00+00	2026-04-23 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e4bb50f0-06c7-4333-8f0c-46f2e0c1cfcf	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-23 10:30:00+00	2026-04-23 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6d15eee6-080f-44fc-b220-54056a69644d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-23 14:30:00+00	2026-04-23 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
06c6faa4-c0d7-4130-9610-8c21b9df91d9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-23 16:00:00+00	2026-04-23 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2bed182-d92c-492d-ae27-2d823f0c9ec7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-24 09:00:00+00	2026-04-24 09:45:00+00	no_show	Paziente non presentato	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b46bc3ea-f0fc-4a4c-ae38-3d0f8e2137e0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-24 10:30:00+00	2026-04-24 11:30:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
614b5fd1-dfd6-4b9b-b464-cfcef8c2019c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-24 14:30:00+00	2026-04-24 15:15:00+00	cancelled	Cancellato per emergenza studio	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0a40c3aa-1e85-4907-b750-74564da97edb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-24 16:00:00+00	2026-04-24 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
78c37735-6c38-4aa8-addd-e6a66e718a62	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-27 09:00:00+00	2026-04-27 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ba258871-c352-46fe-995e-8999dba802b2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-27 10:30:00+00	2026-04-27 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d73737c2-b47f-437b-920c-6dadf4982eaa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-27 14:30:00+00	2026-04-27 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e50aab15-d143-4bda-8669-57e198fa4e35	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-27 16:00:00+00	2026-04-27 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f81e3ec1-6f68-47fd-9ab2-a2ac92ebaa57	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-28 09:00:00+00	2026-04-28 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
07ee13cd-8860-4aba-b206-c94ff71da417	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-28 10:30:00+00	2026-04-28 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ed1a3039-89c0-4187-bd0d-c62fd9da5542	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-28 14:30:00+00	2026-04-28 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fe303054-ef6b-4e59-bf18-abe4fd21a6f8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-28 16:00:00+00	2026-04-28 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b7db7e5e-6621-4cff-8f3d-6c3e0e7fb384	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-29 09:00:00+00	2026-04-29 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fed64fdc-0468-4d62-822d-3b7eb4e0ce7d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-29 10:30:00+00	2026-04-29 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2f3c073c-393d-42da-8a95-000639ee3f14	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-29 14:30:00+00	2026-04-29 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d8fa8089-6651-45dd-8b64-fd01a0d7836a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-29 16:00:00+00	2026-04-29 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bb657432-ee8f-4afd-a6fe-8f510d41be7d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-04-30 09:00:00+00	2026-04-30 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
40b56a2e-ebf8-4bf8-b927-eb32194fb474	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-04-30 10:30:00+00	2026-04-30 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8077accf-a16f-4cf5-bc4d-db0e281086c8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-04-30 14:30:00+00	2026-04-30 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7735cb1b-174d-405a-960b-ba6bbb22e287	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-04-30 16:00:00+00	2026-04-30 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5e294431-6d93-4d02-8a83-530fe1d74c95	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-01 09:00:00+00	2026-05-01 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7f0c3d10-f26f-4bab-9f33-87ed8d85ea6b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-01 10:30:00+00	2026-05-01 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4cf86276-8c13-4b91-96d9-5aeadcbc4d39	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-01 14:30:00+00	2026-05-01 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7e20375d-3840-40c2-8cdd-d58e38c386f4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-01 16:00:00+00	2026-05-01 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
12bb578a-72be-4efa-9bec-dd41183cbcdf	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-04 09:00:00+00	2026-05-04 09:45:00+00	cancelled	Annullato per indisponibilità	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8863d994-5350-45a3-a846-51c18e165dfd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-04 10:30:00+00	2026-05-04 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2da08ec2-3188-40d8-8a7f-2e098c1eb3bc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-04 14:30:00+00	2026-05-04 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b9d0179a-7427-4b44-82ff-967abe7fcd70	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-04 16:00:00+00	2026-05-04 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e76ed6fe-32ae-4c95-8736-e2f4749ea598	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-05 09:00:00+00	2026-05-05 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
226a9476-fb89-4715-8127-c45be92ab734	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-05 10:30:00+00	2026-05-05 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1b9363a6-8f70-4d8b-b51c-ce9ef400d522	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-05 14:30:00+00	2026-05-05 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a957505d-286e-46f8-80b5-f7bc51f317c8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-05 16:00:00+00	2026-05-05 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
87e213de-4fa6-4a95-9287-8e1f0b09fae6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-06 09:00:00+00	2026-05-06 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a3409ee5-edac-4df0-b476-77cb1364bf93	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-06 10:30:00+00	2026-05-06 11:30:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
54145a68-94ef-416d-b0e5-37b7ae7394a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-06 14:30:00+00	2026-05-06 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ac09487b-1dc4-426e-9404-374de2ff435b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-06 16:00:00+00	2026-05-06 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
457e670a-76a7-43e6-9497-08cbdb94c143	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-07 09:00:00+00	2026-05-07 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d5ac8e65-9385-4115-89ca-1fb745b52489	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-07 10:30:00+00	2026-05-07 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3bdbbced-9e36-4926-8912-938b28e3f07b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-07 14:30:00+00	2026-05-07 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c2cf7ec6-1294-4660-a1fc-cb3788be7041	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-07 16:00:00+00	2026-05-07 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6dd6f120-a26b-4301-8fe2-27a3b29013a6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-08 09:00:00+00	2026-05-08 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f266a91d-aa47-454b-bdb2-c758d6f320ef	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-08 10:30:00+00	2026-05-08 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7acee1f3-dcbc-4dcc-9830-c3e3ea9f7a53	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-08 14:30:00+00	2026-05-08 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
889f96de-2964-47b2-a033-2bc3eef13e71	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-08 16:00:00+00	2026-05-08 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
00abf2c7-b13f-4145-8f5a-2b6d7541c459	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-11 09:00:00+00	2026-05-11 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8e89eac1-1144-403a-9361-5ccac3019be0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-11 10:30:00+00	2026-05-11 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
043bc7a7-42f2-4320-b87d-4216f982e717	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-11 14:30:00+00	2026-05-11 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1d52025c-b35c-4825-9be5-bf8e9d9940ca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-11 16:00:00+00	2026-05-11 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
dbcfd5ed-8565-415f-857c-6a9256907abd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-12 09:00:00+00	2026-05-12 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8b9718a4-ac50-4672-a7ba-03ddc3ea8a52	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-12 10:30:00+00	2026-05-12 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d4149df2-30b9-49a5-a361-c0abfbe169e3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-12 14:30:00+00	2026-05-12 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6a8d62eb-7c83-42a5-b957-17cff8a099a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-12 16:00:00+00	2026-05-12 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d9f21f6a-fcb5-4edb-b612-5ca21e66aae9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-13 09:00:00+00	2026-05-13 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b8e57192-253d-42db-902c-3dda2b11c057	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-13 10:30:00+00	2026-05-13 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2f0770d5-919c-4e9c-bef3-61e596efd01b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-13 14:30:00+00	2026-05-13 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ee586691-30fe-4875-b56f-1fd44d88bf09	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-13 16:00:00+00	2026-05-13 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0bf95f16-5aa3-4624-8092-af2fade0dfa9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-14 09:00:00+00	2026-05-14 09:45:00+00	cancelled	Annullato per indisponibilità	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9a219ff7-9b9b-4d3e-97d4-40f5ae88c8d2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-14 10:30:00+00	2026-05-14 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a8a91453-903c-4035-9b00-1cd190bbde95	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-14 14:30:00+00	2026-05-14 15:15:00+00	cancelled	Cancellato per emergenza studio	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6bfeae5e-2b6d-4054-af0a-01f81d93ff4a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-14 16:00:00+00	2026-05-14 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0cb7a4fe-9b19-459d-8862-b4f189f0d1ac	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-15 09:00:00+00	2026-05-15 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
06c69241-28ca-49e0-9543-5fd316476383	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-15 10:30:00+00	2026-05-15 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
525eb555-dc36-435e-a2c2-83ff6426ac66	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-15 14:30:00+00	2026-05-15 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
36169e50-703b-4dc7-b7a3-c68cf30c73b2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-15 16:00:00+00	2026-05-15 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
641b8062-7bf9-4c2f-9715-6ed5bb890f3f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-18 09:00:00+00	2026-05-18 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
443a56b3-b47a-4e09-9c01-c34efc8886b1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-18 10:30:00+00	2026-05-18 11:30:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3c204ec8-f80e-4e4e-bc9a-1d1db232d0f3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-18 14:30:00+00	2026-05-18 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
146e45cd-936c-4718-8fb2-e45070a31250	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-18 16:00:00+00	2026-05-18 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8e4e9335-0b20-437a-89be-c706a1abf2c7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-17 14:00:00+00	2026-06-17 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
adec04d4-957a-42ad-89be-6fbe5b636515	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-19 09:00:00+00	2026-05-19 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d714e037-e952-4a21-bdc2-4ff64bf8dd42	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-19 10:30:00+00	2026-05-19 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ca4bbf2c-da3f-4194-9f3e-ac0fd7e81c40	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-19 14:30:00+00	2026-05-19 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bbdb01f5-9563-43d9-bd3e-db9e81ebce92	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-19 16:00:00+00	2026-05-19 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
45ad3192-fccc-46a2-8c4c-69d8e2590115	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-20 09:00:00+00	2026-05-20 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
80a4e7fc-0ba7-46ef-8444-b6cd99515c81	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-20 10:30:00+00	2026-05-20 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2ccf2e9d-d478-472c-853b-e57878aba326	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-20 14:30:00+00	2026-05-20 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
290e6aba-be83-41be-ad42-0e59c8371b44	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-20 16:00:00+00	2026-05-20 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0566b002-c384-44e8-af5b-863d3160ca4d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-21 09:00:00+00	2026-05-21 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7d3a0276-4e50-4cd8-9357-6deb779cb34f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-21 10:30:00+00	2026-05-21 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d29d73de-367b-4a9e-8dd9-b2d0bdb69f52	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-21 14:30:00+00	2026-05-21 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
07f3219d-7681-417f-8d58-a7c6e52fb1f6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-21 16:00:00+00	2026-05-21 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
036b0e13-463a-41c3-b60a-c5ac8ed4a46a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-22 09:00:00+00	2026-05-22 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5a2cd5e5-7cd5-4f8f-adf9-117ab7d96a12	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-22 10:30:00+00	2026-05-22 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fc11d33a-be54-4a9c-adbb-b47a4f7fd28f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-22 14:30:00+00	2026-05-22 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a4967dba-90f7-4bdc-bdfa-0c44061fe4d6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-22 16:00:00+00	2026-05-22 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8a7577d5-758f-4676-8599-71f494c37f86	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-25 09:00:00+00	2026-05-25 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
25be861e-77bb-4e4a-b522-d83cb5e3fde1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-25 10:30:00+00	2026-05-25 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
df48ad82-c5e4-42b1-8ec7-7d725927f213	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-25 14:30:00+00	2026-05-25 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
060d676d-f252-46a0-83f0-13b4a0bcdf8d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-25 16:00:00+00	2026-05-25 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
77e27c74-be0e-49c9-9e18-5a8780dd62ec	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-26 09:00:00+00	2026-05-26 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f09630d8-bfed-496e-8d24-b091c684c8b4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-26 10:30:00+00	2026-05-26 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ea4367d4-1773-434e-abd9-4d2def4f9d3f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-26 14:30:00+00	2026-05-26 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
947c8bb2-3d40-4b62-9720-162142841a57	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-26 16:00:00+00	2026-05-26 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e419ff27-8908-4a23-a3ea-651152e2a115	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-27 09:00:00+00	2026-05-27 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a49225e8-27af-40fd-8333-84b6f4c0acfd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-27 10:30:00+00	2026-05-27 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7ea8167b-225a-4267-9ab4-7ed4ab1d5ac8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-27 14:30:00+00	2026-05-27 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
91294b29-279a-4436-a044-ec53c663cfd7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-27 16:00:00+00	2026-05-27 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1a14f255-a7e2-482b-9e02-4ddbcb969db3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Poltrona 1	2026-05-28 09:00:00+00	2026-05-28 09:45:00+00	completed	Seduta eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ca839af8-b5a2-4a26-ab7a-519c3b8ebd8d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-28 10:30:00+00	2026-05-28 11:30:00+00	completed	Trattamento eseguito correttamente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a7505b10-c4b8-455a-b2fc-bfb422cd6804	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Poltrona 3	2026-05-28 14:30:00+00	2026-05-28 15:15:00+00	completed	Seduta pomeridiana completata	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b823206b-75f3-4b97-9ddb-c30f873ddc41	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Poltrona 4	2026-05-28 16:00:00+00	2026-05-28 17:00:00+00	completed	Ultima seduta della giornata - eseguita regolarmente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c5f42cc3-7f12-4a21-b652-7324df104420	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-22 09:00:00+00	2026-05-22 09:45:00+00	completed	Igiene professionale eseguita	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2e2c8030-f961-4693-8dc5-c5ff4b9c6b5d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Poltrona 2	2026-05-22 10:00:00+00	2026-05-22 11:00:00+00	completed	Estrazione 48 eseguita senza complicazioni	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
00f53d6b-0e40-4842-9673-d176159ce366	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Poltrona 3	2026-05-22 11:00:00+00	2026-05-22 11:45:00+00	no_show	Paziente non presentato - da ricontattare	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9391c2b6-54a9-4e65-9e8e-1534ac5f45d7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-22 15:00:00+00	2026-05-22 15:45:00+00	completed	Otturazione composito eseguita	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
04b5e29a-918e-431d-838a-45b006d4a132	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Poltrona 2	2026-05-22 16:00:00+00	2026-05-22 17:00:00+00	completed	Controllo ortodonzia - archwire sostituito	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
58751e4e-7a0e-49cd-9624-5f0ed269f89d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000002	Poltrona 1	2026-05-26 09:30:00+00	2026-05-26 10:30:00+00	completed	Otturazione 16 completata con successo	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fdaa1fc6-c4a2-4936-b0ca-be263147a5f7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000005	Poltrona 2	2026-05-26 10:00:00+00	2026-05-26 10:30:00+00	completed	CBCT eseguita - risultato nella documentazione	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
62a5def2-3633-443e-bf87-0b1a33c1cbef	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Poltrona 3	2026-05-26 14:30:00+00	2026-05-26 15:15:00+00	completed	Prima igiene - molto tartaro	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
80865525-0d96-4446-a425-bb03720b7725	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-26 16:00:00+00	2026-05-26 16:45:00+00	cancelled	Annullato per impegno paziente	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4d98264e-52d4-432b-8cc2-71bdcb6ad1f9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-11 10:00:00+00	2026-06-11 10:30:00+00	confirmed	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:06:09.051364+00
25ea25f9-5d16-45f8-b00e-e051049692a2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-28 08:30:00+00	2026-05-28 09:15:00+00	completed	Visita di controllo - programmata igiene	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
766e4a4b-9713-43f0-b221-5aef6531eb70	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	f1000001-0000-0000-0000-000000000011	Poltrona 2	2026-05-28 10:00:00+00	2026-05-28 11:00:00+00	completed	Controllo mensile ortodonzia	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f50ffaef-d09c-4570-9e9f-3a41169b1fbe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Poltrona 3	2026-05-28 11:30:00+00	2026-05-28 12:15:00+00	completed	Igiene profonda quadrante sup. sinistro	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
11f0437d-7ee0-4757-8cd9-a3cc3e258e3b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-28 15:00:00+00	2026-05-28 15:30:00+00	completed	Radiografia di controllo post-otturazione	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e0d1e324-ec10-4e78-9d96-d5faf236bd5a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000026	Poltrona 2	2026-05-28 16:00:00+00	2026-05-28 17:00:00+00	completed	CBCT 46 pre-impianto eseguita	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c7bf2220-244f-48e6-ad98-0b4e95d58bba	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-29 08:30:00+00	2026-05-29 09:15:00+00	completed	Visita estetica - raccolta impronte	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0773060b-fa69-4202-ace0-6689daaa2013	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	f1000001-0000-0000-0000-000000000009	Poltrona 2	2026-05-29 09:00:00+00	2026-05-29 09:45:00+00	completed	Igiene professionale eseguita	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4ee7214f-a1f5-42f6-93f5-76d7c115cb50	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Poltrona 3	2026-05-29 09:30:00+00	2026-05-29 10:30:00+00	completed	Controllo post-estrazione 18	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d341c4d5-2e9a-4af5-b395-df00ab732b0b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-05-29 10:00:00+00	2026-05-29 10:45:00+00	completed	Otturazione 25 - composito	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
61b2eec4-95f4-4fd0-bee0-b1525357ad95	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000003	Poltrona 1	2026-05-29 11:00:00+00	2026-05-29 11:45:00+00	in_progress	Otturazione 14 - in corso	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e627c22e-ac84-4e86-8d3f-6939dc92bb1e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000006	Poltrona 2	2026-05-29 14:30:00+00	2026-05-29 16:00:00+00	confirmed	Inserimento impianto 36 - procedura chirurgica	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7f070cc9-bed1-469f-9f0b-e5aa5507a6f3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Poltrona 3	2026-05-29 15:00:00+00	2026-05-29 15:45:00+00	confirmed	Igiene semestrale	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
20a4ddf8-5d0d-4323-aff5-92b20f63fbe3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000028	Poltrona 1	2026-05-29 16:00:00+00	2026-05-29 16:30:00+00	confirmed	Prima visita - dolore dente 26 - valutazione devitalizzazione	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1264c87f-c4f6-4442-b2c2-72024452be78	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Poltrona 2	2026-05-29 17:00:00+00	2026-05-29 18:00:00+00	confirmed	Visita ortodontica per valutazione trattamento	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0f1a9467-0268-41a6-a2bf-5f7f5e25cc99	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000016	Poltrona 1	2026-05-30 09:00:00+00	2026-05-30 10:30:00+00	scheduled	Devitalizzazione 26 pluriradicolare - prima seduta	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ca01c4e8-9021-454a-9fed-ca493eec265b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-05-30 10:00:00+00	2026-05-30 10:45:00+00	scheduled	Igiene professionale semestrale	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a2fe3b01-2b4c-4e74-b962-1de9a988e77e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Poltrona 3	2026-05-30 14:30:00+00	2026-05-30 16:00:00+00	scheduled	Estrazione 38 incluso - riprenotato dopo no-show	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a46f026a-76cc-4713-9b57-0a37e66196fb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000025	Poltrona 1	2026-05-30 15:30:00+00	2026-05-30 16:30:00+00	scheduled	Otturazione 37 trifacciale	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fc3d4ca9-c447-4ff7-af74-e20385d77c0f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	f1000001-0000-0000-0000-000000000011	Poltrona 1	2026-05-31 09:00:00+00	2026-05-31 10:00:00+00	scheduled	Controllo mensile apparecchio fisso	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
401a1b7e-6634-4f74-84d8-77e790833815	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Poltrona 2	2026-05-31 10:30:00+00	2026-05-31 11:15:00+00	scheduled	Otturazione 35 monofacciale	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
368dbabb-cb8f-4a82-ba49-c4c8603854b4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Poltrona 3	2026-05-31 15:00:00+00	2026-05-31 16:00:00+00	scheduled	Chirurgia parodontale quadrante inf. destro	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
20d17773-d31c-4683-b3de-fc4555770208	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	f1000001-0000-0000-0000-000000000023	Poltrona 4	2026-05-31 16:00:00+00	2026-05-31 17:00:00+00	scheduled	Levigatura radicolare 1° quadrante	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2ce1e894-a353-464d-87d3-d7a58b6dd0b9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Poltrona 1	2026-06-03 09:30:00+00	2026-06-03 10:15:00+00	scheduled	Igiene professionale	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
28a0a8e2-226d-4d85-9306-ef69ff94ec92	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000027	Poltrona 2	2026-06-03 14:00:00+00	2026-06-03 15:30:00+00	scheduled	Inserimento impianto 46	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3079c28e-d2fb-480c-8e09-fa8b1c68c84c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Poltrona 3	2026-06-03 16:00:00+00	2026-06-03 17:00:00+00	scheduled	Prima valutazione ortodontica e foto intraorali	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
023a4ebd-ad5e-48b4-a956-6543e314c133	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-06-05 10:00:00+00	2026-06-05 11:00:00+00	scheduled	Otturazione 46 trifacciale	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
046f161b-c1ea-4869-932c-18a3bedbb058	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Poltrona 2	2026-06-05 11:00:00+00	2026-06-05 11:45:00+00	scheduled	Igiene profonda completamento	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f0f5b08e-196c-4736-88fe-28e22b585437	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000020	Poltrona 1	2026-06-05 14:30:00+00	2026-06-05 15:30:00+00	scheduled	Otturazione bifacciale 35	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b7598085-4a1b-4ba9-9e24-03ebbf9ea1be	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000004	Poltrona 1	2026-06-12 09:00:00+00	2026-06-12 09:45:00+00	scheduled	Igiene di mantenimento - completamento piano cura	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ab550286-7424-4bbd-ab67-0fb04187b848	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Poltrona 2	2026-06-12 10:00:00+00	2026-06-12 10:30:00+00	scheduled	Controllo post-chirurgia impianto 36	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b355aad8-5ab5-426f-9e44-7ba0cbce96fe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000017	Poltrona 3	2026-06-12 14:30:00+00	2026-06-12 15:30:00+00	scheduled	Corona 26 post-devitalizzazione - prova	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f9f780bd-1061-46e9-89ec-49f187aea52f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Poltrona 1	2026-06-12 16:00:00+00	2026-06-12 16:30:00+00	scheduled	Controllo post-otturazione 37	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
adcdbded-939b-41d4-bb09-32ae8cc75c0a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-11 13:00:00+00	2026-06-11 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7993dabb-03fe-45bc-975f-2270e9294d88	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-11 15:00:00+00	2026-06-11 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2621cfe9-53d3-4642-ae6e-60b1a6f46809	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-11 07:00:00+00	2026-06-11 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d48569d0-949f-429c-a44e-22f5cbff7ca6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-11 12:00:00+00	2026-06-11 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9b0bb80f-0941-41a6-993c-97275d7af706	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-11 14:00:00+00	2026-06-11 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
66efec8f-cbd2-462d-9d71-e8a7962e5bfe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-12 07:00:00+00	2026-06-12 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d45c673b-2a5f-414f-affa-56f1eb30fe5b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-12 12:00:00+00	2026-06-12 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f9584141-6a19-4eea-90ac-bc9cac27bfd6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-12 08:00:00+00	2026-06-12 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
791282f5-45e1-4cc1-b751-9f444c46a22a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-12 13:00:00+00	2026-06-12 14:00:00+00	confirmed	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:06:07.769107+00
f3f619c2-a990-4b24-891c-1d704194b76b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-12 15:00:00+00	2026-06-12 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c1af7081-09a6-4dfb-bee7-7abd0a5bc54b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-12 07:00:00+00	2026-06-12 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9867125b-581c-4c56-a5d4-1d569e083de5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-12 09:00:00+00	2026-06-12 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a4e0706e-3821-4e5a-9c0b-b7281443e87a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-12 12:00:00+00	2026-06-12 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1b48b9e5-f6b4-4168-b9f6-72d92219ec08	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-12 14:00:00+00	2026-06-12 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8f170ac2-9e33-41d1-b13f-1844ea5db352	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-12 10:00:00+00	2026-06-12 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5c7574cb-bd20-4d5c-806e-8e0631e70cf5	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-12 13:00:00+00	2026-06-12 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d984556f-bf21-4240-adff-d356216408bc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-12 15:00:00+00	2026-06-12 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c14f5325-6da5-46c4-ad36-5d5c98a55e7b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-15 08:00:00+00	2026-06-15 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6e342098-7cb9-4ddc-8686-84b0a57aceed	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-15 10:00:00+00	2026-06-15 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
532ad7d9-70bb-4f96-9c0f-2ce69c75f472	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-15 15:00:00+00	2026-06-15 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
80cc1ebc-e236-4887-ba4a-49deeb4b3cf9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-15 07:00:00+00	2026-06-15 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bd5d1d36-2c8e-4374-9521-a54a2a4c1c5a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-15 09:00:00+00	2026-06-15 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d0d2b981-d0e1-422e-8e0a-b01f4d56c09a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-15 14:00:00+00	2026-06-15 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d4ae9be2-de96-4f02-83b3-8b4fbe564758	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-15 08:00:00+00	2026-06-15 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b08a6ded-bcb8-4828-8676-c3d4985ed51b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-15 10:00:00+00	2026-06-15 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ec890590-e25e-470e-9aaf-4a83bd96f0a2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-15 13:00:00+00	2026-06-15 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4f593a20-8b72-4500-b761-ccb2c6738cbd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-15 07:00:00+00	2026-06-15 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cd36fccd-62ba-4519-ba98-c818c3f9886e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-15 09:00:00+00	2026-06-15 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b22b407f-2512-45d0-8987-14c14d91c2d1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-15 12:00:00+00	2026-06-15 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ad810e25-fbf3-4346-920f-0f348c8ddb84	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-15 14:00:00+00	2026-06-15 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
13bd4f90-c62f-471d-91d7-4691b509ff29	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-16 07:00:00+00	2026-06-16 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ac63f0e9-fec5-458d-b873-889d00ab73d5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-16 12:00:00+00	2026-06-16 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
eb25c643-1741-4809-abe2-153d61c56ed7	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-16 14:00:00+00	2026-06-16 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8f8c8610-0579-4665-8da1-959af7794318	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-16 08:00:00+00	2026-06-16 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0c365e3a-ba3f-4154-a421-09754fdf3d93	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-16 10:00:00+00	2026-06-16 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
31ee15fe-ff80-4f1a-8341-7381f845550f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-16 13:00:00+00	2026-06-16 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
df6400fb-099f-4556-90e4-d51352f7a56a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-16 07:00:00+00	2026-06-16 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7aef093c-cf91-41b5-b9a3-812b7f1dc5fc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-16 09:00:00+00	2026-06-16 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3f6fa2fd-32af-4c29-ba3d-bf98ffd57d8a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-16 12:00:00+00	2026-06-16 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
45c1cfdb-c44c-47f3-9f78-903b06f3bae3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-16 08:00:00+00	2026-06-16 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4bdcec6f-722a-424d-8831-3a35f25e65dd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-16 10:00:00+00	2026-06-16 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8f7b29e3-8f2d-4c75-b7e9-44e1ea64ec77	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-16 13:00:00+00	2026-06-16 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6dd4942a-6094-435c-b6ae-1b8af2bb3599	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-16 15:00:00+00	2026-06-16 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
decab9cb-2873-4ef6-8364-c7d5597fbae7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-17 10:00:00+00	2026-06-17 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0185d0e0-4a63-41bd-95bf-f5619b4525d0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-17 13:00:00+00	2026-06-17 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0a1b0ab4-773e-4af1-b83a-3f256a722df1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-17 15:00:00+00	2026-06-17 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0a75b961-83eb-465a-9a3d-b0f7d6db4ed7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-17 07:00:00+00	2026-06-17 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b1304428-c278-4e4d-bbf8-404e1b141798	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-17 09:00:00+00	2026-06-17 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2a6a74bb-6694-4d44-8460-55a259c60556	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-17 08:00:00+00	2026-06-17 09:00:00+00	confirmed	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:06:05.166218+00
12692117-b22d-45b2-8387-94aa8cdc5cfb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-15 15:00:00+00	2026-06-15 15:30:00+00	confirmed	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:06:06.733131+00
bf3b43bb-0d70-4c42-8937-2b05efd4adf1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-16 14:00:00+00	2026-06-16 15:00:00+00	confirmed	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-09 16:53:44.724413+00
bf9faeb3-be9c-465e-b40f-8aa8cb2ec4f0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-15 12:00:00+00	2026-06-15 13:00:00+00	confirmed	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-09 16:53:46.104878+00
9f536f7c-c583-4c6b-baec-0b298bd223aa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-17 12:00:00+00	2026-06-17 13:00:00+00	confirmed	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-17 11:02:55.034819+00
393a9dfe-c910-4720-9a14-a9b2c06cc160	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-16 09:00:00+00	2026-06-16 10:00:00+00	confirmed	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-17 11:03:10.61568+00
17221b5f-c95b-4ddc-930c-cd2b3e7cda54	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-12 08:00:00+00	2026-06-12 09:00:00+00	cancelled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-17 11:03:14.911898+00
ad775b7f-a790-4d64-88e6-04c4de1e92f0	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-17 08:00:00+00	2026-06-17 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1c828882-4ec1-49a6-b194-7959f68bc79c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-17 10:00:00+00	2026-06-17 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b88adb81-cf45-4ec8-b3c4-82a6504d9311	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-17 13:00:00+00	2026-06-17 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5ad084e3-b012-4d09-b319-9f70915cf895	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-17 15:00:00+00	2026-06-17 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
61a8e15c-b41d-4c4c-a469-481d11ff8fde	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-17 09:00:00+00	2026-06-17 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
47229fe3-9971-43e2-b3c7-f8fcc286465c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-17 12:00:00+00	2026-06-17 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
55417823-71d9-477f-a1b6-c5009e258720	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-17 14:00:00+00	2026-06-17 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
69c19ecb-cbb4-418c-bb99-e0520eba0c44	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-18 09:00:00+00	2026-06-18 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6c706828-5777-4aad-9f78-1dbac53ce744	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-18 12:00:00+00	2026-06-18 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
950b517f-8eee-4d13-9342-9ab4df416644	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-18 14:00:00+00	2026-06-18 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
55131813-f691-4199-b275-02fe97191a16	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-18 08:00:00+00	2026-06-18 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a5c1116b-1527-4762-9857-a7dbe2b91a05	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-18 13:00:00+00	2026-06-18 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
44f9244f-5345-4c32-a497-85f291619445	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-18 15:00:00+00	2026-06-18 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fd0f8a05-8a3a-4cc3-a2b2-08a7f301f3d1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-18 07:00:00+00	2026-06-18 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e52bddf5-993a-40ae-996b-1aee4f08f409	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-18 09:00:00+00	2026-06-18 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
51dfba3c-521d-436f-9981-6fd008fe677c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-18 12:00:00+00	2026-06-18 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8027ca85-26ef-45e0-b96c-949a8e4b141a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-18 14:00:00+00	2026-06-18 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e50ffd73-528b-45d3-a886-31f8e25558f8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-18 08:00:00+00	2026-06-18 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
02493a41-64ac-4bce-8405-bd59079a9f75	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-18 10:00:00+00	2026-06-18 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
998a9b19-5730-43e3-9e9a-99dae0003044	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-18 13:00:00+00	2026-06-18 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
735350f3-59ba-4b40-b1fb-8cf87f5e7e19	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-18 15:00:00+00	2026-06-18 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
47827da3-4255-4ed0-b10d-a69f7764f2dc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-19 08:00:00+00	2026-06-19 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a9e2ce0c-4013-4178-ac76-ffcbacc3f84e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-19 10:00:00+00	2026-06-19 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e230e736-eb18-483c-867f-3b2d0a86daab	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-19 13:00:00+00	2026-06-19 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8609182d-a163-45b9-916c-ae3152d8c562	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-19 15:00:00+00	2026-06-19 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0c8f3f20-17b9-4fa3-ba65-55cbd23a4d51	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-19 07:00:00+00	2026-06-19 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3fd2b249-010e-467c-b35e-a5cef4923a00	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-19 09:00:00+00	2026-06-19 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cf9675b0-7f4e-4d4a-ada0-c3a461e27b3a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-19 12:00:00+00	2026-06-19 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8ef49235-2775-46de-b967-e017f7daeeae	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-19 14:00:00+00	2026-06-19 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7e71fddf-642f-4740-9b22-17fe0d354b9d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-19 08:00:00+00	2026-06-19 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2f98c59a-013e-4389-b08c-ded2131d0a52	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-19 10:00:00+00	2026-06-19 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5f3bc47e-fbbe-4302-9875-f3bf3d7c5d45	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-19 13:00:00+00	2026-06-19 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
feabf1ab-2734-4c99-9b5d-7fc570b52b7e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-19 15:00:00+00	2026-06-19 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1bcb747e-4f86-49a3-be7f-c0fa7c7d01c4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-19 07:00:00+00	2026-06-19 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
93891627-5606-479a-a826-d07dd589df60	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-19 09:00:00+00	2026-06-19 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5740e36a-7347-4492-8caa-8da7405acb5f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-19 12:00:00+00	2026-06-19 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8a559113-4ee9-4416-99d5-2482bfd212e2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-19 14:00:00+00	2026-06-19 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e259ba14-cfdb-49e1-9f65-301c2a555b00	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-22 07:00:00+00	2026-06-22 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e6bc43db-a510-4c46-a3c0-c9965ef07565	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-22 09:00:00+00	2026-06-22 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c8be887e-b0be-47d5-a500-bd515fd7514e	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-22 12:00:00+00	2026-06-22 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
76f81ea4-e6d5-4ae6-907d-cb8a304b8b6b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-22 14:00:00+00	2026-06-22 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
eb3dce2b-c27f-4c21-90ce-a09f1dc1d4e5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-22 08:00:00+00	2026-06-22 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fcea5a35-e74d-4c15-bc98-f668d0867c64	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-22 10:00:00+00	2026-06-22 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cde52d7d-61ef-47ad-a86a-a203c52b7d90	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-22 13:00:00+00	2026-06-22 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0c59ff73-a98f-416c-84a0-809260742780	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-22 15:00:00+00	2026-06-22 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1d9bcbb1-d13d-4182-accc-e95b3f97a0ed	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-18 10:00:00+00	2026-06-18 10:30:00+00	confirmed	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:06:02.854601+00
d0dbc0d4-1d80-424b-9563-0b8f1eb356d6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-18 07:00:00+00	2026-06-18 08:00:00+00	confirmed	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-09 16:53:42.781858+00
05de0af0-4b7b-4b1a-b533-36e9962e6b2e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-22 07:00:00+00	2026-06-22 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1c14f8de-de2a-4799-a97a-26b2bfce7bae	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-22 09:00:00+00	2026-06-22 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
396d52a9-8427-4c97-958f-2063e9577ae1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-22 12:00:00+00	2026-06-22 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c7bf63d2-aad7-4fdb-936e-f2263122073b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-22 14:00:00+00	2026-06-22 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2a89bdf1-141e-4d86-9cff-483bb00c031d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-22 08:00:00+00	2026-06-22 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2a8374a2-01e4-43b4-8fd3-099524816a08	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-22 10:00:00+00	2026-06-22 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
73695f1b-0a91-403a-b433-f75ed30bb807	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-22 13:00:00+00	2026-06-22 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
dc4ee51a-f6d4-4ffd-8fdf-6491bb14f9bb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-22 15:00:00+00	2026-06-22 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1f44dc09-dc0c-4179-acf2-870e2ee3d8b4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-23 08:00:00+00	2026-06-23 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
43a829c1-d76a-46ec-8441-97a117e61250	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-23 10:00:00+00	2026-06-23 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c2a44d08-bb5d-4a1a-82c4-f6c6520a8dea	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-23 13:00:00+00	2026-06-23 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3118a512-96c4-4899-9870-3c77f4b68931	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-23 15:00:00+00	2026-06-23 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
53836952-f925-46ff-8178-e5b2adecb9a5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-23 07:00:00+00	2026-06-23 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5547a449-ab92-4db3-a795-773d6ada765e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-23 09:00:00+00	2026-06-23 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
beb6604b-e907-44ba-b2e5-3ea544cc88b1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-23 12:00:00+00	2026-06-23 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
857d656b-1153-4b6e-a357-efcb84c0eeae	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-23 14:00:00+00	2026-06-23 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
424715c6-d685-4fb4-b9cc-2255b72122cb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-23 08:00:00+00	2026-06-23 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
eb00e79e-6c7b-4b74-aa68-7d40f697a31d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-23 10:00:00+00	2026-06-23 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e07cfbd3-5808-449c-80b5-7d543e13cf29	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-23 13:00:00+00	2026-06-23 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2a5dc9a2-596d-4a4d-b1f7-fea62b8aad91	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-23 15:00:00+00	2026-06-23 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0f58cadd-af86-44ab-85b3-6cf3e21cf663	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-23 07:00:00+00	2026-06-23 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9d55dfc1-7aee-4ec1-a78b-a751cdd67df9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-23 09:00:00+00	2026-06-23 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c1d0cdfc-c9f3-4ffd-9843-ad0fc203dad1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-23 12:00:00+00	2026-06-23 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3f90c084-cc60-4ef4-9f45-05437c030cca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-23 14:00:00+00	2026-06-23 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2b419913-00e1-415f-8115-87272cefb656	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-24 07:00:00+00	2026-06-24 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
450672ba-a7aa-45d0-988b-d49120e84da7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-24 09:00:00+00	2026-06-24 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bf01db68-7166-4f7a-92b7-a8691cec98cd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-24 12:00:00+00	2026-06-24 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1f69b71c-6f89-442d-b7b5-1f458d247a56	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-24 14:00:00+00	2026-06-24 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1157d305-7054-4c93-99ff-8f2b0d1a65c3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-24 08:00:00+00	2026-06-24 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
621d674f-8048-4e3b-92fa-a7871ce4a383	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-24 10:00:00+00	2026-06-24 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fbcb0d9a-9abb-4717-bd72-9a627eec0e8c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-24 13:00:00+00	2026-06-24 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d014067b-e609-49ec-8d99-2d77587a8da8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-24 15:00:00+00	2026-06-24 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
93e203a2-4d6b-4e27-94e1-a04881112176	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-24 07:00:00+00	2026-06-24 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5c221005-6510-48c3-9c99-05e9aec4d416	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-24 09:00:00+00	2026-06-24 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
58e71e3a-ca33-4a99-a21b-2e6fa5439354	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-24 12:00:00+00	2026-06-24 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
338a7146-00a4-470c-a838-c0da60367647	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-24 14:00:00+00	2026-06-24 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ba2e7a54-5c7a-4ec4-b24e-cacd7398e1c3	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-24 08:00:00+00	2026-06-24 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
01645362-08fd-4364-8671-6ef8e3163f89	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-24 10:00:00+00	2026-06-24 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5fb39296-4669-4c78-90fc-cc6344fa11b5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-24 13:00:00+00	2026-06-24 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
277b1e3d-e2ed-4c69-9cda-696fb5ab8f32	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-24 15:00:00+00	2026-06-24 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
10878acc-503f-4260-b707-921ee4ed448b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-25 08:00:00+00	2026-06-25 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a09ef4c9-7767-434e-9caf-5ec673bc7ec3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-25 10:00:00+00	2026-06-25 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8e580019-addb-4473-94b0-828f9e38cf7e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-25 13:00:00+00	2026-06-25 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0464f3dd-f046-49b6-886e-f242b83ae419	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-25 15:00:00+00	2026-06-25 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cc200c78-5b64-479c-b63a-e8fbed9bc0ad	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-25 07:00:00+00	2026-06-25 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
110225c6-e733-4ea2-93cf-e175262b8b17	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-25 09:00:00+00	2026-06-25 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c52a262c-baab-4c58-a971-1168ac49e801	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-25 12:00:00+00	2026-06-25 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
55b7e644-bc21-4482-92cb-50cc8368dff6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-25 14:00:00+00	2026-06-25 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ac126f52-6b7a-4353-8b14-e63fd614fd64	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-25 08:00:00+00	2026-06-25 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a83dec4e-ce90-4fd8-988b-1c3d87600a6d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-25 10:00:00+00	2026-06-25 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6596037e-c314-4193-aebb-4ce9cb982656	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-25 13:00:00+00	2026-06-25 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
73ad2d78-dbfa-4408-a195-ce00fafd7d36	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-25 15:00:00+00	2026-06-25 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8261bd2f-85e4-4b68-8736-63a26907e048	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-25 07:00:00+00	2026-06-25 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c5767c7a-e155-4fba-affd-27a12ba2b13b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-25 09:00:00+00	2026-06-25 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9e83d432-a40d-41d4-a30b-7b051615846d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-25 12:00:00+00	2026-06-25 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
40ac4ea4-3f01-4605-853b-5a846ffe3266	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-25 14:00:00+00	2026-06-25 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7946d704-5de6-4142-9118-9beef66e093b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-26 07:00:00+00	2026-06-26 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
87be9909-ab2d-4cd9-88f9-eed692c0010c	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-26 09:00:00+00	2026-06-26 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
03cbe3d1-4e5a-439e-b65e-9324e3503bc2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-26 12:00:00+00	2026-06-26 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c5f8ed50-43bd-4a8a-9def-0924f602696b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-26 14:00:00+00	2026-06-26 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5d8c3464-a8de-41d4-a890-30007b84a1c6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-26 08:00:00+00	2026-06-26 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
33cbe01c-2509-49a9-b8ee-b41bcdce9443	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-26 10:00:00+00	2026-06-26 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
02fc19e4-2b9f-4a1a-b3b9-30a594b74458	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-26 13:00:00+00	2026-06-26 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2746683d-97f6-4d5b-a951-6e637dfb32d6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-26 15:00:00+00	2026-06-26 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e959e8b5-e45f-4736-9809-e31899417e6e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-26 07:00:00+00	2026-06-26 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0c0169eb-278f-43ec-bfed-5adcd288f9c2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-26 09:00:00+00	2026-06-26 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
29a628a6-a7bb-401f-9d41-d8de599b02a3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-26 12:00:00+00	2026-06-26 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ecbfc536-cec7-4d35-a0c4-52ae0629e1fc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-26 14:00:00+00	2026-06-26 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
feb1145b-6891-4398-afba-e5ed4abff59f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-26 08:00:00+00	2026-06-26 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
46fdc675-15d6-43a0-8e1c-41200cdace29	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-26 10:00:00+00	2026-06-26 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
085a2e7e-4a7d-454c-9ede-c5763d277ba2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-26 13:00:00+00	2026-06-26 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
02bb44d6-9cb5-4b8d-90a0-64906161a6dc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-26 15:00:00+00	2026-06-26 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e248f2cb-b7c0-40d8-b17e-7916d2158b08	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-29 08:00:00+00	2026-06-29 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7e6c0e81-d4e9-4343-a1a9-42b6d8ff52c8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-29 10:00:00+00	2026-06-29 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
18bf6235-e2d2-4a6c-a3f4-198e5d07cd65	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-29 13:00:00+00	2026-06-29 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c2d5ce0a-0016-4062-9c32-a73a9f6709ab	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-29 15:00:00+00	2026-06-29 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d42e9f0d-3fc9-4bd3-9094-ed3df4fefb9c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-29 07:00:00+00	2026-06-29 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
dafe2538-752f-490b-8d5e-f218e9acc485	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-29 09:00:00+00	2026-06-29 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c122d340-547a-4b75-b36a-0ec2127146b8	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-29 12:00:00+00	2026-06-29 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2e6f97fc-ec48-457b-a530-59c0f0b92b37	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-29 14:00:00+00	2026-06-29 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0addd747-2405-46ba-8a04-73d1daae0f90	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-29 08:00:00+00	2026-06-29 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
577ca888-9089-40b1-95eb-6fc8917aae90	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-29 10:00:00+00	2026-06-29 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
172dfa20-c002-4afd-8088-2b889683cd3a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-29 13:00:00+00	2026-06-29 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c07d5e5f-7f05-4e35-8852-0742fd0ba621	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-29 15:00:00+00	2026-06-29 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
361355a4-bf23-4adf-892d-cfdcaae2745d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-29 07:00:00+00	2026-06-29 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
43004367-473e-4c2b-aa7a-a5666b3b8a86	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-29 09:00:00+00	2026-06-29 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2c529bc8-7ccd-4674-8c04-b124996f80ca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-29 12:00:00+00	2026-06-29 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
847bd10e-116f-449f-9b85-22d3f0242bdd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-29 14:00:00+00	2026-06-29 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0b311c2f-29fb-443b-a16e-bfe713f3d69c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-30 07:00:00+00	2026-06-30 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b25b211c-abbc-49ff-a8c5-aade2aef15bb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-30 09:00:00+00	2026-06-30 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c8b21ec2-6f11-4405-9191-21abe1d213ad	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-30 12:00:00+00	2026-06-30 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ff1708d9-a06d-408b-8a24-d54ebf85538a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-30 14:00:00+00	2026-06-30 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cc3689d8-0196-4161-ad9c-964f9841a9cc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-30 08:00:00+00	2026-06-30 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ca0fdf76-e6b0-4b90-96e2-d6075db68baf	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-30 10:00:00+00	2026-06-30 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
efd509d0-5463-4896-b4ac-0ec8cf809345	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-30 13:00:00+00	2026-06-30 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e99e2362-570b-4b23-a7cc-f20806204a6a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-30 15:00:00+00	2026-06-30 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a8774ac1-4f4a-4b24-b530-d9292c8a9023	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-30 07:00:00+00	2026-06-30 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bc8ffccd-be9d-4939-8a2b-9f073c07e70c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-30 09:00:00+00	2026-06-30 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
15d19113-8283-457a-8c76-b47b726405d2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-30 12:00:00+00	2026-06-30 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fb5738ed-fecd-4eb2-b407-510bec81a63b	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-30 14:00:00+00	2026-06-30 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1cd6e63e-d5da-41e8-ba2d-6dd4ea531ec0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-30 08:00:00+00	2026-06-30 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a310c455-3151-4aa0-84d1-3123bdf71b3f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-30 10:00:00+00	2026-06-30 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
42638981-12bb-48ef-8b34-e671bf4e2b31	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-30 13:00:00+00	2026-06-30 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0219af51-576d-4eb4-9e44-334c1a8c5d5f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-30 15:00:00+00	2026-06-30 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
538aeb7f-3cfe-4ea0-a0ac-4fe8996ddbf8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-01 08:00:00+00	2026-07-01 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9fff1e48-ec14-4ad0-b8f1-68b8df9decb0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-01 10:00:00+00	2026-07-01 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1d61288b-4223-4b92-99b7-c4035eea2b81	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-01 13:00:00+00	2026-07-01 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2b724390-7bea-41b4-961e-7bd917ca9ff5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-01 15:00:00+00	2026-07-01 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
17ed7c4d-52ac-4a57-86e8-b0b6e3a3dba8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-01 07:00:00+00	2026-07-01 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
01c94c0d-c45e-4872-928a-4791a6e4f594	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-01 09:00:00+00	2026-07-01 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
75f508b4-5f94-43ac-a16d-f30bc22278fd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-01 12:00:00+00	2026-07-01 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fcc24126-c631-4fdc-819a-84b2c4ec110a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-01 14:00:00+00	2026-07-01 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a7bfda69-60f1-4969-979d-b0863cd88f20	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-01 08:00:00+00	2026-07-01 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3c73e36d-d814-4f2a-807b-52fa87d28a68	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-01 10:00:00+00	2026-07-01 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
575064e7-421a-4ece-8f00-8f52cad87ac1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-01 13:00:00+00	2026-07-01 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7d53d6d3-28af-4f2b-a7ac-a49b4a3b42b2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-01 15:00:00+00	2026-07-01 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b88b059e-80d4-4df3-84aa-ff4925c312a9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-01 07:00:00+00	2026-07-01 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
28e768c5-71f3-43a9-8d55-fd50469edcbf	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-01 09:00:00+00	2026-07-01 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bbb8ebf3-ad99-4e09-b7df-bfeeffa4e2da	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-01 12:00:00+00	2026-07-01 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e3376acc-04e6-4584-95aa-715b77cbc965	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-01 14:00:00+00	2026-07-01 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ba061bc4-b2a9-4ed4-9d4e-64c30d8e3323	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-02 07:00:00+00	2026-07-02 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
74fa0bba-d114-497a-a2af-d7731c3ee76e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-02 09:00:00+00	2026-07-02 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ea6aabaf-2213-4de4-8ace-6c5135a6506d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-02 12:00:00+00	2026-07-02 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f525c471-1d2e-481c-8a40-97f2afcb5db0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-02 14:00:00+00	2026-07-02 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a974fdc5-6f75-481c-8bd7-053a833f6db3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-02 08:00:00+00	2026-07-02 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
df37ad9d-7052-4ef9-a5a3-0093a890c241	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-02 10:00:00+00	2026-07-02 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
64dc40ad-56b3-4607-92d9-e72e65b75b22	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-02 13:00:00+00	2026-07-02 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
516f6bad-0cf4-4344-82d2-1278f2f6f1a7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-02 15:00:00+00	2026-07-02 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
504fb243-e2f5-4a42-bea2-f04ac635b5ca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-02 07:00:00+00	2026-07-02 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
197f13a5-907a-4c0f-9011-9713562802be	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-02 09:00:00+00	2026-07-02 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5ddcdc19-1711-449c-a00a-7147f3e4df83	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-02 12:00:00+00	2026-07-02 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1caa7aa9-3e08-4c42-8dee-9532f7bb553b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-02 14:00:00+00	2026-07-02 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
52051f31-73e8-40d8-841d-11c2a617e4c5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-02 08:00:00+00	2026-07-02 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ff5662b7-c2af-4b8f-963e-ae020bb744a9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-02 10:00:00+00	2026-07-02 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
62213885-049a-4e64-aa4b-80c98afe4b00	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-02 13:00:00+00	2026-07-02 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d569c9ce-b1e9-4107-8fb5-7e5c81416098	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-02 15:00:00+00	2026-07-02 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9d0fb56b-b6a9-47e9-8630-fc40c4f66080	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-03 08:00:00+00	2026-07-03 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5f9a317b-92d1-4d0a-8ff8-799ec070c73c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-03 10:00:00+00	2026-07-03 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bb6f10b3-464a-495c-b8f1-171a1945c164	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-03 13:00:00+00	2026-07-03 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1cd6e9c9-8e14-42ea-b8ef-b798d5e1d8bb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-03 15:00:00+00	2026-07-03 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1b3c4a84-d731-4b3c-b068-4f17e53a9393	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-03 07:00:00+00	2026-07-03 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cf2e3381-5fe4-4175-9196-24797b797b1f	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-03 09:00:00+00	2026-07-03 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d6d0e258-cb67-4147-ac4c-156c69cb667b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-03 12:00:00+00	2026-07-03 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c6bda3e7-8f1f-44b0-b791-25ea4de93cba	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-03 14:00:00+00	2026-07-03 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fdfc2aec-b08c-4ced-a0ce-184a45d0fa27	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-03 08:00:00+00	2026-07-03 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a331d1e1-90fa-43b8-9c9e-39cdfcc546c7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-03 10:00:00+00	2026-07-03 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9bb501fa-e43e-4332-9be1-f27217fc5267	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-03 13:00:00+00	2026-07-03 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
46d3837a-22be-4b88-8b7b-18b8d0a0fe77	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-03 15:00:00+00	2026-07-03 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6a22c588-0824-4d0d-8e3a-5b3fe2f31af7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-03 07:00:00+00	2026-07-03 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d4bd7e95-a866-4d17-bcf6-92dc159f5150	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-03 09:00:00+00	2026-07-03 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c291d98f-0076-4954-8d97-7d7a819f3f7c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-03 12:00:00+00	2026-07-03 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8f9edce5-704b-45af-b63b-e96cc00d883c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-03 14:00:00+00	2026-07-03 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
db0a43d6-355e-41f8-bd83-4b8555a60b05	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-06 07:00:00+00	2026-07-06 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
25222e27-b2a3-45a1-971d-b929fdae435f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-06 09:00:00+00	2026-07-06 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8f39cc8b-3b70-407b-ae67-168be8008ffc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-06 12:00:00+00	2026-07-06 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
66a56a55-de1f-41c3-9480-ff8ce5e3a55a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-06 14:00:00+00	2026-07-06 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
57c01e05-4947-4457-97b5-c0df05a87cb4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-06 08:00:00+00	2026-07-06 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
33226248-b117-419a-b8de-3139e0a7a7a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-06 10:00:00+00	2026-07-06 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
50b5fd8d-1c8d-4775-aa1e-86306b0c12e9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-06 13:00:00+00	2026-07-06 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c3d2cf8d-cd17-4dab-9ffe-ebeb03dd25a9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-06 15:00:00+00	2026-07-06 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8faf73c3-6eb5-4a68-adcb-f70682447900	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-06 07:00:00+00	2026-07-06 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a6fec2b1-3605-41d2-8995-cf8541c433f5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-06 09:00:00+00	2026-07-06 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
88d38df3-1d4c-4c92-860b-b4344040b67c	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-06 12:00:00+00	2026-07-06 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9ae8e116-d8a0-49d0-b0f1-1b6c059c9283	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-06 14:00:00+00	2026-07-06 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4e9101e2-91af-41f7-a298-e47644c11f0d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-06 08:00:00+00	2026-07-06 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f90c1a60-2225-4349-af63-0ce8db73f6ef	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-06 10:00:00+00	2026-07-06 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d7d94fbb-0432-41a9-a5f8-a6ff53688643	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-06 13:00:00+00	2026-07-06 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1e07262f-b042-4eec-bf69-ff68f7bab9db	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-06 15:00:00+00	2026-07-06 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
371e3ad3-eff3-402f-8787-03d4d8ba8d4e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-07 08:00:00+00	2026-07-07 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a8dd7251-4a81-45e2-ab9a-f96976741202	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-07 10:00:00+00	2026-07-07 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a27c0db5-6e7b-4a07-be1b-0b3c62e1b461	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-07 13:00:00+00	2026-07-07 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0eb5b737-0a4e-40bd-953f-b0179970ffb2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-07 15:00:00+00	2026-07-07 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ead33905-93c5-4f96-8986-be837f27b9fd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-07 07:00:00+00	2026-07-07 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
beaa35ef-577f-40f6-b9fb-b8ee2df479bd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-07 09:00:00+00	2026-07-07 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8d344420-c6e3-44be-954a-d3145dd101b2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-07 12:00:00+00	2026-07-07 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e2dbd11c-1312-4389-9f38-b0c5250f464b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-07 14:00:00+00	2026-07-07 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bf7d7692-a52c-486f-8297-6457ba6c2bf8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-07 08:00:00+00	2026-07-07 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5161a2cc-fb83-42e7-9301-9ac8dfd10f54	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-07 10:00:00+00	2026-07-07 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1b61fff5-81c9-41fc-a3a9-c6ad978d5a1e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-07 13:00:00+00	2026-07-07 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
734b64d6-2f23-439a-8513-eca2ecd0a3b2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-07 15:00:00+00	2026-07-07 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
26199b4f-eba9-4caf-a1e7-789ab74d6c6f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-07 07:00:00+00	2026-07-07 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
602c65c4-908d-417f-a38e-dc6122595a23	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-07 09:00:00+00	2026-07-07 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cfdd6240-a1f9-44b5-aeb7-e1479b13d7c4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-07 12:00:00+00	2026-07-07 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7399f8a7-8763-4679-9c77-cda07489dae1	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-07 14:00:00+00	2026-07-07 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
999363e7-3f87-4c8f-ab37-23e56c2111be	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-08 07:00:00+00	2026-07-08 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a8147057-3a9d-40a0-9883-4afa354e741d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-08 09:00:00+00	2026-07-08 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ef012715-b3a2-4582-88c7-d7dfc1ddbd77	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-08 12:00:00+00	2026-07-08 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
60df9a2e-8e0f-44fc-9e1c-d60db227f40c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-08 14:00:00+00	2026-07-08 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9a21ce95-88c4-483c-bbf5-80bd15575472	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-08 08:00:00+00	2026-07-08 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0fa62bc2-cae5-4cc5-9cf5-f1c72735f226	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-08 10:00:00+00	2026-07-08 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e5a36ce5-cedf-4835-9c28-e4c33fc5bfde	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-08 13:00:00+00	2026-07-08 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
415da51a-52e9-41b5-89e5-99cbeefb4c45	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-08 15:00:00+00	2026-07-08 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0b580a37-2412-447f-a584-99f0ec3c6ba6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-08 07:00:00+00	2026-07-08 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fc2c8e72-5eb5-4eb4-a641-3539beaedf60	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-08 09:00:00+00	2026-07-08 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5d600db8-07b9-4af4-ac3f-30f9b68a482c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-08 12:00:00+00	2026-07-08 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ff690901-dea8-449b-aa1e-35f865116e57	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-08 14:00:00+00	2026-07-08 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8ef3a3b1-6d85-4f1e-aa6c-b2e0975427f7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-08 08:00:00+00	2026-07-08 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
38f9e9ea-37f4-47a6-af93-4b12905a8f37	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-08 10:00:00+00	2026-07-08 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
969dd6b4-17c4-452a-a8b2-9d641d286601	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-08 13:00:00+00	2026-07-08 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fcde924f-0e43-4f55-ba40-f420ca07cfbb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-08 15:00:00+00	2026-07-08 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2870d83d-02b0-487a-93cd-f9b98f5362d2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-09 08:00:00+00	2026-07-09 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1561a3e1-d6c4-410c-b1cb-8f12d3d0d93d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-09 10:00:00+00	2026-07-09 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
38c7a021-21e6-44f7-9090-2d5615ab95b0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-09 13:00:00+00	2026-07-09 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e3f1f6d5-8405-4180-8fc6-b62d5fac615d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-09 15:00:00+00	2026-07-09 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2a5087b8-34c7-47ca-b64f-00062f9d1216	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-09 07:00:00+00	2026-07-09 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
113eed5f-1449-493c-8c83-1efbe220cdc7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-09 09:00:00+00	2026-07-09 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b657e208-5427-4b07-b490-6afc13ab57c1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-09 12:00:00+00	2026-07-09 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
af8e0fa3-90ba-45c9-af11-25ad57847dec	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-09 14:00:00+00	2026-07-09 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
440bfc2c-f003-42f3-8b44-653892766d76	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-09 08:00:00+00	2026-07-09 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b17fc89e-7499-4685-b668-6d4bf4444225	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-09 10:00:00+00	2026-07-09 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fd1699de-6023-4f44-ac5b-0eda8cf5598e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-09 13:00:00+00	2026-07-09 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5a93fa74-e144-4268-aaa3-5c5c4fb75a7f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-09 15:00:00+00	2026-07-09 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f5c682af-b795-40cf-9878-7365cba09d5a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-09 07:00:00+00	2026-07-09 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3301ae53-b409-487f-8c3c-c16acecce0dd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-09 09:00:00+00	2026-07-09 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c87a248c-ea3a-4337-886d-8fc11ea1f4d1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-09 12:00:00+00	2026-07-09 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b9bd243e-2374-439c-84e3-e3cd43982493	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-09 14:00:00+00	2026-07-09 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6ad9e3b4-8fd6-43ae-b2f9-38ffe0d920ed	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-10 07:00:00+00	2026-07-10 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7d912ef0-8b4d-4a68-b4e3-e124e7f56d7c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-10 09:00:00+00	2026-07-10 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cf25e2fc-9a8e-4f38-ab06-a26117ebbf26	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-10 12:00:00+00	2026-07-10 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fff0cbac-c8d4-4a09-878f-9d8a583e1b73	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-10 14:00:00+00	2026-07-10 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3dddd762-2fd0-4fbb-bda4-762c4e52bc3f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-10 08:00:00+00	2026-07-10 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0c41097b-4fba-47de-a29f-123201f73449	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-10 10:00:00+00	2026-07-10 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
69d9f794-1d81-4a5a-bb05-ccbad35df6bc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-10 13:00:00+00	2026-07-10 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bfed7e17-b306-48fb-b1eb-1f33095c2c4d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-10 15:00:00+00	2026-07-10 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
53ee1e22-5cff-49a1-8a27-0e6fad7b9567	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-10 07:00:00+00	2026-07-10 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bd5eb3cd-2fe1-446b-9574-b9c94db82d02	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-10 09:00:00+00	2026-07-10 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fd8c2509-10f4-42d2-9f5c-ff87fce75f61	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-10 12:00:00+00	2026-07-10 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
40000525-f227-4faa-9a5c-ba9f1ada496c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-10 14:00:00+00	2026-07-10 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
058fc30c-2597-4b0b-b781-8fe0f63a1519	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-10 08:00:00+00	2026-07-10 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
67731d2b-a1e0-4ef7-bd43-f159541ae226	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-10 10:00:00+00	2026-07-10 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
07ce631b-da3d-42e5-b1e6-39060af2b946	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-10 13:00:00+00	2026-07-10 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
37485d68-c71f-4168-b2c6-3725b8a4f48c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-10 15:00:00+00	2026-07-10 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9520044a-7d38-49e8-8d34-aa798c3d970e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-13 08:00:00+00	2026-07-13 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
27059aeb-1c17-416e-bb89-b9b95b6796ce	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-13 10:00:00+00	2026-07-13 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f1b39d2e-af19-4290-8d31-4220a5c844ba	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-13 13:00:00+00	2026-07-13 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7cdc4eb6-7ea1-4537-8899-ed572647ed39	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-13 15:00:00+00	2026-07-13 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d42da455-36d7-42dc-89a5-2ab8698296f9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-13 07:00:00+00	2026-07-13 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
14565afc-3df9-4876-b661-1a66eaa4f0ef	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-13 09:00:00+00	2026-07-13 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
abed23bf-761e-42f7-a0c5-15749f025958	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-13 12:00:00+00	2026-07-13 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c3345b1c-3339-480a-af55-3db87259d14e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-13 14:00:00+00	2026-07-13 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
84421302-8527-42a9-9c9f-a3e255cb4fe7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-13 08:00:00+00	2026-07-13 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
17ace76c-80c4-4539-bf26-1adc1a5f4667	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-13 10:00:00+00	2026-07-13 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
164a7115-fc20-43cd-a0f2-7b3996dc4797	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-13 13:00:00+00	2026-07-13 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4936e4a2-e476-455f-bd1b-269f80cb450a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-13 15:00:00+00	2026-07-13 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ada85d57-472e-4081-aa38-de306a89b800	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-13 07:00:00+00	2026-07-13 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e09ec84e-64ce-4bc7-88ed-7fa1bb98959e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-13 09:00:00+00	2026-07-13 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a29eacdc-0de8-4b03-a04a-3c85026f1782	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-13 12:00:00+00	2026-07-13 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b95ac049-c2f9-496a-a900-ff7eab5f72af	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-13 14:00:00+00	2026-07-13 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ef18834e-d3b3-46b3-b99a-61295395f122	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-14 07:00:00+00	2026-07-14 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f223c048-ddfe-46ea-8c0d-c69435492f7b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-14 09:00:00+00	2026-07-14 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
90b39153-9281-4ee5-9f25-b2e43d3c3349	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-14 12:00:00+00	2026-07-14 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a15778ef-0066-47c3-9d9b-c40f72603cc1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-14 14:00:00+00	2026-07-14 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
39650b8f-0432-4357-b08a-64282bba877c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-14 08:00:00+00	2026-07-14 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b61966a9-32c6-4b68-afad-5e8f6024e2dc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-14 10:00:00+00	2026-07-14 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
debe13dc-53d0-4cc8-9b8f-f5b27b77c0c4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-14 13:00:00+00	2026-07-14 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bdb7ab7a-8ec9-41ad-a810-47462fdca8dd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-14 15:00:00+00	2026-07-14 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e9154332-c207-409e-9fd2-449efc2df94f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-14 07:00:00+00	2026-07-14 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0e4abd80-3f89-4e04-8cfc-92e6ffaac1f9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-14 09:00:00+00	2026-07-14 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
24563cbe-c034-4b25-b373-264d0ee3935e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-14 12:00:00+00	2026-07-14 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d6c950fd-f373-4f21-ae13-10c4b87563ca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-14 14:00:00+00	2026-07-14 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0688901b-3858-4bf6-911f-358438d30b5c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-14 08:00:00+00	2026-07-14 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3ee96b85-d590-4def-bff3-d32497b931ab	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-14 10:00:00+00	2026-07-14 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bd86cf8c-1197-4dad-a819-f337572218a1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-14 13:00:00+00	2026-07-14 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4a48daca-083d-498e-8aaf-c802e8552579	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-14 15:00:00+00	2026-07-14 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
050f1d96-68c3-41f5-88e0-3c43d1c61dde	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-15 08:00:00+00	2026-07-15 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9f18e69e-8c2e-4183-a736-04dc6dc7f9dd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-15 10:00:00+00	2026-07-15 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ae4a7204-0998-4982-abd5-445b564b563a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-15 13:00:00+00	2026-07-15 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
63ffc9cc-0008-4f6f-a402-4adb6e1166c3	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-15 15:00:00+00	2026-07-15 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ad840d20-3341-43f3-9332-b9beaeb8d0b6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-15 07:00:00+00	2026-07-15 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a2f50798-a4a2-4a57-b249-8bffb38db887	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-15 09:00:00+00	2026-07-15 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
10689486-5708-4e15-a06e-c5aa11b73321	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-15 12:00:00+00	2026-07-15 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ebf1b981-75dc-423e-bade-395e877c89b3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-15 14:00:00+00	2026-07-15 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
336e8ce4-0cd7-4592-a8f3-d06391f3bd8c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-15 08:00:00+00	2026-07-15 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bfe6f2ac-d357-4b55-8ab8-53a595ccaedc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-15 10:00:00+00	2026-07-15 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
892c3b27-397f-487e-8ac1-2f44f7bd7545	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-15 13:00:00+00	2026-07-15 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a973c2f1-8f1e-40a6-9140-52a187285f8e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-15 15:00:00+00	2026-07-15 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
216dce78-55af-4aba-b6b9-1cc27a302b6f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-15 07:00:00+00	2026-07-15 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d02cbe90-a24c-4b93-8075-2662484f5c41	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-15 09:00:00+00	2026-07-15 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0acef2a7-5145-44a3-9eb0-99316f6f37fd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-15 12:00:00+00	2026-07-15 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7c355b17-d088-4511-adc9-6963cf1e1e0b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-15 14:00:00+00	2026-07-15 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9fbf2f0a-d5ec-4a9f-94c7-692f2b43d8db	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-16 07:00:00+00	2026-07-16 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
aa9bf4aa-982f-4c35-b324-ab4e24272158	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-16 09:00:00+00	2026-07-16 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
51b3f79a-f12b-47fa-9385-64d08c99929e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-16 12:00:00+00	2026-07-16 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
20101cc4-81a2-493c-879c-04b1dc357247	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-16 14:00:00+00	2026-07-16 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d3099568-4328-4d74-a873-17680bec7d82	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-16 08:00:00+00	2026-07-16 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
93000a20-a1e6-49c7-9997-bdf44ff0caa8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-16 10:00:00+00	2026-07-16 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ecaefe31-db6f-4fee-8ecb-8303df458ec5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-16 13:00:00+00	2026-07-16 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
86238fab-c4b7-4842-84f9-ce91e67fab0a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-16 15:00:00+00	2026-07-16 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
14ae3bdd-2daf-4cab-8435-f3a6657a033f	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-16 07:00:00+00	2026-07-16 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0eb3e94e-3137-4c78-90fd-c0bc561f1e3b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-16 09:00:00+00	2026-07-16 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f0dddf4b-23df-46b9-b468-2688261a781f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-16 12:00:00+00	2026-07-16 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
85683f11-7fc5-482a-97a9-7cd607f19d1a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-16 14:00:00+00	2026-07-16 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
61c3cf5f-3a35-4a41-9129-1f44098f7918	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-16 08:00:00+00	2026-07-16 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
05c866cd-b26d-474a-9ba1-2ff39e78eb38	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-16 10:00:00+00	2026-07-16 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8a4e32af-5835-4fd5-a47d-3deb9d1b2f24	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-16 13:00:00+00	2026-07-16 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4620ac50-f102-4688-adc6-a2cb0f442b52	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-16 15:00:00+00	2026-07-16 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8a13f611-8ec8-4234-9afa-3180691f0b5e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-17 08:00:00+00	2026-07-17 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
636ce13d-7be4-4e4a-b20c-3427ae8c957f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-17 10:00:00+00	2026-07-17 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
83867260-39b6-43a1-92e1-553624539b0e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-17 13:00:00+00	2026-07-17 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
106e5849-20b4-4064-85e8-2c0e85e70c05	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-17 15:00:00+00	2026-07-17 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a7926f38-0d19-41c4-a44b-5b49da42f94e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-17 07:00:00+00	2026-07-17 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6f01c405-d706-4b24-8239-61c1348d583f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-17 09:00:00+00	2026-07-17 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4a0dc773-1ed1-49aa-bdf8-28c4c8a1dd26	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-17 12:00:00+00	2026-07-17 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
34e39174-4fd6-47dd-ae52-b38da89007e1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-17 14:00:00+00	2026-07-17 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
454c04b4-df67-4c77-b660-25ddd40555cc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-17 08:00:00+00	2026-07-17 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9fef8a77-7cfc-42c2-a46c-a72863dbc087	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-17 10:00:00+00	2026-07-17 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
99896826-c954-499a-8de3-9ea3bcf5882c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-17 13:00:00+00	2026-07-17 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ff1cec18-d7cc-4466-9803-2862d213c825	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-17 15:00:00+00	2026-07-17 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0669db16-8bff-49cb-b2c0-a8baf79ea875	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-17 07:00:00+00	2026-07-17 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9ff65e8a-e64d-4a90-8569-6341d0f9c7c4	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-17 09:00:00+00	2026-07-17 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1682990e-993d-4a5a-8719-c18b482968aa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-17 12:00:00+00	2026-07-17 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9fb21dc0-f4db-40e9-a8e6-918711d46e33	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-17 14:00:00+00	2026-07-17 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1a14f191-a012-4c98-9df7-3478716b8d70	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-20 07:00:00+00	2026-07-20 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ee5c0865-4230-4d20-b41b-8e7b200f6b7e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-20 09:00:00+00	2026-07-20 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
87067cc7-049a-4fe1-a5b7-5f47063b11a5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-20 12:00:00+00	2026-07-20 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
76edc9e4-cc51-4084-a299-4752ce69e21f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-20 14:00:00+00	2026-07-20 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fce7b5e2-10c4-417c-b24a-20754a43233a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-20 08:00:00+00	2026-07-20 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
36ba348f-903b-4ec3-9a2d-711df5ef318e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-20 10:00:00+00	2026-07-20 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0824034b-9170-429d-be1f-858aed3bd4e5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-20 13:00:00+00	2026-07-20 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3d7fa4dd-66b8-4edf-923e-7121c7da8ab8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-20 15:00:00+00	2026-07-20 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
574b32a5-cc7a-4709-95ea-7d866d385c6f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-20 07:00:00+00	2026-07-20 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f9cce6cb-6932-48d4-9707-ff0cc1c3998e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-20 09:00:00+00	2026-07-20 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c68b3355-a7aa-46df-962b-da79af717e2b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-20 12:00:00+00	2026-07-20 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5d7dddde-c0e9-47eb-a9b3-6d53664dd23c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-20 14:00:00+00	2026-07-20 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
56cc63f6-5533-471a-a1a9-41bc1cb413db	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-20 08:00:00+00	2026-07-20 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1df11c95-16ef-450b-84f7-ea88696e6a2f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-20 10:00:00+00	2026-07-20 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0fbb174b-c6cd-4e17-a62e-d02c3ac04e79	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-20 13:00:00+00	2026-07-20 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d351d5ee-9dda-42be-8739-f8d3afa9e152	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-20 15:00:00+00	2026-07-20 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c0d7ad79-55db-4f8b-beb0-a79e6f08626c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-21 08:00:00+00	2026-07-21 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b0d137c9-a9cc-4f0c-944a-cc3d76edea6f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-21 10:00:00+00	2026-07-21 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bc39a07b-887a-4d18-9ef1-15a9eb55b974	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-21 13:00:00+00	2026-07-21 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4b5db2c5-964b-4e25-9387-c3c7d3af9fd5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-21 15:00:00+00	2026-07-21 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
290fc437-c995-4823-ad92-dbecbb90f948	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-21 07:00:00+00	2026-07-21 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e84cc9f1-fe11-4fc5-a569-825bb3f5d138	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-21 09:00:00+00	2026-07-21 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cf5c68ee-bc24-4c45-8fe7-1fa291c8c39e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-21 12:00:00+00	2026-07-21 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
56214f4f-b09a-46c3-921f-0aa8ed349973	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-21 14:00:00+00	2026-07-21 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
385f49a1-075c-4541-a5d5-765ab82dd748	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-21 08:00:00+00	2026-07-21 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fbd6ccb8-dc6b-4d87-b6ff-0ea4bc5dbacc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-21 10:00:00+00	2026-07-21 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c5f4fa65-8077-4ee1-a28f-7cbe5f2890eb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-21 13:00:00+00	2026-07-21 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
63cd81e8-1801-418b-bc2d-93c8284d6ccc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-21 15:00:00+00	2026-07-21 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
66f6cd18-f0d2-4724-837e-9402a86bebfa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-21 07:00:00+00	2026-07-21 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ee7ad808-9813-49e7-af71-f3e55ef07161	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-21 09:00:00+00	2026-07-21 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1b8a42b7-1a1f-4bfe-9ee9-2244ad2dccc5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-21 12:00:00+00	2026-07-21 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ab45344c-af85-49b6-9a74-9040fb3c4ba5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-21 14:00:00+00	2026-07-21 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5562fef3-a32a-4bd7-811c-9539b9d9df9e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-22 07:00:00+00	2026-07-22 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f88406ee-ba26-4621-a44a-9fcd5ca54293	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-22 09:00:00+00	2026-07-22 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
41e3f320-0276-4baf-a943-528d46a2e427	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-22 12:00:00+00	2026-07-22 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
76eb1e5e-d805-4815-bb57-535e0e2be4c1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-22 14:00:00+00	2026-07-22 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
04b5ccc7-c756-421c-98de-b7a270a2370d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-22 08:00:00+00	2026-07-22 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
26f6011c-09ec-4e00-bbea-c8f7ab18958a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-22 10:00:00+00	2026-07-22 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
72e028df-4b05-4ef0-8bd5-1ac00d64ecb2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-22 13:00:00+00	2026-07-22 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e5b1d903-ae74-45f1-92d1-ca12a2216fa4	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-22 15:00:00+00	2026-07-22 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ee80fa3f-8b62-4b50-8c9c-69d3f3be8810	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-22 07:00:00+00	2026-07-22 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d0dbb9d1-700b-4c2d-a16b-1adfdd6f2745	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-22 09:00:00+00	2026-07-22 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
189c464d-b925-4919-83a6-5ed473a5ddc8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-22 12:00:00+00	2026-07-22 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bf2407c1-1a4a-4c48-bb16-0ce72bbc3173	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-22 14:00:00+00	2026-07-22 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
cd0fae11-2fac-47ed-ac76-20fd456c1fad	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-22 08:00:00+00	2026-07-22 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f3988438-f32e-46aa-88ec-bed601339fdc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-22 10:00:00+00	2026-07-22 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7d9e693b-6538-48dc-9082-090d451503b9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-22 13:00:00+00	2026-07-22 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
72980501-2e04-4bd8-9630-f739580b2831	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-22 15:00:00+00	2026-07-22 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3129718b-d312-4ca8-a4fa-9fbce8c13d59	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-23 08:00:00+00	2026-07-23 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
96e5701a-504a-47d3-b244-2470342f4183	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-23 10:00:00+00	2026-07-23 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bb5a1d2c-fe9b-4356-8c8e-e1c165aac0cb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-23 13:00:00+00	2026-07-23 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a321cb03-4767-4bc6-af83-35b989ad467f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-23 15:00:00+00	2026-07-23 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1d8e0201-cfb8-46fb-8094-d62451ebf0f6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-23 07:00:00+00	2026-07-23 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a980f0b0-bde1-4655-9dd8-e10544e35e00	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-23 09:00:00+00	2026-07-23 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a3f7592a-0b74-49cc-86dd-3da2faffeec0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-23 12:00:00+00	2026-07-23 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
853bb230-5282-41fb-8f5f-2dcdceb1f733	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-23 14:00:00+00	2026-07-23 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6857198c-c3f1-4617-87f3-08cc0340df84	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-23 08:00:00+00	2026-07-23 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7b1d19e2-6e95-49a9-bb68-87a51d8f8ae0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-23 10:00:00+00	2026-07-23 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
70d82006-93a1-4a32-83b5-e87c47bbbc04	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-23 13:00:00+00	2026-07-23 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
648250bc-ed4b-46d0-871a-c137e92c4fe3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-23 15:00:00+00	2026-07-23 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3597e7af-1105-4b72-a73b-4e3f839e0f1a	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-23 07:00:00+00	2026-07-23 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5e2129b8-67db-4cb5-aa58-d7f90411e437	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-23 09:00:00+00	2026-07-23 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
79b0153d-ac83-45d7-b23f-cfa87b3fec86	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-23 12:00:00+00	2026-07-23 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
841b0460-23a3-4bfc-8687-d99fe3fe0003	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-23 14:00:00+00	2026-07-23 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0c736a79-b094-406e-ae63-c248bdff5825	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-24 07:00:00+00	2026-07-24 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c4a7fda0-3171-4d5e-a62e-5cfc6ec5e2c9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-24 09:00:00+00	2026-07-24 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b3999ee3-8c47-47c6-9182-92cdc56a542c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-24 12:00:00+00	2026-07-24 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
32b24ac0-5898-4da7-93bb-63049d278568	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-24 14:00:00+00	2026-07-24 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
24bcd012-c7e0-48bc-b628-5c65557ab6a1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-24 08:00:00+00	2026-07-24 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5cedc99b-75e8-4114-b880-72278fa3e21d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-24 10:00:00+00	2026-07-24 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f4f0a1a2-e9c5-42e3-9b4f-ad0c5bc6c479	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-24 13:00:00+00	2026-07-24 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1848e9da-400d-435c-bac4-a0991fafa6af	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-24 15:00:00+00	2026-07-24 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4a087b24-d2d0-4341-806a-68f486bc2319	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-24 07:00:00+00	2026-07-24 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
e7d53118-6cee-4fd2-a8e8-1a662e5efb6e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-24 09:00:00+00	2026-07-24 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f3b2cde5-c54b-4f27-8d26-48fb57415513	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-24 12:00:00+00	2026-07-24 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b34fe594-f3b0-41ec-b598-3a1b620eaeb7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-24 14:00:00+00	2026-07-24 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
48a79c80-0ba0-4657-975e-79a5d86036d2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-24 08:00:00+00	2026-07-24 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
292f01a9-cc52-45b0-bc2a-6e3ae476f771	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-24 10:00:00+00	2026-07-24 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
eec85d34-d773-4129-8666-1472b7aee662	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-24 13:00:00+00	2026-07-24 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bf149c95-694b-4d32-8a74-b2ec82650a74	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-24 15:00:00+00	2026-07-24 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ce1cd3b3-e244-4312-910e-ce053b217874	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-27 08:00:00+00	2026-07-27 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2665ff5b-f7fe-4436-967a-ced134ed3ecc	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-27 10:00:00+00	2026-07-27 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3a1d4966-7ef5-400e-9ee2-86fbd2a8bf9f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-27 13:00:00+00	2026-07-27 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
92df177b-244f-428f-ab60-5945edb18dbc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-27 15:00:00+00	2026-07-27 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
46d31572-b9f1-4632-bf16-9cd1ff634f04	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-27 07:00:00+00	2026-07-27 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
44329e1a-ccc1-410b-a6c1-e492986ee445	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-27 09:00:00+00	2026-07-27 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
95cc5272-2e42-4dad-98d7-f11d9a022abb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-27 12:00:00+00	2026-07-27 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4c82e07d-1462-468f-b8fc-d58a0b5b9f81	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-27 14:00:00+00	2026-07-27 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9787f4af-8278-4cd4-a99e-87c6009584d3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-27 08:00:00+00	2026-07-27 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2ac0421c-3fc6-472b-9845-9c8f0e916e13	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-27 10:00:00+00	2026-07-27 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2d0fc1aa-6e1d-479b-bd63-eb7ead430b24	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-27 13:00:00+00	2026-07-27 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
bd9d0136-a35c-4f3a-b00d-a54531166295	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-27 15:00:00+00	2026-07-27 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
06e71dac-d160-43f5-964f-0189f1012a3c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-27 07:00:00+00	2026-07-27 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
25194916-836c-4c16-93a4-b99e868fb296	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-27 09:00:00+00	2026-07-27 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1ec454d3-5154-4746-9d8d-d9001927d2c1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-27 12:00:00+00	2026-07-27 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
2e74c282-2a20-489d-a3c0-0d61df178faf	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-27 14:00:00+00	2026-07-27 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
03a8dd3f-100b-4b18-a6d4-2f25ee602aef	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-28 07:00:00+00	2026-07-28 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
78e614dd-936f-4886-9e10-189d34bf00d8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-28 09:00:00+00	2026-07-28 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a960da81-52be-4c31-abc7-ff05aecec300	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-28 12:00:00+00	2026-07-28 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9409fc30-713b-42ec-8827-7c1bd04ce1c5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-28 14:00:00+00	2026-07-28 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4360b749-b08c-4ad2-9795-0acafe0704d4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-28 08:00:00+00	2026-07-28 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
51632703-65da-4b26-9773-3a22c4fa705c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-28 10:00:00+00	2026-07-28 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ef525fc5-5c46-4283-b91c-8bee2439c37a	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-28 13:00:00+00	2026-07-28 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c002e19f-3ce2-44f1-99b6-bfebb8018afc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-28 15:00:00+00	2026-07-28 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
00c3d8cd-bbd1-4438-855c-f7c1bbb27ad3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-28 07:00:00+00	2026-07-28 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c9e5633c-df53-42cd-9ecb-f123066be680	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-28 09:00:00+00	2026-07-28 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
573e0ffc-be37-4a9d-af6d-0b8898724de0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-28 12:00:00+00	2026-07-28 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
51868f88-c1a9-4234-a707-1325a42c7ffb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-28 14:00:00+00	2026-07-28 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c62de689-5778-4904-ae41-b9856127ec18	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-28 08:00:00+00	2026-07-28 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5d1a6d8a-ec8e-4715-8208-47ac2a1ac9f1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-28 10:00:00+00	2026-07-28 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6ad4830f-cf5e-4881-9601-b9ed9f24b16b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-28 13:00:00+00	2026-07-28 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3b97ef02-3413-416b-a62a-1d37da7239f9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-28 15:00:00+00	2026-07-28 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b0bf4a7e-6ab3-453b-bd38-b1a909a8845a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-29 08:00:00+00	2026-07-29 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
37d7ca7e-2ca3-403c-bfed-621eb464f674	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-29 10:00:00+00	2026-07-29 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4ad7477f-3969-4c7f-863f-ac7ce789a0e5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-29 13:00:00+00	2026-07-29 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d1c0b183-a49c-4925-8858-56e8cafb4897	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-29 15:00:00+00	2026-07-29 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9e381186-e7c3-4af8-9729-91a67b625b47	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-29 07:00:00+00	2026-07-29 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
47470052-3289-4f3f-80f5-cb8f02ce1c0a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-29 09:00:00+00	2026-07-29 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
72c912b3-50f7-4f94-ba3b-4a277d743819	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-29 12:00:00+00	2026-07-29 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a4c4a738-8c41-4f27-84bc-a966a4aeb12a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-29 14:00:00+00	2026-07-29 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
da70eb31-56b3-4cee-bcef-8dceeadcf9aa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-29 08:00:00+00	2026-07-29 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4df08864-c9db-4990-9876-ae7231939c57	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-29 10:00:00+00	2026-07-29 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7158d897-e28c-4bec-b445-a301b2c2dc34	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-29 13:00:00+00	2026-07-29 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
06fb9e82-e34f-4252-8224-0b1c969e5065	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-29 15:00:00+00	2026-07-29 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
186527a4-0973-4dff-b2a9-14572707274e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-29 07:00:00+00	2026-07-29 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
54bfcccb-3829-4302-9e32-0828257dd6d4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-29 09:00:00+00	2026-07-29 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0acfff23-7d37-48d4-8e21-a1094b1d84bd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-29 12:00:00+00	2026-07-29 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
53ffb81d-a620-47b8-88aa-bcecbf337b7f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-29 14:00:00+00	2026-07-29 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
ffb47546-7a5e-431c-99d8-d63845c1dc9d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-30 07:00:00+00	2026-07-30 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8e35ca3b-9896-49ea-bd77-6475a9d3cafa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-30 09:00:00+00	2026-07-30 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5c9d0db3-878a-40c2-a227-72587396038c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-30 12:00:00+00	2026-07-30 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3e20950d-3466-423e-bc2d-1ab4b0938577	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-30 14:00:00+00	2026-07-30 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
c656f881-7ae6-459d-b4bb-51c9e76003e4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-30 08:00:00+00	2026-07-30 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6d167600-1660-4f49-89e5-c3e26eed453f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-30 10:00:00+00	2026-07-30 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9e3d5349-a992-4396-90ac-40db143e7289	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-30 13:00:00+00	2026-07-30 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6a79bb9d-bb4f-4080-ab0c-5e470f7e31d9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-30 15:00:00+00	2026-07-30 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1a37c7e4-7bb9-4d5d-b17a-bda5041a9562	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-30 07:00:00+00	2026-07-30 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1f1529f3-fed4-4b21-8e66-589aa8c40ce4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-30 09:00:00+00	2026-07-30 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8661b00a-14e4-4a47-bfe2-944e0600f2f2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-30 12:00:00+00	2026-07-30 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
3f8ec6cc-b894-4e66-aa35-e41d3c17a227	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-30 14:00:00+00	2026-07-30 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
6a6d2f82-2b91-42b6-bb65-06ecaee3b24c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-30 08:00:00+00	2026-07-30 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
640f9b55-9042-4185-9b7d-7d91ead08b4e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-30 10:00:00+00	2026-07-30 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
236ba295-53fb-495a-8584-bfb51fb9cdba	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-30 13:00:00+00	2026-07-30 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7cb69496-13fb-4da7-b978-668513643035	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-30 15:00:00+00	2026-07-30 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a4b50417-b7c5-4713-a61b-e1accea2bd98	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-31 08:00:00+00	2026-07-31 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
a07690be-3182-4825-9452-720d35d22803	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-31 10:00:00+00	2026-07-31 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
5198e7b0-725f-416a-b3bc-54a0b0bb4063	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-31 13:00:00+00	2026-07-31 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
4b34e656-a057-49a1-836e-5b23453ac3da	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-07-31 15:00:00+00	2026-07-31 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
d0ef21d5-313a-4781-a90e-bf9abaa68f16	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-31 07:00:00+00	2026-07-31 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
f0db8872-d7c7-4e42-becc-77fc08d106c7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-31 09:00:00+00	2026-07-31 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
eea61ace-7128-4846-8363-b28e6e12c19f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-31 12:00:00+00	2026-07-31 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
7488487c-7fdb-4ddc-bb9a-54b0294e24cb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-07-31 14:00:00+00	2026-07-31 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
944551bb-466f-4b2b-850a-5ed750eeb7ae	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-31 08:00:00+00	2026-07-31 09:00:00+00	scheduled	Igiene e pulizia	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
9cbbb4e2-8bf2-41d9-b269-7f3fc1bac50b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-31 10:00:00+00	2026-07-31 10:30:00+00	scheduled	Consulto	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
8b8eeb45-1590-41c0-8801-7e1d3ad18972	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-31 13:00:00+00	2026-07-31 14:00:00+00	scheduled	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
54994996-fabe-4fb4-ace3-83feabfb9139	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-07-31 15:00:00+00	2026-07-31 15:30:00+00	scheduled	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
fce62acb-a293-450a-a7f0-c5808d53d34d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-31 07:00:00+00	2026-07-31 08:00:00+00	scheduled	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
251de345-6055-46f9-94ff-78ca0b9b1ae8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-31 09:00:00+00	2026-07-31 10:00:00+00	scheduled	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
b2f83df3-1b60-4855-9a54-249567166b19	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-31 12:00:00+00	2026-07-31 13:00:00+00	scheduled	Trattamento	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
1478b554-df0b-4fa7-b88f-55d85fe77e2b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-07-31 14:00:00+00	2026-07-31 15:00:00+00	scheduled	Visita	\N	2026-06-01 19:19:30.690777+00	2026-06-01 19:19:30.690777+00
0837493f-8ef4-4943-b5d2-9bf95986382a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-09 13:00:00+00	2026-06-09 14:00:00+00	confirmed	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:03:07.47837+00
677b63a0-1091-4db7-96d8-d55090a09378	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-05 09:00:00+00	2026-06-05 10:00:00+00	confirmed	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:03:08.885362+00
a5ba629d-d19f-419f-93ad-acda0983728e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000003	\N	Studio 3	2026-06-04 07:00:00+00	2026-06-04 08:00:00+00	confirmed	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:03:10.559845+00
a83635e7-2783-43d9-adbf-0fea7732bc67	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-17 07:00:00+00	2026-06-17 08:00:00+00	confirmed	Visita di controllo	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:05:34.226978+00
7749d7b0-5106-4827-a621-1a67a6e59338	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	\N	Studio 2	2026-06-16 15:00:00+00	2026-06-16 15:30:00+00	confirmed	Consulto rapido	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:05:36.667547+00
a464cd0c-5280-4c92-a98f-d11c345dd475	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000001	\N	Studio 1	2026-06-15 13:00:00+00	2026-06-15 14:00:00+00	confirmed	Controllo periodico	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:05:38.465049+00
71ec3326-def5-4ec8-9586-12372d46ef64	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000004	\N	Studio 4	2026-06-11 09:00:00+00	2026-06-11 10:00:00+00	confirmed	Trattamento conservativo	\N	2026-06-01 19:19:30.690777+00	2026-06-09 11:05:40.370415+00
\.


--
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.chat_messages (id, session_id, role, content, created_at) FROM stdin;
06256ab9-78ff-40d5-a587-1e7221b1536f	0e311fd2-12f9-40ef-b2cb-e6e751e59926	user	Stato preventivo Sig. Rossi	2026-06-17 09:32:40.485472+00
5bb1034a-fd22-4d00-9a0d-d596109ef7c2	0e311fd2-12f9-40ef-b2cb-e6e751e59926	assistant	Il Sig. Rossi Marco ha il seguente preventivo:\n\n- **Numero Preventivo:** PRE-2024-0001\n- **Titolo:** Preventivo piano carie - Rossi Marco\n- **Stato:** Accettato\n- **Importo Totale:** 292,50 EUR (dopo uno sconto di 32,50 EUR)\n- **Valido Fino al:** 28 Giugno 2026\n\nSe hai bisogno di ulteriori dettagli, fammi sapere!	2026-06-17 09:32:47.508826+00
\.


--
-- Data for Name: chat_sessions; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.chat_sessions (id, provider_id, title, message_count, created_at, updated_at) FROM stdin;
0e311fd2-12f9-40ef-b2cb-e6e751e59926	5cac268e-1fdd-4d13-966c-65e367dca1c8	Stato preventivo Sig. Rossi	2	2026-06-17 09:32:40.471516+00	2026-06-17 09:32:47.508826+00
\.


--
-- Data for Name: clinical_history_entries; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.clinical_history_entries (id, clinic_id, patient_id, appointment_id, provider_id, entry_date, tooth_number, service_code, service_name, clinical_notes, materials_used, next_visit_notes, created_at, updated_at) FROM stdin;
8e39ba01-5c74-4b0f-8d07-56bd88636b69	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	\N	b1000001-0000-0000-0000-000000000001	2026-05-19	16	\N	Radiografia endorale	RX 16: carie distale profonda coinvolgente la dentina. Pianificata otturazione bifacciale.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0257769e-5e57-4d2b-b756-ffe64fa13a31	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	\N	b1000001-0000-0000-0000-000000000001	2026-05-26	16	\N	Otturazione composito bifacciale	Otturazione composito bifacciale completata su 16. Paziente ha tollerato bene la seduta. Nessuna complicazione.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f56df65a-5b17-40f7-a5dd-8049cdc028f3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	\N	b1000001-0000-0000-0000-000000000001	2026-05-26	\N	\N	\N	Piano di cura in corso. Ancora da trattare: 14 monofacciale. Programmata igiene di mantenimento tra 2 settimane.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f359330e-bb5d-44cb-8bcb-90daebdba731	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	\N	b1000001-0000-0000-0000-000000000001	2025-11-30	\N	\N	Prima visita	Prima visita paziente. Interesse per trattamenti estetici. Presentate opzioni sbiancamento e faccette 11-21.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6f66ef05-1a3f-4441-bbe9-1ee6185eb5d9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	\N	b1000001-0000-0000-0000-000000000002	2026-05-09	36	\N	CBCT pre-implantare	CBCT eseguita. Osso disponibile: altezza 12mm, larghezza 7mm. Pianificata inserzione impianto 3.8x11mm.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1ce5abad-fd35-4423-93ab-1520a64bb5d1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	\N	b1000001-0000-0000-0000-000000000002	2026-05-26	36	\N	Programmazione impianto	Discusso piano implantare con paziente. Accettato preventivo. Fissata data intervento per oggi.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d2d6a292-a535-4397-904a-1eb531f9bf51	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	\N	b1000001-0000-0000-0000-000000000001	2025-11-10	\N	\N	Prima visita	Prima visita. Allergia anestetici locali di tipo amidico: verificare uso anestetici esteri. Annotata in anamnesi.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
918d2f93-7946-4579-8772-505a2db11998	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	\N	b1000001-0000-0000-0000-000000000004	2025-12-30	\N	\N	Visita parodontale	Paziente fumatore. Gengivite generalizzata da placca. Istruzione igiene orale. Programmata igiene profonda.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c5f5b9a5-079d-447d-88e5-591176bcab82	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	\N	b1000001-0000-0000-0000-000000000001	2026-05-15	26	\N	Visita urgente	Paziente con dolore acuto 26 da 5 gg. RX: carie profonda con probabile interessamento pulpare. Indicata devitalizzazione.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b8734dc9-994b-4a85-bed5-d668e2ae29ff	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	\N	b1000001-0000-0000-0000-000000000004	2026-05-26	\N	\N	Igiene orale	Prima igiene professionale. Abbondante tartaro sopragengivale. Istruita sulla tecnica di spazzolamento.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3ffa7160-3b61-4af1-880b-796c174f699e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	\N	b1000001-0000-0000-0000-000000000003	2025-08-02	\N	\N	Visita ortodontica	Prima valutazione ortodontica. Malocclusione classe I con affollamento moderato. Proposto trattamento con apparecchio fisso.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1f8ce63d-732b-44fe-84e7-7472722f9f15	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	\N	b1000001-0000-0000-0000-000000000003	2026-05-28	\N	\N	Controllo ortodonzia mensile	Allineamento progredisce regolarmente. Sostituito archwire 0.16 NiTi. Lieve dolore previsto per 48h. Prossimo controllo tra 4 settimane.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
035008a7-faf0-4cc9-9fcc-ed9315eb3634	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	\N	b1000001-0000-0000-0000-000000000002	2026-04-14	18	\N	Estrazione complessa 18	Estrazione dente 18 incluso mesioangolato. Osteotomia + odontotomia. Sutura 3/0 Vicryl x3. Istruzioni post-op fornite.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4e4f7ddd-613b-44ca-8eb1-0198c0a42218	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	\N	b1000001-0000-0000-0000-000000000002	2026-04-21	18	\N	Rimozione punti 18	Guarigione regolare. Rimossi 3 punti Vicryl. Mucosa integra. Nessuna complicazione.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8e9a13d8-f75c-4c79-a077-0cd615003b6f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	\N	b1000001-0000-0000-0000-000000000001	2026-04-29	\N	\N	Annotazione	ATTENZIONE: paziente in terapia con bifosfonati e patologia cardiaca. Consultare cardiologo prima di qualsiasi chirurgia futura.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
85da85a0-74a2-437c-9759-0dd06257e0c1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	\N	b1000001-0000-0000-0000-000000000004	2026-05-22	\N	\N	Igiene professionale	Igiene semestrale. Buona compliance igienica domiciliare. Lieve tartaro interdentale sup. Nessuna carie rilevata.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
31096e4e-6c88-479f-bb7e-71c495cde3c3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	\N	b1000001-0000-0000-0000-000000000001	2026-03-30	\N	\N	Visita diagnosi carie	RX evidenzia carie 35 bifacciale e 45 occlusale. Pianificato programma restaurativo in 2 sedute.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
46ea0f88-e612-47a3-8f51-e42217123c44	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	\N	b1000001-0000-0000-0000-000000000001	2026-05-29	25	\N	Otturazione composito bifacciale	Otturazione composito A2 su 25 bifacciale. Isolamento con diga. Buon risultato estetico e occlusale.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
57e779c5-c8eb-4670-b751-4a4ac6d168b0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	\N	b1000001-0000-0000-0000-000000000004	2026-01-29	\N	\N	Visita parodontale	Parodontite cronica generalizzata moderata. BOP 60%. Tasche 4-6mm in zona 31-41. Pianificato SRP 4 quadranti.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
54a233b3-cae0-41f4-b8c8-d1e8fb1311d3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	\N	b1000001-0000-0000-0000-000000000004	2026-05-28	\N	\N	Igiene profonda	SRP quadrante superiore sinistro completato. Buona risposta dei tessuti. Seconda seduta pianificata per completare arcata.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d8e6e805-9057-4a7e-a409-5a323628fd4c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	\N	b1000001-0000-0000-0000-000000000002	2025-09-21	\N	\N	Prima visita	Prima visita. Paziente in buona salute generale. Nessuna patologia significativa. Igiene orale migliorabile.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ebdf97b7-6dd3-4d32-a696-c2d2b01dc6ad	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	\N	b1000001-0000-0000-0000-000000000001	2026-05-28	\N	\N	Radiografia controllo	RX controllo post-otturazione: contatti prossimali corretti, margini ben sigillati. Tutto nella norma.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
261c3a71-ad45-40c2-b39a-6d0b782ec666	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	\N	b1000001-0000-0000-0000-000000000001	2026-05-26	37	\N	Visita pre-restauro	Esaminato 37: carie trifacciale estesa. Pianificata otturazione composito in prossima seduta.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b1e726c7-f232-464a-975f-a55d0e04708f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	\N	b1000001-0000-0000-0000-000000000002	2026-05-28	46	\N	CBCT pre-impianto	CBCT 46: osso disponibile 13mm altezza, 8mm larghezza. Ottimo sito implantare. Programmato intervento tra 5 gg.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ffcfe644-243e-4e72-9bb3-0c73c3eab9c8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	\N	b1000001-0000-0000-0000-000000000002	2024-10-06	\N	\N	Annotazione importante	Paziente anziano (61aa). Ipertensione in terapia, cardiopatico, anticoagulante. Allergia penicillina. MAX ATTENZIONE in chirurgia.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b48223df-b27e-410b-be19-271e20275fe1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	\N	b1000001-0000-0000-0000-000000000001	2026-05-29	26	\N	Visita urgente	Dolore acuto 26 da 3 gg. RX: carie profonda prossima alla polpa. Probabile devitalizzazione necessaria. Programmata per oggi pomeriggio.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5dd04ade-aedc-4c4a-9d7d-a178a338a80c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	\N	b1000001-0000-0000-0000-000000000001	2026-03-20	\N	\N	Prima visita	Prima visita. Paziente in buona salute. Ultima visita odontoiatrica 3 anni fa. Controllo completo effettuato.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
87a43681-3094-4eab-b1c4-431b73d670cb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	\N	b1000001-0000-0000-0000-000000000003	2026-05-19	\N	\N	Prima visita ortodontica	Prima valutazione. Malocclusione classe II div. 1. Affollamento severo arcata superiore. Programmato approfondimento con radiografie.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
916b4293-1b5d-4c58-b3ac-89259165e91a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	\N	b1000001-0000-0000-0000-000000000001	2025-01-14	\N	\N	Annotazione cronologia	Paziente con diabete tipo 2 e ipertensione in compenso. Monitorare guarigione in seguito a trattamenti chirurgici.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
21b4cd0e-92e8-4f4c-a5f5-5cb7a9759cf7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	\N	b1000001-0000-0000-0000-000000000003	2026-05-22	\N	\N	Controllo ortodonzia adulti	Paziente non in trattamento ortodontico attivo. Valutazione crowding anteriore inferiore. Escluso trattamento per età e compliance prevista.	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: clinics; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.clinics (id, name, legal_name, vat_number, fiscal_code, phone, address_line1, address_line2, city, province, postal_code, country, created_at, updated_at, city_id, email) FROM stdin;
9d754153-6579-4b7e-a56b-025f00299cd9	Clinica Demo DentalCare Roma	DentalCare Roma S.r.l.	DEMO-ROMA-001	DEMOROMA001	+39 06 5550101	Via Nomentana 123	\N	Roma	RM	00162	IT	2026-05-29 13:52:49.31794+00	2026-06-01 19:29:36.01755+00	00000003-0000-0000-0000-000000000001	\N
\.


--
-- Data for Name: condition_service_defaults; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.condition_service_defaults (id, clinic_id, condition_name, service_id, sort_order) FROM stdin;
4bb7ab86-3b78-414c-a291-5a4d430b6c94	9d754153-6579-4b7e-a56b-025f00299cd9	cavity	d1000001-0000-0000-0000-000000000007	10
dd4d95af-be8e-4c16-9c1a-011abc1691ec	9d754153-6579-4b7e-a56b-025f00299cd9	cavity	d1000001-0000-0000-0000-000000000004	20
adb2fc16-4b56-4a75-940e-749fa9e0bb88	9d754153-6579-4b7e-a56b-025f00299cd9	to_extract	d1000001-0000-0000-0000-000000000018	10
93039afa-7461-4c5a-9b5e-b177a2a3989b	9d754153-6579-4b7e-a56b-025f00299cd9	to_extract	d1000001-0000-0000-0000-000000000025	20
8cedb4e7-5a6b-4ea7-8559-85fff52ad81a	9d754153-6579-4b7e-a56b-025f00299cd9	root_canal	d1000001-0000-0000-0000-000000000013	10
03fd81e7-39fb-41e8-ac10-ba7d9d52970e	9d754153-6579-4b7e-a56b-025f00299cd9	root_canal	d1000001-0000-0000-0000-000000000004	20
9797601f-7965-4961-8e36-3ba702a66765	9d754153-6579-4b7e-a56b-025f00299cd9	missing	d1000001-0000-0000-0000-000000000006	10
53cae957-53f7-4fc2-907c-b7f69c26d446	9d754153-6579-4b7e-a56b-025f00299cd9	missing	d1000001-0000-0000-0000-000000000016	20
e36aa3a8-9b30-439e-9ad4-848e811de3b9	9d754153-6579-4b7e-a56b-025f00299cd9	missing	d1000001-0000-0000-0000-000000000017	30
77b1bd7b-d492-44e9-b492-bb8a9766ce80	9d754153-6579-4b7e-a56b-025f00299cd9	missing	d1000001-0000-0000-0000-000000000014	40
58c333c3-e021-48c2-aac1-293e4df6d27c	9d754153-6579-4b7e-a56b-025f00299cd9	crown	d1000001-0000-0000-0000-000000000014	10
9f003ba0-761c-4a56-91f7-03d040863fc8	9d754153-6579-4b7e-a56b-025f00299cd9	bridge_pillar	d1000001-0000-0000-0000-000000000014	10
87034618-da75-4201-980f-e982d90b978d	9d754153-6579-4b7e-a56b-025f00299cd9	bridge_pontic	d1000001-0000-0000-0000-000000000014	10
5749f9c0-d1c2-4464-b608-a91ff4fcffb3	9d754153-6579-4b7e-a56b-025f00299cd9	implant	d1000001-0000-0000-0000-000000000006	10
97524fbb-3c98-4004-a5a8-244722afa163	9d754153-6579-4b7e-a56b-025f00299cd9	implant	d1000001-0000-0000-0000-000000000016	20
\.


--
-- Data for Name: estimate_lines; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.estimate_lines (id, clinic_id, estimate_id, treatment_plan_item_id, service_id, line_position, description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, created_at, updated_at) FROM stdin;
89c87af4-690f-468c-a493-2acb9ef190cb	9d754153-6579-4b7e-a56b-025f00299cd9	d47f0351-ca37-4ed0-b754-5db16d66eba3	04ac7394-58ed-4b1d-9fc7-1a6399e65d8a	d1000001-0000-0000-0000-000000000014	10	Corona in zirconia	44	1.00	650.00	0.00	0.00	2026-05-29 17:34:22.697661+00	2026-05-29 17:34:22.697661+00
34996610-4711-4ab1-b8c7-5a3df784550e	9d754153-6579-4b7e-a56b-025f00299cd9	d47f0351-ca37-4ed0-b754-5db16d66eba3	0611f2a4-57b0-4c14-894a-a1e973445192	d1000001-0000-0000-0000-000000000014	30	Corona in zirconia	45	1.00	650.00	0.00	0.00	2026-05-29 17:34:23.111313+00	2026-05-29 17:34:23.111313+00
345ca4c1-7a9e-490f-817c-45e0fb857e7a	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000001	d1000001-0000-0000-0000-000000000004	1	Radiografia endorale 16	16	1.00	25.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2b3abb7c-561a-4c21-9afc-6eb74309e3c9	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000002	d1000001-0000-0000-0000-000000000008	2	Otturazione composito bifacciale 16	16	1.00	130.00	13.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f2225b5d-f2d4-4243-915b-6a6b87dd29c4	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000003	d1000001-0000-0000-0000-000000000007	3	Otturazione composito monofacciale 14	14	1.00	90.00	9.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
05fc15b7-bfb6-4720-9b32-f2d0aaa3614d	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000001	f1000001-0000-0000-0000-000000000004	d1000001-0000-0000-0000-000000000001	4	Igiene orale professionale	\N	1.00	80.00	8.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
269f693f-8bd1-4226-a25f-c78db34e64a4	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000005	d1000001-0000-0000-0000-000000000006	1	CBCT arcata inferiore	36	1.00	180.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
97f727be-3608-4216-9778-8054cb0d555a	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000006	d1000001-0000-0000-0000-000000000016	2	Impianto osteointegrato 36	36	1.00	1200.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4140e7b7-7717-457a-b8d2-0aa4eb792ea2	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000007	d1000001-0000-0000-0000-000000000017	3	Moncone implantare 36	36	1.00	350.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fa0dd2e2-a6fc-4834-bc26-e90cc843f2ce	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000002	f1000001-0000-0000-0000-000000000008	d1000001-0000-0000-0000-000000000014	4	Corona in zirconia 36	36	1.00	650.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f02d2393-23cb-4862-83dc-10fcfc4c0b0c	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000003	f1000001-0000-0000-0000-000000000009	d1000001-0000-0000-0000-000000000001	1	Igiene orale professionale	\N	1.00	80.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
692a3155-8e45-419e-b2eb-6b6a06b1264b	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000003	f1000001-0000-0000-0000-000000000010	d1000001-0000-0000-0000-000000000007	2	Otturazione composito monofacciale 24	\N	1.00	90.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0089eb92-6b31-4bc5-99ce-3bf9bfaf16c8	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000004	f1000001-0000-0000-0000-000000000012	d1000001-0000-0000-0000-000000000024	1	Sbiancamento professionale	\N	1.00	250.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d6b7f273-7ad0-4cc1-a34b-335b9960de9a	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000004	f1000001-0000-0000-0000-000000000013	d1000001-0000-0000-0000-000000000015	2	Faccetta in ceramica 11	\N	1.00	550.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2aba2758-19e7-4ff3-850e-c404dbf9de13	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000004	f1000001-0000-0000-0000-000000000014	d1000001-0000-0000-0000-000000000015	3	Faccetta in ceramica 21	\N	1.00	550.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2071a5d2-f045-468b-98e5-32ae8bef9e6e	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000005	f1000001-0000-0000-0000-000000000015	d1000001-0000-0000-0000-000000000004	1	Radiografia endorale 26	26	1.00	25.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6650c7c6-6c22-4527-af4e-959d9c00cf8b	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000005	f1000001-0000-0000-0000-000000000016	d1000001-0000-0000-0000-000000000012	2	Devitalizzazione pluriradicolare 26	26	1.00	480.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3ef9b21a-e5f3-46b4-8858-2f68ed9e5f30	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000005	f1000001-0000-0000-0000-000000000017	d1000001-0000-0000-0000-000000000014	3	Corona in zirconia 26	26	1.00	650.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6a0b8995-51cc-4c60-8fa7-2d80af03ab9a	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000006	f1000001-0000-0000-0000-000000000018	d1000001-0000-0000-0000-000000000019	1	Estrazione complessa 18	18	1.00	200.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
cfa44d4d-62c7-4fd9-bc64-e09be8588f61	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000006	f1000001-0000-0000-0000-000000000019	d1000001-0000-0000-0000-000000000025	2	Rimozione punti di sutura 18	18	1.00	30.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
646efc06-6d87-4d60-8a23-0530a4f2f0fa	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000007	f1000001-0000-0000-0000-000000000026	d1000001-0000-0000-0000-000000000006	1	CBCT arcata inferiore	46	1.00	180.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
aa1575f8-e7b9-49de-86e9-63092594a4ae	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000007	f1000001-0000-0000-0000-000000000027	d1000001-0000-0000-0000-000000000016	2	Impianto osteointegrato 46	46	1.00	1200.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
28f6cdc6-a784-41ed-9199-3d0d8203e842	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000007	\N	d1000001-0000-0000-0000-000000000017	3	Moncone implantare 46	46	1.00	350.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4e108ad0-599c-4edf-be05-7a722a5ded50	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000008	f1000001-0000-0000-0000-000000000023	d1000001-0000-0000-0000-000000000020	1	Levigatura radicolare 4 quadranti (4 sedute)	\N	4.00	180.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
47ea29bf-9976-4675-8396-02709a6affdc	9d754153-6579-4b7e-a56b-025f00299cd9	a2000001-0000-0000-0000-000000000008	f1000001-0000-0000-0000-000000000024	d1000001-0000-0000-0000-000000000002	2	Igiene orale profonda	\N	1.00	120.00	0.00	0.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
13f91d4e-af58-490f-9181-2e0f6fc58544	9d754153-6579-4b7e-a56b-025f00299cd9	d47f0351-ca37-4ed0-b754-5db16d66eba3	0d19ff8f-1c12-4f06-8f77-693e1d9835c3	d1000001-0000-0000-0000-000000000006	20	CBCT arcata singola	45	1.00	180.00	0.00	0.00	2026-05-29 17:34:22.916245+00	2026-05-29 17:34:22.916245+00
6ccd16ff-8ec0-4cd5-a561-be0324b1ed7f	9d754153-6579-4b7e-a56b-025f00299cd9	d47f0351-ca37-4ed0-b754-5db16d66eba3	67871adf-12be-4865-8b17-bed25a42ae61	d1000001-0000-0000-0000-000000000017	40	Moncone implantare	45	1.00	350.00	0.00	0.00	2026-05-29 17:34:23.300766+00	2026-05-29 17:34:23.300766+00
7528c694-b195-4d6a-8920-200bb05e301b	9d754153-6579-4b7e-a56b-025f00299cd9	d47f0351-ca37-4ed0-b754-5db16d66eba3	c6c32d63-b5d9-4414-82fb-6f3676305798	d1000001-0000-0000-0000-000000000016	50	Impianto osteointegrato	45	1.00	1200.00	0.00	0.00	2026-05-29 17:34:23.453786+00	2026-05-29 17:34:23.453786+00
\.


--
-- Data for Name: estimates; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.estimates (id, clinic_id, patient_id, treatment_plan_id, estimate_number, version, status, title, notes, currency, subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, issued_at, sent_at, valid_until, accepted_at, rejected_at, created_at, updated_at, created_by_provider_id) FROM stdin;
a2000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	e1000001-0000-0000-0000-000000000001	PRE-2024-0001	1	accepted	Preventivo piano carie - Rossi Marco	Sconto 10% sul totale	EUR	325.00	32.50	292.50	0.00	292.50	\N	\N	2026-06-28	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000001
a2000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	e1000001-0000-0000-0000-000000000002	PRE-2024-0002	1	sent	Preventivo implantologia - Romano Luca	Include CBCT, impianto, moncone, corona	EUR	2380.00	0.00	2380.00	0.00	2380.00	\N	\N	2026-07-13	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000002
a2000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	e1000001-0000-0000-0000-000000000003	PRE-2024-0003	1	draft	Bozza conservativa - Ricci Andrea	\N	EUR	170.00	0.00	170.00	0.00	170.00	\N	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000001
a2000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	e1000001-0000-0000-0000-000000000005	PRE-2024-0004	1	draft	Preventivo estetica - Bianchi Giulia	In valutazione	EUR	1350.00	0.00	1350.00	0.00	1350.00	\N	\N	2026-07-28	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000001
a2000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	e1000001-0000-0000-0000-000000000006	PRE-2024-0005	1	accepted	Preventivo devitalizzazione 26 - Marino Valentina	Urgenza - accettato immediatamente	EUR	1155.00	0.00	1155.00	0.00	1155.00	\N	\N	2026-06-18	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000001
a2000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	e1000001-0000-0000-0000-000000000007	PRE-2024-0006	1	accepted	Preventivo estrazione 18 - Bruno Francesca	Procedura eseguita e completata	EUR	230.00	0.00	230.00	0.00	230.00	\N	\N	2026-04-29	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000002
a2000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	e1000001-0000-0000-0000-000000000011	PRE-2024-0007	1	sent	Preventivo impianto 46 - Lombardi Alessia	Include CBCT e impianto	EUR	1580.00	0.00	1580.00	0.00	1580.00	\N	\N	2026-08-27	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000002
a2000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	e1000001-0000-0000-0000-000000000009	PRE-2024-0008	1	sent	Preventivo parodontologia - De Luca Roberto	Piano parodontale completo in 4 sedute	EUR	480.00	0.00	480.00	0.00	480.00	\N	\N	2026-06-28	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	b1000001-0000-0000-0000-000000000004
d47f0351-ca37-4ed0-b754-5db16d66eba3	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	ROMA-2026-00009	1	accepted	Preventivo Fabrizio	notenote	EUR	0.00	0.00	0.00	0.00	0.00	\N	\N	2026-07-31	2026-05-29 17:50:55.387136+00	\N	2026-05-29 17:33:49.45419+00	2026-05-29 17:50:55.387136+00	b1000001-0000-0000-0000-000000000003
d51f5755-116b-4a6e-abc7-9a19e7ff2fdd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	e1000001-0000-0000-0000-000000000012	ROMA-2026-00010	1	draft	Preventivo Carie	\N	EUR	0.00	0.00	0.00	0.00	0.00	\N	\N	2026-06-04	\N	\N	2026-06-01 11:47:48.934258+00	2026-06-01 11:47:48.934258+00	b1000001-0000-0000-0000-000000000001
\.


--
-- Data for Name: invoice_lines; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.invoice_lines (id, invoice_id, clinic_id, line_position, description, tooth_info, quantity, unit_price, discount_amount, vat_rate, line_subtotal, line_taxable, line_vat_amount, line_total, created_at, updated_at) FROM stdin;
5537b086-4f42-4348-a012-8147bbbdf117	b2000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	1	Radiografia endorale 16	16	1.0000	25.00	0.00	0.00	25.00	25.00	0.00	25.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
af02304a-8dd7-47d2-bfd5-57ff940078ef	b2000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	2	Otturazione composito bifacciale 16	16	1.0000	117.00	0.00	0.00	117.00	117.00	0.00	117.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d411b315-3e98-4bba-8095-d59e06a2be93	b2000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	3	Otturazione composito monofacciale 14	14	1.0000	81.00	0.00	0.00	81.00	81.00	0.00	81.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5f65e1fb-5e61-45f4-9f5c-3130ace4c428	b2000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	4	Igiene orale professionale	\N	1.0000	72.00	0.00	0.00	72.00	72.00	0.00	72.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1c577fff-fe29-4a5b-92f4-0da676b6ecda	b2000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	1	CBCT arcata inferiore pre-implantare	36	1.0000	180.00	0.00	0.00	180.00	180.00	0.00	180.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
14286b76-1b75-49c7-afad-f4edc83d8022	b2000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	1	Estrazione complessa dente del giudizio 18	18	1.0000	200.00	0.00	0.00	200.00	200.00	0.00	200.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bcaa3095-516e-4c4e-873e-89b02bf1f7b1	b2000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	2	Rimozione punti di sutura 18	18	1.0000	30.00	0.00	0.00	30.00	30.00	0.00	30.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d9e340b9-8115-49b0-a716-f9da6d1941d4	b2000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	1	Igiene orale professionale semestrale	\N	1.0000	80.00	0.00	0.00	80.00	80.00	0.00	80.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
732d2f0c-4e13-49ac-9ccf-ee3cc1d137d5	b2000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	1	Controllo mensile apparecchio fisso - archwire cambio	\N	1.0000	150.00	0.00	0.00	150.00	150.00	0.00	150.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
910ef199-3f94-4e4f-9e79-964b91eea450	b2000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	1	Igiene orale profonda quadrante superiore sinistro	\N	1.0000	120.00	0.00	0.00	120.00	120.00	0.00	120.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1c88e96f-c1b4-48d6-a123-5c0a1432a4d6	b2000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	1	Visita di controllo con compilazione piano di cura	\N	1.0000	80.00	0.00	0.00	80.00	80.00	0.00	80.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
19c385ed-6e88-423c-85aa-15251a9f3e30	b2000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	1	Otturazione composito bifacciale 25	25	1.0000	130.00	0.00	0.00	130.00	130.00	0.00	130.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fdaf96f9-163b-4e71-81f3-117eb2ede6bd	b2000001-0000-0000-0000-000000000009	9d754153-6579-4b7e-a56b-025f00299cd9	1	Igiene orale professionale	\N	1.0000	80.00	0.00	0.00	80.00	80.00	0.00	80.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f624528e-f9df-4d12-b26b-d99390f424a2	b2000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	1	Visita urgente dolore dente 26	26	1.0000	80.00	0.00	0.00	80.00	80.00	0.00	80.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7de4ad18-23e8-4d96-8f6f-a4c88b7bbb7c	b2000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	2	Radiografia endorale urgenza 26	26	1.0000	25.00	0.00	0.00	25.00	25.00	0.00	25.00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fbaebc6d-34d8-4af8-ac31-c6b1392a0d69	d95de0b3-27a6-433d-9bb7-f6e93646840b	9d754153-6579-4b7e-a56b-025f00299cd9	10	Corona in zirconia	44	1.0000	650.00	0.00	0.00	650.00	650.00	0.00	650.00	2026-05-29 18:07:20.32731+00	2026-05-29 18:07:20.32731+00
a48f05b2-2bfd-4a61-9410-a3e4b7f9df2e	d95de0b3-27a6-433d-9bb7-f6e93646840b	9d754153-6579-4b7e-a56b-025f00299cd9	20	CBCT arcata singola	45	1.0000	180.00	0.00	0.00	180.00	180.00	0.00	180.00	2026-05-29 18:07:20.32731+00	2026-05-29 18:07:20.32731+00
eb8c024f-ca2e-4eeb-89e5-f2ecbf601af4	d95de0b3-27a6-433d-9bb7-f6e93646840b	9d754153-6579-4b7e-a56b-025f00299cd9	30	Corona in zirconia	45	1.0000	650.00	0.00	0.00	650.00	650.00	0.00	650.00	2026-05-29 18:07:20.32731+00	2026-05-29 18:07:20.32731+00
723c432a-0a8d-41a9-903c-7e0c014427d6	d95de0b3-27a6-433d-9bb7-f6e93646840b	9d754153-6579-4b7e-a56b-025f00299cd9	40	Moncone implantare	45	1.0000	350.00	0.00	0.00	350.00	350.00	0.00	350.00	2026-05-29 18:07:20.32731+00	2026-05-29 18:07:20.32731+00
c3db8a6f-9f43-4437-9f31-03b1f8c66acd	d95de0b3-27a6-433d-9bb7-f6e93646840b	9d754153-6579-4b7e-a56b-025f00299cd9	50	Impianto osteointegrato	45	1.0000	1200.00	0.00	0.00	1200.00	1200.00	0.00	1200.00	2026-05-29 18:07:20.32731+00	2026-05-29 18:07:20.32731+00
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.invoices (id, clinic_id, invoice_number, document_type, invoice_date, due_date, status, issuer_type, provider_id, patient_id, estimate_id, issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address, issuer_email, issuer_pec, issuer_sdi_code, issuer_iban, patient_full_name, patient_fiscal_code, patient_address, patient_email, subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency, notes, payment_method, paid_at, issued_at, created_at, updated_at) FROM stdin;
b2000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0001	fattura	2026-05-21	2026-05-29	paid	clinic	\N	c1000001-0000-0000-0000-000000000001	a2000001-0000-0000-0000-000000000001	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Marco Rossi	RSSMRC85A01H501X	\N	\N	295.00	0.00	295.00	0.00	295.00	EUR	\N	carta	2026-05-21 11:00:00+00	2026-05-21 11:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0002	ricevuta	2026-05-09	2026-05-09	paid	clinic	\N	c1000001-0000-0000-0000-000000000003	a2000001-0000-0000-0000-000000000002	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Luca Romano	RMNLCU78C03H501Z	\N	\N	180.00	0.00	180.00	0.00	180.00	EUR	\N	bonifico	2026-05-09 10:30:00+00	2026-05-09 10:30:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0003	fattura	2026-04-14	2026-04-14	paid	clinic	\N	c1000001-0000-0000-0000-000000000008	a2000001-0000-0000-0000-000000000006	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Francesca Bruno	BRNFNC95H48H501S	\N	\N	230.00	0.00	230.00	0.00	230.00	EUR	\N	contanti	2026-04-14 11:30:00+00	2026-04-14 11:30:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0004	ricevuta	2026-05-22	2026-05-22	paid	clinic	\N	c1000001-0000-0000-0000-000000000009	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Matteo Gallo	GLLMTT82I09H501R	\N	\N	80.00	0.00	80.00	0.00	80.00	EUR	\N	contanti	2026-05-22 09:45:00+00	2026-05-22 09:45:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0005	ricevuta	2026-05-28	2026-05-28	paid	clinic	\N	c1000001-0000-0000-0000-000000000007	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Stefano Greco	GRCSFN75G07H501T	\N	\N	150.00	0.00	150.00	0.00	150.00	EUR	\N	carta	2026-05-28 10:30:00+00	2026-05-28 10:30:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0006	fattura	2026-05-28	2026-06-28	issued	clinic	\N	c1000001-0000-0000-0000-000000000012	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Elena Mancini	MNCLNE86B52H501N	\N	\N	120.00	0.00	120.00	0.00	120.00	EUR	\N	\N	\N	2026-05-28 12:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0007	ricevuta	2026-05-28	2026-06-13	draft	clinic	\N	c1000001-0000-0000-0000-000000000004	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Chiara Colombo	CLMCHR92D44H501W	\N	\N	80.00	0.00	80.00	0.00	80.00	EUR	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0008	ricevuta	2026-05-29	2026-05-29	paid	clinic	\N	c1000001-0000-0000-0000-000000000010	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Silvia Conti	CNTSLV91L50H501Q	\N	\N	130.00	0.00	130.00	0.00	130.00	EUR	\N	carta	2026-05-29 10:45:00+00	2026-05-29 10:45:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000009	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0009	ricevuta	2026-05-26	2026-05-26	paid	clinic	\N	c1000001-0000-0000-0000-000000000015	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Paolo Rizzo	RZZPLA70E15H501K	\N	\N	80.00	0.00	80.00	0.00	80.00	EUR	\N	contanti	2026-05-26 10:00:00+00	2026-05-26 10:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b2000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	FAT-2024-0010	parcella	2026-05-29	2026-06-13	issued	clinic	\N	c1000001-0000-0000-0000-000000000018	\N	Clinica Demo DentalCare Roma	DEMO-ROMA-001	DEMOROMA001	Via Nomentana 123, 00162 Roma	\N	\N	\N	\N	Sara Barbieri	BRBSRA89H58H501H	\N	\N	105.00	0.00	105.00	0.00	105.00	EUR	\N	\N	\N	2026-05-29 18:30:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d95de0b3-27a6-433d-9bb7-f6e93646840b	9d754153-6579-4b7e-a56b-025f00299cd9	PARC-2026-00011	fattura	2026-05-29	2026-07-31	issued	provider	b1000001-0000-0000-0000-000000000003	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	d47f0351-ca37-4ed0-b754-5db16d66eba3	Serena Amato	\N	\N		\N	\N	\N	\N	Fabrizio Papale	pplfrz63d09h501w	Via Millevie 801, Roma	fabrizio.papale@gmail.com	3030.00	0.00	3030.00	0.00	3030.00	EUR	\N	\N	\N	2026-05-29 18:08:58.801306+00	2026-05-29 18:07:20.32731+00	2026-05-29 18:08:58.801306+00
\.


--
-- Data for Name: odontogram_teeth; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.odontogram_teeth (id, clinic_id, patient_id, tooth_number, quadrant, is_deciduous, condition, surfaces, bridge_group_id, implant_ref, notes, recorded_at, recorded_by_provider_id, created_at, updated_at) FROM stdin;
98a99548-8e25-47c3-b268-38bcfdcc9e95	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	16	1	f	filling	{O,D}	\N	\N	Otturazione composito recente	2026-05-26 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ccd6a8de-2947-47ac-810f-b7528c5d8010	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	14	1	f	caries	{O}	\N	\N	Carie intercuspale iniziale	2026-05-26 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5bb624f6-6cfa-4299-b29e-04d9cdd1a5e7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	36	3	f	healthy	\N	\N	\N	\N	2025-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6e918237-fbd5-49b6-adcf-4323053f8a4f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	46	4	f	filling	{O}	\N	\N	Otturazione amalgama vecchia	2025-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c1e58a51-0c99-4dfc-ad93-45a845dfee23	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	26	2	f	healthy	\N	\N	\N	\N	2025-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ba689312-fdc3-47cb-9338-3da26d8608b5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	47	4	f	caries	{M}	\N	\N	Carie mesiale iniziale	2026-05-26 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b35810c8-17e8-460d-af45-163906514031	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	11	1	f	healthy	\N	\N	\N	Valutazione faccetta	2025-11-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ad1fd70e-472c-4b6c-b86d-9b5116ab77aa	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	21	2	f	healthy	\N	\N	\N	Valutazione faccetta	2025-11-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5494507f-90f5-4635-9dae-4ef8437f0bc9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	12	1	f	filling	{M}	\N	\N	Otturazione vecchia	2025-11-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ca867c38-1641-482d-80b6-104fbf9e259f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	22	2	f	filling	{M}	\N	\N	Otturazione vecchia	2025-11-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
82735bcb-db72-479a-bb7e-f6c27c275313	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	36	3	f	missing	\N	\N	\N	Sito implantare - pianificato	2026-05-09 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9a98e2bf-5e14-4bbf-a484-9cfc659f4339	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	37	3	f	healthy	\N	\N	\N	\N	2026-05-09 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8169dd0c-fff6-4d9a-9b5f-539bf136c722	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	46	4	f	crown	\N	\N	\N	Corona in PFM 2018	2026-05-09 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
245283c2-a6cc-4f1f-aa37-1652026642d3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	17	1	f	filling	{O,D,M}	\N	\N	Otturazione ampia	2026-05-09 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
401ae1d9-d3a9-496d-8840-57ba85cf736a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	11	1	f	healthy	\N	\N	\N	\N	2025-12-30 00:00:00+00	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f2363ab9-9a48-4d6e-a296-1ece03fedfcb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	16	1	f	filling	{O}	\N	\N	Piccola otturazione	2025-12-30 00:00:00+00	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f764ac18-9aa3-4f37-abd2-a9d69683c94d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	26	2	f	caries	{O}	\N	\N	Carie iniziale intercuspale	2025-12-30 00:00:00+00	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
145abad2-84ac-43af-b9a7-fbd0820b167d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	26	2	f	devitalized	\N	\N	\N	Devitalizzazione in corso	2026-05-15 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
84f6c58a-2852-4fdc-a166-5ecaa44967e2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	25	2	f	filling	{O}	\N	\N	Otturazione esistente	2026-05-15 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ceb576be-f3f2-4ff3-bac5-7de002915cf3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	27	2	f	healthy	\N	\N	\N	\N	2026-05-15 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
09663b0e-9cf3-48f2-b037-4aaaa30b4d33	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	13	1	f	healthy	\N	\N	\N	Con bracket	2025-08-02 00:00:00+00	b1000001-0000-0000-0000-000000000003	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6b748ee5-c32d-4c1d-a083-3009daf92c2f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	23	2	f	healthy	\N	\N	\N	Con bracket	2025-08-02 00:00:00+00	b1000001-0000-0000-0000-000000000003	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
34af64f1-5ce3-402a-8802-8b522981b975	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	34	3	f	healthy	\N	\N	\N	Con bracket	2025-08-02 00:00:00+00	b1000001-0000-0000-0000-000000000003	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bc505526-7e99-4f39-bf7d-96c6f6ebc404	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	43	4	f	healthy	\N	\N	\N	Con bracket	2025-08-02 00:00:00+00	b1000001-0000-0000-0000-000000000003	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
17a6ec82-c88e-4eed-82b6-9c776445ff23	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	18	1	f	missing	\N	\N	\N	Estratto 45 gg fa	2026-04-14 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c258868a-0ab3-4b09-a42a-3de53f322d41	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	17	1	f	filling	{O,D}	\N	\N	Otturazione composito	2026-04-14 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a55f00f5-38b8-4c19-98fb-d46d9658b6f1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	35	3	f	caries	{O,M}	\N	\N	Carie bifacciale	2026-03-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
01b0f6de-d548-4a4c-87da-e694c7535bd9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	45	4	f	caries	{O}	\N	\N	Carie occlusale	2026-03-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
10d947ed-cbe5-4dcc-a1ca-dc95e0ecc7f1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	25	2	f	filling	{O}	\N	\N	Otturazione recente	2026-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
55f6876a-aee9-4e44-8a5e-fa75a667579c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	31	3	f	healthy	\N	\N	\N	Recessione gengivale 2mm	2026-01-29 00:00:00+00	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0cc0008f-9c4b-44ad-9ee0-9368b92d9dc8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	41	4	f	healthy	\N	\N	\N	Recessione gengivale 1mm	2026-01-29 00:00:00+00	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2f13ab27-4147-495d-aa58-463e38278c1d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	36	3	f	filling	{O}	\N	\N	Otturazione vecchia	2026-01-29 00:00:00+00	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
252edc18-0add-4076-a3da-f1ce07bef262	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	46	4	f	missing	\N	\N	\N	Sito impianto in programma	2026-05-14 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
64f663e5-3040-4691-b61d-809fba0ba6a3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	47	4	f	healthy	\N	\N	\N	\N	2026-05-14 00:00:00+00	b1000001-0000-0000-0000-000000000002	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
bfc6c5d0-9563-495d-b1be-fde57aa775e8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	26	2	f	caries	{O,M,D}	\N	\N	Carie profonda - dolore	2026-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c833b437-c948-4db7-907a-d1d03c012414	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	25	2	f	devitalized	\N	\N	\N	Devitalizzazione precedente	2026-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7c0830d4-e570-4995-bbb2-4a9f61dc4fa1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	27	2	f	healthy	\N	\N	\N	\N	2026-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: patient_anamnesis; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patient_anamnesis (id, clinic_id, patient_id, recorded_at, recorded_by_provider_id, blood_type, smoker, cigarettes_per_day, alcohol_use, drug_use, hypertension, diabetes, diabetes_type, heart_disease, coagulopathy, immunodeficiency, osteoporosis, thyroid_disease, epilepsy, hepatitis, hiv_positive, tumor_history, autoimmune_disease, other_diseases, taking_anticoagulants, taking_bisphosphonates, taking_cortisone, current_medications, allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin, other_allergies, bruxism, mouth_breathing, nail_biting, pacifier_use, notes, signed_at, signature_notes, is_current, created_at, updated_at) FROM stdin;
ae843917-b419-4be2-abf4-58a6c2b5e218	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	2025-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	A+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
eb8aa0f0-33bb-4547-82dd-8f1850ef46c3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	2025-11-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	B+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	t	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
4aeaf8af-651b-4a39-b8e4-dc08a872cd66	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	2026-02-28 00:00:00+00	b1000001-0000-0000-0000-000000000002	0+	f	\N	\N	\N	t	f	\N	f	f	f	f	f	f	f	f	f	f	\N	t	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7b8585ef-3b95-4616-8e78-9fe1fe0779f3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	2025-11-10 00:00:00+00	b1000001-0000-0000-0000-000000000001	AB-	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	t	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
26dc4ec4-9867-4d36-92ce-035070f53326	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	2025-12-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	A-	t	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	t	Ibuprofene	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fea7c9ac-fa21-48cd-a47b-8136dc39f6ae	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	2026-04-14 00:00:00+00	b1000001-0000-0000-0000-000000000004	0-	f	\N	\N	\N	f	t	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7baa2849-c29d-4bb8-9506-710b372af247	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	2025-08-02 00:00:00+00	b1000001-0000-0000-0000-000000000003	A+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
76936651-eed3-4d96-89d5-deee745887d0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	2026-04-29 00:00:00+00	b1000001-0000-0000-0000-000000000002	B-	f	\N	\N	\N	f	f	\N	t	f	f	f	f	f	f	f	f	f	\N	f	t	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e21c3286-f965-47bd-9f35-aca193cd7e40	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	2025-04-24 00:00:00+00	b1000001-0000-0000-0000-000000000004	0+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1ce7a6f3-fc41-47c2-a0c4-e9fdca1e5499	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	2026-03-30 00:00:00+00	b1000001-0000-0000-0000-000000000001	AB+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
665c5acd-3ca1-4250-9f81-55882d630164	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	2026-01-29 00:00:00+00	b1000001-0000-0000-0000-000000000004	A+	t	\N	\N	\N	t	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	Codeina	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d4505492-2cfb-4ea4-8444-c236dac2eca8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	2026-03-10 00:00:00+00	b1000001-0000-0000-0000-000000000004	B+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	t	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e012ef7c-7e46-4f7b-a413-411e65003f69	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	2025-09-21 00:00:00+00	b1000001-0000-0000-0000-000000000001	0+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
46f8cb4d-529b-4235-b22d-cec5e5566172	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	2026-04-24 00:00:00+00	b1000001-0000-0000-0000-000000000001	AB+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	t	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
42c412bd-17a6-41ef-a567-65f8b25992c4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	2025-01-14 00:00:00+00	b1000001-0000-0000-0000-000000000001	A-	f	\N	\N	\N	t	t	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
cf9af319-768b-4604-9eb4-289cf560a674	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	2026-05-14 00:00:00+00	b1000001-0000-0000-0000-000000000002	0-	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7b5698d8-fdf4-4a1a-a55c-b2220b823be1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	2024-10-06 00:00:00+00	b1000001-0000-0000-0000-000000000002	A+	f	\N	\N	\N	t	f	\N	t	f	f	f	f	f	f	f	f	f	\N	t	f	f	\N	f	f	f	f	Penicillina e derivati	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
b88f987c-b92b-4c63-9350-9ef144db7919	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	2026-05-29 00:00:00+00	b1000001-0000-0000-0000-000000000001	B+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
abeba488-bc60-4433-a12f-b13b431f3a25	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	2026-03-20 00:00:00+00	b1000001-0000-0000-0000-000000000001	0+	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7f4eb0b3-a54d-4139-93ee-b1e4712a374b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	2026-05-19 00:00:00+00	b1000001-0000-0000-0000-000000000003	AB-	f	\N	\N	\N	f	f	\N	f	f	f	f	f	f	f	f	f	f	\N	f	f	f	\N	f	f	f	f	\N	f	f	f	\N	\N	\N	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: patient_anamnesis_item_selections; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patient_anamnesis_item_selections (id, clinic_id, patient_id, item_id, notes, recorded_at, updated_at, recorded_by_provider_id) FROM stdin;
\.


--
-- Data for Name: patient_diagnoses; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patient_diagnoses (id, clinic_id, patient_id, provider_id, tooth_number, title, description, icd_code, status, diagnosed_at, resolved_at, created_at, updated_at) FROM stdin;
2ebf34c1-0de2-4cb9-bce4-b850070e305d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	16	Carie occlusale	Carie di I grado sulla fossa centrale del 16	K02.1	active	2026-04-29	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
dc6f02c5-093b-4106-a3d6-73dacc06e4f8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	47	Carie mesiale iniziale	Carie mesiale del 47 in stadio iniziale	K02.1	active	2026-05-26	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6290de84-fe53-479d-ac63-dc0653c201f0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000001	21	Pulpite reversibile	Sensibilità aumentata su 21 da stimoli freddi	K04.0	active	2026-05-19	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c5736bb5-a40a-49ab-ac9e-71cce03d5cb1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	b1000001-0000-0000-0000-000000000003	\N	Malocclusione classe II	Malocclusione scheletrica classe II divisione 1	K07.2	chronic	2025-11-30	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c2f5667e-6684-4e19-804e-bf5b5f87b82b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	46	Parodontite localizzata	Parodontite cronica localizzata al 46 con tasca 5mm	K05.3	active	2026-04-14	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
695856b7-b036-4256-ab96-fc2aea32ebcb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	b1000001-0000-0000-0000-000000000002	18	Dente del giudizio incluso	Terzo molare superiore sinistro incluso in osso	K01.1	active	2025-11-10	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
24787693-d669-49bc-9c7c-37a4c9c9577f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	\N	Gengivite generalizzata	Gengivite da placca batterica generalizzata	K05.1	active	2026-05-22	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
42d57cd6-d87a-432a-8d57-1a9e749e7023	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	26	Pulpite irreversibile	Pulpite irreversibile sintomatica 26 con dolore spontaneo	K04.0	active	2026-05-15	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3fd90b97-79e0-4d04-a3e2-35e1e568cf4f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	18	Terzo molare incluso risolto	Estratto il 18 incluso mesioangolato	K01.1	resolved	2026-04-14	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fbfc7e00-680f-4a90-80a2-304b3a905ce7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	35	Carie bifacciale	Carie dentinale bifacciale OM del 35	K02.1	active	2026-03-30	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
934b430c-67ea-44ad-9e9c-7036f73e8651	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	b1000001-0000-0000-0000-000000000001	45	Carie occlusale	Carie occlusale del 45 in stadio dentinale	K02.1	active	2026-03-30	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
0ac7976a-5913-40fb-81ab-3cd4988653fc	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	\N	Parodontite cronica moderata	Parodontite cronica generalizzata moderata BOP 60%	K05.3	chronic	2026-01-29	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1afbe5c3-354b-4aa6-9d2c-d699745edcab	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	\N	Diabete mellito tipo 2	Paziente diabetico - monitorare guarigione tissutale	E11	chronic	2025-01-14	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
faa75f20-57a2-45ff-90e6-aee2595ecc27	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	b1000001-0000-0000-0000-000000000002	\N	Cardiopatia con anticoagulante	Paziente in TAO - INR da verificare prima di chirurgia	I25.1	chronic	2024-10-06	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
15c81be5-eb44-409b-a34e-23779286be02	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	26	Carie profonda	Carie profonda 26 prossima alla polpa - probabile devitalizzazione	K02.3	active	2026-05-29	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: patient_documents; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patient_documents (id, clinic_id, patient_id, appointment_id, uploaded_by_provider_id, document_type, title, description, file_name, file_path, file_size_bytes, mime_type, tooth_number, taken_at, notes, created_at, updated_at) FROM stdin;
3bbce673-539c-4ed1-8002-bd84cd78dead	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	\N	b1000001-0000-0000-0000-000000000001	rx_endorale	RX endorale 16	\N	rx_16_rossi_2024.jpg	/uploads/demo/rx_16_rossi_2024.jpg	\N	\N	\N	\N	RX endorale elemento 16 pre-otturazione	2026-05-19 10:00:00+00	2026-05-29 13:52:49.31794+00
42d13785-c1c7-4cd9-8c68-29fb647543e7	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	\N	b1000001-0000-0000-0000-000000000001	consenso_informato	Consenso informato piano di cura	\N	consenso_rossi_2024.pdf	/uploads/demo/consenso_rossi_2024.pdf	\N	\N	\N	\N	Consenso informato piano di cura	2025-05-29 09:00:00+00	2026-05-29 13:52:49.31794+00
aede0bcf-ac59-4ed3-a66f-cc4121fa91a5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	\N	b1000001-0000-0000-0000-000000000001	foto_clinica	Foto post-otturazione 16	\N	foto_16_rossi_post.jpg	/uploads/demo/foto_16_rossi_post.jpg	\N	\N	\N	\N	Foto post-otturazione 16	2026-05-26 10:30:00+00	2026-05-29 13:52:49.31794+00
99625c8f-8f68-46a5-ae08-8a5a23c62de4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	\N	b1000001-0000-0000-0000-000000000001	foto_clinica	Foto frontale sorriso	\N	foto_frontale_bianchi.jpg	/uploads/demo/foto_frontale_bianchi.jpg	\N	\N	\N	\N	Foto frontale sorriso per valutazione estetica	2025-11-30 09:00:00+00	2026-05-29 13:52:49.31794+00
042df7b9-721e-4c5f-a21a-cf3b9a9ca121	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	\N	b1000001-0000-0000-0000-000000000001	foto_extraorale	Foto profilo valutazione	\N	foto_profilo_bianchi.jpg	/uploads/demo/foto_profilo_bianchi.jpg	\N	\N	\N	\N	Foto profilo sinistro per valutazione	2025-11-30 09:05:00+00	2026-05-29 13:52:49.31794+00
32fcb183-8afb-4650-aaf1-ff48826b6360	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	\N	b1000001-0000-0000-0000-000000000002	cbct	CBCT arcata inferiore 36	\N	cbct_36_romano_2024.dcm	/uploads/demo/cbct_36_romano_2024.dcm	\N	\N	\N	\N	CBCT arcata inferiore pre-impianto 36	2026-05-09 09:00:00+00	2026-05-29 13:52:49.31794+00
a09fd284-3288-4bd9-91b4-56b17cea1d7c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	\N	b1000001-0000-0000-0000-000000000002	rx_panoramica	Ortopantomografia inquadramento	\N	ortopan_romano_2024.jpg	/uploads/demo/ortopan_romano_2024.jpg	\N	\N	\N	\N	Ortopantomografia di inquadramento	2026-05-04 08:30:00+00	2026-05-29 13:52:49.31794+00
02a11c67-d712-4b5d-8ead-788a4d3fbf64	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	\N	b1000001-0000-0000-0000-000000000002	consenso_informato	Consenso procedura implantare	\N	consenso_impianto_romano.pdf	/uploads/demo/consenso_impianto_romano.pdf	\N	\N	\N	\N	Consenso informato procedura implantare	2026-05-09 09:30:00+00	2026-05-29 13:52:49.31794+00
bef29ec9-5c6b-484c-9996-dd56a13e89b3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	\N	b1000001-0000-0000-0000-000000000004	rx_panoramica	OPT inquadramento parodontale	\N	ortopan_ricci_2024.jpg	/uploads/demo/ortopan_ricci_2024.jpg	\N	\N	\N	\N	OPT di inquadramento - gengivite generalizzata	2025-12-30 10:00:00+00	2026-05-29 13:52:49.31794+00
2e23020b-7b81-43d7-8faa-df0fdb041921	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	\N	b1000001-0000-0000-0000-000000000004	foto_clinica	Foto gengivite generalizzata	\N	foto_gengivite_ricci.jpg	/uploads/demo/foto_gengivite_ricci.jpg	\N	\N	\N	\N	Documentazione fotografica gengivite	2025-12-30 10:15:00+00	2026-05-29 13:52:49.31794+00
c61c2116-9a88-42bc-8e3e-08fdd112c7a8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	\N	b1000001-0000-0000-0000-000000000001	rx_endorale	RX endorale 26 pre-devitaliz.	\N	rx_26_marino_pre.jpg	/uploads/demo/rx_26_marino_pre.jpg	\N	\N	\N	\N	RX endorale 26 pre-devitalizzazione	2026-05-15 09:00:00+00	2026-05-29 13:52:49.31794+00
96ed6618-e3b0-4bf2-9f67-473b22a137f1	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	\N	b1000001-0000-0000-0000-000000000001	consenso_informato	Consenso devitalizzazione 26	\N	consenso_devital_marino.pdf	/uploads/demo/consenso_devital_marino.pdf	\N	\N	\N	\N	Consenso devitalizzazione 26	2026-05-15 09:15:00+00	2026-05-29 13:52:49.31794+00
10dd504a-44ee-4263-b341-4e113b9040c3	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	\N	b1000001-0000-0000-0000-000000000003	rx_panoramica	OPT pre-trattamento ortodontico	\N	ortopan_greco_pre_orto.jpg	/uploads/demo/ortopan_greco_pre_orto.jpg	\N	\N	\N	\N	OPT pre-trattamento ortodontico	2025-08-02 09:00:00+00	2026-05-29 13:52:49.31794+00
feb9c077-b500-4660-916a-1a510d2cb145	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	\N	b1000001-0000-0000-0000-000000000003	foto_clinica	Foto intraorali pre-trattamento	\N	foto_intraoral_greco_pre.jpg	/uploads/demo/foto_intraoral_greco_pre.jpg	\N	\N	\N	\N	Foto intraorali pre-trattamento	2025-08-02 09:30:00+00	2026-05-29 13:52:49.31794+00
21ae7c1c-b054-4859-a6cb-873b67c6da37	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	\N	b1000001-0000-0000-0000-000000000003	foto_extraorale	Foto profilo pre-trattamento	\N	foto_profilo_greco_pre.jpg	/uploads/demo/foto_profilo_greco_pre.jpg	\N	\N	\N	\N	Foto profilo pre-trattamento	2025-08-02 09:35:00+00	2026-05-29 13:52:49.31794+00
4f7a4636-859a-4fcc-8ae0-109e1a1682ab	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	\N	b1000001-0000-0000-0000-000000000003	consenso_informato	Consenso trattamento ortodontico	\N	consenso_orto_greco.pdf	/uploads/demo/consenso_orto_greco.pdf	\N	\N	\N	\N	Consenso trattamento ortodontico	2025-08-02 10:00:00+00	2026-05-29 13:52:49.31794+00
2d8de0d9-b2ee-4b1b-92b7-32be6a1832f0	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	\N	b1000001-0000-0000-0000-000000000002	rx_endorale	RX endorale 18 pre-estrazione	\N	rx_18_bruno_pre.jpg	/uploads/demo/rx_18_bruno_pre.jpg	\N	\N	\N	\N	RX endorale 18 incluso pre-estrazione	2026-04-13 09:00:00+00	2026-05-29 13:52:49.31794+00
6e40264e-39a6-4184-9185-2c3c646c5056	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	\N	b1000001-0000-0000-0000-000000000002	consenso_informato	Consenso estrazione 18	\N	consenso_estrazione_bruno.pdf	/uploads/demo/consenso_estrazione_bruno.pdf	\N	\N	\N	\N	Consenso estrazione 18	2026-04-14 09:30:00+00	2026-05-29 13:52:49.31794+00
4381f81e-e64c-4999-b7d2-212e2273a4fe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	\N	b1000001-0000-0000-0000-000000000002	referto	Referto post-estrazione 18	\N	referto_estrazione_bruno.pdf	/uploads/demo/referto_estrazione_bruno.pdf	\N	\N	\N	\N	Referto post-estrazione 18	2026-04-14 11:00:00+00	2026-05-29 13:52:49.31794+00
88c87090-b0d9-4fd3-94bf-80fb36bb66ea	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	\N	b1000001-0000-0000-0000-000000000004	rx_panoramica	OPT parodontologica	\N	ortopan_deluca_paro.jpg	/uploads/demo/ortopan_deluca_paro.jpg	\N	\N	\N	\N	OPT parodontologica con misurazione tasche	2026-01-29 09:00:00+00	2026-05-29 13:52:49.31794+00
6f8a4584-2ad7-4821-91cf-f87c34fc9f26	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	\N	b1000001-0000-0000-0000-000000000004	documento_amministrativo	Cartella parodontale completa	\N	cartella_paro_deluca.pdf	/uploads/demo/cartella_paro_deluca.pdf	\N	\N	\N	\N	Cartella parodontale completa con sondaggi	2026-01-29 10:00:00+00	2026-05-29 13:52:49.31794+00
50041d72-db3a-4ace-84a3-77469be9df0c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	\N	b1000001-0000-0000-0000-000000000002	cbct	CBCT arcata inferiore 46	\N	cbct_46_lombardi_2024.dcm	/uploads/demo/cbct_46_lombardi_2024.dcm	\N	\N	\N	\N	CBCT arcata inferiore pre-impianto 46	2026-05-28 14:00:00+00	2026-05-29 13:52:49.31794+00
f751f6c6-425c-443d-81bd-590fe7571b5d	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	\N	b1000001-0000-0000-0000-000000000002	consenso_informato	Consenso procedura implantare 46	\N	consenso_impianto_lombardi.pdf	/uploads/demo/consenso_impianto_lombardi.pdf	\N	\N	\N	\N	Consenso procedura implantare 46	2026-05-28 14:30:00+00	2026-05-29 13:52:49.31794+00
e6fb15b7-258c-4078-ad72-2c1c7895f0bd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	\N	b1000001-0000-0000-0000-000000000001	rx_endorale	RX urgente 26	\N	rx_26_barbieri_urgenza.jpg	/uploads/demo/rx_26_barbieri_urgenza.jpg	\N	\N	\N	\N	RX urgente 26 - dolore acuto	2026-05-29 16:00:00+00	2026-05-29 13:52:49.31794+00
78f18d32-9c44-462a-9cd4-5d8353d0083b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	\N	b1000001-0000-0000-0000-000000000003	foto_extraorale	Foto profilo valutazione orto	\N	foto_profilo_santoro_valut.jpg	/uploads/demo/foto_profilo_santoro_valut.jpg	\N	\N	\N	\N	Foto profilo valutazione ortodontica	2026-05-19 10:00:00+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: patient_prescriptions; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patient_prescriptions (id, clinic_id, patient_id, provider_id, drug_name, dosage, frequency, duration, notes, prescribed_at, expires_at, active, created_at, updated_at) FROM stdin;
2feae31d-95d4-4ad8-967b-15024b61df57	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	Amoxicillina	1g	3 volte al giorno	7 giorni	Assumere lontano dai pasti. Sospendere e contattare lo studio in caso di reazione allergica.	2026-04-29	2026-07-28	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8dab4254-74a7-4218-963f-d652d5df7a8a	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	b1000001-0000-0000-0000-000000000001	Ibuprofene	600mg	Al bisogno, max 3 al giorno	5 giorni	Non superare la dose massima giornaliera. Non assumere a stomaco vuoto.	2026-05-26	2026-06-03	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5f3ecb8e-12ef-4be9-a849-60c69e42b089	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	b1000001-0000-0000-0000-000000000001	Clorexidina collutorio 0.2%	\N	2 volte al giorno dopo i pasti	30 giorni	Risciacquare per 1 minuto. Non ingerire. Può colorare i denti temporaneamente.	2026-04-14	2026-05-14	f	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ae4d1628-154c-412f-ab0f-edd68bd8a83f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	b1000001-0000-0000-0000-000000000004	Clorexidina gel 1%	\N	2 applicazioni al giorno	14 giorni	Applicare sui bordi gengivali con spazzolino morbido.	2026-05-22	2026-06-05	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e29de3ae-c57c-4b1c-b698-cd9638db7a5b	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	Nimesulide	100mg	2 volte al giorno	5 giorni	Assumere dopo i pasti. Controindicato in insufficienza epatica.	2026-05-15	2026-05-20	f	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9ed8d2b3-3f0c-4182-a435-8267e44bbbff	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	b1000001-0000-0000-0000-000000000001	Amoxicillina + Acido Clavulanico	1g	2 volte al giorno	6 giorni	Profilassi post-devitalizzazione. Assumere ai pasti.	2026-05-15	2026-05-21	f	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fdaf1f1b-cef7-4178-8be0-6f1fbb3558be	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	b1000001-0000-0000-0000-000000000002	Ibuprofene	400mg	Ogni 6 ore per le prime 24h, poi al bisogno	3 giorni	Post-estrazione 18. Ghiaccio applicato esternamente nelle prime 2h.	2026-04-14	2026-04-17	f	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fc3c97bc-9882-4816-a9e5-9218491e3524	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	b1000001-0000-0000-0000-000000000004	Clorexidina collutorio 0.12%	\N	3 volte al giorno	14 giorni	Dopo SRP parodontale. Non sostituisce lo spazzolamento.	2026-01-29	2026-02-12	f	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6a61cdf3-af17-4ba2-a7e9-e084cfefeba5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	b1000001-0000-0000-0000-000000000001	Metronidazolo	250mg	3 volte al giorno	7 giorni	Evitare alcol durante il trattamento. Assumere ai pasti.	2026-05-26	2026-06-02	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
454e9108-b7a9-4441-a45e-01a0896fff6e	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	b1000001-0000-0000-0000-000000000001	Ketoprofene	25mg	Al bisogno, max 3 al giorno	3 giorni	Antidolorifico per dolore acuto 26. Ripresentarsi se il dolore aumenta.	2026-05-29	2026-06-01	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: patient_recalls; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patient_recalls (id, clinic_id, patient_id, recall_type, due_date, status, priority, notes, source_appointment_id, booked_appointment_id, last_contact_at, contact_count, created_at, updated_at) FROM stdin;
a7675bb6-9cc4-450c-b9fc-5d7aadfbbccb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	Controllo periodico	2026-05-29	da_contattare	media	\N	\N	\N	\N	0	2026-05-29 18:35:58.578667+00	2026-05-29 18:35:58.578667+00
fdc5bdd2-220f-41d8-909c-007b047056b5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	Controllo periodico	2026-05-22	confermato	alta	\N	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 18:37:29.26568+00
389b6eea-f1f1-4de9-bb8d-49a0b6d6af07	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	Controllo post-chirurgia	2026-04-21	confermato	alta	\N	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 18:37:36.139151+00
e73173a8-27d3-4043-a963-8f2e8543a1f9	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000009	Controllo periodico	2026-04-29	contattato	alta	\N	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 18:37:39.232173+00
59929d2c-cffd-42da-a645-33154bf34047	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	Controllo post-trattamento	2026-05-26	in_attesa	alta	\N	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 18:39:20.254611+00
000a018f-8be4-4281-be74-45d8977caf45	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	Controllo post-trattamento	2026-06-01	contattato	media	Follow-up post-otturazione 37 - confermato per domani	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f47fd211-c6d2-41a7-bc86-3937759b7517	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000004	Controllo periodico	2026-06-03	confermato	media	Igiene programmata - appuntamento fissato	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ab32bb1a-3177-41c3-af47-4c23fa5649fe	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	Controllo post-trattamento	2026-06-05	da_contattare	media	Controllo post-igiene profonda e devitalizzazione 26	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d6300282-7bea-41ca-b4b9-b5e947e455f4	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	Controllo periodico	2026-06-08	da_contattare	media	Igiene semestrale - paziente con parodontite cronica	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a9387e0f-bd32-4b3d-becc-c138ddbf04bd	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000012	Controllo post-trattamento	2026-06-12	contattato	media	Controllo post-SRP - valutare risposta parodontale	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
9222bfff-7012-4272-b1e8-f4d90bcd1824	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	Controllo post-trattamento	2026-06-12	confermato	alta	Controllo post-impianto 36 - fondamentale per osteointegrazione	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fe81a522-a228-4120-a74e-025f39be0bb8	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	Controllo post-trattamento	2026-06-19	da_contattare	alta	Controllo post-impianto 46 - pianificato tra 3 settimane	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
3cfd9cc8-b45f-4dd1-8556-6e3c3c872198	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	Controllo periodico	2026-06-28	da_contattare	bassa	Visita annuale di controllo - ultimo accesso 6 mesi fa	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
88ca5c7a-05f3-4c95-90e5-ffa99ab9a103	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	Controllo post-trattamento	2026-06-19	da_contattare	media	Controllo carie 35 e 45 dopo restauro	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
22c2ed22-3905-4017-b1c5-dd3687cc0e96	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000019	Controllo periodico	2026-07-13	da_contattare	bassa	Visita annuale di controllo	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
37651cef-b01c-4cb6-8a29-231e66dcdddb	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000014	Controllo periodico	2026-07-03	da_contattare	bassa	Igiene semestrale - buona compliance	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
8b04d0dc-0384-4167-b30a-1fd4beff259c	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000020	Controllo ortodontico	2026-07-28	da_contattare	bassa	Prima visita ortodontica di controllo post-valutazione	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
26c426ff-5cbc-4e84-babf-069f3b63984f	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	Controllo periodico	2026-06-28	da_contattare	media	Richiamo igiene - paziente fumatore, rischio parodontale	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
93615e17-c84e-4e6e-a3a6-268adbc0b3e2	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	Controllo ortodontico	2026-06-28	confermato	media	Controllo mensile apparecchio fisso - già programmato	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f2b4e7e8-a710-4ed8-9115-f78d267774ca	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	Controllo estetico	2026-07-13	in_attesa	bassa	Follow-up valutazione faccette - in attesa risposta preventivo	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
7464648a-32cb-4323-a580-ed99c70b89b5	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	Controllo post-trattamento	2026-05-24	chiuso	bassa	Follow-up completato - paziente tornato in cura regolare	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f79f3587-d82d-4e64-a8e2-65e16c221750	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000013	Controllo periodico	2026-03-30	annullato	media	Paziente trasferito ad altro studio - chiuso	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
41702e06-4f9e-4aa5-98b4-807ee96c0ea6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000017	Controllo periodico	2026-02-28	annullato	bassa	Doppio richiamo - eliminato duplicato	\N	\N	\N	0	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.patients (id, clinic_id, first_name, last_name, fiscal_code, birth_date, phone, address_line1, address_line2, city, province, postal_code, country, notes, created_at, updated_at, photo_url, email, active, primary_provider_id) FROM stdin;
c1000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	Marco	Rossi	RSSMRC85A01H501X	1985-01-01	+39 348 1110001	\N	\N	Roma	RM	00100	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	Giulia	Bianchi	BNCGLI90B41H501Y	1990-02-28	+39 348 1110002	\N	\N	Roma	RM	00144	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	Luca	Romano	RMNLCU78C03H501Z	1978-03-15	+39 348 1110003	\N	\N	Roma	RM	00162	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	Chiara	Colombo	CLMCHR92D44H501W	1992-04-10	+39 348 1110004	\N	\N	Milano	MI	20100	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	Andrea	Ricci	RCCNDR80E05H501V	1980-05-22	+39 348 1110005	\N	\N	Roma	RM	00185	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	Valentina	Marino	MRNVNT88F46H501U	1988-06-05	+39 348 1110006	\N	\N	Napoli	NA	80100	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	Stefano	Greco	GRCSFN75G07H501T	1975-07-18	+39 348 1110007	\N	\N	Roma	RM	00136	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	Francesca	Bruno	BRNFNC95H48H501S	1995-08-30	+39 348 1110008	\N	\N	Roma	RM	00167	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000009	9d754153-6579-4b7e-a56b-025f00299cd9	Matteo	Gallo	GLLMTT82I09H501R	1982-09-12	+39 348 1110009	\N	\N	Firenze	FI	50100	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	Silvia	Conti	CNTSLV91L50H501Q	1991-11-25	+39 348 1110010	\N	\N	Roma	RM	00192	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000011	9d754153-6579-4b7e-a56b-025f00299cd9	Roberto	De Luca	DLCRBT68A11H501P	1968-01-20	+39 348 1110011	\N	\N	Roma	RM	00118	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000012	9d754153-6579-4b7e-a56b-025f00299cd9	Elena	Mancini	MNCLNE86B52H501N	1986-02-14	+39 348 1110012	\N	\N	Roma	RM	00176	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000013	9d754153-6579-4b7e-a56b-025f00299cd9	Daniele	Costa	CSTDNL79C13H501M	1979-03-08	+39 348 1110013	\N	\N	Torino	TO	10100	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000014	9d754153-6579-4b7e-a56b-025f00299cd9	Martina	Giordano	GRDMTN93D54H501L	1993-04-02	+39 348 1110014	\N	\N	Roma	RM	00154	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000015	9d754153-6579-4b7e-a56b-025f00299cd9	Paolo	Rizzo	RZZPLA70E15H501K	1970-05-16	+39 348 1110015	\N	\N	Roma	RM	00122	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000016	9d754153-6579-4b7e-a56b-025f00299cd9	Alessia	Lombardi	LMBLSS97F56H501J	1997-06-28	+39 348 1110016	\N	\N	Roma	RM	00145	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000017	9d754153-6579-4b7e-a56b-025f00299cd9	Giovanni	Moretti	MRTGNN65G17H501I	1965-07-04	+39 348 1110017	\N	\N	Bologna	BO	40100	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000018	9d754153-6579-4b7e-a56b-025f00299cd9	Sara	Barbieri	BRBSRA89H58H501H	1989-08-19	+39 348 1110018	\N	\N	Roma	RM	00159	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000019	9d754153-6579-4b7e-a56b-025f00299cd9	Nicola	Fontana	FNTNCL83I19H501G	1983-09-11	+39 348 1110019	\N	\N	Roma	RM	00173	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
c1000001-0000-0000-0000-000000000020	9d754153-6579-4b7e-a56b-025f00299cd9	Beatrice	Santoro	SNTBRC96L60H501F	1996-12-03	+39 348 1110020	\N	\N	Roma	RM	00141	IT	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	t	\N
3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	9d754153-6579-4b7e-a56b-025f00299cd9	Papale	Fabrizio	pplfrz63d09h501w	1963-04-09	+393483448500	Via Millevie 801	\N	Roma	RM	00100	IT	Pasta e patate	2026-05-29 17:28:16.854142+00	2026-06-01 19:23:39.437176+00	data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8LCwkMEQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/2wBDAQUFBQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh7/wAARCAGQAZADASIAAhEBAxEB/8QAHAAAAgMBAQEBAAAAAAAAAAAAAwQCBQYBAAcI/8QAPhAAAgICAQMDAwMCBAUCBAcAAQIAAwQRIQUSMSJBUQYTYRQycSOBQlKRoQcVM7HRYsEkY3KTFiVDg+Hw8f/EABoBAAIDAQEAAAAAAAAAAAAAAAABAgMEBQb/xAAjEQEBAAMAAgICAwEBAAAAAAAAAQIDERIhBDETQQUUUSIy/9oADAMBAAIRAxEAPwAQMmDBzoMpAoM6DBBpINAC7klMF3ToaIDgyQMAp1Jd0CH3OgwIaTU8x9AwMKDzAK0IrRSmMIRTAqYRWj6XBVMIpgQZNTDpjqZNTAq0mrRgdDCAwCtCKY+gYGTEEphAYgKphkMWBhEaCJlTJqYBWhVaIujoYRTAK0mGjK3owMkDAhpINH0dGBnQYINO90DgpaR3Bl55W3EYyeYdfEAkKDCAQGd3B9093SRJ7/MHf+2d7pC07UwIGtvXG9yvU+uNq3EDFJkCwkS0gWgSZIkGMiWkWaA68xkC04zQbNAnXME7TzvAu0XQ+abntyO57citTE7uQBndwCYMkDB7ndwCfdJKYIGSBhQMGk1MADJqZEDq0IrRdTCK0AZRoRTFkaFVo+gwpkwYBTJhowODJqYBTCKYAwphEMAphFMOgwphBAKYRTDoFBk1MEDJBo+lwdTCK35ib3JWnc7BQPcmdoyqrBuuxWH8xI8WCt+ZMNE1sHzCLZvwYxwyGkg0AHne+BcH7vzPd/5i5snPuQ6OGO6EQxVXhkaLpw0jQgb8xZWku6OFR+6e7oHunu6BDd047enzB908xJEcAWwGh1biKlSWjCKe3zJBItIkwiVFjrcI2G2uOYAqTBs0NdRYnkRWwkeREHmaDZpwtBs0iHnaCZvzOO0CzRnHz3c9uRngYlie53chud3AJ7ntyAM9uAEBnQYMGSBgBAZ0NBgyQMQFRoUGLAwitERhWhFaKhtQiNEZpXhFaKhuYQNDoNK0mrxZWhFP5iBpWhVaLK35k1b8yUBpWkw4infoeYOzKCDzzAH2vVBtjqLv1FdHtHj5Mr7r/uDZMTdgxIkMs+HJ1YWXfqnBc7A8D4juKtdQ4/2lCgKMDvgSxpsZl5JkJsPxP5GSVXSnmewrru/liR+ZXkFn2TGsclRvfiOZ9ouPF0to0NyF94rXZMrLMwJoknURyOoNb3doIWTyz4jMVm3VUVyrTtHUhc2kUgfmZ37nfz4EZxLW8gAKPeV/m/1L8bUJeNbJ1DJkp/mEzffc49LdvxB21dRCl6mR9fnmObpSutr0vB94QWgzHYXU8iqzsvVgfgzSYtv3kVkOwZbjl1XlOHxZGKaXs51oSGJQNgtLrGrQJ7alqKv+yFEE5CxzqAKAmsbEprLGJ54j4B2dQYRbl1E120mBo6iB+i9e4CXWOENez5Mp+mYjWP3EcS/XGZa96jOK3PCAblXaqsDGuppZ3knYAlUbmVtHmOQUPIqK8rFGbXBj1rBl2IhkcjYiuJBu8GWGpBm/MEz6HmJKMLueE4fM9K00tz25Hc9DoT3PSO50RhMGd3Bgzu4gIDOgwe53cAJvidDQW50GAHV4RWiwPMIrREaVuIQNFVeSD/mRpm1aEV4mHHzJfcHzEDf3gJE5Sr7kxN3/ADAF7Bvn+whcuHxZ/rFI1zIuQT3EiVgtcMBscwzOXr2DoiV3Yl4j2NvhTBKpDck+ZzFsUto+feFYAWENxM+eftbjiirMwPEsayRRuV6FQeDHqLN4+jqRmR+ItKbHcfJkrQU9zIUWgqF9oWxlOhH+QXDpS1ix58QVir26A0TDW9iltxcuCRzDLM8cOOWKQQo4h8c9zBSoVF/3gAw2fzDpaAABqRl7Tvo8GUjQjFQX7CluD87lVWzFidGMm5+wAca+ZfjZFdx6LbWj2LvyDvcvOmAKo0dKPJmcqbb7dpcUZdaUisOpl+GyKssV7ZmIo9Gwo8fJhMHqFhfTb1KrH1YQAdzS9D6T97TFf7y6Xquw0i/crB1vcq+oYeyWQaPxNevTftVbA41KzJoVrtASyVHjN4uPa3p7DHqenWs42JqundMRlB7JZDp6IN9sjafFV0fACqNrLl8VTXoCTpVa+BqHc7TiLqXGO+oKVRW4mNyG1dqbz6gq7lbYmQvoRbfA8y3FCkG7h4HmCZCVOxLSxa9AcQNqKFMlYGfyD2ORFneG6mwW4iIPZuVWHGWfzIQlggj5labs9ObnNwCe50GQ3O7h0Jzshue3AJ7ndwe53cOBPc6DB7kgYAQSQMGDOgxAQGSDwW54mATa3UicggeRF7WOjrzA9jfuY8SrLLiUnTLZThidjQgv1rFtE/7QWuSAeJE0knmUXK9WTEwLW33bJj2NYr1E+ZTOO3gmcx8k1Ow3xK8qsmK4A1b3KePaM2WhqQxHqXz/ABKRM/TerkRtcpLE5bX5lOVWSGhYrEaMYx7uxihPBEz1jPVZtH2NxmrNNmtjREr8qnMVylunI3GDfuoNvkSoW77gGjzCo76KmL8ic1msu/345ii5HPn2kMjuZON8RI/cXeovydP8dWP6jgGGquDyn23bzviEqubjtMlM0brXzXEaAkGtYtrulat5LdxPiFps2S0n5qvx8Wdbb13DiGpsrZuFZT8mVauSd7MPTYWYbMtwyQyxafpzWhlKacA+N8z6v9IBLOmI/aQfcGfF8B9WKUsKMPHPmfTvpj6h7sJcUBFtQeNef4m3XkzZRt7yv2iOPEzmQEXK/vDY3UTlIwDereojmV2C3vAJAMvlQ40/TCDUNRq46SU/Rb2YAGW1h2NRUyZYh+Yx91e0DcC1Z3uLWllaEAfV6w9RIG5866819Fx0p1PpKH7g03vKbrvSUtUsVGpKZcKxgMbJttbbeBDvf6CSYfNx0xnKKNCUOdk6t+2p/mX43qHCfVX2xf8AMrXtjnUDurcp3eRzghGwQDxhjuAslPFiG56cnog7OiRE7AJT25Ge3AJT25Hc9uAT3JAwYMkDACbngZDc9uICbkXaR7tSDngmK0RxttyDPLs8E8yKOobXJ3GUQFS3bsTLnkuxCWn3A18iRa1a3+3Ydb8GNCxEO2lf1ZVur9B/PHtKLl1bIVzLwrnnkefzK67K8kNB5VraCN5HvK+wuz6G5FOGzmuGHMewcl39uIjiYJfXfxLvFoSlQBKs85GjXruRmiva7bmMJUn+UAyFPPGoceRMmWxsw0wWitQRoRtKxFqjo6jAY68yjLOr5rnEmUfAg2qQ+dSQYkSLM3xIeeR/jgRoU8AQTY4B44jIZp1tfEnNtiN1Sq90ZTxO1uV9/MbZAfMXsq868zRht/1nz0DVuNctqEa/7Y9JiKlgSDJ18vv/AG9ppxy6yZYc+1ji5Ts3hh/E1n0suXlZDGksRSvc3POvxMcjqo5l99O9ePTablraxWsGgycEfnc0YZM2eL6h9PCz9QbHuQsvPb/mHzNOKUyagQJ8b6H17KbOWxbCzJxyfI+J9Y+lOqLn4hZtC0H1ibdWTLlOLLFxvtHgSwCjtEE9yKuyRE7OpVI2u4S5E5kHtGhErHBBHvDrkJemwREsthUN7jD1JJt1+YTqilsUgD2i2HchuGzHcy1Wq1+I+F18w+ovvJawUHXzMbksyZO2959N69XUwbQG583+pFCMWT2MtxILIsD0kSjtbTEb94V8vaRNnJO4qXHAdiQs5nlPMkeRK6lC58yMI4gzI03Z2cnYB6enp6AcJntzk9AJAzu5Cd3FQlv8z25Dc93RAQncHYdLOg8zrAH8yGdSxJ6ct+/X8ywqsZEBZ1/O4AY3c2wJ2xCi63x/Ey51fi5nPW43W/afj5lS97oSASfxGb1YnXGoE4jv6jv+ZSshO1Tc35kqccb2w5hzX9s6BhqxvUqzz4069fXaUA8RqteRIVodxpVAHmYs82/XhyDVAa4EMFPkiDpYQ4I1yZnuVaZHlGodQNQKv7AQqSu00vxI655kvzPeCdwN7j4niv4ngw8mEDAxW0AsnP4kGTnxGGAJg3U7kscuIXHpV0ECSQdRpvgwLqNeZp17eM2zVK4gu5K6P4hqXbu7GHafyIKlu1xzqOqq2KN8/mb9eUrnbMeGOmf0sju7in5E2P0/1u3EyEdH99N+RMdSjAa3HsF+yxUY6LHWzNmvL2x54vr79X+9SHVt9y74mfzsvMfJ3Xvti/0pd96j7L2AGs8D5miSmojkCbozu9EzbftgWE7lh1C8tQSDzK5vtVAkcalfldTVVPqGhLJCqww8jtcbOoXqXU/t16DTLjqaklyeBKD6h69YFIRuJPiHV91HqKMzAvsmZDr5/pufOxK7F6t9y7utY7kuo5X3088SXeJRQu2iRI90jafUf5ke6U2pcF8GTU74kG8zqmFKOsIIrGPIkWSRSB1PahOyeKxUBanoQoZzsgAzOQnYZHsMAjOEyZUyJUxBAmR7pJlMgQYg6rQ9TJ5aLaMNSm/PMpzqzGHFZiv9MDXyZGyt3HqBP4Ahcaqw+2hGC1qL4A/My5LpOE68YAbKa/mCyvtohGtmWBV2HqYmKZNY7SSAP5lVq7Ce1DfrvPtJ0ca1OZIHfr/eeq9HAEy7G7X6OK2hJIe7jZi6sT4jdSEgDUzWNUo1TaGhCeqSoq2fEYWkg61K8otxApUltmMqDD1UfiSar8SqpgDjzODcK1Z3qTShjEAO3Z1qd0QI5+mPnUg9OvYwBfZ8zm+eeZOytgOII714iCLrvx4gygPiE3/rOL55OpLG8RygDUnyI1i9wAEkK+N+RO1eltEcTo6M/Tmb8TmOwHpb+05exTkEED2nu3a8cRPLNiKfcfM1TL2x3HrX/S2bWUW1fQ++0j5mpHUNAHunyTonUDh5YYAlSTwZo16u7p6DvfmdTVe4sWePK2eb1AGrfdrcyWdmk5LVq5IJlfl9Wu7CHJEracwW5HnmX4q60yWbpIZuJn+vFXrPaeBD3ZZSo6Mos7MNoKr495Z30XCiuQ41HDd/T1uIb1Itboa3IdNK5/WdQZeCLEnZMiWkLUotGnBOnzOe8mgJX5hu3Yi6cRlGkalHOydKSYIneNRUwSonvt7hNCSGogD9qd+1DTjHQiAJqEiaRA5mUKgdmV46zWGILiFoWho/Eg9HHiJf83q1vu/3nv8Am1R/xCR8hwZ6yJOpxXywOvxFR1HHYgM+t8Tr2dx5PEo2VbgZv6nYpC0VD8kmO9JW3KJewE695V4+Ob3Cg6G+TNbi44x8NQgCqB7zNlYuxgdtaVrs+ZR9VuHaQBLHIyA2z3d2vf2ma6z1TBpUh8msN8b2ZnytrTrkhOwlnO4StGI8ymPVq2c/Yrsu/hTqDs6nmkEJQ1Z9tncquFq/8kjSVhE9TNHsfIoI7Qy8+OZgHtzXcvYz7/nQha78lDsb/udyN0ZJT5Ej6Jj3Kp0TyJZUFHAIIO585xesZSEC07X3EucXrFaW1lbWZD+4HjUz56bGnX8iZN3Ui8RgY4Zd6mfwer1307VhsEiXHSs5bfSW3+ZlvZ9tU9/SbY23GowmKAORJ9692xAZeeKuPMj5BNq9A+IrYQvnUqes9frxq+bB3+yqeZmb+vZd5J2SD4HjUtx1ZZfSrPbjh9tne9YUszooHuTqVt+VQG19xT/BmQtzsy6wB3Yj2UDidFWRYRtnWXf1slP9qNULAeUII/E6r7bmUeL0zLYDWa1Y/wBf/eNJ0bP3tOqEn8r/APzI/wBe/wCpf2JV4rekeRJVnTalL+l+oscei6q1fyRuBbqedi2gZWLo+58S/Vhliz7c8cmurHoizhR3K3iJ9I+oOn3stVzmpzxojj/WOZ69jlkPcpmmWsfOVTvUyZDkE9u9jftLTp9217d8yutcqxGtj8ydDHexxOj8bP8ATHvx99OdQIZCN8yvxj9u0Ew9hLck7i9n4m2VQcybx9sgSotbRMK5cjUC9RPmS6iCzmDYw5pPxIGo/EikATObhmqPxI/aPxEFnPDmenQJag6JMGQWS4isNMOZ3vMGDzO7i8T6n3EyXfAycPEuiB5x3BWQEjd+0xeJ9U3X31WxmHy8ixbzpj5ms+oLfQw3MXkHuuJlGz0lj7E/WW+zGeGXfv8AeYACTAAlPas8Vt0e2y7Lr724U7mnVy7DtmR6RaEyF/J1Nbj6QBjI2pSNF0KgtenG+3RMZ+sM9sLptlnlK12VB/cZ36YZRjm1h+4zPf8AEHKNuNfWrcBdalF5Vs9Ma/VOsdXvFH6h1Vzpa6z2iaOj6awOnVq+aq5GRrZDcgTO/RTf/n2L3ePuD/vNT1nJazJclt8mRs59LMaXyWrX0UVJWvsFGhEzT3toiE2GPvCb7SJC5cWzHr1PTkcbMbr6TVrQUmcptIIVR3NHqLrR+++qsfkiUXdVk1Qsejprf2x/pBW9Ho7TvuU/g6lt+r44yaLPwGEXtzEI066PzHjs8vtGyYs7k1ZXT2NlVpKD4jXSvqe7GYd1BsH4bUPl2I1F5JBArYj/AEmXwcZsm2uokgEerXmPPThZ2rNe/Oeo3tf1m7DQwD/90GJ53WczLBYD7Q+B5gcH6dwxV/03UkfuViDILitiWGl27k/wk+dSj8Ov9L/y7P2exOjoVF2YzO7c9u/+8eTp+OdKtSqo+BE8jPcaOtb5kB1GzW+7sEruVn0LJ+11V02oDa1J/pPW4X/yxKvG6pSTpntY/wDpEfo6hjWkrXbYCPIYeJHzyV2Y/pOqoKwUsFXfx4jOTT+luKC+u4AA91Z2JGu1LOCQQfBEnZT3Ke32kfLogP6gq3mEyRVmYzVXKGBH9xKvNf7Z2TF26n9mo+Cx4E06bYo2fbPdQZMW2xWY+hiu/wC8+idMrXI6TimwkM9Kn/afMfqA/d6kKweXtn1VwKMOipRr7dar/tNGSuKXOR6LWR13qcx2XXxHupouVUD4cSvGM1adxJ3NXxr2s28x31651I91R9xM91jMsxwTs8SkH1EwOiTOjKyt2RUfeRK1/MxS/Uf5k1+ot/4oeSLXlU+ROfbQ+4mTH1AP80InX1/zR9hxqDUvyJA0rM+OvJ/mjGN1dbm0Gh2Gt9SQnAZ0S5B0CS0ZwSYgaOp2dM5AnhOzwnIHElgsg6QwqxfMOqzFQyn1DZrumVc7cy/+obNsRM8T6pk21Ziksk04k9ZKVsExXK2KR5B3NliO1tSHY5AmJq/dN30Ctf0NbHR2BI2dOfbUYD/YwkXfhdzJ/VTK1d4LcsJo0tDV6HsJlOuVNdmsn4lSzqo6FWMfPxX3s945/vLTJu3fYGJ7gxlfYv2MmpiNCtgeJddfxVHUfu1j0XKrjX5EMvaeJak75nsl+3WvMnWvauoGw9z6lFkaIPgg2kByQPxFutK1Nq9n7Wj2IFVNydwFi6I7v5ke4wZYZVV4VzPfWnag55KrqWOS6qdKwIkPt1r4UCLZH7j7Q7O+lV15O59yL024705AUf3PMH9MVNZabPbfERzmZmroHLE71NV9PYJSpQOP4i2Zf8tHxsP+l/iVbq7ZX9bxzVWLdeDzv2E0GHjkJxPZuD9+hkZdgjUwzLldHPCWMi3Y9SseRIHsKMoU7IjKYr0WvjWD1D9pI9p1KSreJZMuXrJnr7FHRVk13k/atCD3A8y9+nR9uu+65T3OO0Ax7H7lH7P9pJ1+Box5bYrw+PSldhTK2Dpd+Jdo4asMDKV6+5t65lhgpYatA/6zPbF/4+K/q6sVZgOBKBEe/ICjkTX5OObanSwcEa3Kd6MfBqa2gesDkmatGUrNuwvWT6gwb6kxlHgW7P8ArPrmSyMmte0+YY/Tvu5NeaSS4fx+J9GW0WgEc7WXbKqkL2jXKkQLt6TD5C+k6iNjEDU0fFy5ko349jOfUwBRjqYewetv5m5+oeUMxVw1Y38zo5X0ySAToE8fM9K+peLjSIY+xk2kPeK0eKQY/Msui2kXhSfeVyiHw2+3kKdx45eysfTtSSmc9p1RN6lNZ2eE9APTw5np0QD2p7U7PQJ7xE+oNqox0ys6q+qjFTYvrr7cyjJ9UtesvuwynJ5mPZ9rsYPUZJ5Cg8QlkqTRq/dN90b09LpUcencwVH7pr8PLP6CsKdaXUV+jn2uf1AoqZ24Ht+Yu6plqMsDTa0RKpmuyHCszdollUy01BdnkciUVbIqepJwysPMewstc/pldZYffxh2ke5XzFsxFd9g7EQsxbkt+9huVsH+8hb1bjOe1qSe3WoJa/VsiKJ1S6gazsCwH3av1f8AaHr630p/3vfX/NLSmyr8asaUB1HaaF95V09b6Mv/AOvaf/2W/wDEP/8AiXpif9NLrPj0Ef8AeU5SrpYcuoRVPEpOpvVjVtbawGvA+Z7P+ob7gVx8Qrvxs7lG+HndRyBZluQg/wAMswx/1DP2b+n6Xy8s5T+CfTPpPQ8dUrA1Mn0fGCdgCgAccTd9BRCVDNKt+X6a/jYc9rSmjSbAk2QhTxzLnGxqjWNaPE9di1qntuY7W30wf1RjMMX9ZUhFlXJ48j3lb07KxuoUh6nX7gHqT33Nxn46sjIQCDMD1f6Pt/UtldHyXxrCdlQSAZOXyjNnjy+l1igD0sOZO2lDyOJlUt+qen+i5a7wPcrzHKeu9XIAfpNbn8WAQuNRkWbVlSdDcYxyQPAEq/8AmnVnHHRR/wDeWcOX11hpMCirfuzgyNwNc5FoNfrA18zLdStXJv8A0+LyAfUfaOvg9QzR/wDHZvavulQ1Opi1Yq9lK6A9z5Mswy8VeWvyDwcbsq1rWvEdTJNYA5g+8hdEcRe7izuBOjNGN82XLHxWJyu4+d78wFx2fxEluH3FXfkyxsr0o/ibPj67L1i+Rl+me64NodzGZI1Y38zb9ZTaGYvMGrmm5kKNwZETtnmRBiTiTeOIMeYTyJHUQSTzJKdOD+ZATrHUCfVZNYPYk08zoM4q+J4zgInSYzcnR5nJ4QJ6SkZ0GBOk8Sl62+qzLiw6Ez/XbNIZHL6OMb1Nt2N/MrCeY7nNuxog37pjz+12JnHPEJbBY54hHldWRyo6MtenZBVwhPpJlUsZxnKsCDoiINgwSmj7nGyOBF1uLKWJ1E6snvoGzsgcySsGXXiVZeluHtJm3vUJSTqA/aIfGJMz5XjVhOrDGUkcw/2Q3mRo0AIUsO7W5ly2Vrx14hHGU+w/0kGwUbyuzHqwG5j+FiGw/t3Iflq2apfpSV9NAGwn+04MQ/eWtVmrsxFrqLEa4lfhNjnP7SQCfG5H8yX4S9iY+Bj/AHL3CgfMY6P1bFutCUWju+PBiX1xi3Nilqgda4nz7p5z0zQ9ZcOjRZY3Z7OZzC8fo3pWQxxlDN7Q+VeqVl7HVVHkkzKfS3UnyMCs2cWBR3fzEPrrH6n1Kn7ONY6VBdnt9z+Zm8Lau813f9QdHN4pXMR7CdaXxHqkVwHUjRnyXoXQOq5WaDbQyBG1yJ9V6bVZj4iUudso0ZGy4/tP7j2ThKQWCBpTZeAhff2wp/Amk7wOGgsigWL3CLzo8YzlWMEP7jDJQG8xq/H7G3qCQkH4iudLxhe2oCVWaum3uXlo7llNnJrZ88yWN6jYTYHt4MrnylOQ9QcFl8iW6p3IefaZeml7OvZNY86/8Tf8b3eMXyeYzq26RS+RngnfYvJmgyE0pMF0fF/T4yq3LHyY1lDSTu69Xji4WzPyyZrq6+gzE9QXWQ03fVRtDxMT1NdXmOxCKu0SAhb4JfMimmvicI1OpOvEERxOsB2yJ8yX+GIPqIhkggOYVOJ0mdLU9zPbnYHx4fmcM7PGAeE9OAie3BFC86UzL9ft4bmaPLbSmZHr9n7pDP6OMzkttiYodFoXIbkwCNtpjy+1+JqjxJsZynWp55E3QeIStuYESVfmLhrCi4odyxxWFlZIaUwPEdwHIrYDzuVbPpdq+1n2nt1C4gIbnmQXfYOOdQ+Lvu5EzZz014fawD6AMEHLWQnlPE9j1hrBxMuTVh7q26fSHVRrc0nT8ZUr34lf0mgLWGMbzswU0lK99xExZ22tuJfq+Wqk1qwOvMzGZUz2fcqYqwOwRLFkssYto8zgoJOu0iPCT9i0jbnZjUfavbuGteJzAx0Z9isbMtasBXYFhLbBw6618AtLvKSelN913otCoQN6mgrG69JogjR2JVisIR28H3MtMUjs4YeJmyvtbAWQ1se3QP4E9WG33MxJjRXu+DBdhHMqtqyWOE78+YWiwHStIfbJEH6kbYESX2Nl44YdwlVkUlW44lzW+x6ovl1bGwIgpWLAGVmaD3H4ltahDkGV+Yvrk8IjfZBH7T+Ili4ajrn6hN6dPVv5jtqknQEbxKSp7mHq8Ttfxuryy65P8jsuOPDlK6EjlD0QicCQyOVM79npwus/1NfQZiOrjVx/mbnqI9JmJ62NW/3mepxT3+NwKnmHuHEX8GVrBV8zpkF8wp5EQCPmSHiQbgySmBvqamFWBWFBnRZk54GR7hPQPqRMiTue5njAO8TxM5OHxBErmtpDMb119luZreovqszEdbfbGVbL6Sk9qPJPmArPqhMg+YGn98yVfD9R9M855nE4WRbkyKSQMnX5gdwlR5gXTBOo10yztyQD4MQdobCP9VSPmRynU8bytSQB/ELjcNqADdy7hcdwp2R4mPNt1rA+BqN9Nq7rRscRVG79aEtenKFGzMWyt2qLmphXWAIKxe5u5hvc5hj7zEgnUb7F8bmWtHSbdqDt15ge9SxXWtRvO1j0G1taA3/Mq68quzubuVPyTJRC5HqmLHa8AeTH8Vwyd3bpjxMwOs4VBKfeDMD4XmN4nU7rQDVTadeB2wqUxtaK2pwvB9p7pqXp3LskE72YHE6tYyAZHT7969l8ydmflkdmN0+8D5IEpyW44Vb12ldK3kwjMu/UdzPr1HKqsJycaxEA91jNPWunWLs39jD2ZSJA/CxcKwI88SLaPAlcvU8K0+jITf8AMcrcMoapwwMVhS8e2VY8wgfuXXvBWaYek8zlY1xvmRtS6Vyk9exKvLUB/aXOSCRscyq6gDvxLMUar7E9QP5jKWIPJESygwrZgd6G+JSPnXA65nf/AIvLmNcP+S95RrBch8ETlpDJxKHCyXYje5cUMWrna76cnir6iODMX11fWTNv1BeDMb15eWmfJOKCzwYsfMYsB1Fm8yqrYmIUeIEGFQ8QNCyRWdukFMQfVl8wkgsmDOkzOzw4M8DPGBJbnNyO5zcCS3IueJ7chYeIxFb1Vv6ZmJ6u23aa/q76Rpi+pNuwyjZ9J4qnIPmQo/dJZB5nsYczMtlOD9kg/mTPCiDY8xcS6iSZKoyDETtPmBDOeYzg/uH8xOziO9O5Ii4crS0+qtfHiGrTnkxfF5QAxqsANM27Hnts1Xp/H8D5lpVYEr4J8SsxyFXWtw4tDsFG5zNs66OF40PRe62jZbRJncvI+1kFe8fkn2EH04tXjen3EUz8dsg9z+kfMpxx7UsqpPqL6gtu/wDhcLbez2e39pT1Yl+UQL7WfftLsdMRXIGtbllgdPCjUttxiMmVA6H0mqlV7ah/M1uKFxqwqAL7xXBpSrUbY1k9vB38TNll36acbyCHLvZgqkGP0WWEqWA2Ihg45++XKnsHJ5j6WLvQ8SF6n2U4LWZDo8RDPxKb0ItrD7GjsRytlBhdBgfEh0dYXrHQcZ62GNX9p/YiB+nuoXYjpRl2EPW2lB/xfM2luN3E8cTP9X6Qv6uvIRQSDzxLcLL9qtnftoWq22624PME6FW2YfCH9Cs/4gum/MJk1+ngSnZJFmu2krRxxzKvqKHXPEt3H4ld1AAqdRYJZKHKI7CD7yqfHTuB1LHPYKe2Is09L/H4eOvrz3ztnlsM49SqAdSwxyPESqPoEZoPqnUjn0t1D3mR68ODNfne8yfXRw0qySjMWeDE3PqjdnvEbv3GVVOUVYRDAVtCKYuJddt4glPMLbzAA8wR6+uLOkSKniS3Oiqe3PbM9OHcCeM8JHc7Andwdp9JkiYG5vSYUKPrdnB5mPzW25M0/XLNBpksp9sZn2J4kbyO6GxYpc3r1GcY8SmrDLmBbzCMYFjzEbjGEpgWMLRChOw7Me6YORK5zzLLpZ8QxK1ocY6WO1kFdyrViqRnp2RXaxpZvUOdSrfh2NGjL3xb18INnjXmExyO7hhFq1OtckRipOzntJnMzxdOZND00WXWV1rsjfP8S36p0y2wpXQjdgHLe0F9KY1f6ilWDCwjbKW32ia/PrNGJZYq92hwD4ldw9I/k9vm2VjtRea9ciM476XW9RnqAtYmy9k7vhVErQ7s2lWZco2Y30asvcDSn+8n097L8kIOfk/Eh9tlpJZfUPaXHTaUxsZO1N228ncjMeJXKLPEpAHaCWGtQhpUftGzO09y0KzkAmHxVH7/ABIZniEqfOwYSpT28w5VTuCP49pXw3O1v5kLKUt9NiwwYhdkbjdFSXVgkaEt1Y21XtykgGNjfaqAJ2oHHEFlDSkjxLr9Oi4fav8AhGxKHNtPYe4DYMe/HiOnK0pYRuIZg3+BGnbfMrOrZC1YzkH+o3Ai+Pr885Et+yYYWs51GwPe/b4B0IkTyIe1STBFJ6zVh4zkeZ2ZeV6dxuaxGquGg8JP6QhW4cTRIqoOb7zLdbXatNVm+JmesDhpTmlGQuGiREbxyZY5H/UaIZA5lVWSBoYRTzBp5kx5gYrcrFzwYc8rFz5iofWxJBpAeJ7ep0WdPc4xkO6cJiCQM9uRB4npKFUiYtktpDDMeInmNpDFTjM9es/dMtkNvcv+uvsmZy88GZc04Uc7eOY37RERzZLDHHAldWQRvHEC0M/AMAZGC1EmGo/bAEw9P7JIo83mWvSxwJU79UtunnSbhPsVYZly1UMxPAEzKdVso6mmQp3puR+I11/LAX7QP8yjxE+7eN+SZPLHsGGXK+t4F6ZOOl9a7BG49S/bpgPHzMd9K5z0N+ku4rf9p34M11dbNoE8Ccjfjcb7dbVlM8fTc/QqtbkgsBtyDv8AE1PXWL4jU9xUH3HxMZ9D5AoyguipJOvxxNfnWfcU92iCJV9z0jfVZHLxgTpNnfjc9i4CIFD+pt70JbOg5IUHRh6sZfvd41uQ8Ismy8Vd2JYuVWOz+k/PcBxr3jtlPZcbO3SompeY9K24/wBvyFPiRtxGPo1wx5kMsE8dqvprNwVSNajVdbd5RBvQ5jeNisGVAB52Y2tDr3duhvzKrqW47lNb3FyoOjPVLZ3qGHB4jiY39ZnI4jldFfeAOSBCaTu8rTiMRoDuPxLHDxSj/bI/mOYdKoy+NmECBcgFZbjhIz57bkFbjdqkE6XUx2b6riCQDvU2HWr1rw3LOFM+fXZq2Ozt5Mo3zt5F+i8nXb7AnB41Mx1bLF+Se0+leBHus5+q2RG9TcH8CZ9zOr/G/G5POuf8/f2+ESZhOFxrxBEmcnamLk3Je9KT7lfEJl1djAmF+l076zHOtUhat6lsx9DqiytGvczvVxtWmhyeUEoOqftMzZxPGsdl8WtEMgyw6hxaZXZHgyirIEphBAqeZMGBjf4YtZw0ZU8Ra8cxB9b3OEyO+JEtOizJ7EjI7ntx8HU9z25Dc8TxAJMeJXdQbSGOseJV9TfSGRypsp1l9uRuUWQeDLXqz7sP8ynyT6ZlyvtZAKuXljVwJW4/7pYodLIZJSJufTF3PMJYeIBvMik8TzGKz6IrvmMofRGUjg/cI+lorq37ARAHR3BZd+q+0HzJQr9ls61rsjQ2STLLAwVx9PZ6rNePYRXoeP8Afyjcw2tfP95Y5Lhe7zuWyekP2hk32LYrBtdp2NT6D9P5v6nHVbD61Ub37z5Xk5B7tb95selXtSKrAdcDc5/zMeuh8TLj6P0nKai/7veNAcCanpnV1yK/tsPV+Z89wr++sEN5jtNt9VquthAE5Uy8a35a5lOvohZNeRzGsRQSFJHMy/SepJkIK3OnHz7zQ4T67d+R7y6ZdZrOejwZqclVG+0yzpK2DevUIACp61Y/uEaxwDWSBFSerrAc2aHPvDDlSNbi5JLqreAfaNA96hVXW4rD6UJI9KrC49ZVSW5JjDVfbHaF5naKj39x8RcO0epNKG0dweRcE2x1+fxCvaQNBSf4Ey31P1D7df2a29THbfiRyy8YMcfKqr6x6sL8kYlNnCnb6P8AtM+dLWX2d/zO2VA2F/cnZO4HJJIPsJn8vKt0x8cVRmOWtO/MWbzJ5O+/u9twVh0qsQe1vB9p6f4mPNcef+T3zrhkZ3fM4ZtjK1H0g3HbLbr4Bx+Jm/pi7sv1L7qlwag8+0tn0Gbt/YZR9SG1Mu3PoP8AMpeoftMxbVmLHdUGrpWZHgy16sP6kqMj9pmerYAvniT3AqeYXfAgcGrMDkSdZkLzEH1TuPzOSO5zc6XGepbndyG57cCT3OE8SO5wmIPOeJT9Wb0GWtjemUPWH9JkckmW6k27DKrJPBljmNtzKzIMy37WRHG/dLEftlfi/uj6niLJOOOeIu55h7TxFWPMUCS/uEZX9kWr5YQ5/bxCl0Ox9RK9u4w9wJPuZddP6A1QryM49rsO5KtcgfJlmGNqOVF6PiGjpygjTv6jKrq932rWrH7pqio7ePiZTMxzb1K5jv8AdxJZ3xGGPSmLjta/c+5qcNwK1G/ErMekII9jzBuy8m3Vj4tP0nIAAUzQYzd6j4mQ6e3AM03S7V0AeZzduLoa8urXHV67VdW0RL3pfV3rtFdo2vsZRpogSFljI3p8zPM7is2a5k+nYWWl1YC65HzLXHs7KxvmfN+idQuq0C51+Zr16nWcdT3e0u85WPwsvF/iUh7PuN/aWdVVa8jW/aY3E6v28NYQBC5n1Maad1IGY8DmK7MYcwyrWWpo8jRgHyaqQe914/M+f5vXM/M83sq/CnUD+pvYeu9vGtbld3yfSyaL+1/9R/UhcHGwTr2dx/2EzD32XOS7Mx+SZ1zsa4nVQfEzZ7blWrDXJAHX43F8pP6TE8cSwNe/aV3X3OJ062z4U638w13uUTznMVJYgZSfPxB0FU2ltReluGHuPyIXCDPhox5JG54KQda4nrvjTmEee3e7S2djWYZSwn7mNZzVbrW/wfgwAYEcETS9EWi77vTcxQ2PkDXP+E/I/MyOdjXdK6rkdNuJ7qm9J+V9pplZrituk2iu/ZaXGbkbqI37TJpbpu4KvdrXd76lhZm2W1gFVBBHI+JKZo+PDO9oZU9QHBj63IV/dqI5vqB95Rs9pYsh1geomUt/IMvutKeR7yhuBCmZrFsKjzCA8QJ/dCKeIGmp5kbzxOA8yNx9MIH1We3I7ntzo9Zndz25zc5uIJSJM5uRLQDlx9MznWX9Jl7kN6ZmetPw0hmlGfyG25lfkHcbvbkxGwktM9WQXFHvHh4iuKOIydn2kal1C48RVjzG2Rm4AJPwIxi9IyrvUyfbX5biEhdV9IJYSzpw7Hr72HYnuxljjYWNiDuK/cce7eI70nGPV80/cPZiUjutb218f3luOrv2VqPQOl4+PR/zXJq7zvWOjDhj/mI+BDWO915d2LMTsmMdSyvv27UBakHbWg8KoilfLTZjhMYh0wq7BGpnb6wMyz/6jNVQBoE7lBn09ufcdeW2Jzvl1q0QuBvUNSDvxqdrT5EMqE+JzrWqRYYHKDQl50ve9b1KXAUgAS/6bXsiZd3016ouaj218wVrbYa4kirKnniBrYG4Dcw3rWt8AaQc7lgGbt13cRLGKqoPjiHW5SdSq5U5hEyzE67jIktsAkmd0DogyBftOpHyp+En0dxwpXZk2A9xF6ru0aAEMjNYOAf9JG0/F0MN61uTr7mbQEnXj+7nX8QjDtXS8Rdp8iaKFHkbmd+vbQOksgPqdlUa/mXFmSqnR/1mJ+rOofrOsVYKH01/1G//AL/eaPjY3LOKd15jVnhprFRR47RONXptj3hMHnFG/iFCA/xPXaZzF57P3QR3IyuCRqc/4lYhyF6b9Q0rtWT7d5HzvjcbCAjRG9yy6PdivVb0fqXqwsrjn/A3sZdLyoSPn6r3aIPEcprJTkw/1B0XL+nOqnFy/VQ/NN3s4/8AMlUAawQYs/XuCQhkqV43xI47b4J3D5a7HIitJKtsRQWI5/TsbKX+ouj/AJl8ymyfpW2wE4+TWR7CzYP+01HDL+YJW7G5Bh4SosPkfSvVqyStVdn/ANDxHJ6Tn4w3dh3IPkrPpn3BrY951LO79w2PzD8WI6+SlCDrWv5kLQe2fVsvp/Tc0aycRG+GX0kf3Eos/wCjK7NnByu3fhbB/wC8ruuw+rjc9ObnCZqUu7nCZzc8YBwkzhnfEixi6ZbLbSnmZXrNnJ5mkzT6TMz1Kp7HIVST8CQySkUNhJJgPtsWmixOhZNo7rAKl+T5ljR0PGq0zguf/VKpjal1nMHFtsICISZb43SiTu9u0fAlsKq6RpEA/tBsT3Syav8AR5BVU0Uf9Grn5PMk9jH9xnXfXPA/tFMm8AEyckn1CQynZl+3Xs2PwoE0tuOvSukU9OT/AKrj7l599+wi/wBJdNC1P17OTVVR/oIf8bTmZfZkXvdae5nOyZZjiCdpPOpyskfzJW6PE5SNuBLb6iM+1ljj+mCeZWdQRWymYb5lzQgKARDqlYTLVN8su/8Aecn5V9dbNE9klq9PAhK6T5IjuNTtfEOlGudTm+bd4OYlPAOpd9NTt5IldjL6wNS6xu1UGx4mTbl1p1Y8SyLCF8TnT6wz9xG4O5ha/aglp02g6A7Zkt40w1Wno8QPcVs5HEuMfFP2+Vi2XiDu2BzKb7TiKaasMOII9pbR5EZShvt6I1FLa2RuOREZmoIoHEZTJC8cCVyXcBed/wAQ1WFn2nuSrtX5JEQOnL14MDZmbOp0dIcpu7J03wsJVjUY41yxHu3MfiXYRynYUPYeABvZnz/ovdl9Uycxj3Bn0D+JqP8AiB1hacD9JjkCywa4+JSfSVGsJBr+Z1fgae5dYPl5+uNXgL/QA1Dfb5hMavtpGxC9nPiejwcbILt0sG6Kw0fMOyHU4tZ8yVRi8xKaPqj6du6Hna/U1L3Y9h8jU+dYovxb7um5Y1djsV595s+mXNhdQoyayQVYE/x7xD/i9i14n1n0/NpAWvNrXu17nj/zFh77ibPWgMDs7iLV6biWV3aNjiJWtzxI/QeRiBoidO2B8QQJY+YdU8cRjkDUenmFQfEmqDY2IVqG8iPpcDUeP+0PWD52IMKB5MKvHzqHaOKbc9vcHsz3dLVAm5zch3ThaATJkTId/M8X1BKB2Vd50Zxaaa/CjckXJ8CQPyYeMN1iNcDUERs87hUOzOlNnkxmUuqYxd6yvJGzLYVrr3MSzgqgxdCqyLdA74jH0v0PI+oOqrSB241fqucjwIHHxbM3MTHpRmextKB7mfV8zp1f0n9K19No1+tyV7r3HkSVnjB9sh9TZlb2Jg4Y7MTGHYgHufmUT7PtH8mkjcSsQjgyzCcRtLOfaFw03YIK0HfiWnRsVrl7h7fiPZ/5E+zlIHGzKnrV6f8AO8apfPZo/wCsu3qahSzDWphrss3dd/Ub8Px/E5u/DuNatOXMm1w6B2715hrKQvjiRx7h2jWvENa69u9zhZ9662M6URglkZOQWHauxFmXbeIWhSr/ADKsl2PpZYVel7vJmh6WhA2RsmVPTaC+i25pcOkBQB5mPZV+MMpYFXWvEDbcpblRGfsMRrW4hdS6WerepT7Tkg7W1hP2TlRpsB9I3F7l3XweYtju62aMPY4t6aqtghFJEe+4nYPErsY7HB1DM+hz7SXkhY5kWqDKXrHUqsTHsusICgf6xrKt2x1PnP171I25H6WskhfIHzJ68blkjl6nVD1TqF3UurNbsnZ0qj2E230djs2Ivdwd8gzIdIw7KMqqxqmDOeCRN90JWrvUnw3kT0/xcMcMOOL8jO5ZdaWurtrA0J018a1GcfsYSbBN+BNjIr2rO9anQuh4McKrrXtAuAPB4kpQUt9AJ5gf+KzDIp+l3PLc/wCg1/4k8t+Do7i31u33s7pVCEN+lxO48+C3/wDkePrLo6o8gAL4iRX1eDGbSx4OvzO41QPnZioRorGvEZpq5A8f2h66gPaGrT1eJHplrK1UbJEiu2XzoQmYAo8bMhSpKf8AtAI6T3OzJLzwJ5qyG/Mmike0CZnc4WgifzBvZr3l6jgzWSJsixckzoaAkMBjue2W94MMdcTq/k8xpSJjfzCDXbyINfkwi6I1uI3lA3CqOP2iRVAAOdwnYQPMKEGZVU8eJQ9SyTkZH2qhpR5Ma6xmGvdSPzKzpzC7JFPl7GAH95LVj2+xX1H/AIL/AE8jPd9Q5qD9PigivuHlvmd+o8yzqPU7slz6WY9o+BNh1atOgfQ/T+iUemy2sNbr50CZhrlJY7kLl559CoyadknUQvo86Et8ga35lde2t7mjFFTZSabQmt+k8YfpQdbMyeWxa4IAe5joAT6F9NYLUYdYs49OzFtvIIQ+s0TE6HZaBp29I/kz5JbQ62js3vc+yddSrrFoxeTj18kj3P4mI6f0Zh9RHFtXvrrO968ym+FwvftZh2ZRPDdyo5PiPVpa2tgmXGP0VAwJEtcbp9QIHZ4nm9/jjft3dUuU+lLgYLP5Uyxx+lE3AkaEvKMVFHAEbooBbxMeW2fUaJjSmNi/aKgCW+NUABOGoaGtcQ1PpmXK9WQzWp44gMzFNnKxpDtdmS3x5laSnvxCF5HIii439XxL21O/giB/TDfiOQulK8YqNgyN1bNwBLAIAPBEDZaKt6XcfC6z/XAMLBsusbRA4E+aWVtfe1xXZJ3Nv9c5j3MtBHnwBM62HTj4RtYl7SP2idH4Orzy6zfK2eOPFeuRlGyugUNpOQwHH+s1PR8h/tA2VsrD595Q9Nzms+2KsdQK29QHJf8An4l3dlKl1SqeXHAI1PQ44SONnl1et1mrCxHvyktCJ5KJ3RF/rnofaGV8k7/+TGsKhmxrltUMjKdhvifPuoYf2bXRkKDu4441J94hxs3/AOIP04n/AFLMpfn+iZPE+rvp3qThMPqtIc+EtPY2/wCDPlufiqZVWdN7m3Uun9u3zJTOFY+25OQUuAfxuKZLtbkWXO/qf/Ye0pfpLHz6+kVpnWs4HKBvIEuCu/BhllL9FPRc1gvsxvFr0w9M5VXs7I3HqF412mQ6OPKAOda/tIuzAk8RjWjoQV6aHIAkTV+UxJ5G57G3vftO3/8ApEJhDflTJ/oOuh89u/zPIpbyIzYPTxxBVg74EV9nOMG9kEW2Yv8AcLNCAmaJGcSEQGDTmEUnwJLhic6nAdnUi7dq+ZHHYvZqIz1FexGVqXfKztNelBAhgePErt9iIfaQc+Ip1bIrxqNKduw8/EZyLlRN+TMz1O/71pLb/AhKfPRHIZncsx3uBSxqLkuq4dGDA/kQjn351Ane5PpR9S6P9a1fUldNHUrlqzqaxWu+BYPnfzHsisgHf+s+M2Ky+uv0t7EeZZYH1X9QYCCsXVX1D/Dcpb/3ik4la+gZajwBuVGUdb0N/OhKQ/X2Sy6u6RSzfKsQJX531p1WxSuHi4mID5YIS3+pMsmfEONBh4mSbmzRT6k/6KsPLex18TaYzZj9PrTJdfuMP6nYND+J8v8ApD6jy6+rKnULWtW067m8jmfWVC2YwcHQPiUZ7LanjiUuIpAVdL8QWElK32WDRtfyYdcF8xnRWHcilhv31Kuxe2wEWFfnUq/SyXi+rA3G6SDKvHuXtG22THsWw904PzdXjl5Oz8XZ5Y8WFZG9ajlC8bBiSjYjOM/ZwxnNybIa7T+JNQfbUgbFI4nFcj3ldSkFJZfedDt57oDvO97ne7Y1Inwf7mhz5nha2+dQYOx5kCO07jlLgl9rFe0cSs6ll14OM19zgccD3MbtuVFJafOvq/q/6zLamtvQh0JZjjcqLZjOgZHUFz8626w+P2jfiNYQHds6Ya8GZvFp78kHXIPmaTGXsCk+J6X4Wqa8XE+Tt88hMfpuOmQbaVNZJ2QDqds6Wl2Sj7s9Ld2w3J/EfrqLqGQnj2EjlZgpYYtI7riPUf8AIP8AzN8vGP7PAlKlrFhPH+n4MjbTVdV2X46Wr+RzB4uyPUdmG7gvudSFpzqnyeidKY7bDP8ArAU9Mwqm3RhVKfY9vP8ArLfIuT5JkEb4BkelwNFcKPRx+YRK3POhqe5I594RGIHpIj6Ha1KjxqMoToeYDuJHIhFI1ow6BG8b2SIte6sNQw4XhuPiBetXPMASZeeDGscFfJ3BWoiniEosI1sSVIe3u7dga3B1t2nR3Du3cuynEX8PvfB9ovRv/9k=	fabrizio.papale@gmail.com	t	b1000001-0000-0000-0000-000000000003
\.


--
-- Data for Name: product_categories; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.product_categories (id, clinic_id, name) FROM stdin;
a4000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	Materiali Compositi
a4000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	Anestesia
a4000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	Igiene Professionale
a4000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	Chirurgia
a4000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	Radiologia
a4000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	Monouso e DPI
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.products (id, clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost, is_active, created_at, updated_at) FROM stdin;
433ba4fc-22c7-429e-924a-f11d831ccacc	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000001	a3000001-0000-0000-0000-000000000001	Filtek Supreme A2 4g	Composito universale 3M	COMP-A2-4G	siringa	5.00	0.00	38.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
eecf583c-8988-4d54-8544-5a837ce959ec	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000001	a3000001-0000-0000-0000-000000000001	Filtek Supreme A3 4g	Composito universale 3M	COMP-A3-4G	siringa	5.00	0.00	38.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
d53e016e-3f1c-4115-852e-356fc55cade4	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000001	a3000001-0000-0000-0000-000000000001	Single Bond Universal 5ml	Adesivo universale 3M	BOND-SBU	flacone	3.00	0.00	52.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
6f6e77b3-b295-46e9-8bb1-eacbe901039f	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000001	a3000001-0000-0000-0000-000000000001	Gel mordenzante 37% 5ml	Acido ortofosforico 37%	ETCH-GEL	siringa	10.00	0.00	8.50	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
be60aa81-2a24-453d-959a-4d53ff5446ee	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000002	a3000001-0000-0000-0000-000000000001	Articaina 4% 1:100.000 bx50	Carpule anestesia	ANEST-ART-100	confezione	3.00	0.00	45.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f7b81781-dd9a-4079-a361-2d03dfe911b2	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000002	a3000001-0000-0000-0000-000000000001	Articaina 4% 1:200.000 bx50	Vasocostrittore ridotto	ANEST-ART-200	confezione	2.00	0.00	45.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c38fe0d9-6d94-4c4e-a7dd-a1171c036f74	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000002	a3000001-0000-0000-0000-000000000001	Aghi 30G corti bx100	Aghi siringa carpule	AGO-SHORT	confezione	5.00	0.00	12.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
ea417970-1733-49a5-9063-8faa68cef5b0	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000002	a3000001-0000-0000-0000-000000000001	Aghi 27G lunghi bx100	Aghi blocco mandibolare	AGO-LONG	confezione	3.00	0.00	12.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
225939a6-0106-4bed-b328-8a86bf68e3f1	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000003	a3000001-0000-0000-0000-000000000001	Pasta lucidante grossolana 200g	Pasta profilassi grossa	PAS-IGIENE-C	vaso	5.00	0.00	18.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c746805b-4137-49a9-9993-c5c12a53f235	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000003	a3000001-0000-0000-0000-000000000001	Pasta lucidante fine 200g	Pasta profilassi fine	PAS-IGIENE-F	vaso	5.00	0.00	18.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
85a2a119-eb80-401c-ae59-e4e044c76a9d	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000003	a3000001-0000-0000-0000-000000000001	Gel fluoruro 1,23% 200g	Fluoruro professionale	FLUORO-GEL	vaso	3.00	0.00	22.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c92bd178-e31a-4e79-9264-b331cc11b455	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000003	a3000001-0000-0000-0000-000000000001	Copette profilassi bx144	Copette monouso	COPETTE-PL	confezione	4.00	0.00	14.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
abaa0f58-9f72-4253-b8ec-c1939f6d38b0	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000004	a3000001-0000-0000-0000-000000000001	Filo sutura 4/0 VICRYL bx36	Sutura riassorbibile	SUTURA-4-0	confezione	3.00	0.00	48.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
c63c0b58-9965-4fd3-a91e-8607102c4c72	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000004	a3000001-0000-0000-0000-000000000001	Filo sutura 3/0 VICRYL bx36	Calibro maggiore	SUTURA-3-0	confezione	2.00	0.00	48.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
82b1cb99-469f-4e76-81ed-a56fd64fcd66	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000004	a3000001-0000-0000-0000-000000000002	Impianto Straumann BLT 3.8x11	Tissue level TL	IMP-3811	pezzo	2.00	0.00	320.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
12f8dfb2-bb60-472e-9e0e-a97252cfed44	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000004	a3000001-0000-0000-0000-000000000002	Impianto Straumann BLT 4.1x11	Tissue level TL	IMP-4111	pezzo	2.00	0.00	320.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
2fff0952-bcf5-42ef-afa0-cb2bdbeef895	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000005	a3000001-0000-0000-0000-000000000001	Pellicole endorali E-speed bx150	Pellicole radiografiche	PELLICOLA-E0	confezione	2.00	0.00	85.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1c1628fb-d757-41a4-83cd-9f6ab430d19a	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000005	a3000001-0000-0000-0000-000000000001	Guanti piombo 0.5mm taglia M	Protezione radiazioni	GUANTI-RX	paio	2.00	0.00	95.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
29a31362-235a-4951-b0a0-0e388a10dfe0	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000006	a3000001-0000-0000-0000-000000000001	Guanti nitrile M bx100	Guanti senza polvere	GUANTI-NIT-M	confezione	10.00	0.00	8.50	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
5b4904ba-a8f1-4786-a969-a553f01778ea	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000006	a3000001-0000-0000-0000-000000000001	Guanti nitrile L bx100	Guanti senza polvere	GUANTI-NIT-L	confezione	8.00	0.00	8.50	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
fa058df0-0761-4861-ad56-4f244bed7240	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000006	a3000001-0000-0000-0000-000000000001	Mascherine FFP2 bx10	FFP2 certificate	MASCHERINE-FF	confezione	20.00	0.00	12.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
37b273e7-b4e6-438c-b217-cd5aca9b4504	9d754153-6579-4b7e-a56b-025f00299cd9	a4000001-0000-0000-0000-000000000006	a3000001-0000-0000-0000-000000000001	Bavagli plastificati bx500	Bavagli monouso	BAVAGLIO	confezione	5.00	0.00	18.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.providers (id, clinic_id, first_name, last_name, role, phone, active, created_at, updated_at, vat_number, fiscal_code, professional_register, register_number, billing_address_street, billing_address_zip, billing_address_city, billing_address_province, billing_pec, billing_iban, billing_sdi_code, invoice_prefix, photo_url, email, password_hash, password_temporary) FROM stdin;
a0000001-0000-0000-0000-000000000011	9d754153-6579-4b7e-a56b-025f00299cd9	Admin	Demo	admin	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	admin@demo.dentalcare.it	$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O	f
b1000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	Paolo	Marchetti	surgeon	+39 334 1001002	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
b1000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	Serena	Amato	orthodontist	+39 334 1001003	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
62b0d49c-c2a7-4f46-89c5-0deb768d29a9	9d754153-6579-4b7e-a56b-025f00299cd9	Maria	Rossi	secretary	\N	t	2026-06-01 10:22:44.364517+00	2026-06-01 11:32:08.321107+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	segreteria@demo.dentalcare.it	$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O	f
b1000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	Laura	Ferretti	dentist	\N	t	2026-05-29 13:52:49.31794+00	2026-06-01 11:42:48.360267+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	medico@demo.dentalcare.it	$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O	f
5cac268e-1fdd-4d13-966c-65e367dca1c8	9d754153-6579-4b7e-a56b-025f00299cd9	Demo	Tutto	admin	\N	t	2026-06-01 18:11:28.15558+00	2026-06-01 18:11:28.15558+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	demo@demo.dentalcare.it	$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O	f
b1000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	Michele	Gentili	hygienist	+39 334 1001004	f	2026-05-29 13:52:49.31794+00	2026-06-01 19:07:43.64366+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
\.


--
-- Data for Name: recall_contacts; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.recall_contacts (id, clinic_id, recall_id, contact_type, contact_at, outcome, notes, created_by_provider_id, created_at) FROM stdin;
a47d1539-95b8-4700-a40c-3c0724bb67de	9d754153-6579-4b7e-a56b-025f00299cd9	e73173a8-27d3-4043-a963-8f2e8543a1f9	telefono	2026-05-04 13:52:49.31794+00	non_risposto	Nessuna risposta - squillato 3 volte	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
df216ace-5169-417e-b894-f6cb58dabaff	9d754153-6579-4b7e-a56b-025f00299cd9	e73173a8-27d3-4043-a963-8f2e8543a1f9	sms	2026-05-09 13:52:49.31794+00	risposto	SMS inviato - risposto che richiamerà ma non l'ha fatto	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
74eb110d-4821-4766-9730-1cd53fd75bbf	9d754153-6579-4b7e-a56b-025f00299cd9	fdc5bdd2-220f-41d8-909c-007b047056b5	telefono	2026-05-24 13:52:49.31794+00	messaggio_lasciato	Lasciato messaggio in segreteria per riprenotare	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
ada27196-0d8d-492d-8ff8-4b6793a3edb9	9d754153-6579-4b7e-a56b-025f00299cd9	fdc5bdd2-220f-41d8-909c-007b047056b5	whatsapp	2026-05-27 13:52:49.31794+00	risposto	Risposto via WhatsApp - disponibile venerdì mattina	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
2e197f05-289c-40f4-936b-bf47cd045e96	9d754153-6579-4b7e-a56b-025f00299cd9	000a018f-8be4-4281-be74-45d8977caf45	telefono	2026-05-27 13:52:49.31794+00	messaggio_lasciato	Lasciato messaggio in segreteria	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
c499f290-9252-44f3-8cd6-df8bf8a36cc6	9d754153-6579-4b7e-a56b-025f00299cd9	000a018f-8be4-4281-be74-45d8977caf45	telefono	2026-05-28 13:52:49.31794+00	confermato	Paziente richiamato - confermato appuntamento per domani	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
8e4024ab-93b5-4425-a3b4-83de5d7c87ef	9d754153-6579-4b7e-a56b-025f00299cd9	59929d2c-cffd-42da-a645-33154bf34047	telefono	2026-05-27 13:52:49.31794+00	risposto	Paziente contattato - preferisce email per comunicazioni	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
e53da7d6-b8b2-4c17-8364-942abd0a8c29	9d754153-6579-4b7e-a56b-025f00299cd9	59929d2c-cffd-42da-a645-33154bf34047	email	2026-05-28 13:52:49.31794+00	risposto	Email inviata con disponibilità orari - risposto positivamente	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
9c6ccb45-9ca1-4e70-a7fc-0ac15247dac6	9d754153-6579-4b7e-a56b-025f00299cd9	f47fd211-c6d2-41a7-bc86-3937759b7517	sms	2026-05-26 13:52:49.31794+00	confermato	SMS promemoria inviato - confermato via risposta SMS	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
8b2e4afc-a457-4f8e-9d27-a950b77dc844	9d754153-6579-4b7e-a56b-025f00299cd9	9222bfff-7012-4272-b1e8-f4d90bcd1824	telefono	2026-05-28 13:52:49.31794+00	confermato	Confermato controllo post-impianto tra 2 settimane	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
2aebadc5-c379-4199-930a-c350f0b8edfc	9d754153-6579-4b7e-a56b-025f00299cd9	a9387e0f-bd32-4b3d-becc-c138ddbf04bd	whatsapp	2026-05-24 13:52:49.31794+00	risposto	Inviato messaggio WhatsApp per controllo SRP - risposto ok	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
ddd539f8-fb7e-45c4-a24f-443ffb83fb87	9d754153-6579-4b7e-a56b-025f00299cd9	93615e17-c84e-4e6e-a3a6-268adbc0b3e2	sms	2026-05-25 13:52:49.31794+00	confermato	Promemoria mensile inviato - confermato come di consueto	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
f32eb952-d1f2-4e09-a919-1f5db3e54cb9	9d754153-6579-4b7e-a56b-025f00299cd9	f2b4e7e8-a710-4ed8-9115-f78d267774ca	email	2026-05-22 13:52:49.31794+00	risposto	Email con preventivo inviata - paziente sta valutando	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
87967aeb-8aa5-49e2-9314-a83f3719eb2a	9d754153-6579-4b7e-a56b-025f00299cd9	ab32bb1a-3177-41c3-af47-4c23fa5649fe	telefono	2026-05-28 13:52:49.31794+00	non_risposto	Nessuna risposta - riprovare domani	b1000001-0000-0000-0000-000000000004	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: service_bundle_items; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.service_bundle_items (id, clinic_id, parent_service_id, child_service_id, sort_order) FROM stdin;
19d79c71-35ea-4e67-9e93-77277ce08ae7	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000018	d1000001-0000-0000-0000-000000000025	10
0e5d0c54-dd3f-48a3-b5a2-8ffbe849ee59	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000019	d1000001-0000-0000-0000-000000000025	10
d6387c38-39a9-4e67-9cff-d169277e1548	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000010	d1000001-0000-0000-0000-000000000004	10
f02efd76-e131-4d73-b19d-0be224812ba2	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000010	d1000001-0000-0000-0000-000000000007	20
7d406d69-aaa6-46eb-ad16-902fe25b7a33	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000011	d1000001-0000-0000-0000-000000000004	10
d9f7fb17-ef18-4385-b1f2-c672dc08e2e6	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000012	d1000001-0000-0000-0000-000000000004	10
d0377703-fef6-4177-9d5a-1d48a5530fec	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000016	d1000001-0000-0000-0000-000000000006	10
8b218ed5-474d-4e85-9349-1f1846686d33	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000016	d1000001-0000-0000-0000-000000000017	20
a096a732-0850-41fb-8570-cbe4da2f1723	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000016	d1000001-0000-0000-0000-000000000014	30
0a25af82-a249-4164-81cc-da028625395e	9d754153-6579-4b7e-a56b-025f00299cd9	d1000001-0000-0000-0000-000000000002	d1000001-0000-0000-0000-000000000003	10
\.


--
-- Data for Name: service_catalog; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.service_catalog (id, clinic_id, code, name, category, description, default_price, default_vat_rate, active, created_at, updated_at, duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous) FROM stdin;
d1000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	IGI-01	Igiene orale professionale	Igiene	\N	80.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	45	\N	\N	t
d1000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	IGI-02	Igiene orale profonda	Igiene	\N	120.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	t
d1000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	IGI-03	Fluoroprofilassi	Igiene	\N	30.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	15	\N	\N	t
d1000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	DIA-01	Radiografia endorale	Diagnostica	\N	25.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	10	\N	\N	t
d1000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	DIA-02	Ortopantomografia	Diagnostica	\N	80.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	15	\N	\N	t
d1000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	DIA-03	CBCT arcata singola	Diagnostica	\N	180.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	20	\N	\N	f
d1000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	CON-01	Otturazione composito monofacciale	Conservativa	\N	90.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	45	\N	\N	t
d1000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	CON-02	Otturazione composito bifacciale	Conservativa	\N	130.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	t
d1000001-0000-0000-0000-000000000009	9d754153-6579-4b7e-a56b-025f00299cd9	CON-03	Otturazione composito trifacciale	Conservativa	\N	160.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	75	\N	\N	t
d1000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	END-01	Devitalizzazione monoradicolare	Endodonzia	\N	280.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	90	1	5	t
d1000001-0000-0000-0000-000000000011	9d754153-6579-4b7e-a56b-025f00299cd9	END-02	Devitalizzazione biradicolare	Endodonzia	\N	380.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	120	4	6	f
d1000001-0000-0000-0000-000000000012	9d754153-6579-4b7e-a56b-025f00299cd9	END-03	Devitalizzazione pluriradicolare	Endodonzia	\N	480.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	150	6	8	f
d1000001-0000-0000-0000-000000000013	9d754153-6579-4b7e-a56b-025f00299cd9	END-04	Ritrattamento canalare	Endodonzia	\N	380.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	120	\N	\N	f
d1000001-0000-0000-0000-000000000014	9d754153-6579-4b7e-a56b-025f00299cd9	PRO-01	Corona in zirconia	Protesi	\N	650.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	f
d1000001-0000-0000-0000-000000000015	9d754153-6579-4b7e-a56b-025f00299cd9	PRO-02	Faccetta in ceramica	Protesi	\N	550.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	90	1	3	f
d1000001-0000-0000-0000-000000000016	9d754153-6579-4b7e-a56b-025f00299cd9	IMP-01	Impianto osteointegrato	Implantologia	\N	1200.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	90	\N	\N	f
d1000001-0000-0000-0000-000000000017	9d754153-6579-4b7e-a56b-025f00299cd9	IMP-02	Moncone implantare	Implantologia	\N	350.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	45	\N	\N	f
d1000001-0000-0000-0000-000000000018	9d754153-6579-4b7e-a56b-025f00299cd9	CHI-01	Estrazione semplice	Chirurgia	\N	100.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	30	\N	\N	t
d1000001-0000-0000-0000-000000000019	9d754153-6579-4b7e-a56b-025f00299cd9	CHI-02	Estrazione complessa	Chirurgia	\N	200.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	f
d1000001-0000-0000-0000-000000000025	9d754153-6579-4b7e-a56b-025f00299cd9	CHI-03	Rimozione punti di sutura	Chirurgia	\N	30.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	15	\N	\N	t
d1000001-0000-0000-0000-000000000020	9d754153-6579-4b7e-a56b-025f00299cd9	PAR-01	Levigatura radicolare per quadrante	Parodontologia	\N	180.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	f
d1000001-0000-0000-0000-000000000021	9d754153-6579-4b7e-a56b-025f00299cd9	PAR-02	Terapia parodontale di mantenimento	Parodontologia	\N	80.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	45	\N	\N	f
d1000001-0000-0000-0000-000000000022	9d754153-6579-4b7e-a56b-025f00299cd9	ORT-01	Apparecchio mobile rimovibile	Ortodonzia	\N	450.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	t
d1000001-0000-0000-0000-000000000023	9d754153-6579-4b7e-a56b-025f00299cd9	ORT-02	Apparecchio fisso multibrackets	Ortodonzia	\N	2800.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	90	\N	\N	f
d1000001-0000-0000-0000-000000000024	9d754153-6579-4b7e-a56b-025f00299cd9	EST-01	Sbiancamento professionale	Estetica	\N	250.00	0.00	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	60	\N	\N	f
\.


--
-- Data for Name: stock_movements; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.stock_movements (id, clinic_id, product_id, movement_type, quantity, unit_cost, notes, reference_doc, created_by_provider_id, created_at) FROM stdin;
0d770346-7a74-4a0c-b23a-1e5eb6ccec7f	9d754153-6579-4b7e-a56b-025f00299cd9	433ba4fc-22c7-429e-924a-f11d831ccacc	carico	25.00	26.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
a97abf29-2d42-4825-aeae-84ed902ccd70	9d754153-6579-4b7e-a56b-025f00299cd9	eecf583c-8988-4d54-8544-5a837ce959ec	carico	25.00	26.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
b16e1a33-3a90-4c83-8467-0c829a3bfe70	9d754153-6579-4b7e-a56b-025f00299cd9	d53e016e-3f1c-4115-852e-356fc55cade4	carico	15.00	36.40	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
b095e8c5-02d7-40de-bc7e-fa6b9b42bb2e	9d754153-6579-4b7e-a56b-025f00299cd9	6f6e77b3-b295-46e9-8bb1-eacbe901039f	carico	50.00	5.95	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
8c4a71aa-bc50-44d0-a76c-efb34f3dd91c	9d754153-6579-4b7e-a56b-025f00299cd9	be60aa81-2a24-453d-959a-4d53ff5446ee	carico	15.00	31.50	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
794a40f7-06eb-443f-bbd1-404231d0bec9	9d754153-6579-4b7e-a56b-025f00299cd9	f7b81781-dd9a-4079-a361-2d03dfe911b2	carico	10.00	31.50	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
c3248e15-21a9-4c95-b781-a1fe769c4d08	9d754153-6579-4b7e-a56b-025f00299cd9	c38fe0d9-6d94-4c4e-a7dd-a1171c036f74	carico	25.00	8.40	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
915f6121-cdc5-4b0f-b60b-19997aa0e689	9d754153-6579-4b7e-a56b-025f00299cd9	ea417970-1733-49a5-9063-8faa68cef5b0	carico	15.00	8.40	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
71555153-25f5-4faf-b28f-fd16baf17227	9d754153-6579-4b7e-a56b-025f00299cd9	225939a6-0106-4bed-b328-8a86bf68e3f1	carico	25.00	12.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
5531baf8-44ee-4e0a-9192-9c61ad39c7d9	9d754153-6579-4b7e-a56b-025f00299cd9	c746805b-4137-49a9-9993-c5c12a53f235	carico	25.00	12.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
2921adee-e8bb-4f9b-ac2b-618a772cfd44	9d754153-6579-4b7e-a56b-025f00299cd9	85a2a119-eb80-401c-ae59-e4e044c76a9d	carico	15.00	15.40	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
4a90ef25-8c18-4dfe-8c61-1ee0f1bf76bd	9d754153-6579-4b7e-a56b-025f00299cd9	c92bd178-e31a-4e79-9264-b331cc11b455	carico	20.00	9.80	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
fd6f583e-452a-4fd5-9efc-fbea8976281b	9d754153-6579-4b7e-a56b-025f00299cd9	abaa0f58-9f72-4253-b8ec-c1939f6d38b0	carico	15.00	33.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
0abacd9d-ca98-4217-96c6-0c40fedf3a34	9d754153-6579-4b7e-a56b-025f00299cd9	c63c0b58-9965-4fd3-a91e-8607102c4c72	carico	10.00	33.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
31462f86-377d-4d14-9b2f-ed678d47da15	9d754153-6579-4b7e-a56b-025f00299cd9	82b1cb99-469f-4e76-81ed-a56fd64fcd66	carico	10.00	224.00	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
d6c1da6b-c668-4abe-a264-631d6b08ccb9	9d754153-6579-4b7e-a56b-025f00299cd9	12f8dfb2-bb60-472e-9e0e-a97252cfed44	carico	10.00	224.00	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
8ad8879e-c1ef-4c2f-881f-0344e3fa32f5	9d754153-6579-4b7e-a56b-025f00299cd9	2fff0952-bcf5-42ef-afa0-cb2bdbeef895	carico	10.00	59.50	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
68e8a5cf-2797-49bd-9bbe-c83d3006ad90	9d754153-6579-4b7e-a56b-025f00299cd9	1c1628fb-d757-41a4-83cd-9f6ab430d19a	carico	10.00	66.50	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
d81ebe50-0db5-4750-91f1-81e741d8151a	9d754153-6579-4b7e-a56b-025f00299cd9	29a31362-235a-4951-b0a0-0e388a10dfe0	carico	50.00	5.95	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
51fc6abc-559b-4296-ad08-45ea1c306d2b	9d754153-6579-4b7e-a56b-025f00299cd9	5b4904ba-a8f1-4786-a969-a553f01778ea	carico	40.00	5.95	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
cfb49856-c256-4816-bb64-bf0c64fa06e9	9d754153-6579-4b7e-a56b-025f00299cd9	fa058df0-0761-4861-ad56-4f244bed7240	carico	100.00	8.40	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
312c7dfb-9c5a-482f-835b-2e9a6f8e4fe1	9d754153-6579-4b7e-a56b-025f00299cd9	37b273e7-b4e6-438c-b217-cd5aca9b4504	carico	25.00	12.60	Carico iniziale magazzino	DDT-INIT-001	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
c836cfdf-5ee0-4841-96c9-ff204e17d05d	9d754153-6579-4b7e-a56b-025f00299cd9	433ba4fc-22c7-429e-924a-f11d831ccacc	scarico	1.00	26.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
b52620d7-10e4-45e8-aacc-8d82990da032	9d754153-6579-4b7e-a56b-025f00299cd9	eecf583c-8988-4d54-8544-5a837ce959ec	scarico	1.00	26.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
358f7410-bd40-47c0-874c-38ec14abfb02	9d754153-6579-4b7e-a56b-025f00299cd9	d53e016e-3f1c-4115-852e-356fc55cade4	scarico	1.00	36.40	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
8b592fa4-dab0-4b4b-9674-853ddda50bfd	9d754153-6579-4b7e-a56b-025f00299cd9	6f6e77b3-b295-46e9-8bb1-eacbe901039f	scarico	1.00	5.95	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
e8caa3eb-4ef1-4a8a-9df2-e2c5e8b69afb	9d754153-6579-4b7e-a56b-025f00299cd9	be60aa81-2a24-453d-959a-4d53ff5446ee	scarico	2.00	31.50	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
a568bfaa-fa25-4236-90d8-fde1fecd6bc1	9d754153-6579-4b7e-a56b-025f00299cd9	f7b81781-dd9a-4079-a361-2d03dfe911b2	scarico	2.00	31.50	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
6bdb9820-341b-45d5-a7da-db0583db4993	9d754153-6579-4b7e-a56b-025f00299cd9	c38fe0d9-6d94-4c4e-a7dd-a1171c036f74	scarico	2.00	8.40	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
8bab1022-5d4c-4bb7-842b-92b56e698e73	9d754153-6579-4b7e-a56b-025f00299cd9	ea417970-1733-49a5-9063-8faa68cef5b0	scarico	2.00	8.40	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
5d96e0fe-d292-4465-9a22-0344f6d49615	9d754153-6579-4b7e-a56b-025f00299cd9	225939a6-0106-4bed-b328-8a86bf68e3f1	scarico	1.00	12.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
014023e1-250a-4622-98d5-fbc0c6d7813d	9d754153-6579-4b7e-a56b-025f00299cd9	c746805b-4137-49a9-9993-c5c12a53f235	scarico	1.00	12.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
fd456d3b-aa44-4fe6-b36e-65369ddb5e9e	9d754153-6579-4b7e-a56b-025f00299cd9	85a2a119-eb80-401c-ae59-e4e044c76a9d	scarico	1.00	15.40	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
597a1441-cae9-485e-9563-a621be0e3cd9	9d754153-6579-4b7e-a56b-025f00299cd9	c92bd178-e31a-4e79-9264-b331cc11b455	scarico	1.00	9.80	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
60e3bb6e-cc6d-4f1a-a18e-7a17c0fe9b74	9d754153-6579-4b7e-a56b-025f00299cd9	abaa0f58-9f72-4253-b8ec-c1939f6d38b0	scarico	1.00	33.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
02733283-9ef2-49a6-a145-aa95b80217a5	9d754153-6579-4b7e-a56b-025f00299cd9	c63c0b58-9965-4fd3-a91e-8607102c4c72	scarico	1.00	33.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
2c7e0e5f-2c8c-427c-8f01-83e2ea785540	9d754153-6579-4b7e-a56b-025f00299cd9	82b1cb99-469f-4e76-81ed-a56fd64fcd66	scarico	1.00	224.00	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
008e84f8-f983-4105-bb68-1e67d9dab2f5	9d754153-6579-4b7e-a56b-025f00299cd9	12f8dfb2-bb60-472e-9e0e-a97252cfed44	scarico	1.00	224.00	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
1d455b3b-aa87-4ddb-b81e-ce33820cd23f	9d754153-6579-4b7e-a56b-025f00299cd9	2fff0952-bcf5-42ef-afa0-cb2bdbeef895	scarico	1.00	59.50	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
f9a685c6-24bc-402b-8b81-5a00af5b4f05	9d754153-6579-4b7e-a56b-025f00299cd9	1c1628fb-d757-41a4-83cd-9f6ab430d19a	scarico	1.00	66.50	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
17949fec-a0c9-4bd0-b688-47c057e6493e	9d754153-6579-4b7e-a56b-025f00299cd9	29a31362-235a-4951-b0a0-0e388a10dfe0	scarico	3.00	5.95	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
aba27d3d-106e-43c4-b0dd-51e237303ad2	9d754153-6579-4b7e-a56b-025f00299cd9	5b4904ba-a8f1-4786-a969-a553f01778ea	scarico	3.00	5.95	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
849ed0a5-ce9b-42f7-900c-599007173616	9d754153-6579-4b7e-a56b-025f00299cd9	fa058df0-0761-4861-ad56-4f244bed7240	scarico	3.00	8.40	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
79b5da1f-5da2-4920-9584-2245c7a6e3e0	9d754153-6579-4b7e-a56b-025f00299cd9	37b273e7-b4e6-438c-b217-cd5aca9b4504	scarico	3.00	12.60	Utilizzo sedute settimana 1	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
e89415e1-19af-401d-bc83-e1001727699a	9d754153-6579-4b7e-a56b-025f00299cd9	433ba4fc-22c7-429e-924a-f11d831ccacc	scarico	1.00	26.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
577ab212-e1a8-4b67-ba6c-8698a9b5b2e5	9d754153-6579-4b7e-a56b-025f00299cd9	eecf583c-8988-4d54-8544-5a837ce959ec	scarico	1.00	26.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
88265fb5-d976-44b1-aaed-6d7862174a10	9d754153-6579-4b7e-a56b-025f00299cd9	d53e016e-3f1c-4115-852e-356fc55cade4	scarico	1.00	36.40	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
38ca3f95-3989-4aef-8324-76a11d5e095b	9d754153-6579-4b7e-a56b-025f00299cd9	6f6e77b3-b295-46e9-8bb1-eacbe901039f	scarico	1.00	5.95	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
00912a07-296b-462e-9257-46ff1794f706	9d754153-6579-4b7e-a56b-025f00299cd9	be60aa81-2a24-453d-959a-4d53ff5446ee	scarico	3.00	31.50	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
1166718d-81bd-44cc-87df-9e4ff35e1744	9d754153-6579-4b7e-a56b-025f00299cd9	f7b81781-dd9a-4079-a361-2d03dfe911b2	scarico	3.00	31.50	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
5f4aa16f-04d0-4a56-84a7-fbda1e4792ab	9d754153-6579-4b7e-a56b-025f00299cd9	c38fe0d9-6d94-4c4e-a7dd-a1171c036f74	scarico	3.00	8.40	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
09aad487-b9f3-453e-b32e-4e6073042596	9d754153-6579-4b7e-a56b-025f00299cd9	ea417970-1733-49a5-9063-8faa68cef5b0	scarico	3.00	8.40	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
05dbda6f-1488-4a24-8977-539fd54b6cc8	9d754153-6579-4b7e-a56b-025f00299cd9	225939a6-0106-4bed-b328-8a86bf68e3f1	scarico	1.00	12.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
e2183e6f-beed-4a64-b5d6-b28eda9d1e26	9d754153-6579-4b7e-a56b-025f00299cd9	c746805b-4137-49a9-9993-c5c12a53f235	scarico	1.00	12.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
353f41d2-734e-4ec5-aca5-d93e218307e8	9d754153-6579-4b7e-a56b-025f00299cd9	85a2a119-eb80-401c-ae59-e4e044c76a9d	scarico	1.00	15.40	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
966d39fe-68b6-4738-b3fe-4a8c4c8744e0	9d754153-6579-4b7e-a56b-025f00299cd9	c92bd178-e31a-4e79-9264-b331cc11b455	scarico	1.00	9.80	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
2a4cafac-e1c4-4115-9b5c-2bc3a811ea96	9d754153-6579-4b7e-a56b-025f00299cd9	abaa0f58-9f72-4253-b8ec-c1939f6d38b0	scarico	1.00	33.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
3f192abf-e71a-4604-b938-e53c4add7004	9d754153-6579-4b7e-a56b-025f00299cd9	c63c0b58-9965-4fd3-a91e-8607102c4c72	scarico	1.00	33.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
ce4f224f-c244-4bf7-9e49-c18799c4ff0e	9d754153-6579-4b7e-a56b-025f00299cd9	82b1cb99-469f-4e76-81ed-a56fd64fcd66	scarico	1.00	224.00	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
cae91a3e-6e8a-40f3-a9e9-32131c03cc15	9d754153-6579-4b7e-a56b-025f00299cd9	12f8dfb2-bb60-472e-9e0e-a97252cfed44	scarico	1.00	224.00	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
29bae285-72d9-4f47-b54f-6789f4b16e24	9d754153-6579-4b7e-a56b-025f00299cd9	2fff0952-bcf5-42ef-afa0-cb2bdbeef895	scarico	1.00	59.50	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
f7232c9f-340f-4a3e-8aad-bc1c15be4d9d	9d754153-6579-4b7e-a56b-025f00299cd9	1c1628fb-d757-41a4-83cd-9f6ab430d19a	scarico	1.00	66.50	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
041ef094-06e4-4357-ba9c-8980e5878505	9d754153-6579-4b7e-a56b-025f00299cd9	29a31362-235a-4951-b0a0-0e388a10dfe0	scarico	4.00	5.95	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
0f6b160b-1c69-43a5-9a0a-5aeac8941b86	9d754153-6579-4b7e-a56b-025f00299cd9	5b4904ba-a8f1-4786-a969-a553f01778ea	scarico	4.00	5.95	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
812c0d5a-ffa9-4968-a777-8f94639761d6	9d754153-6579-4b7e-a56b-025f00299cd9	fa058df0-0761-4861-ad56-4f244bed7240	scarico	4.00	8.40	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
cf263f4a-2408-4746-87b6-45056cf7c7ac	9d754153-6579-4b7e-a56b-025f00299cd9	37b273e7-b4e6-438c-b217-cd5aca9b4504	scarico	4.00	12.60	Utilizzo sedute settimana 2	\N	b1000001-0000-0000-0000-000000000001	2026-05-29 13:52:49.31794+00
3a09385d-f58c-4105-8b12-098b3f8ff2ce	9d754153-6579-4b7e-a56b-025f00299cd9	433ba4fc-22c7-429e-924a-f11d831ccacc	rettifica	2.00	26.60	Rettifica inventario mensile	INV-2024-01	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
37450c19-f676-4096-a7cd-a8c0100187b7	9d754153-6579-4b7e-a56b-025f00299cd9	be60aa81-2a24-453d-959a-4d53ff5446ee	rettifica	2.00	31.50	Rettifica inventario mensile	INV-2024-01	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
3a49183d-b382-41e9-8db8-13aebc5e9aac	9d754153-6579-4b7e-a56b-025f00299cd9	fa058df0-0761-4861-ad56-4f244bed7240	rettifica	2.00	8.40	Rettifica inventario mensile	INV-2024-01	a0000001-0000-0000-0000-000000000011	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.suppliers (id, clinic_id, name, contact_person, phone, email, notes, is_active, created_at, updated_at) FROM stdin;
a3000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	Dental Supply Italia S.r.l.	Marco Betti	+39 06 5550200	ordini@dentalsupply.it	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
a3000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	Implantec Medical S.p.A.	Anna Ferrara	+39 02 5550300	ordini@implantec.it	\N	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
\.


--
-- Data for Name: tooth_conditions; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.tooth_conditions (id, clinic_id, patient_id, tooth_fdi, surface, condition, notes, updated_at) FROM stdin;
863f353e-0b43-48a6-b9a1-8b3647db7c5e	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	16	O	filling	\N	2026-05-29 17:30:22.267213+00
a9fd91c8-7e4e-4534-a653-2c561dbddfae	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	45	WHOLE	missing	\N	2026-05-29 17:30:22.267213+00
161c20db-ed7d-47f9-af07-5470d7caf16f	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	44	WHOLE	crown	\N	2026-05-29 17:30:22.267213+00
c885e880-9f25-451b-af5a-59ba3e5ac58d	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	43	O	filling	\N	2026-05-29 17:30:22.267213+00
b6ba69f2-80d8-4590-8669-5a807946af78	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	16	WHOLE	root_canal	\N	2026-06-01 11:45:42.566231+00
\.


--
-- Data for Name: treatment_plan_items; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.treatment_plan_items (id, clinic_id, plan_id, service_catalog_id, provider_id, tooth_fdi, quadrant, surfaces, quantity, planned_price, planned_vat_rate, clinical_notes, status, priority, planned_date, completed_at, created_at, updated_at) FROM stdin;
f1000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000001	d1000001-0000-0000-0000-000000000004	\N	16	\N	\N	1.00	25.00	0.00	\N	completed	10	\N	2026-05-19 10:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000001	d1000001-0000-0000-0000-000000000008	\N	16	\N	{O,D}	1.00	130.00	0.00	\N	completed	20	\N	2026-05-19 10:30:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000001	d1000001-0000-0000-0000-000000000007	\N	14	\N	{O}	1.00	90.00	0.00	\N	scheduled	30	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000001	d1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	1.00	80.00	0.00	\N	planned	40	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000002	d1000001-0000-0000-0000-000000000006	\N	36	\N	\N	1.00	180.00	0.00	\N	completed	10	\N	2026-05-09 09:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000002	d1000001-0000-0000-0000-000000000016	\N	36	\N	\N	1.00	1200.00	0.00	\N	scheduled	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000002	d1000001-0000-0000-0000-000000000017	\N	36	\N	\N	1.00	350.00	0.00	\N	planned	30	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000002	d1000001-0000-0000-0000-000000000014	\N	36	\N	\N	1.00	650.00	0.00	\N	planned	40	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000009	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000003	d1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	1.00	80.00	0.00	\N	planned	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000003	d1000001-0000-0000-0000-000000000007	\N	24	\N	{O}	1.00	90.00	0.00	\N	planned	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000011	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000004	d1000001-0000-0000-0000-000000000023	\N	\N	\N	\N	1.00	2800.00	0.00	\N	accepted	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000012	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000005	d1000001-0000-0000-0000-000000000024	\N	\N	\N	\N	1.00	250.00	0.00	\N	planned	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000013	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000005	d1000001-0000-0000-0000-000000000015	\N	11	\N	\N	1.00	550.00	0.00	\N	planned	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000014	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000005	d1000001-0000-0000-0000-000000000015	\N	21	\N	\N	1.00	550.00	0.00	\N	planned	30	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000015	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000006	d1000001-0000-0000-0000-000000000004	\N	26	\N	\N	1.00	25.00	0.00	\N	completed	10	\N	2026-05-15 09:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000016	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000006	d1000001-0000-0000-0000-000000000012	\N	26	\N	\N	1.00	480.00	0.00	\N	scheduled	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000017	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000006	d1000001-0000-0000-0000-000000000014	\N	26	\N	\N	1.00	650.00	0.00	\N	planned	30	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000018	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000007	d1000001-0000-0000-0000-000000000019	\N	18	\N	\N	1.00	200.00	0.00	\N	completed	10	\N	2026-04-14 10:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000019	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000007	d1000001-0000-0000-0000-000000000025	\N	18	\N	\N	1.00	30.00	0.00	\N	completed	20	\N	2026-04-21 10:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000020	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000008	d1000001-0000-0000-0000-000000000008	\N	35	\N	{O,M}	1.00	130.00	0.00	\N	planned	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000021	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000008	d1000001-0000-0000-0000-000000000007	\N	45	\N	{O}	1.00	90.00	0.00	\N	planned	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000022	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000008	d1000001-0000-0000-0000-000000000004	\N	35	\N	\N	1.00	25.00	0.00	\N	planned	30	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000023	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000009	d1000001-0000-0000-0000-000000000020	\N	\N	\N	\N	1.00	180.00	0.00	\N	planned	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000024	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000009	d1000001-0000-0000-0000-000000000002	\N	\N	\N	\N	1.00	120.00	0.00	\N	planned	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000025	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000010	d1000001-0000-0000-0000-000000000009	\N	37	\N	{O,M,D}	1.00	160.00	0.00	\N	accepted	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000026	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000011	d1000001-0000-0000-0000-000000000006	\N	46	\N	\N	1.00	180.00	0.00	\N	completed	10	\N	2026-05-22 14:00:00+00	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000027	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000011	d1000001-0000-0000-0000-000000000016	\N	46	\N	\N	1.00	1200.00	0.00	\N	scheduled	20	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
f1000001-0000-0000-0000-000000000028	9d754153-6579-4b7e-a56b-025f00299cd9	e1000001-0000-0000-0000-000000000012	d1000001-0000-0000-0000-000000000010	\N	26	\N	\N	1.00	280.00	0.00	\N	planned	10	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
04ac7394-58ed-4b1d-9fc7-1a6399e65d8a	9d754153-6579-4b7e-a56b-025f00299cd9	1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	d1000001-0000-0000-0000-000000000014	\N	44	4	\N	1.00	650.00	0.00	\N	planned	100	\N	\N	2026-05-29 17:31:15.80544+00	2026-05-29 17:31:15.80544+00
0d19ff8f-1c12-4f06-8f77-693e1d9835c3	9d754153-6579-4b7e-a56b-025f00299cd9	1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	d1000001-0000-0000-0000-000000000006	\N	45	4	\N	1.00	180.00	0.00	\N	planned	100	\N	\N	2026-05-29 17:31:15.806566+00	2026-05-29 17:31:15.806566+00
0611f2a4-57b0-4c14-894a-a1e973445192	9d754153-6579-4b7e-a56b-025f00299cd9	1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	d1000001-0000-0000-0000-000000000014	\N	45	4	\N	1.00	650.00	0.00	Aggiunto automaticamente	planned	100	\N	\N	2026-05-29 17:31:15.807227+00	2026-05-29 17:31:15.807227+00
67871adf-12be-4865-8b17-bed25a42ae61	9d754153-6579-4b7e-a56b-025f00299cd9	1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	d1000001-0000-0000-0000-000000000017	\N	45	4	\N	1.00	350.00	0.00	Aggiunto automaticamente	planned	100	\N	\N	2026-05-29 17:31:15.807794+00	2026-05-29 17:31:15.807794+00
c6c32d63-b5d9-4414-82fb-6f3676305798	9d754153-6579-4b7e-a56b-025f00299cd9	1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	d1000001-0000-0000-0000-000000000016	\N	45	4	\N	1.00	1200.00	0.00	Aggiunto automaticamente	planned	100	\N	\N	2026-05-29 17:31:15.808468+00	2026-05-29 17:31:15.808468+00
f3dd52e1-c977-4f8a-b146-7be6bcad5166	9d754153-6579-4b7e-a56b-025f00299cd9	65fe126d-2831-48b3-a38c-678277d679e6	d1000001-0000-0000-0000-000000000007	\N	45	4	\N	1.00	90.00	0.00	\N	planned	10	\N	\N	2026-06-01 11:47:09.519583+00	2026-06-01 11:47:09.519583+00
329a2779-0372-42a4-8077-bd91e8e4ad1b	9d754153-6579-4b7e-a56b-025f00299cd9	65fe126d-2831-48b3-a38c-678277d679e6	d1000001-0000-0000-0000-000000000004	\N	45	4	\N	1.00	25.00	0.00	\N	planned	20	\N	\N	2026-06-01 11:47:09.519583+00	2026-06-01 11:47:09.519583+00
\.


--
-- Data for Name: treatment_plans; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.treatment_plans (id, clinic_id, patient_id, name, description, status, created_by_provider_id, proposed_at, accepted_at, completed_at, rejected_at, created_at, updated_at) FROM stdin;
e1000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000001	Piano carie multiple - Rossi Marco	\N	in_progress	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000003	Implantologia 36 - Romano Luca	\N	accepted	b1000001-0000-0000-0000-000000000002	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000005	Conservativa e igiene - Ricci Andrea	\N	proposed	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000007	Ortodonzia adulti - Greco Stefano	\N	in_progress	b1000001-0000-0000-0000-000000000003	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000005	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000002	Sbiancamento e faccette - Bianchi Giulia	\N	draft	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000006	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000006	Devitalizzazione 26 - Marino Valentina	\N	accepted	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000007	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000008	Chirurgia 18 - Bruno Francesca	\N	completed	b1000001-0000-0000-0000-000000000002	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000008	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000010	Carie multiple inf. - Conti Silvia	\N	in_progress	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000009	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000011	Parodontite - De Luca Roberto	\N	proposed	b1000001-0000-0000-0000-000000000004	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000010	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000015	Restauro molare - Rizzo Paolo	\N	accepted	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
e1000001-0000-0000-0000-000000000011	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000016	Impianto 46 - Lombardi Alessia	\N	in_progress	b1000001-0000-0000-0000-000000000002	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	Riabilitazione	Nota mia	draft	\N	\N	\N	\N	\N	2026-05-29 17:29:34.46128+00	2026-05-29 17:29:34.46128+00
e1000001-0000-0000-0000-000000000012	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	Urgenza 26 devitalizzazione - Barbieri Sara	\N	accepted	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-06-01 11:48:16.26892+00
65fe126d-2831-48b3-a38c-678277d679e6	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	Piano di cura da odontogramma	Generato da odontogramma	accepted	\N	\N	\N	\N	\N	2026-06-01 11:47:09.519583+00	2026-06-01 11:48:34.6245+00
\.


--
-- Name: anamnesis_categories anamnesis_categories_code_unique; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.anamnesis_categories
    ADD CONSTRAINT anamnesis_categories_code_unique UNIQUE (code);


--
-- Name: anamnesis_categories anamnesis_categories_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.anamnesis_categories
    ADD CONSTRAINT anamnesis_categories_pkey PRIMARY KEY (id);


--
-- Name: anamnesis_items anamnesis_items_code_unique; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.anamnesis_items
    ADD CONSTRAINT anamnesis_items_code_unique UNIQUE (code);


--
-- Name: anamnesis_items anamnesis_items_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.anamnesis_items
    ADD CONSTRAINT anamnesis_items_pkey PRIMARY KEY (id);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: flyway_schema_history flyway_schema_history_pk; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.flyway_schema_history
    ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);


--
-- Name: national_holidays national_holidays_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.national_holidays
    ADD CONSTRAINT national_holidays_pkey PRIMARY KEY (id);


--
-- Name: regions regions_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.regions
    ADD CONSTRAINT regions_pkey PRIMARY KEY (id);


--
-- Name: states states_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.states
    ADD CONSTRAINT states_pkey PRIMARY KEY (id);


--
-- Name: tenant_clinics tenant_clinics_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.tenant_clinics
    ADD CONSTRAINT tenant_clinics_pkey PRIMARY KEY (clinic_id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_schema_name_key; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.tenants
    ADD CONSTRAINT tenants_schema_name_key UNIQUE (schema_name);


--
-- Name: cities uq_cities_region_name; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.cities
    ADD CONSTRAINT uq_cities_region_name UNIQUE (region_id, name);


--
-- Name: regions uq_regions_state_code; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.regions
    ADD CONSTRAINT uq_regions_state_code UNIQUE (state_id, code);


--
-- Name: states uq_states_code; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.states
    ADD CONSTRAINT uq_states_code UNIQUE (code);


--
-- Name: anamnesis_categories ux_anamnesis_categories_name; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.anamnesis_categories
    ADD CONSTRAINT ux_anamnesis_categories_name UNIQUE (name);


--
-- Name: national_holidays ux_holidays_state_date; Type: CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.national_holidays
    ADD CONSTRAINT ux_holidays_state_date UNIQUE (state_id, holiday_date);


--
-- Name: ai_conversations ai_conversations_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.ai_conversations
    ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.appointments
    ADD CONSTRAINT appointments_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_sessions chat_sessions_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.chat_sessions
    ADD CONSTRAINT chat_sessions_pkey PRIMARY KEY (id);


--
-- Name: clinical_history_entries clinical_history_entries_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinical_history_entries
    ADD CONSTRAINT clinical_history_entries_pkey PRIMARY KEY (id);


--
-- Name: clinical_history_entries clinical_history_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinical_history_entries
    ADD CONSTRAINT clinical_history_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: clinics clinics_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinics
    ADD CONSTRAINT clinics_pkey PRIMARY KEY (id);


--
-- Name: condition_service_defaults condition_service_defaults_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_pkey PRIMARY KEY (id);


--
-- Name: estimate_lines estimate_lines_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimate_lines
    ADD CONSTRAINT estimate_lines_pkey PRIMARY KEY (id);


--
-- Name: estimate_lines estimate_lines_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimate_lines
    ADD CONSTRAINT estimate_lines_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: estimates estimates_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimates
    ADD CONSTRAINT estimates_pkey PRIMARY KEY (id);


--
-- Name: estimates estimates_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimates
    ADD CONSTRAINT estimates_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: invoice_lines invoice_lines_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoice_lines
    ADD CONSTRAINT invoice_lines_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT invoices_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: odontogram_teeth odontogram_teeth_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.odontogram_teeth
    ADD CONSTRAINT odontogram_teeth_pkey PRIMARY KEY (id);


--
-- Name: odontogram_teeth odontogram_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.odontogram_teeth
    ADD CONSTRAINT odontogram_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: patient_anamnesis_item_selections patient_anamnesis_item_selections_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_pkey PRIMARY KEY (id);


--
-- Name: patient_anamnesis_item_selections patient_anamnesis_item_selections_unique; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_unique UNIQUE (clinic_id, patient_id, item_id);


--
-- Name: patient_anamnesis patient_anamnesis_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_pkey PRIMARY KEY (id);


--
-- Name: patient_anamnesis patient_anamnesis_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: patient_diagnoses patient_diagnoses_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_diagnoses
    ADD CONSTRAINT patient_diagnoses_pkey PRIMARY KEY (id);


--
-- Name: patient_documents patient_documents_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_documents
    ADD CONSTRAINT patient_documents_pkey PRIMARY KEY (id);


--
-- Name: patient_documents patient_documents_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_documents
    ADD CONSTRAINT patient_documents_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: patient_prescriptions patient_prescriptions_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_prescriptions
    ADD CONSTRAINT patient_prescriptions_pkey PRIMARY KEY (id);


--
-- Name: patient_recalls patient_recalls_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_recalls
    ADD CONSTRAINT patient_recalls_pkey PRIMARY KEY (id);


--
-- Name: patient_recalls patient_recalls_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_recalls
    ADD CONSTRAINT patient_recalls_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);


--
-- Name: patients patients_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patients
    ADD CONSTRAINT patients_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: product_categories product_categories_clinic_id_name_key; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.product_categories
    ADD CONSTRAINT product_categories_clinic_id_name_key UNIQUE (clinic_id, name);


--
-- Name: product_categories product_categories_id_clinic_id_key; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.product_categories
    ADD CONSTRAINT product_categories_id_clinic_id_key UNIQUE (id, clinic_id);


--
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- Name: products products_id_clinic_id_key; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.products
    ADD CONSTRAINT products_id_clinic_id_key UNIQUE (id, clinic_id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);


--
-- Name: providers providers_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.providers
    ADD CONSTRAINT providers_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: recall_contacts recall_contacts_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.recall_contacts
    ADD CONSTRAINT recall_contacts_pkey PRIMARY KEY (id);


--
-- Name: recall_contacts recall_contacts_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.recall_contacts
    ADD CONSTRAINT recall_contacts_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: service_bundle_items service_bundle_items_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_bundle_items
    ADD CONSTRAINT service_bundle_items_pkey PRIMARY KEY (id);


--
-- Name: service_catalog service_catalog_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_catalog
    ADD CONSTRAINT service_catalog_pkey PRIMARY KEY (id);


--
-- Name: service_catalog service_catalog_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_catalog
    ADD CONSTRAINT service_catalog_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: stock_movements stock_movements_id_clinic_id_key; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.stock_movements
    ADD CONSTRAINT stock_movements_id_clinic_id_key UNIQUE (id, clinic_id);


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_id_clinic_id_key; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.suppliers
    ADD CONSTRAINT suppliers_id_clinic_id_key UNIQUE (id, clinic_id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: tooth_conditions tooth_conditions_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.tooth_conditions
    ADD CONSTRAINT tooth_conditions_pkey PRIMARY KEY (id);


--
-- Name: treatment_plan_items treatment_plan_items_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_pkey PRIMARY KEY (id);


--
-- Name: treatment_plan_items treatment_plan_items_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: treatment_plans treatment_plans_pkey; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plans
    ADD CONSTRAINT treatment_plans_pkey PRIMARY KEY (id);


--
-- Name: treatment_plans treatment_plans_unique_per_clinic; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plans
    ADD CONSTRAINT treatment_plans_unique_per_clinic UNIQUE (id, clinic_id);


--
-- Name: service_bundle_items uq_bundle_item; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_bundle_items
    ADD CONSTRAINT uq_bundle_item UNIQUE (clinic_id, parent_service_id, child_service_id);


--
-- Name: condition_service_defaults uq_condition_default; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.condition_service_defaults
    ADD CONSTRAINT uq_condition_default UNIQUE (clinic_id, condition_name, service_id);


--
-- Name: tooth_conditions uq_tooth_surface; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.tooth_conditions
    ADD CONSTRAINT uq_tooth_surface UNIQUE (clinic_id, patient_id, tooth_fdi, surface);


--
-- Name: estimates ux_estimates_clinic_number; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimates
    ADD CONSTRAINT ux_estimates_clinic_number UNIQUE (clinic_id, estimate_number);


--
-- Name: invoices ux_invoices_number; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT ux_invoices_number UNIQUE (clinic_id, invoice_number);


--
-- Name: service_catalog ux_service_catalog_clinic_code; Type: CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_catalog
    ADD CONSTRAINT ux_service_catalog_clinic_code UNIQUE (clinic_id, code);


--
-- Name: flyway_schema_history_s_idx; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX flyway_schema_history_s_idx ON dentalcare.flyway_schema_history USING btree (success);


--
-- Name: ix_anamnesis_categories_sort; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_anamnesis_categories_sort ON dentalcare.anamnesis_categories USING btree (sort_order, code) WHERE (enabled = true);


--
-- Name: ix_anamnesis_items_category; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_anamnesis_items_category ON dentalcare.anamnesis_items USING btree (category_id, sort_order);


--
-- Name: ix_anamnesis_items_category_sort; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_anamnesis_items_category_sort ON dentalcare.anamnesis_items USING btree (category_id, sort_order) WHERE (enabled = true);


--
-- Name: ix_cities_name; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_cities_name ON dentalcare.cities USING btree (name);


--
-- Name: ix_cities_region; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_cities_region ON dentalcare.cities USING btree (region_id);


--
-- Name: ix_holidays_date; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_holidays_date ON dentalcare.national_holidays USING btree (state_id, holiday_date) WHERE (holiday_date IS NOT NULL);


--
-- Name: ix_holidays_recurring; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_holidays_recurring ON dentalcare.national_holidays USING btree (state_id, month, day) WHERE (is_recurring = true);


--
-- Name: ix_regions_state; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_regions_state ON dentalcare.regions USING btree (state_id);


--
-- Name: ix_tenant_clinics_tenant_id; Type: INDEX; Schema: dentalcare; Owner: -
--

CREATE INDEX ix_tenant_clinics_tenant_id ON dentalcare.tenant_clinics USING btree (tenant_id);


--
-- Name: chat_messages_session_idx; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX chat_messages_session_idx ON t_9d754153.chat_messages USING btree (session_id);


--
-- Name: chat_sessions_provider_idx; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX chat_sessions_provider_idx ON t_9d754153.chat_sessions USING btree (provider_id, created_at DESC);


--
-- Name: idx_patient_diagnoses_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX idx_patient_diagnoses_patient ON t_9d754153.patient_diagnoses USING btree (clinic_id, patient_id);


--
-- Name: idx_patient_diagnoses_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX idx_patient_diagnoses_status ON t_9d754153.patient_diagnoses USING btree (clinic_id, patient_id, status);


--
-- Name: idx_patient_prescriptions_active; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX idx_patient_prescriptions_active ON t_9d754153.patient_prescriptions USING btree (clinic_id, patient_id, active);


--
-- Name: idx_patient_prescriptions_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX idx_patient_prescriptions_patient ON t_9d754153.patient_prescriptions USING btree (clinic_id, patient_id);


--
-- Name: idx_tooth_conditions_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX idx_tooth_conditions_patient ON t_9d754153.tooth_conditions USING btree (clinic_id, patient_id);


--
-- Name: ix_ai_conversations_clinic; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_ai_conversations_clinic ON t_9d754153.ai_conversations USING btree (clinic_id);


--
-- Name: ix_appointments_clinic_date; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_appointments_clinic_date ON t_9d754153.appointments USING btree (clinic_id, starts_at, ends_at);


--
-- Name: ix_appointments_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_appointments_patient ON t_9d754153.appointments USING btree (clinic_id, patient_id, starts_at DESC);


--
-- Name: ix_appointments_provider_date; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_appointments_provider_date ON t_9d754153.appointments USING btree (clinic_id, provider_id, starts_at);


--
-- Name: ix_clinical_history_patient_date; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_clinical_history_patient_date ON t_9d754153.clinical_history_entries USING btree (clinic_id, patient_id, entry_date DESC);


--
-- Name: ix_condition_service_defaults_cond; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_condition_service_defaults_cond ON t_9d754153.condition_service_defaults USING btree (clinic_id, condition_name);


--
-- Name: ix_estimate_lines_estimate_position; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimate_lines_estimate_position ON t_9d754153.estimate_lines USING btree (clinic_id, estimate_id, line_position);


--
-- Name: ix_estimate_lines_plan_item; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimate_lines_plan_item ON t_9d754153.estimate_lines USING btree (clinic_id, treatment_plan_item_id) WHERE (treatment_plan_item_id IS NOT NULL);


--
-- Name: ix_estimate_lines_treatment_item; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimate_lines_treatment_item ON t_9d754153.estimate_lines USING btree (clinic_id, treatment_plan_item_id) WHERE (treatment_plan_item_id IS NOT NULL);


--
-- Name: ix_estimates_clinic_patient_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimates_clinic_patient_status ON t_9d754153.estimates USING btree (clinic_id, patient_id, status, created_at DESC);


--
-- Name: ix_estimates_clinic_plan_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimates_clinic_plan_status ON t_9d754153.estimates USING btree (clinic_id, treatment_plan_id, status) WHERE (treatment_plan_id IS NOT NULL);


--
-- Name: ix_estimates_provider; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimates_provider ON t_9d754153.estimates USING btree (clinic_id, created_by_provider_id) WHERE (created_by_provider_id IS NOT NULL);


--
-- Name: ix_estimates_treatment_plan; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_estimates_treatment_plan ON t_9d754153.estimates USING btree (clinic_id, treatment_plan_id) WHERE (treatment_plan_id IS NOT NULL);


--
-- Name: ix_invoice_lines_clinic; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_invoice_lines_clinic ON t_9d754153.invoice_lines USING btree (clinic_id);


--
-- Name: ix_invoice_lines_invoice; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_invoice_lines_invoice ON t_9d754153.invoice_lines USING btree (invoice_id);


--
-- Name: ix_invoices_clinic_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_invoices_clinic_status ON t_9d754153.invoices USING btree (clinic_id, status, invoice_date DESC);


--
-- Name: ix_invoices_estimate; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_invoices_estimate ON t_9d754153.invoices USING btree (clinic_id, estimate_id) WHERE (estimate_id IS NOT NULL);


--
-- Name: ix_invoices_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_invoices_patient ON t_9d754153.invoices USING btree (clinic_id, patient_id);


--
-- Name: ix_invoices_provider; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_invoices_provider ON t_9d754153.invoices USING btree (clinic_id, provider_id) WHERE (provider_id IS NOT NULL);


--
-- Name: ix_odontogram_patient_tooth; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_odontogram_patient_tooth ON t_9d754153.odontogram_teeth USING btree (clinic_id, patient_id, tooth_number, recorded_at DESC);


--
-- Name: ix_patient_anamnesis_patient_current; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_patient_anamnesis_patient_current ON t_9d754153.patient_anamnesis USING btree (clinic_id, patient_id, is_current, recorded_at DESC);


--
-- Name: ix_patient_anamnesis_selections_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_patient_anamnesis_selections_patient ON t_9d754153.patient_anamnesis_item_selections USING btree (clinic_id, patient_id);


--
-- Name: ix_patient_documents_patient_type; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_patient_documents_patient_type ON t_9d754153.patient_documents USING btree (clinic_id, patient_id, document_type, taken_at DESC);


--
-- Name: ix_patients_clinic_name; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_patients_clinic_name ON t_9d754153.patients USING btree (clinic_id, last_name, first_name);


--
-- Name: ix_patients_clinic_phone; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_patients_clinic_phone ON t_9d754153.patients USING btree (clinic_id, phone) WHERE (phone IS NOT NULL);


--
-- Name: ix_patients_primary_provider; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_patients_primary_provider ON t_9d754153.patients USING btree (clinic_id, primary_provider_id) WHERE (primary_provider_id IS NOT NULL);


--
-- Name: ix_products_category; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_products_category ON t_9d754153.products USING btree (clinic_id, category_id);


--
-- Name: ix_products_clinic; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_products_clinic ON t_9d754153.products USING btree (clinic_id) WHERE (is_active = true);


--
-- Name: ix_providers_clinic_active; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_providers_clinic_active ON t_9d754153.providers USING btree (clinic_id, active);


--
-- Name: ix_recall_contacts_recall; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_recall_contacts_recall ON t_9d754153.recall_contacts USING btree (recall_id, contact_at DESC);


--
-- Name: ix_recalls_clinic_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_recalls_clinic_status ON t_9d754153.patient_recalls USING btree (clinic_id, status, due_date);


--
-- Name: ix_recalls_due_date; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_recalls_due_date ON t_9d754153.patient_recalls USING btree (clinic_id, due_date);


--
-- Name: ix_recalls_patient; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_recalls_patient ON t_9d754153.patient_recalls USING btree (clinic_id, patient_id);


--
-- Name: ix_service_bundle_parent; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_service_bundle_parent ON t_9d754153.service_bundle_items USING btree (clinic_id, parent_service_id);


--
-- Name: ix_service_catalog_clinic_active_category; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_service_catalog_clinic_active_category ON t_9d754153.service_catalog USING btree (clinic_id, active, category);


--
-- Name: ix_stock_movements_product; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_stock_movements_product ON t_9d754153.stock_movements USING btree (clinic_id, product_id, created_at DESC);


--
-- Name: ix_suppliers_clinic; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_suppliers_clinic ON t_9d754153.suppliers USING btree (clinic_id) WHERE (is_active = true);


--
-- Name: ix_tooth_conditions_patient_fdi_surface; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_tooth_conditions_patient_fdi_surface ON t_9d754153.tooth_conditions USING btree (clinic_id, patient_id, tooth_fdi, surface);


--
-- Name: ix_treatment_plan_items_plan_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plan_items_plan_status ON t_9d754153.treatment_plan_items USING btree (clinic_id, plan_id, status, priority);


--
-- Name: ix_treatment_plan_items_provider; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plan_items_provider ON t_9d754153.treatment_plan_items USING btree (clinic_id, provider_id) WHERE (provider_id IS NOT NULL);


--
-- Name: ix_treatment_plan_items_service; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plan_items_service ON t_9d754153.treatment_plan_items USING btree (clinic_id, service_catalog_id);


--
-- Name: ix_treatment_plans_clinic_patient_status; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plans_clinic_patient_status ON t_9d754153.treatment_plans USING btree (clinic_id, patient_id, status);


--
-- Name: ix_treatment_plans_status_updated; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plans_status_updated ON t_9d754153.treatment_plans USING btree (clinic_id, status, updated_at DESC);


--
-- Name: ux_clinics_vat_number; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE UNIQUE INDEX ux_clinics_vat_number ON t_9d754153.clinics USING btree (vat_number) WHERE (vat_number IS NOT NULL);


--
-- Name: ux_patients_clinic_fiscal_code; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE UNIQUE INDEX ux_patients_clinic_fiscal_code ON t_9d754153.patients USING btree (clinic_id, fiscal_code) WHERE (fiscal_code IS NOT NULL);


--
-- Name: tenants trg_tenants_updated_at; Type: TRIGGER; Schema: dentalcare; Owner: -
--

CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON dentalcare.tenants FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: ai_conversations trg_ai_conversations_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_ai_conversations_updated_at BEFORE UPDATE ON t_9d754153.ai_conversations FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: appointments trg_appointments_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_appointments_updated_at BEFORE UPDATE ON t_9d754153.appointments FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: clinical_history_entries trg_clinical_history_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_clinical_history_updated_at BEFORE UPDATE ON t_9d754153.clinical_history_entries FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: clinics trg_clinics_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_clinics_updated_at BEFORE UPDATE ON t_9d754153.clinics FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: estimates trg_estimates_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_estimates_updated_at BEFORE UPDATE ON t_9d754153.estimates FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: invoice_lines trg_invoice_line_compute_totals; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_invoice_line_compute_totals BEFORE INSERT OR UPDATE ON t_9d754153.invoice_lines FOR EACH ROW EXECUTE FUNCTION t_9d754153.trg_compute_invoice_line_totals();


--
-- Name: invoice_lines trg_invoice_lines_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_invoice_lines_updated_at BEFORE UPDATE ON t_9d754153.invoice_lines FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: invoice_lines trg_invoices_recalc_from_lines; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_invoices_recalc_from_lines AFTER INSERT OR DELETE OR UPDATE ON t_9d754153.invoice_lines FOR EACH ROW EXECUTE FUNCTION t_9d754153.trg_update_invoice_totals_from_lines();


--
-- Name: invoices trg_invoices_set_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_invoices_set_updated_at BEFORE UPDATE ON t_9d754153.invoices FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: odontogram_teeth trg_odontogram_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_odontogram_updated_at BEFORE UPDATE ON t_9d754153.odontogram_teeth FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patient_anamnesis_item_selections trg_patient_anamnesis_selections_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_patient_anamnesis_selections_updated_at BEFORE UPDATE ON t_9d754153.patient_anamnesis_item_selections FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patient_anamnesis trg_patient_anamnesis_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_patient_anamnesis_updated_at BEFORE UPDATE ON t_9d754153.patient_anamnesis FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patient_diagnoses trg_patient_diagnoses_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_patient_diagnoses_updated_at BEFORE UPDATE ON t_9d754153.patient_diagnoses FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patient_documents trg_patient_documents_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_patient_documents_updated_at BEFORE UPDATE ON t_9d754153.patient_documents FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patient_prescriptions trg_patient_prescriptions_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_patient_prescriptions_updated_at BEFORE UPDATE ON t_9d754153.patient_prescriptions FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patients trg_patients_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_patients_updated_at BEFORE UPDATE ON t_9d754153.patients FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: products trg_products_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON t_9d754153.products FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: providers trg_providers_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_providers_updated_at BEFORE UPDATE ON t_9d754153.providers FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: patient_recalls trg_recalls_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_recalls_updated_at BEFORE UPDATE ON t_9d754153.patient_recalls FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: service_catalog trg_service_catalog_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_service_catalog_updated_at BEFORE UPDATE ON t_9d754153.service_catalog FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: suppliers trg_suppliers_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_suppliers_updated_at BEFORE UPDATE ON t_9d754153.suppliers FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: treatment_plan_items trg_treatment_plan_items_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_treatment_plan_items_updated_at BEFORE UPDATE ON t_9d754153.treatment_plan_items FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: treatment_plans trg_treatment_plans_updated_at; Type: TRIGGER; Schema: t_9d754153; Owner: -
--

CREATE TRIGGER trg_treatment_plans_updated_at BEFORE UPDATE ON t_9d754153.treatment_plans FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();


--
-- Name: anamnesis_items anamnesis_items_category_id_fkey; Type: FK CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.anamnesis_items
    ADD CONSTRAINT anamnesis_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES dentalcare.anamnesis_categories(id) ON DELETE CASCADE;


--
-- Name: cities cities_region_id_fkey; Type: FK CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.cities
    ADD CONSTRAINT cities_region_id_fkey FOREIGN KEY (region_id) REFERENCES dentalcare.regions(id);


--
-- Name: national_holidays national_holidays_state_id_fkey; Type: FK CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.national_holidays
    ADD CONSTRAINT national_holidays_state_id_fkey FOREIGN KEY (state_id) REFERENCES dentalcare.states(id);


--
-- Name: regions regions_state_id_fkey; Type: FK CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.regions
    ADD CONSTRAINT regions_state_id_fkey FOREIGN KEY (state_id) REFERENCES dentalcare.states(id);


--
-- Name: tenant_clinics tenant_clinics_tenant_id_fkey; Type: FK CONSTRAINT; Schema: dentalcare; Owner: -
--

ALTER TABLE ONLY dentalcare.tenant_clinics
    ADD CONSTRAINT tenant_clinics_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES dentalcare.tenants(id) ON DELETE CASCADE;


--
-- Name: ai_conversations ai_conversations_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.ai_conversations
    ADD CONSTRAINT ai_conversations_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: ai_conversations ai_conversations_patient_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.ai_conversations
    ADD CONSTRAINT ai_conversations_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES t_9d754153.patients(id) ON DELETE SET NULL;


--
-- Name: ai_conversations ai_conversations_provider_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.ai_conversations
    ADD CONSTRAINT ai_conversations_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES t_9d754153.providers(id) ON DELETE SET NULL;


--
-- Name: appointments appointments_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.appointments
    ADD CONSTRAINT appointments_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.chat_messages
    ADD CONSTRAINT chat_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES t_9d754153.chat_sessions(id) ON DELETE CASCADE;


--
-- Name: clinical_history_entries clinical_history_entries_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinical_history_entries
    ADD CONSTRAINT clinical_history_entries_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: clinics clinics_city_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinics
    ADD CONSTRAINT clinics_city_id_fkey FOREIGN KEY (city_id) REFERENCES dentalcare.cities(id);


--
-- Name: condition_service_defaults condition_service_defaults_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: condition_service_defaults condition_service_defaults_service_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_service_id_fkey FOREIGN KEY (service_id) REFERENCES t_9d754153.service_catalog(id) ON DELETE CASCADE;


--
-- Name: estimate_lines estimate_lines_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimate_lines
    ADD CONSTRAINT estimate_lines_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: estimates estimates_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimates
    ADD CONSTRAINT estimates_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: appointments fk_appointments_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.appointments
    ADD CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: appointments fk_appointments_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.appointments
    ADD CONSTRAINT fk_appointments_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: appointments fk_appointments_treatment_item; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.appointments
    ADD CONSTRAINT fk_appointments_treatment_item FOREIGN KEY (treatment_plan_item_id) REFERENCES t_9d754153.treatment_plan_items(id) ON DELETE SET NULL;


--
-- Name: service_bundle_items fk_bundle_child; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_bundle_items
    ADD CONSTRAINT fk_bundle_child FOREIGN KEY (child_service_id) REFERENCES t_9d754153.service_catalog(id) ON DELETE CASCADE;


--
-- Name: service_bundle_items fk_bundle_parent; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_bundle_items
    ADD CONSTRAINT fk_bundle_parent FOREIGN KEY (parent_service_id) REFERENCES t_9d754153.service_catalog(id) ON DELETE CASCADE;


--
-- Name: clinical_history_entries fk_clinical_history_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinical_history_entries
    ADD CONSTRAINT fk_clinical_history_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: clinical_history_entries fk_clinical_history_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.clinical_history_entries
    ADD CONSTRAINT fk_clinical_history_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: estimate_lines fk_estimate_lines_estimate; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimate_lines
    ADD CONSTRAINT fk_estimate_lines_estimate FOREIGN KEY (estimate_id, clinic_id) REFERENCES t_9d754153.estimates(id, clinic_id) ON DELETE CASCADE;


--
-- Name: estimate_lines fk_estimate_lines_service; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimate_lines
    ADD CONSTRAINT fk_estimate_lines_service FOREIGN KEY (service_id, clinic_id) REFERENCES t_9d754153.service_catalog(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: estimate_lines fk_estimate_lines_treatment_item; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimate_lines
    ADD CONSTRAINT fk_estimate_lines_treatment_item FOREIGN KEY (treatment_plan_item_id, clinic_id) REFERENCES t_9d754153.treatment_plan_items(id, clinic_id) ON DELETE CASCADE;


--
-- Name: estimates fk_estimates_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimates
    ADD CONSTRAINT fk_estimates_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: estimates fk_estimates_treatment_plan; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.estimates
    ADD CONSTRAINT fk_estimates_treatment_plan FOREIGN KEY (treatment_plan_id, clinic_id) REFERENCES t_9d754153.treatment_plans(id, clinic_id) ON DELETE CASCADE;


--
-- Name: invoice_lines fk_invoice_lines_clinic; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoice_lines
    ADD CONSTRAINT fk_invoice_lines_clinic FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: invoice_lines fk_invoice_lines_invoice; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoice_lines
    ADD CONSTRAINT fk_invoice_lines_invoice FOREIGN KEY (invoice_id) REFERENCES t_9d754153.invoices(id) ON DELETE CASCADE;


--
-- Name: invoices fk_invoices_estimate; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT fk_invoices_estimate FOREIGN KEY (estimate_id, clinic_id) REFERENCES t_9d754153.estimates(id, clinic_id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: invoices fk_invoices_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT fk_invoices_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: invoices fk_invoices_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT fk_invoices_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: odontogram_teeth fk_odontogram_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.odontogram_teeth
    ADD CONSTRAINT fk_odontogram_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: odontogram_teeth fk_odontogram_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.odontogram_teeth
    ADD CONSTRAINT fk_odontogram_provider FOREIGN KEY (recorded_by_provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: patient_anamnesis_item_selections fk_pais_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT fk_pais_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_anamnesis fk_patient_anamnesis_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis
    ADD CONSTRAINT fk_patient_anamnesis_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_anamnesis fk_patient_anamnesis_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis
    ADD CONSTRAINT fk_patient_anamnesis_provider FOREIGN KEY (recorded_by_provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: patient_diagnoses fk_patient_diagnoses_clinic; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_diagnoses
    ADD CONSTRAINT fk_patient_diagnoses_clinic FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patient_diagnoses fk_patient_diagnoses_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_diagnoses
    ADD CONSTRAINT fk_patient_diagnoses_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_diagnoses fk_patient_diagnoses_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_diagnoses
    ADD CONSTRAINT fk_patient_diagnoses_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: patient_documents fk_patient_documents_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_documents
    ADD CONSTRAINT fk_patient_documents_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_documents fk_patient_documents_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_documents
    ADD CONSTRAINT fk_patient_documents_provider FOREIGN KEY (uploaded_by_provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: patient_prescriptions fk_patient_prescriptions_clinic; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_prescriptions
    ADD CONSTRAINT fk_patient_prescriptions_clinic FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patient_prescriptions fk_patient_prescriptions_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_prescriptions
    ADD CONSTRAINT fk_patient_prescriptions_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_prescriptions fk_patient_prescriptions_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_prescriptions
    ADD CONSTRAINT fk_patient_prescriptions_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: products fk_products_category; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.products
    ADD CONSTRAINT fk_products_category FOREIGN KEY (category_id, clinic_id) REFERENCES t_9d754153.product_categories(id, clinic_id) ON DELETE SET NULL;


--
-- Name: products fk_products_supplier; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.products
    ADD CONSTRAINT fk_products_supplier FOREIGN KEY (supplier_id, clinic_id) REFERENCES t_9d754153.suppliers(id, clinic_id) ON DELETE SET NULL;


--
-- Name: recall_contacts fk_recall_contacts_recall; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.recall_contacts
    ADD CONSTRAINT fk_recall_contacts_recall FOREIGN KEY (recall_id, clinic_id) REFERENCES t_9d754153.patient_recalls(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_recalls fk_recalls_booked_apt; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_recalls
    ADD CONSTRAINT fk_recalls_booked_apt FOREIGN KEY (booked_appointment_id) REFERENCES t_9d754153.appointments(id) ON DELETE SET NULL;


--
-- Name: patient_recalls fk_recalls_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_recalls
    ADD CONSTRAINT fk_recalls_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: patient_recalls fk_recalls_source_apt; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_recalls
    ADD CONSTRAINT fk_recalls_source_apt FOREIGN KEY (source_appointment_id) REFERENCES t_9d754153.appointments(id) ON DELETE SET NULL;


--
-- Name: stock_movements fk_stock_movements_product; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.stock_movements
    ADD CONSTRAINT fk_stock_movements_product FOREIGN KEY (product_id, clinic_id) REFERENCES t_9d754153.products(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: treatment_plan_items fk_treatment_plan_items_plan; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_plan FOREIGN KEY (plan_id, clinic_id) REFERENCES t_9d754153.treatment_plans(id, clinic_id) ON DELETE CASCADE;


--
-- Name: treatment_plan_items fk_treatment_plan_items_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: treatment_plan_items fk_treatment_plan_items_service; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_service FOREIGN KEY (service_catalog_id, clinic_id) REFERENCES t_9d754153.service_catalog(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: treatment_plans fk_treatment_plans_patient; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plans
    ADD CONSTRAINT fk_treatment_plans_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES t_9d754153.patients(id, clinic_id) ON DELETE CASCADE;


--
-- Name: treatment_plans fk_treatment_plans_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plans
    ADD CONSTRAINT fk_treatment_plans_provider FOREIGN KEY (created_by_provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: invoices invoices_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.invoices
    ADD CONSTRAINT invoices_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: odontogram_teeth odontogram_teeth_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.odontogram_teeth
    ADD CONSTRAINT odontogram_teeth_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patient_anamnesis patient_anamnesis_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patient_anamnesis_item_selections patient_anamnesis_item_selections_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patient_anamnesis_item_selections patient_anamnesis_item_selections_item_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey FOREIGN KEY (item_id) REFERENCES dentalcare.anamnesis_items(id) ON DELETE CASCADE;


--
-- Name: patient_documents patient_documents_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_documents
    ADD CONSTRAINT patient_documents_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patient_recalls patient_recalls_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patient_recalls
    ADD CONSTRAINT patient_recalls_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: patients patients_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patients
    ADD CONSTRAINT patients_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: patients patients_primary_provider_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.patients
    ADD CONSTRAINT patients_primary_provider_id_fkey FOREIGN KEY (primary_provider_id) REFERENCES t_9d754153.providers(id) ON DELETE SET NULL;


--
-- Name: product_categories product_categories_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.product_categories
    ADD CONSTRAINT product_categories_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: products products_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.products
    ADD CONSTRAINT products_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: providers providers_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.providers
    ADD CONSTRAINT providers_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: recall_contacts recall_contacts_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.recall_contacts
    ADD CONSTRAINT recall_contacts_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: service_bundle_items service_bundle_items_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_bundle_items
    ADD CONSTRAINT service_bundle_items_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: service_catalog service_catalog_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.service_catalog
    ADD CONSTRAINT service_catalog_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: stock_movements stock_movements_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.stock_movements
    ADD CONSTRAINT stock_movements_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: suppliers suppliers_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.suppliers
    ADD CONSTRAINT suppliers_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE RESTRICT;


--
-- Name: treatment_plan_items treatment_plan_items_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- Name: treatment_plans treatment_plans_clinic_id_fkey; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plans
    ADD CONSTRAINT treatment_plans_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES t_9d754153.clinics(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict lNAdE5IhYi17M1sN2xgfhCuIzN8zuHt8fQas73pWLY45tqDAQ4azNGnYO7YJ260


--
-- Registry demo-only: tenant + mappatura clinica demo
--
INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active, created_at, updated_at) VALUES ('a0000001-0000-0000-0000-000000000001', 'Clinica Demo DentalCare', 't_9d754153', 'demo@dentalcare.it', NULL, 'professional', true, '2026-05-17T13:11:14.678307+00:00', '2026-05-29T13:52:49.317940+00:00');
INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id, created_at) VALUES ('9d754153-6579-4b7e-a56b-025f00299cd9', 'a0000001-0000-0000-0000-000000000001', '2026-05-29T13:52:49.317940+00:00');
