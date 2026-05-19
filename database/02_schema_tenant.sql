-- =============================================================================
-- DentalCare Pro - Schema Operativo Tenant
-- File: 02_schema_tenant.sql
-- Descrizione: Crea tutte le tabelle, funzioni, trigger e viste operative
--              per uno schema tenant. Idempotente (IF NOT EXISTS).
--              Allineato al live DB (schema_dump_live.sql, t_9d754153).
--
-- Uso:
--   psql -v tenant_schema=t_9d754153 -f 02_schema_tenant.sql
--
-- Con tablespace dedicato (opzionale):
--   psql -v tenant_schema=t_9d754153 -v tenant_tablespace=ts_t_9d754153 \
--        -f 02_schema_tenant.sql
--
-- Prerequisiti:
--   - 01_schema_applicative.sql applicato (enum globali in schema dentalcare)
--   - La variabile psql :tenant_schema deve essere valorizzata
--   - Se :tenant_tablespace e' specificato, il tablespace deve gia' esistere
-- =============================================================================

\set ON_ERROR_STOP on

-- Se tenant_tablespace non e' specificato, usa pg_default
\if :{?tenant_tablespace}
\else
\set tenant_tablespace pg_default
\endif

BEGIN;

-- Crea lo schema tenant se non esiste
CREATE SCHEMA IF NOT EXISTS :"tenant_schema";

-- Imposta search_path: prima lo schema tenant, poi dentalcare per gli enum globali
SET search_path TO :"tenant_schema", dentalcare, public;

-- =============================================================================
-- 1. CLINICS
-- Anagrafica della clinica. Ogni tenant puo' avere piu' cliniche.
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinics (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    name           text        NOT NULL,
    legal_name     text,
    vat_number     text,
    fiscal_code    text,
    phone          text,
    address_line1  text,
    address_line2  text,
    city           text,
    province       text,
    postal_code    text,
    country        text        NOT NULL DEFAULT 'IT',
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    city_id        uuid,
    CONSTRAINT clinics_pkey PRIMARY KEY (id),
    CONSTRAINT clinics_name_not_empty CHECK (length(TRIM(BOTH FROM name)) > 0)
) TABLESPACE :"tenant_tablespace";

CREATE UNIQUE INDEX IF NOT EXISTS ux_clinics_vat_number
    ON clinics (vat_number)
    TABLESPACE :"tenant_tablespace"
    WHERE vat_number IS NOT NULL;

DROP TRIGGER IF EXISTS trg_clinics_updated_at ON clinics;
CREATE TRIGGER trg_clinics_updated_at
BEFORE UPDATE ON clinics
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 2. PATIENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patients (
    id            uuid        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id     uuid        NOT NULL,
    first_name    text        NOT NULL,
    last_name     text        NOT NULL,
    fiscal_code   text,
    birth_date    date,
    phone         text,
    email         text,
    address_line1 text,
    address_line2 text,
    city          text,
    province      text,
    postal_code   text,
    country       text        NOT NULL DEFAULT 'IT',
    notes         text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    photo_url     text,
    CONSTRAINT patients_pkey PRIMARY KEY (id),
    CONSTRAINT patients_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT patients_first_name_not_empty CHECK (length(TRIM(BOTH FROM first_name)) > 0),
    CONSTRAINT patients_last_name_not_empty  CHECK (length(TRIM(BOTH FROM last_name)) > 0)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE patients
    DROP CONSTRAINT IF EXISTS patients_clinic_id_fkey;
ALTER TABLE patients
    ADD CONSTRAINT patients_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS ux_patients_clinic_fiscal_code
    ON patients (clinic_id, fiscal_code)
    TABLESPACE :"tenant_tablespace"
    WHERE fiscal_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_patients_clinic_name
    ON patients (clinic_id, last_name, first_name)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_patients_clinic_phone
    ON patients (clinic_id, phone)
    TABLESPACE :"tenant_tablespace"
    WHERE phone IS NOT NULL;

DROP TRIGGER IF EXISTS trg_patients_updated_at ON patients;
CREATE TRIGGER trg_patients_updated_at
BEFORE UPDATE ON patients
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 3. PROVIDERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS providers (
    id                       uuid                    NOT NULL DEFAULT gen_random_uuid(),
    clinic_id                uuid                    NOT NULL,
    first_name               text                    NOT NULL,
    last_name                text                    NOT NULL,
    role                     dentalcare.provider_role NOT NULL DEFAULT 'dentist',
    phone                    text,
    email                    text,
    active                   boolean                 NOT NULL DEFAULT true,
    created_at               timestamptz             NOT NULL DEFAULT now(),
    updated_at               timestamptz             NOT NULL DEFAULT now(),
    vat_number               text,
    fiscal_code              text,
    professional_register    text,
    register_number          text,
    billing_address_street   text,
    billing_address_zip      text,
    billing_address_city     text,
    billing_address_province text,
    billing_pec              text,
    billing_iban             text,
    billing_sdi_code         text,
    invoice_prefix           text                    DEFAULT 'PARC',
    photo_url                text,
    CONSTRAINT providers_pkey PRIMARY KEY (id),
    CONSTRAINT providers_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT providers_first_name_not_empty CHECK (length(TRIM(BOTH FROM first_name)) > 0),
    CONSTRAINT providers_last_name_not_empty  CHECK (length(TRIM(BOTH FROM last_name)) > 0)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE providers
    DROP CONSTRAINT IF EXISTS providers_clinic_id_fkey;
ALTER TABLE providers
    ADD CONSTRAINT providers_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_providers_clinic_active
    ON providers (clinic_id, active)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_providers_updated_at ON providers;
CREATE TRIGGER trg_providers_updated_at
BEFORE UPDATE ON providers
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 4. SERVICE_CATALOG
-- =============================================================================

CREATE TABLE IF NOT EXISTS service_catalog (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id               uuid          NOT NULL,
    code                    text          NOT NULL,
    name                    text          NOT NULL,
    category                text,
    description             text,
    default_price           numeric(12,2) NOT NULL DEFAULT 0,
    default_vat_rate        numeric(5,2)  NOT NULL DEFAULT 0,
    active                  boolean       NOT NULL DEFAULT true,
    created_at              timestamptz   NOT NULL DEFAULT now(),
    updated_at              timestamptz   NOT NULL DEFAULT now(),
    duration_minutes        integer,
    min_tooth_digit         integer,
    max_tooth_digit         integer,
    applicable_to_deciduous boolean       NOT NULL DEFAULT true,
    CONSTRAINT service_catalog_pkey PRIMARY KEY (id),
    CONSTRAINT service_catalog_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT ux_service_catalog_clinic_code UNIQUE (clinic_id, code),
    CONSTRAINT service_catalog_code_not_empty CHECK (length(TRIM(BOTH FROM code)) > 0),
    CONSTRAINT service_catalog_name_not_empty CHECK (length(TRIM(BOTH FROM name)) > 0),
    CONSTRAINT service_catalog_default_price_non_negative CHECK (default_price >= 0),
    CONSTRAINT service_catalog_default_vat_rate_range CHECK (default_vat_rate >= 0 AND default_vat_rate <= 100)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE service_catalog
    DROP CONSTRAINT IF EXISTS service_catalog_clinic_id_fkey;
ALTER TABLE service_catalog
    ADD CONSTRAINT service_catalog_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_service_catalog_clinic_active_category
    ON service_catalog (clinic_id, active, category)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_service_catalog_updated_at ON service_catalog;
CREATE TRIGGER trg_service_catalog_updated_at
BEFORE UPDATE ON service_catalog
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 5. TREATMENT_PLANS
-- =============================================================================

CREATE TABLE IF NOT EXISTS treatment_plans (
    id                     uuid                            NOT NULL DEFAULT gen_random_uuid(),
    clinic_id              uuid                            NOT NULL,
    patient_id             uuid                            NOT NULL,
    name                   text                            NOT NULL DEFAULT 'Piano di cura',
    description            text,
    status                 dentalcare.treatment_plan_status NOT NULL DEFAULT 'draft',
    created_by_provider_id uuid,
    proposed_at            timestamptz,
    accepted_at            timestamptz,
    completed_at           timestamptz,
    rejected_at            timestamptz,
    created_at             timestamptz                     NOT NULL DEFAULT now(),
    updated_at             timestamptz                     NOT NULL DEFAULT now(),
    CONSTRAINT treatment_plans_pkey PRIMARY KEY (id),
    CONSTRAINT treatment_plans_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT treatment_plans_name_not_empty CHECK (length(TRIM(BOTH FROM name)) > 0)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE treatment_plans
    DROP CONSTRAINT IF EXISTS treatment_plans_clinic_id_fkey;
ALTER TABLE treatment_plans
    ADD CONSTRAINT treatment_plans_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE treatment_plans
    DROP CONSTRAINT IF EXISTS fk_treatment_plans_patient;
ALTER TABLE treatment_plans
    ADD CONSTRAINT fk_treatment_plans_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE treatment_plans
    DROP CONSTRAINT IF EXISTS fk_treatment_plans_provider;
ALTER TABLE treatment_plans
    ADD CONSTRAINT fk_treatment_plans_provider
        FOREIGN KEY (created_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_treatment_plans_clinic_patient_status
    ON treatment_plans (clinic_id, patient_id, status)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_treatment_plans_status_updated
    ON treatment_plans (clinic_id, status, updated_at DESC)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_treatment_plans_updated_at ON treatment_plans;
CREATE TRIGGER trg_treatment_plans_updated_at
BEFORE UPDATE ON treatment_plans
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 6. TREATMENT_PLAN_ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS treatment_plan_items (
    id                  uuid                             NOT NULL DEFAULT gen_random_uuid(),
    clinic_id           uuid                             NOT NULL,
    treatment_plan_id   uuid                             NOT NULL,
    service_id          uuid                             NOT NULL,
    provider_id         uuid,
    tooth_number        text,
    quadrant            smallint,
    surfaces            text[],
    quantity            numeric(10,2)                    NOT NULL DEFAULT 1,
    planned_price       numeric(12,2)                    NOT NULL DEFAULT 0,
    planned_vat_rate    numeric(5,2)                     NOT NULL DEFAULT 0,
    clinical_notes      text,
    status              dentalcare.treatment_item_status NOT NULL DEFAULT 'planned',
    priority            integer                          NOT NULL DEFAULT 100,
    planned_date        date,
    completed_at        timestamptz,
    created_at          timestamptz                      NOT NULL DEFAULT now(),
    updated_at          timestamptz                      NOT NULL DEFAULT now(),
    CONSTRAINT treatment_plan_items_pkey PRIMARY KEY (id),
    CONSTRAINT treatment_plan_items_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT treatment_plan_items_price_non_negative CHECK (planned_price >= 0),
    CONSTRAINT treatment_plan_items_quadrant_range CHECK (quadrant IS NULL OR (quadrant >= 1 AND quadrant <= 4)),
    CONSTRAINT treatment_plan_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT treatment_plan_items_vat_rate_range CHECK (planned_vat_rate >= 0 AND planned_vat_rate <= 100)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE treatment_plan_items
    DROP CONSTRAINT IF EXISTS treatment_plan_items_clinic_id_fkey;
ALTER TABLE treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE treatment_plan_items
    DROP CONSTRAINT IF EXISTS fk_treatment_plan_items_plan;
ALTER TABLE treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_plan
        FOREIGN KEY (treatment_plan_id, clinic_id) REFERENCES treatment_plans(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE treatment_plan_items
    DROP CONSTRAINT IF EXISTS fk_treatment_plan_items_service;
ALTER TABLE treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_service
        FOREIGN KEY (service_id, clinic_id) REFERENCES service_catalog(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE treatment_plan_items
    DROP CONSTRAINT IF EXISTS fk_treatment_plan_items_provider;
ALTER TABLE treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_provider
        FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_plan_status
    ON treatment_plan_items (clinic_id, treatment_plan_id, status, priority)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_service
    ON treatment_plan_items (clinic_id, service_id)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_provider
    ON treatment_plan_items (clinic_id, provider_id)
    TABLESPACE :"tenant_tablespace"
    WHERE provider_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_treatment_plan_items_updated_at ON treatment_plan_items;
CREATE TRIGGER trg_treatment_plan_items_updated_at
BEFORE UPDATE ON treatment_plan_items
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 7. APPOINTMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS appointments (
    id                     uuid                       NOT NULL DEFAULT gen_random_uuid(),
    clinic_id              uuid                       NOT NULL,
    patient_id             uuid                       NOT NULL,
    provider_id            uuid                       NOT NULL,
    treatment_plan_item_id uuid,
    chair_label            text                       NOT NULL DEFAULT 'Poltrona 1',
    starts_at              timestamptz                NOT NULL,
    ends_at                timestamptz                NOT NULL,
    status                 dentalcare.appointment_status NOT NULL DEFAULT 'scheduled',
    notes                  text,
    cancellation_reason    text,
    created_at             timestamptz                NOT NULL DEFAULT now(),
    updated_at             timestamptz                NOT NULL DEFAULT now(),
    CONSTRAINT appointments_pkey PRIMARY KEY (id),
    CONSTRAINT appointments_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT appointments_dates_valid CHECK (ends_at > starts_at)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE appointments
    DROP CONSTRAINT IF EXISTS appointments_clinic_id_fkey;
ALTER TABLE appointments
    ADD CONSTRAINT appointments_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE appointments
    DROP CONSTRAINT IF EXISTS fk_appointments_patient;
ALTER TABLE appointments
    ADD CONSTRAINT fk_appointments_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE appointments
    DROP CONSTRAINT IF EXISTS fk_appointments_provider;
ALTER TABLE appointments
    ADD CONSTRAINT fk_appointments_provider
        FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE appointments
    DROP CONSTRAINT IF EXISTS fk_appointments_treatment_item;
ALTER TABLE appointments
    ADD CONSTRAINT fk_appointments_treatment_item
        FOREIGN KEY (treatment_plan_item_id) REFERENCES treatment_plan_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_date
    ON appointments (clinic_id, starts_at, ends_at)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_appointments_patient
    ON appointments (clinic_id, patient_id, starts_at DESC)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_appointments_provider_date
    ON appointments (clinic_id, provider_id, starts_at)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 8. ESTIMATES
-- =============================================================================

CREATE TABLE IF NOT EXISTS estimates (
    id                     uuid                       NOT NULL DEFAULT gen_random_uuid(),
    clinic_id              uuid                       NOT NULL,
    patient_id             uuid                       NOT NULL,
    treatment_plan_id      uuid,
    estimate_number        text                       NOT NULL,
    version                integer                    NOT NULL DEFAULT 1,
    status                 dentalcare.estimate_status NOT NULL DEFAULT 'draft',
    title                  text                       NOT NULL DEFAULT 'Preventivo',
    notes                  text,
    currency               char(3)                    NOT NULL DEFAULT 'EUR',
    subtotal_amount        numeric(12,2)              NOT NULL DEFAULT 0,
    discount_amount        numeric(12,2)              NOT NULL DEFAULT 0,
    taxable_amount         numeric(12,2)              NOT NULL DEFAULT 0,
    vat_amount             numeric(12,2)              NOT NULL DEFAULT 0,
    total_amount           numeric(12,2)              NOT NULL DEFAULT 0,
    issued_at              timestamptz,
    sent_at                timestamptz,
    valid_until            date,
    accepted_at            timestamptz,
    rejected_at            timestamptz,
    created_at             timestamptz                NOT NULL DEFAULT now(),
    updated_at             timestamptz                NOT NULL DEFAULT now(),
    created_by_provider_id uuid,
    CONSTRAINT estimates_pkey PRIMARY KEY (id),
    CONSTRAINT estimates_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT ux_estimates_clinic_number UNIQUE (clinic_id, estimate_number),
    CONSTRAINT estimates_amounts_non_negative CHECK (
        subtotal_amount >= 0 AND discount_amount >= 0 AND
        taxable_amount  >= 0 AND vat_amount      >= 0 AND total_amount >= 0
    ),
    CONSTRAINT estimates_currency_upper CHECK ((currency)::text = upper((currency)::text)),
    CONSTRAINT estimates_version_positive CHECK (version > 0)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE estimates
    DROP CONSTRAINT IF EXISTS estimates_clinic_id_fkey;
ALTER TABLE estimates
    ADD CONSTRAINT estimates_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE estimates
    DROP CONSTRAINT IF EXISTS fk_estimates_patient;
ALTER TABLE estimates
    ADD CONSTRAINT fk_estimates_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE estimates
    DROP CONSTRAINT IF EXISTS fk_estimates_treatment_plan;
ALTER TABLE estimates
    ADD CONSTRAINT fk_estimates_treatment_plan
        FOREIGN KEY (treatment_plan_id, clinic_id) REFERENCES treatment_plans(id, clinic_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_patient_status
    ON estimates (clinic_id, patient_id, status, created_at DESC)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_plan_status
    ON estimates (clinic_id, treatment_plan_id, status)
    TABLESPACE :"tenant_tablespace"
    WHERE treatment_plan_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_estimates_treatment_plan
    ON estimates (clinic_id, treatment_plan_id)
    TABLESPACE :"tenant_tablespace"
    WHERE treatment_plan_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_estimates_provider
    ON estimates (clinic_id, created_by_provider_id)
    TABLESPACE :"tenant_tablespace"
    WHERE created_by_provider_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimates_updated_at ON estimates;
CREATE TRIGGER trg_estimates_updated_at
BEFORE UPDATE ON estimates
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 9. ESTIMATE_LINES
-- =============================================================================

CREATE TABLE IF NOT EXISTS estimate_lines (
    id                     uuid          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id              uuid          NOT NULL,
    estimate_id            uuid          NOT NULL,
    treatment_plan_item_id uuid,
    service_id             uuid,
    line_position          integer       NOT NULL DEFAULT 1,
    description_snapshot   text          NOT NULL,
    tooth_snapshot         text,
    quantity               numeric(10,2) NOT NULL DEFAULT 1,
    unit_price             numeric(12,2) NOT NULL DEFAULT 0,
    discount_amount        numeric(12,2) NOT NULL DEFAULT 0,
    vat_rate               numeric(5,2)  NOT NULL DEFAULT 0,
    line_subtotal          numeric(12,2) GENERATED ALWAYS AS (round(quantity * unit_price, 2)) STORED,
    line_taxable           numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(quantity * unit_price - discount_amount, 0), 2)) STORED,
    line_vat_amount        numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(quantity * unit_price - discount_amount, 0) * vat_rate / 100, 2)) STORED,
    line_total             numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(quantity * unit_price - discount_amount, 0) + GREATEST(quantity * unit_price - discount_amount, 0) * vat_rate / 100, 2)) STORED,
    created_at             timestamptz   NOT NULL DEFAULT now(),
    updated_at             timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT estimate_lines_pkey PRIMARY KEY (id),
    CONSTRAINT estimate_lines_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT estimate_lines_description_not_empty CHECK (length(TRIM(BOTH FROM description_snapshot)) > 0),
    CONSTRAINT estimate_lines_discount_non_negative CHECK (discount_amount >= 0),
    CONSTRAINT estimate_lines_position_positive CHECK (line_position > 0),
    CONSTRAINT estimate_lines_quantity_positive CHECK (quantity > 0),
    CONSTRAINT estimate_lines_unit_price_non_negative CHECK (unit_price >= 0),
    CONSTRAINT estimate_lines_vat_rate_range CHECK (vat_rate >= 0 AND vat_rate <= 100)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE estimate_lines
    DROP CONSTRAINT IF EXISTS estimate_lines_clinic_id_fkey;
ALTER TABLE estimate_lines
    ADD CONSTRAINT estimate_lines_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE estimate_lines
    DROP CONSTRAINT IF EXISTS fk_estimate_lines_estimate;
ALTER TABLE estimate_lines
    ADD CONSTRAINT fk_estimate_lines_estimate
        FOREIGN KEY (estimate_id, clinic_id) REFERENCES estimates(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE estimate_lines
    DROP CONSTRAINT IF EXISTS fk_estimate_lines_service;
ALTER TABLE estimate_lines
    ADD CONSTRAINT fk_estimate_lines_service
        FOREIGN KEY (service_id, clinic_id) REFERENCES service_catalog(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE estimate_lines
    DROP CONSTRAINT IF EXISTS fk_estimate_lines_treatment_item;
ALTER TABLE estimate_lines
    ADD CONSTRAINT fk_estimate_lines_treatment_item
        FOREIGN KEY (treatment_plan_item_id, clinic_id) REFERENCES treatment_plan_items(id, clinic_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_estimate_lines_estimate_position
    ON estimate_lines (clinic_id, estimate_id, line_position)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_estimate_lines_plan_item
    ON estimate_lines (clinic_id, treatment_plan_item_id)
    TABLESPACE :"tenant_tablespace"
    WHERE treatment_plan_item_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_estimate_lines_treatment_item
    ON estimate_lines (clinic_id, treatment_plan_item_id)
    TABLESPACE :"tenant_tablespace"
    WHERE treatment_plan_item_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimate_lines_recalc_totals ON estimate_lines;
CREATE TRIGGER trg_estimate_lines_recalc_totals
AFTER INSERT OR DELETE OR UPDATE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION dentalcare.trg_recalc_estimate_totals();

DROP TRIGGER IF EXISTS trg_estimate_lines_updated_at ON estimate_lines;
CREATE TRIGGER trg_estimate_lines_updated_at
BEFORE UPDATE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 10. INVOICES
-- =============================================================================

CREATE TABLE IF NOT EXISTS invoices (
    id                  uuid                          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id           uuid                          NOT NULL,
    invoice_number      text                          NOT NULL,
    document_type       dentalcare.invoice_document_type NOT NULL DEFAULT 'fattura',
    invoice_date        date                          NOT NULL DEFAULT CURRENT_DATE,
    due_date            date,
    status              dentalcare.invoice_status     NOT NULL DEFAULT 'draft',
    issuer_type         dentalcare.invoice_issuer_type NOT NULL DEFAULT 'clinic',
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
) TABLESPACE :"tenant_tablespace";

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
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_invoices_patient
    ON invoices (clinic_id, patient_id)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_invoices_estimate
    ON invoices (clinic_id, estimate_id)
    TABLESPACE :"tenant_tablespace"
    WHERE estimate_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_invoices_provider
    ON invoices (clinic_id, provider_id)
    TABLESPACE :"tenant_tablespace"
    WHERE provider_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_invoices_set_updated_at ON invoices;
CREATE TRIGGER trg_invoices_set_updated_at
BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 11. PATIENT_ANAMNESIS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_anamnesis (
    id                       uuid        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id                uuid        NOT NULL,
    patient_id               uuid        NOT NULL,
    recorded_at              timestamptz NOT NULL DEFAULT now(),
    recorded_by_provider_id  uuid,
    blood_type               text,
    smoker                   boolean,
    cigarettes_per_day       smallint,
    alcohol_use              boolean,
    drug_use                 boolean,
    hypertension             boolean     NOT NULL DEFAULT false,
    diabetes                 boolean     NOT NULL DEFAULT false,
    diabetes_type            text,
    heart_disease            boolean     NOT NULL DEFAULT false,
    coagulopathy             boolean     NOT NULL DEFAULT false,
    immunodeficiency         boolean     NOT NULL DEFAULT false,
    osteoporosis             boolean     NOT NULL DEFAULT false,
    thyroid_disease          boolean     NOT NULL DEFAULT false,
    epilepsy                 boolean     NOT NULL DEFAULT false,
    hepatitis                boolean     NOT NULL DEFAULT false,
    hiv_positive             boolean     NOT NULL DEFAULT false,
    tumor_history            boolean     NOT NULL DEFAULT false,
    autoimmune_disease       boolean     NOT NULL DEFAULT false,
    other_diseases           text,
    taking_anticoagulants    boolean     NOT NULL DEFAULT false,
    taking_bisphosphonates   boolean     NOT NULL DEFAULT false,
    taking_cortisone         boolean     NOT NULL DEFAULT false,
    current_medications      text,
    allergy_penicillin       boolean     NOT NULL DEFAULT false,
    allergy_latex            boolean     NOT NULL DEFAULT false,
    allergy_anesthetic       boolean     NOT NULL DEFAULT false,
    allergy_aspirin          boolean     NOT NULL DEFAULT false,
    other_allergies          text,
    bruxism                  boolean     NOT NULL DEFAULT false,
    mouth_breathing          boolean     NOT NULL DEFAULT false,
    nail_biting              boolean     NOT NULL DEFAULT false,
    pacifier_use             boolean,
    general_notes            text,
    signed_at                timestamptz,
    signature_notes          text,
    is_current               boolean     NOT NULL DEFAULT true,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patient_anamnesis_pkey PRIMARY KEY (id),
    CONSTRAINT patient_anamnesis_unique_per_clinic UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE patient_anamnesis
    DROP CONSTRAINT IF EXISTS patient_anamnesis_clinic_id_fkey;
ALTER TABLE patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE patient_anamnesis
    DROP CONSTRAINT IF EXISTS fk_patient_anamnesis_patient;
ALTER TABLE patient_anamnesis
    ADD CONSTRAINT fk_patient_anamnesis_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE patient_anamnesis
    DROP CONSTRAINT IF EXISTS fk_patient_anamnesis_provider;
ALTER TABLE patient_anamnesis
    ADD CONSTRAINT fk_patient_anamnesis_provider
        FOREIGN KEY (recorded_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_patient_current
    ON patient_anamnesis (clinic_id, patient_id, is_current, recorded_at DESC)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_patient_anamnesis_updated_at ON patient_anamnesis;
CREATE TRIGGER trg_patient_anamnesis_updated_at
BEFORE UPDATE ON patient_anamnesis
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 12. PATIENT_ANAMNESIS_ITEM_SELECTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_anamnesis_item_selections (
    id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id               uuid        NOT NULL,
    patient_id              uuid        NOT NULL,
    item_id                 uuid        NOT NULL,
    notes                   text,
    recorded_at             timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    recorded_by_provider_id uuid,
    CONSTRAINT patient_anamnesis_item_selections_pkey PRIMARY KEY (id),
    CONSTRAINT patient_anamnesis_item_selections_unique UNIQUE (clinic_id, patient_id, item_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE patient_anamnesis_item_selections
    DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_clinic_id_fkey;
ALTER TABLE patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE patient_anamnesis_item_selections
    DROP CONSTRAINT IF EXISTS fk_pais_patient;
ALTER TABLE patient_anamnesis_item_selections
    ADD CONSTRAINT fk_pais_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE patient_anamnesis_item_selections
    DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_item_id_fkey;
ALTER TABLE patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey
        FOREIGN KEY (item_id) REFERENCES dentalcare.anamnesis_items(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_selections_patient
    ON patient_anamnesis_item_selections (clinic_id, patient_id)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_patient_anamnesis_selections_updated_at ON patient_anamnesis_item_selections;
CREATE TRIGGER trg_patient_anamnesis_selections_updated_at
BEFORE UPDATE ON patient_anamnesis_item_selections
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 13. ODONTOGRAM_TEETH
-- =============================================================================

CREATE TABLE IF NOT EXISTS odontogram_teeth (
    id                      uuid                      NOT NULL DEFAULT gen_random_uuid(),
    clinic_id               uuid                      NOT NULL,
    patient_id              uuid                      NOT NULL,
    tooth_number            text                      NOT NULL,
    quadrant                smallint                  NOT NULL,
    is_deciduous            boolean                   NOT NULL DEFAULT false,
    condition               dentalcare.tooth_condition NOT NULL DEFAULT 'healthy',
    surfaces                text[],
    bridge_group_id         uuid,
    implant_ref             text,
    notes                   text,
    recorded_at             timestamptz               NOT NULL DEFAULT now(),
    recorded_by_provider_id uuid,
    created_at              timestamptz               NOT NULL DEFAULT now(),
    updated_at              timestamptz               NOT NULL DEFAULT now(),
    CONSTRAINT odontogram_teeth_pkey PRIMARY KEY (id),
    CONSTRAINT odontogram_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT odontogram_teeth_quadrant_check CHECK (quadrant >= 1 AND quadrant <= 4)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE odontogram_teeth
    DROP CONSTRAINT IF EXISTS odontogram_teeth_clinic_id_fkey;
ALTER TABLE odontogram_teeth
    ADD CONSTRAINT odontogram_teeth_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE odontogram_teeth
    DROP CONSTRAINT IF EXISTS fk_odontogram_patient;
ALTER TABLE odontogram_teeth
    ADD CONSTRAINT fk_odontogram_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE odontogram_teeth
    DROP CONSTRAINT IF EXISTS fk_odontogram_provider;
ALTER TABLE odontogram_teeth
    ADD CONSTRAINT fk_odontogram_provider
        FOREIGN KEY (recorded_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_odontogram_patient_tooth
    ON odontogram_teeth (clinic_id, patient_id, tooth_number, recorded_at DESC)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_odontogram_updated_at ON odontogram_teeth;
CREATE TRIGGER trg_odontogram_updated_at
BEFORE UPDATE ON odontogram_teeth
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 14. TOOTH_CONDITIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS tooth_conditions (
    id         uuid            NOT NULL DEFAULT gen_random_uuid(),
    clinic_id  uuid            NOT NULL,
    patient_id uuid            NOT NULL,
    tooth_fdi  smallint        NOT NULL,
    surface    character varying(10) NOT NULL,
    condition  character varying(50) NOT NULL,
    notes      text,
    updated_at timestamptz     NOT NULL DEFAULT now(),
    CONSTRAINT tooth_conditions_pkey PRIMARY KEY (id),
    CONSTRAINT uq_tooth_surface UNIQUE (clinic_id, patient_id, tooth_fdi, surface)
) TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS idx_tooth_conditions_patient
    ON tooth_conditions (clinic_id, patient_id)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_tooth_conditions_patient_fdi_surface
    ON tooth_conditions (clinic_id, patient_id, tooth_fdi, surface)
    TABLESPACE :"tenant_tablespace";

-- =============================================================================
-- 15. CLINICAL_HISTORY_ENTRIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS clinical_history_entries (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id      uuid        NOT NULL,
    patient_id     uuid        NOT NULL,
    appointment_id uuid,
    provider_id    uuid        NOT NULL,
    entry_date     date        NOT NULL DEFAULT CURRENT_DATE,
    tooth_number   text,
    service_code   text,
    service_name   text,
    clinical_notes text        NOT NULL,
    materials_used text,
    next_visit_notes text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT clinical_history_entries_pkey PRIMARY KEY (id),
    CONSTRAINT clinical_history_unique_per_clinic UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE clinical_history_entries
    DROP CONSTRAINT IF EXISTS clinical_history_entries_clinic_id_fkey;
ALTER TABLE clinical_history_entries
    ADD CONSTRAINT clinical_history_entries_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE clinical_history_entries
    DROP CONSTRAINT IF EXISTS fk_clinical_history_patient;
ALTER TABLE clinical_history_entries
    ADD CONSTRAINT fk_clinical_history_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE clinical_history_entries
    DROP CONSTRAINT IF EXISTS fk_clinical_history_provider;
ALTER TABLE clinical_history_entries
    ADD CONSTRAINT fk_clinical_history_provider
        FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_clinical_history_patient_date
    ON clinical_history_entries (clinic_id, patient_id, entry_date DESC)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_clinical_history_updated_at ON clinical_history_entries;
CREATE TRIGGER trg_clinical_history_updated_at
BEFORE UPDATE ON clinical_history_entries
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 16. PATIENT_DOCUMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_documents (
    id                      uuid                      NOT NULL DEFAULT gen_random_uuid(),
    clinic_id               uuid                      NOT NULL,
    patient_id              uuid                      NOT NULL,
    appointment_id          uuid,
    uploaded_by_provider_id uuid,
    document_type           dentalcare.document_type  NOT NULL DEFAULT 'altro',
    title                   text                      NOT NULL,
    description             text,
    file_name               text                      NOT NULL,
    file_path               text                      NOT NULL,
    file_size_bytes         bigint,
    mime_type               text,
    tooth_number            text,
    taken_at                date,
    notes                   text,
    created_at              timestamptz               NOT NULL DEFAULT now(),
    updated_at              timestamptz               NOT NULL DEFAULT now(),
    CONSTRAINT patient_documents_pkey PRIMARY KEY (id),
    CONSTRAINT patient_documents_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT patient_documents_file_name_not_empty CHECK (length(TRIM(BOTH FROM file_name)) > 0),
    CONSTRAINT patient_documents_title_not_empty CHECK (length(TRIM(BOTH FROM title)) > 0)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE patient_documents
    DROP CONSTRAINT IF EXISTS patient_documents_clinic_id_fkey;
ALTER TABLE patient_documents
    ADD CONSTRAINT patient_documents_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE patient_documents
    DROP CONSTRAINT IF EXISTS fk_patient_documents_patient;
ALTER TABLE patient_documents
    ADD CONSTRAINT fk_patient_documents_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE patient_documents
    DROP CONSTRAINT IF EXISTS fk_patient_documents_provider;
ALTER TABLE patient_documents
    ADD CONSTRAINT fk_patient_documents_provider
        FOREIGN KEY (uploaded_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_patient_documents_patient_type
    ON patient_documents (clinic_id, patient_id, document_type, taken_at DESC)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_patient_documents_updated_at ON patient_documents;
CREATE TRIGGER trg_patient_documents_updated_at
BEFORE UPDATE ON patient_documents
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 17. SUPPLIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS suppliers (
    id             uuid        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id      uuid        NOT NULL,
    name           text        NOT NULL,
    contact_person text,
    phone          text,
    email          text,
    notes          text,
    is_active      boolean     NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT suppliers_pkey PRIMARY KEY (id),
    CONSTRAINT suppliers_id_clinic_id_key UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE suppliers
    DROP CONSTRAINT IF EXISTS suppliers_clinic_id_fkey;
ALTER TABLE suppliers
    ADD CONSTRAINT suppliers_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_suppliers_clinic
    ON suppliers (clinic_id)
    TABLESPACE :"tenant_tablespace"
    WHERE is_active = true;

DROP TRIGGER IF EXISTS trg_suppliers_updated_at ON suppliers;
CREATE TRIGGER trg_suppliers_updated_at
BEFORE UPDATE ON suppliers
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 18. PRODUCT_CATEGORIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS product_categories (
    id        uuid NOT NULL DEFAULT gen_random_uuid(),
    clinic_id uuid NOT NULL,
    name      text NOT NULL,
    CONSTRAINT product_categories_pkey PRIMARY KEY (id),
    CONSTRAINT product_categories_id_clinic_id_key UNIQUE (id, clinic_id),
    CONSTRAINT product_categories_clinic_id_name_key UNIQUE (clinic_id, name)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE product_categories
    DROP CONSTRAINT IF EXISTS product_categories_clinic_id_fkey;
ALTER TABLE product_categories
    ADD CONSTRAINT product_categories_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

-- =============================================================================
-- 19. PRODUCTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS products (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id          uuid          NOT NULL,
    category_id        uuid,
    supplier_id        uuid,
    name               text          NOT NULL,
    description        text,
    sku                text,
    unit               text          NOT NULL DEFAULT 'pz',
    min_stock_quantity numeric(10,2) NOT NULL DEFAULT 0,
    reorder_quantity   numeric(10,2) NOT NULL DEFAULT 0,
    unit_cost          numeric(12,2),
    is_active          boolean       NOT NULL DEFAULT true,
    created_at         timestamptz   NOT NULL DEFAULT now(),
    updated_at         timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT products_pkey PRIMARY KEY (id),
    CONSTRAINT products_id_clinic_id_key UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE products
    DROP CONSTRAINT IF EXISTS products_clinic_id_fkey;
ALTER TABLE products
    ADD CONSTRAINT products_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE products
    DROP CONSTRAINT IF EXISTS fk_products_category;
ALTER TABLE products
    ADD CONSTRAINT fk_products_category
        FOREIGN KEY (category_id, clinic_id) REFERENCES product_categories(id, clinic_id) ON DELETE SET NULL;

ALTER TABLE products
    DROP CONSTRAINT IF EXISTS fk_products_supplier;
ALTER TABLE products
    ADD CONSTRAINT fk_products_supplier
        FOREIGN KEY (supplier_id, clinic_id) REFERENCES suppliers(id, clinic_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_products_clinic
    ON products (clinic_id)
    TABLESPACE :"tenant_tablespace"
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS ix_products_category
    ON products (clinic_id, category_id)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 20. STOCK_MOVEMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS stock_movements (
    id                     uuid                          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id              uuid                          NOT NULL,
    product_id             uuid                          NOT NULL,
    movement_type          dentalcare.stock_movement_type NOT NULL,
    quantity               numeric(10,2)                 NOT NULL,
    unit_cost              numeric(12,2),
    notes                  text,
    reference_doc          text,
    created_by_provider_id uuid,
    created_at             timestamptz                   NOT NULL DEFAULT now(),
    CONSTRAINT stock_movements_pkey PRIMARY KEY (id),
    CONSTRAINT stock_movements_id_clinic_id_key UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE stock_movements
    DROP CONSTRAINT IF EXISTS stock_movements_clinic_id_fkey;
ALTER TABLE stock_movements
    ADD CONSTRAINT stock_movements_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE stock_movements
    DROP CONSTRAINT IF EXISTS fk_stock_movements_product;
ALTER TABLE stock_movements
    ADD CONSTRAINT fk_stock_movements_product
        FOREIGN KEY (product_id, clinic_id) REFERENCES products(id, clinic_id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ix_stock_movements_product
    ON stock_movements (clinic_id, product_id, created_at DESC)
    TABLESPACE :"tenant_tablespace";

-- =============================================================================
-- 21. SERVICE_BUNDLE_ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS service_bundle_items (
    id                uuid    NOT NULL DEFAULT gen_random_uuid(),
    clinic_id         uuid    NOT NULL,
    parent_service_id uuid    NOT NULL,
    child_service_id  uuid    NOT NULL,
    sort_order        integer NOT NULL DEFAULT 10,
    CONSTRAINT service_bundle_items_pkey PRIMARY KEY (id),
    CONSTRAINT uq_bundle_item UNIQUE (clinic_id, parent_service_id, child_service_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE service_bundle_items
    DROP CONSTRAINT IF EXISTS service_bundle_items_clinic_id_fkey;
ALTER TABLE service_bundle_items
    ADD CONSTRAINT service_bundle_items_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE service_bundle_items
    DROP CONSTRAINT IF EXISTS fk_bundle_parent;
ALTER TABLE service_bundle_items
    ADD CONSTRAINT fk_bundle_parent
        FOREIGN KEY (parent_service_id) REFERENCES service_catalog(id) ON DELETE CASCADE;

ALTER TABLE service_bundle_items
    DROP CONSTRAINT IF EXISTS fk_bundle_child;
ALTER TABLE service_bundle_items
    ADD CONSTRAINT fk_bundle_child
        FOREIGN KEY (child_service_id) REFERENCES service_catalog(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_service_bundle_parent
    ON service_bundle_items (clinic_id, parent_service_id)
    TABLESPACE :"tenant_tablespace";

-- =============================================================================
-- 22. CONDITION_SERVICE_DEFAULTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS condition_service_defaults (
    id         uuid    NOT NULL DEFAULT gen_random_uuid(),
    clinic_id  uuid    NOT NULL,
    condition_name text NOT NULL,
    service_id uuid    NOT NULL,
    sort_order integer NOT NULL DEFAULT 10,
    CONSTRAINT condition_service_defaults_pkey PRIMARY KEY (id),
    CONSTRAINT uq_condition_default UNIQUE (clinic_id, condition_name, service_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE condition_service_defaults
    DROP CONSTRAINT IF EXISTS condition_service_defaults_clinic_id_fkey;
ALTER TABLE condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE condition_service_defaults
    DROP CONSTRAINT IF EXISTS condition_service_defaults_service_id_fkey;
ALTER TABLE condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_service_id_fkey
        FOREIGN KEY (service_id) REFERENCES service_catalog(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_condition_service_defaults_cond
    ON condition_service_defaults (clinic_id, condition_name)
    TABLESPACE :"tenant_tablespace";

-- =============================================================================
-- 23. PATIENT_RECALLS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_recalls (
    id                    uuid                      NOT NULL DEFAULT gen_random_uuid(),
    clinic_id             uuid                      NOT NULL,
    patient_id            uuid                      NOT NULL,
    recall_type           text                      NOT NULL DEFAULT 'Controllo periodico',
    due_date              date                      NOT NULL,
    status                dentalcare.recall_status  NOT NULL DEFAULT 'da_contattare',
    priority              dentalcare.recall_priority NOT NULL DEFAULT 'media',
    notes                 text,
    source_appointment_id uuid,
    booked_appointment_id uuid,
    last_contact_at       date,
    contact_count         integer                   NOT NULL DEFAULT 0,
    created_at            timestamptz               NOT NULL DEFAULT now(),
    updated_at            timestamptz               NOT NULL DEFAULT now(),
    CONSTRAINT patient_recalls_pkey PRIMARY KEY (id),
    CONSTRAINT patient_recalls_unique_per_clinic UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS patient_recalls_clinic_id_fkey;
ALTER TABLE patient_recalls
    ADD CONSTRAINT patient_recalls_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS fk_recalls_patient;
ALTER TABLE patient_recalls
    ADD CONSTRAINT fk_recalls_patient
        FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS fk_recalls_source_apt;
ALTER TABLE patient_recalls
    ADD CONSTRAINT fk_recalls_source_apt
        FOREIGN KEY (source_appointment_id) REFERENCES appointments(id) ON DELETE SET NULL;

ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS fk_recalls_booked_apt;
ALTER TABLE patient_recalls
    ADD CONSTRAINT fk_recalls_booked_apt
        FOREIGN KEY (booked_appointment_id) REFERENCES appointments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_recalls_clinic_status
    ON patient_recalls (clinic_id, status, due_date)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_recalls_due_date
    ON patient_recalls (clinic_id, due_date)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS ix_recalls_patient
    ON patient_recalls (clinic_id, patient_id)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_recalls_updated_at ON patient_recalls;
CREATE TRIGGER trg_recalls_updated_at
BEFORE UPDATE ON patient_recalls
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 24. RECALL_CONTACTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS recall_contacts (
    id                     uuid                          NOT NULL DEFAULT gen_random_uuid(),
    clinic_id              uuid                          NOT NULL,
    recall_id              uuid                          NOT NULL,
    contact_type           dentalcare.recall_contact_type NOT NULL DEFAULT 'telefono',
    contact_at             timestamptz                   NOT NULL DEFAULT now(),
    outcome                dentalcare.recall_outcome     NOT NULL,
    notes                  text,
    created_by_provider_id uuid,
    created_at             timestamptz                   NOT NULL DEFAULT now(),
    CONSTRAINT recall_contacts_pkey PRIMARY KEY (id),
    CONSTRAINT recall_contacts_unique_per_clinic UNIQUE (id, clinic_id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE recall_contacts
    DROP CONSTRAINT IF EXISTS recall_contacts_clinic_id_fkey;
ALTER TABLE recall_contacts
    ADD CONSTRAINT recall_contacts_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE recall_contacts
    DROP CONSTRAINT IF EXISTS fk_recall_contacts_recall;
ALTER TABLE recall_contacts
    ADD CONSTRAINT fk_recall_contacts_recall
        FOREIGN KEY (recall_id, clinic_id) REFERENCES patient_recalls(id, clinic_id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS ix_recall_contacts_recall
    ON recall_contacts (recall_id, contact_at DESC)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_recall_contact_update ON recall_contacts;
CREATE TRIGGER trg_recall_contact_update
AFTER INSERT ON recall_contacts
FOR EACH ROW EXECUTE FUNCTION dentalcare.update_recall_on_contact();

-- =============================================================================
-- 25. AI_CONVERSATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id          uuid        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id   uuid        NOT NULL,
    patient_id  uuid,
    provider_id uuid,
    title       text,
    messages    jsonb       NOT NULL DEFAULT '[]',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ai_conversations_pkey PRIMARY KEY (id)
) TABLESPACE :"tenant_tablespace";

ALTER TABLE ai_conversations
    DROP CONSTRAINT IF EXISTS ai_conversations_clinic_id_fkey;
ALTER TABLE ai_conversations
    ADD CONSTRAINT ai_conversations_clinic_id_fkey
        FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ai_conversations
    DROP CONSTRAINT IF EXISTS ai_conversations_patient_id_fkey;
ALTER TABLE ai_conversations
    ADD CONSTRAINT ai_conversations_patient_id_fkey
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE SET NULL;

ALTER TABLE ai_conversations
    DROP CONSTRAINT IF EXISTS ai_conversations_provider_id_fkey;
ALTER TABLE ai_conversations
    ADD CONSTRAINT ai_conversations_provider_id_fkey
        FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_ai_conversations_clinic
    ON ai_conversations (clinic_id)
    TABLESPACE :"tenant_tablespace";

DROP TRIGGER IF EXISTS trg_ai_conversations_updated_at ON ai_conversations;
CREATE TRIGGER trg_ai_conversations_updated_at
BEFORE UPDATE ON ai_conversations
FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

-- =============================================================================
-- 26. PATIENT_DIAGNOSES
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_diagnoses (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    clinic_id       UUID        NOT NULL,
    patient_id      UUID        NOT NULL,
    provider_id     UUID        NOT NULL,
    tooth_number    VARCHAR(10),
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    icd_code        VARCHAR(20),
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
    diagnosed_at    DATE        NOT NULL DEFAULT CURRENT_DATE,
    resolved_at     DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT patient_diagnoses_pkey PRIMARY KEY (id)
) TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS idx_patient_diagnoses_patient
    ON patient_diagnoses (clinic_id, patient_id)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS idx_patient_diagnoses_status
    ON patient_diagnoses (clinic_id, patient_id, status)
    TABLESPACE :"tenant_tablespace";

-- =============================================================================
-- 27. PATIENT_PRESCRIPTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_prescriptions (
    id              UUID         NOT NULL DEFAULT gen_random_uuid(),
    clinic_id       UUID         NOT NULL,
    patient_id      UUID         NOT NULL,
    provider_id     UUID         NOT NULL,
    drug_name       VARCHAR(255) NOT NULL,
    dosage          VARCHAR(100),
    frequency       VARCHAR(100),
    duration        VARCHAR(100),
    notes           TEXT,
    prescribed_at   DATE         NOT NULL DEFAULT CURRENT_DATE,
    expires_at      DATE,
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT patient_prescriptions_pkey PRIMARY KEY (id)
) TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS idx_patient_prescriptions_patient
    ON patient_prescriptions (clinic_id, patient_id)
    TABLESPACE :"tenant_tablespace";

CREATE INDEX IF NOT EXISTS idx_patient_prescriptions_active
    ON patient_prescriptions (clinic_id, patient_id, active)
    TABLESPACE :"tenant_tablespace";

-- =============================================================================
-- VISTE
-- =============================================================================

CREATE OR REPLACE VIEW product_stock_v AS
SELECT
    p.id                   AS product_id,
    p.clinic_id,
    p.name,
    p.sku,
    p.unit,
    p.min_stock_quantity,
    p.reorder_quantity,
    p.unit_cost,
    p.description,
    p.is_active,
    p.category_id,
    pc.name                AS category_name,
    s.name                 AS supplier_name,
    p.supplier_id,
    COALESCE(sum(
        CASE
            WHEN sm.movement_type = ANY (ARRAY['carico'::dentalcare.stock_movement_type, 'rientro'::dentalcare.stock_movement_type]) THEN sm.quantity
            WHEN sm.movement_type = 'scarico'::dentalcare.stock_movement_type  THEN -sm.quantity
            WHEN sm.movement_type = 'rettifica'::dentalcare.stock_movement_type THEN sm.quantity
            ELSE 0
        END
    ), 0) AS current_stock,
    CASE
        WHEN COALESCE(sum(
            CASE
                WHEN sm.movement_type = ANY (ARRAY['carico'::dentalcare.stock_movement_type, 'rientro'::dentalcare.stock_movement_type]) THEN sm.quantity
                WHEN sm.movement_type = 'scarico'::dentalcare.stock_movement_type  THEN -sm.quantity
                WHEN sm.movement_type = 'rettifica'::dentalcare.stock_movement_type THEN sm.quantity
                ELSE 0
            END
        ), 0) = 0               THEN 'critico'
        WHEN COALESCE(sum(
            CASE
                WHEN sm.movement_type = ANY (ARRAY['carico'::dentalcare.stock_movement_type, 'rientro'::dentalcare.stock_movement_type]) THEN sm.quantity
                WHEN sm.movement_type = 'scarico'::dentalcare.stock_movement_type  THEN -sm.quantity
                WHEN sm.movement_type = 'rettifica'::dentalcare.stock_movement_type THEN sm.quantity
                ELSE 0
            END
        ), 0) <= p.min_stock_quantity THEN 'basso'
        ELSE 'ok'
    END AS stock_status
FROM products p
LEFT JOIN product_categories pc ON pc.id = p.category_id AND pc.clinic_id = p.clinic_id
LEFT JOIN suppliers          s  ON s.id  = p.supplier_id  AND s.clinic_id  = p.clinic_id
LEFT JOIN stock_movements    sm ON sm.product_id = p.id   AND sm.clinic_id = p.clinic_id
GROUP BY p.id, p.clinic_id, p.name, p.sku, p.unit, p.min_stock_quantity,
         p.reorder_quantity, p.unit_cost, p.description, p.is_active,
         p.category_id, pc.name, s.name, p.supplier_id;

CREATE OR REPLACE VIEW v_agenda_daily AS
SELECT
    a.id            AS appointment_id,
    a.clinic_id,
    a.starts_at,
    a.ends_at,
    a.chair_label,
    a.status        AS appointment_status,
    a.notes,
    a.patient_id,
    concat_ws(' '::text, pat.last_name, pat.first_name) AS patient_full_name,
    pat.phone       AS patient_phone,
    a.provider_id,
    concat_ws(' '::text, prov.last_name, prov.first_name) AS provider_name,
    (prov.role)::text AS provider_role,
    sc.name         AS service_name,
    sc.category     AS service_category,
    tpi.tooth_number,
    (SELECT bool_or(pa.allergy_penicillin OR pa.allergy_anesthetic OR pa.allergy_latex)
     FROM patient_anamnesis pa
     WHERE pa.patient_id = a.patient_id AND pa.clinic_id = a.clinic_id AND pa.is_current = true
    ) AS has_allergy_alert,
    (SELECT bool_or(pa.taking_anticoagulants OR pa.taking_bisphosphonates)
     FROM patient_anamnesis pa
     WHERE pa.patient_id = a.patient_id AND pa.clinic_id = a.clinic_id AND pa.is_current = true
    ) AS has_medication_alert
FROM appointments a
JOIN patients             pat  ON pat.id  = a.patient_id  AND pat.clinic_id  = a.clinic_id
JOIN providers            prov ON prov.id = a.provider_id AND prov.clinic_id = a.clinic_id
LEFT JOIN treatment_plan_items tpi ON tpi.id = a.treatment_plan_item_id AND tpi.clinic_id = a.clinic_id
LEFT JOIN service_catalog      sc  ON sc.id  = tpi.service_id            AND sc.clinic_id  = tpi.clinic_id;

CREATE OR REPLACE VIEW v_clinic_dashboard AS
WITH patient_agg AS (
    SELECT clinic_id, count(*) AS patients_count
    FROM patients GROUP BY clinic_id
),
provider_agg AS (
    SELECT clinic_id,
           count(*) FILTER (WHERE active = true) AS active_providers_count
    FROM providers GROUP BY clinic_id
),
plan_agg AS (
    SELECT clinic_id,
           count(*) FILTER (WHERE status = 'in_progress'::dentalcare.treatment_plan_status) AS in_progress_treatment_plans_count
    FROM treatment_plans GROUP BY clinic_id
),
estimate_agg AS (
    SELECT clinic_id,
           count(*) FILTER (WHERE status = 'sent'::dentalcare.estimate_status) AS sent_estimates_count,
           COALESCE(round(sum(total_amount) FILTER (WHERE status = 'accepted'::dentalcare.estimate_status), 2), 0) AS accepted_estimates_amount
    FROM estimates GROUP BY clinic_id
)
SELECT
    c.id                                                              AS clinic_id,
    c.name                                                            AS clinic_name,
    c.city,
    COALESCE(pa.patients_count,                     0)               AS patients_count,
    COALESCE(pra.active_providers_count,            0)               AS active_providers_count,
    COALESCE(tpa.in_progress_treatment_plans_count, 0)               AS in_progress_treatment_plans_count,
    COALESCE(ea.sent_estimates_count,               0)               AS sent_estimates_count,
    COALESCE(ea.accepted_estimates_amount,          0)               AS accepted_estimates_amount
FROM clinics c
LEFT JOIN patient_agg  pa  ON pa.clinic_id  = c.id
LEFT JOIN provider_agg pra ON pra.clinic_id = c.id
LEFT JOIN plan_agg     tpa ON tpa.clinic_id = c.id
LEFT JOIN estimate_agg ea  ON ea.clinic_id  = c.id;

-- ─────────────────────────────────────────────────────────────────────────────
-- Viste dashboard pazienti e preventivi
-- ─────────────────────────────────────────────────────────────────────────────

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
    COUNT(DISTINCT tp.id)                                                                   AS treatment_plans_count,
    COUNT(DISTINCT tpi.id) FILTER (WHERE tpi.status IN ('planned','accepted','scheduled')) AS open_treatment_items_count,
    COALESCE(SUM(e.total_amount) FILTER (WHERE e.status::text = 'accepted'), 0)            AS accepted_estimates_amount
FROM patients p
LEFT JOIN treatment_plans      tp  ON tp.patient_id         = p.id  AND tp.clinic_id  = p.clinic_id
LEFT JOIN treatment_plan_items tpi ON tpi.treatment_plan_id = tp.id AND tpi.clinic_id = p.clinic_id
LEFT JOIN estimates            e   ON e.patient_id          = p.id  AND e.clinic_id   = p.clinic_id
GROUP BY p.id, p.clinic_id, p.first_name, p.last_name,
         p.fiscal_code, p.birth_date, p.phone, p.email, p.city, p.province;

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

CREATE OR REPLACE VIEW v_patient_estimates_summary AS
SELECT
    e.id                                       AS estimate_id,
    e.clinic_id,
    e.patient_id,
    e.estimate_number,
    e.version,
    e.status::text                             AS estimate_status,
    e.title                                    AS estimate_title,
    e.currency,
    e.subtotal_amount,
    e.discount_amount,
    e.taxable_amount,
    e.vat_amount,
    e.total_amount,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.fiscal_code                              AS patient_fiscal_code,
    p.phone                                    AS patient_phone,
    e.issued_at,
    e.sent_at,
    e.valid_until,
    e.accepted_at,
    e.rejected_at,
    e.created_at                               AS estimate_created_at,
    e.created_by_provider_id
FROM estimates e
LEFT JOIN patients p ON p.id = e.patient_id AND p.clinic_id = e.clinic_id;

-- =============================================================================
-- VERIFICA FINALE
-- =============================================================================

SELECT
    schemaname,
    COUNT(*) AS table_count
FROM pg_tables
WHERE schemaname = :'tenant_schema'
GROUP BY schemaname;

COMMIT;
