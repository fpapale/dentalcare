-- DentalCare - Tenant Schema DDL Template
-- Placeholders replaced by TenantProvisioningService before execution:
--   {schema}     -> tenant schema name (e.g. t_9d754153)
--   {tablespace} -> tablespace name    (e.g. ts_t_9d754153 or pg_default)
-- No psql metacommands. No BEGIN/COMMIT (managed by Java TransactionTemplate).

SET LOCAL search_path TO {schema}, dentalcare, public;

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
) TABLESPACE {tablespace};

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
    active        boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patients_first_name_not_empty CHECK (length(trim(first_name)) > 0),
    CONSTRAINT patients_last_name_not_empty  CHECK (length(trim(last_name)) > 0)
) TABLESPACE {tablespace};

CREATE UNIQUE INDEX IF NOT EXISTS ux_patients_clinic_fiscal_code
    ON patients (clinic_id, fiscal_code)
    TABLESPACE {tablespace}
    WHERE fiscal_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_patients_clinic_name
    ON patients (clinic_id, last_name, first_name)
    TABLESPACE {tablespace};

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
    created_at           timestamptz   NOT NULL DEFAULT now(),
    updated_at           timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT providers_first_name_not_empty CHECK (length(trim(first_name)) > 0),
    CONSTRAINT providers_last_name_not_empty  CHECK (length(trim(last_name)) > 0),
    CONSTRAINT providers_color_hex_format     CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_providers_clinic_role_active
    ON providers (clinic_id, role)
    TABLESPACE {tablespace}
    WHERE active = true;

DROP TRIGGER IF EXISTS trg_providers_updated_at ON providers;
CREATE TRIGGER trg_providers_updated_at
BEFORE UPDATE ON providers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

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
    price                    numeric(12,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_service_catalog_clinic_active_cat
    ON service_catalog (clinic_id, is_active, category)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_treatment_plans_clinic_patient
    ON treatment_plans (clinic_id, patient_id, status)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_plan
    ON treatment_plan_items (plan_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_treatment_plan_items_clinic_status
    ON treatment_plan_items (clinic_id, status)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_starts
    ON appointments (clinic_id, starts_at)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_provider_starts
    ON appointments (clinic_id, provider_id, starts_at)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_patient
    ON appointments (clinic_id, patient_id)
    TABLESPACE {tablespace};

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
    plan_id                 uuid            REFERENCES treatment_plans(id) ON DELETE SET NULL,
    version                 integer         NOT NULL DEFAULT 1 CHECK (version > 0),
    status                  estimate_status NOT NULL DEFAULT 'draft',
    title                   text,
    notes                   text,
    valid_until             date,
    subtotal                numeric(12,2)   NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    discount_total          numeric(12,2)   NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    total                   numeric(12,2)   NOT NULL DEFAULT 0 CHECK (total >= 0),
    created_at              timestamptz     NOT NULL DEFAULT now(),
    updated_at              timestamptz     NOT NULL DEFAULT now()
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_patient
    ON estimates (clinic_id, patient_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_status
    ON estimates (clinic_id, status)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_provider
    ON estimates (clinic_id, created_by_provider_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_estimates_clinic_plan
    ON estimates (clinic_id, plan_id)
    TABLESPACE {tablespace}
    WHERE plan_id IS NOT NULL;

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
    service_catalog_id      uuid          REFERENCES service_catalog(id) ON DELETE SET NULL,
    description             text          NOT NULL,
    tooth_fdi               text,
    surfaces                text[],
    quantity                integer       NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price              numeric(12,2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    discount_pct            numeric(5,2)  NOT NULL DEFAULT 0 CHECK (discount_pct >= 0 AND discount_pct <= 100),
    line_total              numeric(12,2) NOT NULL DEFAULT 0 CHECK (line_total >= 0),
    position                integer       NOT NULL DEFAULT 0,
    created_at              timestamptz   NOT NULL DEFAULT now(),
    updated_at              timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT estimate_lines_description_not_empty CHECK (length(trim(description)) > 0)
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_estimate_lines_estimate
    ON estimate_lines (estimate_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_estimate_lines_plan_item
    ON estimate_lines (clinic_id, treatment_plan_item_id)
    TABLESPACE {tablespace}
    WHERE treatment_plan_item_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_estimate_lines_updated_at ON estimate_lines;
CREATE TRIGGER trg_estimate_lines_updated_at
BEFORE UPDATE ON estimate_lines
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 10. INVOICES
-- =============================================================================

CREATE TABLE IF NOT EXISTS invoices (
    id               uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id        uuid                  NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id       uuid                  REFERENCES patients(id) ON DELETE SET NULL,
    provider_id      uuid                  REFERENCES providers(id) ON DELETE SET NULL,
    estimate_id      uuid                  REFERENCES estimates(id) ON DELETE SET NULL,
    document_type    invoice_document_type NOT NULL DEFAULT 'fattura',
    issuer_type      invoice_issuer_type   NOT NULL DEFAULT 'clinic',
    status           invoice_status        NOT NULL DEFAULT 'draft',
    invoice_number   text,
    invoice_date     date,
    due_date         date,
    subtotal         numeric(12,2)         NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    vat_total        numeric(12,2)         NOT NULL DEFAULT 0 CHECK (vat_total >= 0),
    total            numeric(12,2)         NOT NULL DEFAULT 0 CHECK (total >= 0),
    notes            text,
    created_at       timestamptz           NOT NULL DEFAULT now(),
    updated_at       timestamptz           NOT NULL DEFAULT now()
) TABLESPACE {tablespace};

CREATE UNIQUE INDEX IF NOT EXISTS ux_invoices_clinic_number
    ON invoices (clinic_id, invoice_number)
    TABLESPACE {tablespace}
    WHERE invoice_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_invoices_clinic_status
    ON invoices (clinic_id, status)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_invoices_clinic_patient
    ON invoices (clinic_id, patient_id)
    TABLESPACE {tablespace};

DROP TRIGGER IF EXISTS trg_invoices_updated_at ON invoices;
CREATE TRIGGER trg_invoices_updated_at
BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- 11. INVOICE_LINES
-- =============================================================================

CREATE TABLE IF NOT EXISTS invoice_lines (
    id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id       uuid          NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    clinic_id        uuid          NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    estimate_line_id uuid          REFERENCES estimate_lines(id) ON DELETE SET NULL,
    description      text          NOT NULL,
    quantity         integer       NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price       numeric(12,2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    vat_rate         numeric(5,2)  NOT NULL DEFAULT 22 CHECK (vat_rate >= 0 AND vat_rate <= 100),
    line_total       numeric(12,2) NOT NULL DEFAULT 0 CHECK (line_total >= 0),
    position         integer       NOT NULL DEFAULT 0,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT invoice_lines_description_not_empty CHECK (length(trim(description)) > 0)
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_invoice_lines_invoice
    ON invoice_lines (invoice_id)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_anamnesis_current
    ON patient_anamnesis (clinic_id, patient_id)
    TABLESPACE {tablespace}
    WHERE is_current = true;

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_patient
    ON patient_anamnesis (clinic_id, patient_id)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_item_selections_anamnesis
    ON patient_anamnesis_item_selections (anamnesis_id)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_tooth_conditions_clinic_patient
    ON tooth_conditions (clinic_id, patient_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_tooth_conditions_clinic_tooth
    ON tooth_conditions (clinic_id, tooth_fdi)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_clinical_history_entries_clinic_patient
    ON clinical_history_entries (clinic_id, patient_id)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_patient_documents_clinic_patient
    ON patient_documents (clinic_id, patient_id)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

-- =============================================================================
-- 20. PRODUCTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS products (
    id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id    uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    supplier_id  uuid    REFERENCES suppliers(id) ON DELETE SET NULL,
    category_id  uuid    REFERENCES product_categories(id) ON DELETE SET NULL,
    sku          text,
    name         text    NOT NULL,
    description  text,
    unit         text    NOT NULL DEFAULT 'pz',
    min_stock    integer NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
    price_unit   numeric(12,2) NOT NULL DEFAULT 0 CHECK (price_unit >= 0),
    is_active    boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT products_name_not_empty CHECK (length(trim(name)) > 0)
) TABLESPACE {tablespace};

CREATE UNIQUE INDEX IF NOT EXISTS ux_products_clinic_sku
    ON products (clinic_id, sku)
    TABLESPACE {tablespace}
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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_stock_movements_clinic_product
    ON stock_movements (clinic_id, product_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_stock_movements_clinic_moved_at
    ON stock_movements (clinic_id, moved_at)
    TABLESPACE {tablespace};

-- =============================================================================
-- 22. SERVICE_BUNDLE_ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS service_bundle_items (
    id                   uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id            uuid    NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    bundle_service_id    uuid    NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    component_service_id uuid    NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    quantity             integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
    created_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (bundle_service_id, component_service_id)
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_service_bundle_items_bundle
    ON service_bundle_items (clinic_id, bundle_service_id)
    TABLESPACE {tablespace};

-- =============================================================================
-- 23. CONDITION_SERVICE_DEFAULTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS condition_service_defaults (
    id                 uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id          uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    condition          tooth_condition NOT NULL,
    service_catalog_id uuid            NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    sort_order         integer         NOT NULL DEFAULT 0,
    created_at         timestamptz     NOT NULL DEFAULT now(),
    UNIQUE (clinic_id, condition, service_catalog_id)
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_condition_service_defaults_condition
    ON condition_service_defaults (clinic_id, condition)
    TABLESPACE {tablespace};

-- =============================================================================
-- 24. PATIENT_RECALLS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patient_recalls (
    id             uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id      uuid            NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id     uuid            NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    provider_id    uuid            REFERENCES providers(id) ON DELETE SET NULL,
    appointment_id uuid            REFERENCES appointments(id) ON DELETE SET NULL,
    recall_type    text            NOT NULL DEFAULT 'routine_checkup',
    status         recall_status   NOT NULL DEFAULT 'pending',
    priority       recall_priority NOT NULL DEFAULT 'medium',
    due_date       date            NOT NULL,
    completed_at   timestamptz,
    notes          text,
    created_at     timestamptz     NOT NULL DEFAULT now(),
    updated_at     timestamptz     NOT NULL DEFAULT now()
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_patient_recalls_clinic_status
    ON patient_recalls (clinic_id, status)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_patient_recalls_clinic_patient
    ON patient_recalls (clinic_id, patient_id)
    TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_patient_recalls_clinic_due_date
    ON patient_recalls (clinic_id, due_date)
    TABLESPACE {tablespace};

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
    contacted_by_provider_id uuid                REFERENCES providers(id) ON DELETE SET NULL,
    contacted_at             timestamptz         NOT NULL DEFAULT now(),
    notes                    text,
    created_at               timestamptz         NOT NULL DEFAULT now()
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_recall_contacts_recall
    ON recall_contacts (recall_id)
    TABLESPACE {tablespace};

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
) TABLESPACE {tablespace};

CREATE INDEX IF NOT EXISTS ix_ai_conversations_clinic
    ON ai_conversations (clinic_id)
    TABLESPACE {tablespace};

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

CREATE OR REPLACE FUNCTION recalc_invoice_totals()
RETURNS trigger AS $$
DECLARE
    v_invoice_id uuid;
BEGIN
    v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
    UPDATE invoices
    SET
        subtotal   = COALESCE((SELECT SUM(unit_price * quantity)                  FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        vat_total  = COALESCE((SELECT SUM(unit_price * quantity * vat_rate / 100) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        total      = COALESCE((SELECT SUM(line_total)                             FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
        updated_at = now()
    WHERE id = v_invoice_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recalc_invoice_totals ON invoice_lines;
CREATE TRIGGER trg_recalc_invoice_totals
AFTER INSERT OR UPDATE OR DELETE ON invoice_lines
FOR EACH ROW EXECUTE FUNCTION recalc_invoice_totals();

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
-- VISTE
-- =============================================================================

CREATE OR REPLACE VIEW v_patient_dashboard AS
SELECT
    p.id          AS patient_id,
    p.clinic_id,
    p.first_name,
    p.last_name,
    p.birth_date,
    p.phone,
    p.email,
    p.active,
    COUNT(DISTINCT a.id)  FILTER (WHERE a.status IN ('scheduled', 'confirmed'))                         AS upcoming_appointments,
    COUNT(DISTINCT a.id)  FILTER (WHERE a.status = 'completed')                                         AS completed_appointments,
    COUNT(DISTINCT tp.id) FILTER (WHERE tp.status NOT IN ('rejected', 'archived'))                      AS active_plans,
    COUNT(DISTINCT e.id)  FILTER (WHERE e.status IN ('draft', 'sent'))                                  AS pending_estimates,
    MAX(a.starts_at)      FILTER (WHERE a.status = 'completed')                                         AS last_appointment_at,
    MIN(a.starts_at)      FILTER (WHERE a.status IN ('scheduled', 'confirmed') AND a.starts_at > now()) AS next_appointment_at
FROM patients p
LEFT JOIN appointments    a  ON a.patient_id  = p.id AND a.clinic_id  = p.clinic_id
LEFT JOIN treatment_plans tp ON tp.patient_id = p.id AND tp.clinic_id = p.clinic_id
LEFT JOIN estimates       e  ON e.patient_id  = p.id AND e.clinic_id  = p.clinic_id
GROUP BY p.id, p.clinic_id, p.first_name, p.last_name, p.birth_date, p.phone, p.email, p.active;

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
    p.notes,
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
    pa.recorded_at AS anamnesis_date
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
    pr.min_stock,
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
    pr.min_stock AS min_stock_threshold,
    pr.is_active,
    CASE
        WHEN COALESCE(SUM(CASE sm.movement_type
                WHEN 'carico' THEN sm.quantity WHEN 'rientro' THEN sm.quantity
                WHEN 'scarico' THEN -sm.quantity WHEN 'rettifica' THEN sm.quantity ELSE 0
             END), 0) = 0              THEN 'critico'
        WHEN COALESCE(SUM(CASE sm.movement_type
                WHEN 'carico' THEN sm.quantity WHEN 'rientro' THEN sm.quantity
                WHEN 'scarico' THEN -sm.quantity WHEN 'rettifica' THEN sm.quantity ELSE 0
             END), 0) <= pr.min_stock  THEN 'basso'
        ELSE 'ok'
    END AS stock_status
FROM products pr
LEFT JOIN product_categories pc ON pc.id = pr.category_id AND pc.clinic_id = pr.clinic_id
LEFT JOIN suppliers          s  ON s.id  = pr.supplier_id  AND s.clinic_id  = pr.clinic_id
LEFT JOIN stock_movements    sm ON sm.product_id = pr.id   AND sm.clinic_id = pr.clinic_id
GROUP BY pr.clinic_id, pr.id, pr.name, pr.sku, pr.unit, pr.min_stock,
         pc.name, s.name, pr.is_active;

CREATE OR REPLACE VIEW v_agenda_daily AS
SELECT
    a.id           AS appointment_id,
    a.clinic_id,
    a.starts_at,
    a.ends_at,
    a.chair_label,
    a.status,
    a.notes        AS appointment_notes,
    p.id           AS patient_id,
    p.first_name   AS patient_first_name,
    p.last_name    AS patient_last_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.phone        AS patient_phone,
    p.email        AS patient_email,
    pr.id          AS provider_id,
    pr.first_name  AS provider_first_name,
    pr.last_name   AS provider_last_name,
    pr.role        AS provider_role,
    pr.color_hex   AS provider_color,
    sc.name        AS service_name,
    sc.duration_minutes,
    tpi.tooth_fdi,
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

CREATE OR REPLACE VIEW v_patient_estimates_summary AS
SELECT
    e.id                    AS estimate_id,
    e.clinic_id,
    e.patient_id,
    e.provider_id,
    e.created_by_provider_id,
    e.plan_id,
    e.version,
    e.status,
    e.title,
    e.valid_until,
    e.subtotal,
    e.discount_total,
    e.total,
    e.created_at,
    e.updated_at,
    p.first_name            AS patient_first_name,
    p.last_name             AS patient_last_name,
    pr.first_name           AS provider_first_name,
    pr.last_name            AS provider_last_name,
    COUNT(el.id)            AS line_count,
    CASE
        WHEN e.valid_until IS NULL                                    THEN false
        WHEN e.status IN ('accepted', 'rejected', 'cancelled')        THEN false
        WHEN e.valid_until < CURRENT_DATE                             THEN true
        ELSE false
    END AS is_expired,
    CASE WHEN e.valid_until IS NULL THEN NULL
         ELSE e.valid_until - CURRENT_DATE END AS days_to_expiry
FROM estimates e
LEFT JOIN patients       p  ON p.id  = e.patient_id
LEFT JOIN providers      pr ON pr.id = e.provider_id
LEFT JOIN estimate_lines el ON el.estimate_id = e.id
GROUP BY e.id, e.clinic_id, e.patient_id, e.provider_id, e.created_by_provider_id,
         e.plan_id, e.version, e.status, e.title, e.valid_until,
         e.subtotal, e.discount_total, e.total, e.created_at, e.updated_at,
         p.first_name, p.last_name, pr.first_name, pr.last_name;

CREATE OR REPLACE VIEW v_clinic_dashboard AS
WITH patient_agg AS (
    SELECT clinic_id,
           COUNT(*)                               AS total_patients,
           COUNT(*) FILTER (WHERE active = true)  AS active_patients
    FROM patients GROUP BY clinic_id
),
provider_agg AS (
    SELECT clinic_id,
           COUNT(*) AS total_providers,
           COUNT(*) FILTER (WHERE active = true AND role IN ('dentist','hygienist','orthodontist','surgeon')) AS clinical_providers
    FROM providers GROUP BY clinic_id
),
plan_agg AS (
    SELECT clinic_id,
           COUNT(*) AS total_plans,
           COUNT(*) FILTER (WHERE status = 'in_progress') AS active_plans
    FROM treatment_plans GROUP BY clinic_id
),
estimate_agg AS (
    SELECT clinic_id,
           COUNT(*) AS total_estimates,
           COALESCE(SUM(total) FILTER (WHERE status = 'accepted'), 0) AS accepted_revenue
    FROM estimates GROUP BY clinic_id
),
appointment_agg AS (
    SELECT clinic_id,
           COUNT(*) FILTER (WHERE status IN ('scheduled','confirmed') AND starts_at > now()) AS upcoming_appointments,
           COUNT(*) FILTER (WHERE status = 'completed' AND starts_at::date = CURRENT_DATE)  AS today_completed
    FROM appointments GROUP BY clinic_id
)
SELECT
    c.id                                       AS clinic_id,
    c.name                                     AS clinic_name,
    COALESCE(pa.total_patients,        0)      AS total_patients,
    COALESCE(pa.active_patients,       0)      AS active_patients,
    COALESCE(pra.total_providers,      0)      AS total_providers,
    COALESCE(pra.clinical_providers,   0)      AS clinical_providers,
    COALESCE(tpa.total_plans,          0)      AS total_plans,
    COALESCE(tpa.active_plans,         0)      AS active_plans,
    COALESCE(ea.total_estimates,       0)      AS total_estimates,
    COALESCE(ea.accepted_revenue,      0)      AS accepted_revenue,
    COALESCE(aa.upcoming_appointments, 0)      AS upcoming_appointments,
    COALESCE(aa.today_completed,       0)      AS today_completed
FROM clinics c
LEFT JOIN patient_agg     pa  ON pa.clinic_id  = c.id
LEFT JOIN provider_agg    pra ON pra.clinic_id = c.id
LEFT JOIN plan_agg        tpa ON tpa.clinic_id = c.id
LEFT JOIN estimate_agg    ea  ON ea.clinic_id  = c.id
LEFT JOIN appointment_agg aa  ON aa.clinic_id  = c.id;
