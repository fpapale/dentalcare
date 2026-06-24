-- V25: rigenera dentalcare.create_tenant con lo schema CANONICO completo (allineato al tenant demo).
-- Crea TUTTE le tabelle, viste, funzioni, trigger, vincoli, indici necessari all'app.
-- DDL derivato da pg_dump --schema-only del tenant demo t_9d754153.

SET search_path TO dentalcare, public;

CREATE OR REPLACE FUNCTION dentalcare.create_tenant(
    p_tenant_id uuid, p_clinic_id uuid, p_schema text, p_studio_name text, p_email text,
    p_phone text, p_plan text, p_vat text, p_address text, p_city text, p_province text,
    p_admin_first text, p_admin_last text, p_admin_email text, p_admin_pw_hash text
) RETURNS uuid LANGUAGE plpgsql AS $provision$
DECLARE l_admin_id uuid := gen_random_uuid(); l_ddl text;
BEGIN
    IF p_schema !~ '^t_[0-9a-f]{8}$' THEN RAISE EXCEPTION 'Invalid schema name: %', p_schema; END IF;
    IF EXISTS (SELECT 1 FROM dentalcare.tenants WHERE schema_name = p_schema) THEN RAISE EXCEPTION 'Schema already registered: %', p_schema; END IF;
    IF p_admin_pw_hash IS NULL OR length(p_admin_pw_hash) = 0 THEN RAISE EXCEPTION 'admin password hash required'; END IF;

    EXECUTE format('CREATE SCHEMA %I', p_schema);

    l_ddl := 'SET LOCAL search_path TO ' || quote_ident(p_schema) || ', dentalcare, public;
'
    ||
$ddl$
CREATE FUNCTION recalc_estimate_totals() RETURNS trigger
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

CREATE FUNCTION trg_compute_invoice_line_totals() RETURNS trigger
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

CREATE FUNCTION trg_update_invoice_totals_from_lines() RETURNS trigger
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

CREATE FUNCTION update_recall_on_contact() RETURNS trigger
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

CREATE TABLE ai_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid,
    provider_id uuid,
    title text,
    messages jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE appointments (
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

CREATE TABLE chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chat_messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text])))
);

CREATE TABLE chat_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_id uuid NOT NULL,
    title text NOT NULL,
    message_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE clinical_history_entries (
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

CREATE TABLE clinics (
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

CREATE TABLE condition_service_defaults (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    condition_name text NOT NULL,
    service_id uuid NOT NULL,
    sort_order integer DEFAULT 10 NOT NULL
);

CREATE TABLE estimate_lines (
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

CREATE TABLE estimates (
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

CREATE TABLE invoice_lines (
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

CREATE TABLE invoices (
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

CREATE TABLE odontogram_teeth (
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

CREATE TABLE patient_anamnesis (
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
    general_notes text,
    signed_at timestamp with time zone,
    signature_notes text,
    is_current boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE patient_anamnesis_item_selections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    item_id uuid NOT NULL,
    notes text,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by_provider_id uuid
);

CREATE TABLE patient_diagnoses (
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

CREATE TABLE patient_documents (
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

CREATE TABLE patient_prescriptions (
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

CREATE TABLE patient_recalls (
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

CREATE TABLE patients (
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

CREATE TABLE product_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    name text NOT NULL
);

CREATE TABLE products (
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

CREATE TABLE stock_movements (
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

CREATE TABLE suppliers (
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

CREATE VIEW product_stock_v AS
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
   FROM (((products pr
     LEFT JOIN product_categories pc ON (((pc.id = pr.category_id) AND (pc.clinic_id = pr.clinic_id))))
     LEFT JOIN suppliers s ON (((s.id = pr.supplier_id) AND (s.clinic_id = pr.clinic_id))))
     LEFT JOIN stock_movements sm ON (((sm.product_id = pr.id) AND (sm.clinic_id = pr.clinic_id))))
  GROUP BY pr.clinic_id, pr.id, pr.category_id, pc.name, pr.supplier_id, s.name, pr.name, pr.description, pr.sku, pr.unit, pr.min_stock_quantity, pr.reorder_quantity, pr.unit_cost, pr.is_active;

CREATE TABLE providers (
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

CREATE TABLE recall_contacts (
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

CREATE TABLE service_bundle_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    parent_service_id uuid NOT NULL,
    child_service_id uuid NOT NULL,
    sort_order integer DEFAULT 10 NOT NULL
);

CREATE TABLE service_catalog (
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

CREATE TABLE tooth_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    tooth_fdi smallint NOT NULL,
    surface character varying(10) NOT NULL,
    condition character varying(50) NOT NULL,
    notes text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE treatment_plan_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    treatment_plan_id uuid NOT NULL,
    service_id uuid NOT NULL,
    provider_id uuid,
    tooth_number text,
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

CREATE TABLE treatment_plans (
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

CREATE VIEW v_agenda_daily AS
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
    tpi.tooth_number,
    (EXISTS ( SELECT 1
           FROM patient_anamnesis pa2
          WHERE ((pa2.patient_id = p.id) AND (pa2.clinic_id = a.clinic_id) AND (pa2.is_current = true) AND (pa2.allergy_penicillin OR pa2.allergy_latex OR pa2.allergy_anesthetic OR pa2.allergy_aspirin OR (pa2.other_allergies IS NOT NULL))))) AS has_allergy_alert,
    (EXISTS ( SELECT 1
           FROM patient_anamnesis pa2
          WHERE ((pa2.patient_id = p.id) AND (pa2.clinic_id = a.clinic_id) AND (pa2.is_current = true) AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates OR pa2.heart_disease)))) AS has_medication_alert
   FROM ((((appointments a
     LEFT JOIN patients p ON ((p.id = a.patient_id)))
     LEFT JOIN providers pr ON ((pr.id = a.provider_id)))
     LEFT JOIN treatment_plan_items tpi ON ((tpi.id = a.treatment_plan_item_id)))
     LEFT JOIN service_catalog sc ON ((sc.id = tpi.service_id)));

CREATE VIEW v_clinic_dashboard AS
 WITH patient_agg AS (
         SELECT patients.clinic_id,
            count(*) FILTER (WHERE (patients.active = true)) AS patients_count
           FROM patients
          GROUP BY patients.clinic_id
        ), provider_agg AS (
         SELECT providers.clinic_id,
            count(*) FILTER (WHERE (providers.active = true)) AS active_providers_count
           FROM providers
          GROUP BY providers.clinic_id
        ), plan_agg AS (
         SELECT treatment_plans.clinic_id,
            count(*) FILTER (WHERE (treatment_plans.status = 'in_progress'::dentalcare.treatment_plan_status)) AS in_progress_treatment_plans_count
           FROM treatment_plans
          GROUP BY treatment_plans.clinic_id
        )
 SELECT c.id AS clinic_id,
    c.name AS clinic_name,
    c.city,
    COALESCE(pa.patients_count, (0)::bigint) AS patients_count,
    COALESCE(pra.active_providers_count, (0)::bigint) AS active_providers_count,
    COALESCE(tpa.in_progress_treatment_plans_count, (0)::bigint) AS in_progress_treatment_plans_count
   FROM (((clinics c
     LEFT JOIN patient_agg pa ON ((pa.clinic_id = c.id)))
     LEFT JOIN provider_agg pra ON ((pra.clinic_id = c.id)))
     LEFT JOIN plan_agg tpa ON ((tpa.clinic_id = c.id)));

CREATE VIEW v_patient_clinical_card AS
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
    pa.general_notes AS anamnesis_notes,
    pa.recorded_at AS anamnesis_date,
    ( SELECT count(*) AS count
           FROM appointments a
          WHERE ((a.patient_id = p.id) AND (a.clinic_id = p.clinic_id))) AS total_appointments
   FROM (patients p
     LEFT JOIN patient_anamnesis pa ON (((pa.patient_id = p.id) AND (pa.clinic_id = p.clinic_id) AND (pa.is_current = true))));

CREATE VIEW v_patient_dashboard AS
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
   FROM (((patients p
     LEFT JOIN treatment_plans tp ON (((tp.patient_id = p.id) AND (tp.clinic_id = p.clinic_id))))
     LEFT JOIN treatment_plan_items tpi ON (((tpi.treatment_plan_id = tp.id) AND (tpi.clinic_id = p.clinic_id))))
     LEFT JOIN estimates e ON (((e.patient_id = p.id) AND (e.clinic_id = p.clinic_id))))
  GROUP BY p.id, p.clinic_id, p.first_name, p.last_name, p.fiscal_code, p.birth_date, p.phone, p.email, p.city, p.province, p.active;

CREATE VIEW v_patient_estimates_summary AS
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
   FROM (estimates e
     LEFT JOIN patients p ON (((p.id = e.patient_id) AND (p.clinic_id = e.clinic_id))));

ALTER TABLE ONLY ai_conversations
    ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id);

ALTER TABLE ONLY appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);

ALTER TABLE ONLY appointments
    ADD CONSTRAINT appointments_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);

ALTER TABLE ONLY chat_sessions
    ADD CONSTRAINT chat_sessions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY clinical_history_entries
    ADD CONSTRAINT clinical_history_entries_pkey PRIMARY KEY (id);

ALTER TABLE ONLY clinical_history_entries
    ADD CONSTRAINT clinical_history_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY clinics
    ADD CONSTRAINT clinics_pkey PRIMARY KEY (id);

ALTER TABLE ONLY condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_pkey PRIMARY KEY (id);

ALTER TABLE ONLY estimate_lines
    ADD CONSTRAINT estimate_lines_pkey PRIMARY KEY (id);

ALTER TABLE ONLY estimate_lines
    ADD CONSTRAINT estimate_lines_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY estimates
    ADD CONSTRAINT estimates_pkey PRIMARY KEY (id);

ALTER TABLE ONLY estimates
    ADD CONSTRAINT estimates_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY invoice_lines
    ADD CONSTRAINT invoice_lines_pkey PRIMARY KEY (id);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT invoices_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY odontogram_teeth
    ADD CONSTRAINT odontogram_teeth_pkey PRIMARY KEY (id);

ALTER TABLE ONLY odontogram_teeth
    ADD CONSTRAINT odontogram_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_unique UNIQUE (clinic_id, patient_id, item_id);

ALTER TABLE ONLY patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY patient_diagnoses
    ADD CONSTRAINT patient_diagnoses_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patient_documents
    ADD CONSTRAINT patient_documents_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patient_documents
    ADD CONSTRAINT patient_documents_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY patient_prescriptions
    ADD CONSTRAINT patient_prescriptions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patient_recalls
    ADD CONSTRAINT patient_recalls_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patient_recalls
    ADD CONSTRAINT patient_recalls_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);

ALTER TABLE ONLY patients
    ADD CONSTRAINT patients_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY product_categories
    ADD CONSTRAINT product_categories_clinic_id_name_key UNIQUE (clinic_id, name);

ALTER TABLE ONLY product_categories
    ADD CONSTRAINT product_categories_id_clinic_id_key UNIQUE (id, clinic_id);

ALTER TABLE ONLY product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);

ALTER TABLE ONLY products
    ADD CONSTRAINT products_id_clinic_id_key UNIQUE (id, clinic_id);

ALTER TABLE ONLY products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);

ALTER TABLE ONLY providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);

ALTER TABLE ONLY providers
    ADD CONSTRAINT providers_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY recall_contacts
    ADD CONSTRAINT recall_contacts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY recall_contacts
    ADD CONSTRAINT recall_contacts_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY service_bundle_items
    ADD CONSTRAINT service_bundle_items_pkey PRIMARY KEY (id);

ALTER TABLE ONLY service_catalog
    ADD CONSTRAINT service_catalog_pkey PRIMARY KEY (id);

ALTER TABLE ONLY service_catalog
    ADD CONSTRAINT service_catalog_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY stock_movements
    ADD CONSTRAINT stock_movements_id_clinic_id_key UNIQUE (id, clinic_id);

ALTER TABLE ONLY stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);

ALTER TABLE ONLY suppliers
    ADD CONSTRAINT suppliers_id_clinic_id_key UNIQUE (id, clinic_id);

ALTER TABLE ONLY suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);

ALTER TABLE ONLY tooth_conditions
    ADD CONSTRAINT tooth_conditions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_pkey PRIMARY KEY (id);

ALTER TABLE ONLY treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY treatment_plans
    ADD CONSTRAINT treatment_plans_pkey PRIMARY KEY (id);

ALTER TABLE ONLY treatment_plans
    ADD CONSTRAINT treatment_plans_unique_per_clinic UNIQUE (id, clinic_id);

ALTER TABLE ONLY service_bundle_items
    ADD CONSTRAINT uq_bundle_item UNIQUE (clinic_id, parent_service_id, child_service_id);

ALTER TABLE ONLY condition_service_defaults
    ADD CONSTRAINT uq_condition_default UNIQUE (clinic_id, condition_name, service_id);

ALTER TABLE ONLY tooth_conditions
    ADD CONSTRAINT uq_tooth_surface UNIQUE (clinic_id, patient_id, tooth_fdi, surface);

ALTER TABLE ONLY estimates
    ADD CONSTRAINT ux_estimates_clinic_number UNIQUE (clinic_id, estimate_number);

ALTER TABLE ONLY invoices
    ADD CONSTRAINT ux_invoices_number UNIQUE (clinic_id, invoice_number);

ALTER TABLE ONLY service_catalog
    ADD CONSTRAINT ux_service_catalog_clinic_code UNIQUE (clinic_id, code);

CREATE INDEX chat_messages_session_idx ON chat_messages USING btree (session_id);

CREATE INDEX chat_sessions_provider_idx ON chat_sessions USING btree (provider_id, created_at DESC);

CREATE INDEX idx_patient_diagnoses_patient ON patient_diagnoses USING btree (clinic_id, patient_id);

CREATE INDEX idx_patient_diagnoses_status ON patient_diagnoses USING btree (clinic_id, patient_id, status);

CREATE INDEX idx_patient_prescriptions_active ON patient_prescriptions USING btree (clinic_id, patient_id, active);

CREATE INDEX idx_patient_prescriptions_patient ON patient_prescriptions USING btree (clinic_id, patient_id);

CREATE INDEX idx_tooth_conditions_patient ON tooth_conditions USING btree (clinic_id, patient_id);

CREATE INDEX ix_ai_conversations_clinic ON ai_conversations USING btree (clinic_id);

CREATE INDEX ix_appointments_clinic_date ON appointments USING btree (clinic_id, starts_at, ends_at);

CREATE INDEX ix_appointments_patient ON appointments USING btree (clinic_id, patient_id, starts_at DESC);

CREATE INDEX ix_appointments_provider_date ON appointments USING btree (clinic_id, provider_id, starts_at);

CREATE INDEX ix_clinical_history_patient_date ON clinical_history_entries USING btree (clinic_id, patient_id, entry_date DESC);

CREATE INDEX ix_condition_service_defaults_cond ON condition_service_defaults USING btree (clinic_id, condition_name);

CREATE INDEX ix_estimate_lines_estimate_position ON estimate_lines USING btree (clinic_id, estimate_id, line_position);

CREATE INDEX ix_estimate_lines_plan_item ON estimate_lines USING btree (clinic_id, treatment_plan_item_id) WHERE (treatment_plan_item_id IS NOT NULL);

CREATE INDEX ix_estimate_lines_treatment_item ON estimate_lines USING btree (clinic_id, treatment_plan_item_id) WHERE (treatment_plan_item_id IS NOT NULL);

CREATE INDEX ix_estimates_clinic_patient_status ON estimates USING btree (clinic_id, patient_id, status, created_at DESC);

CREATE INDEX ix_estimates_clinic_plan_status ON estimates USING btree (clinic_id, treatment_plan_id, status) WHERE (treatment_plan_id IS NOT NULL);

CREATE INDEX ix_estimates_provider ON estimates USING btree (clinic_id, created_by_provider_id) WHERE (created_by_provider_id IS NOT NULL);

CREATE INDEX ix_estimates_treatment_plan ON estimates USING btree (clinic_id, treatment_plan_id) WHERE (treatment_plan_id IS NOT NULL);

CREATE INDEX ix_invoice_lines_clinic ON invoice_lines USING btree (clinic_id);

CREATE INDEX ix_invoice_lines_invoice ON invoice_lines USING btree (invoice_id);

CREATE INDEX ix_invoices_clinic_status ON invoices USING btree (clinic_id, status, invoice_date DESC);

CREATE INDEX ix_invoices_estimate ON invoices USING btree (clinic_id, estimate_id) WHERE (estimate_id IS NOT NULL);

CREATE INDEX ix_invoices_patient ON invoices USING btree (clinic_id, patient_id);

CREATE INDEX ix_invoices_provider ON invoices USING btree (clinic_id, provider_id) WHERE (provider_id IS NOT NULL);

CREATE INDEX ix_odontogram_patient_tooth ON odontogram_teeth USING btree (clinic_id, patient_id, tooth_number, recorded_at DESC);

CREATE INDEX ix_patient_anamnesis_patient_current ON patient_anamnesis USING btree (clinic_id, patient_id, is_current, recorded_at DESC);

CREATE INDEX ix_patient_anamnesis_selections_patient ON patient_anamnesis_item_selections USING btree (clinic_id, patient_id);

CREATE INDEX ix_patient_documents_patient_type ON patient_documents USING btree (clinic_id, patient_id, document_type, taken_at DESC);

CREATE INDEX ix_patients_clinic_name ON patients USING btree (clinic_id, last_name, first_name);

CREATE INDEX ix_patients_clinic_phone ON patients USING btree (clinic_id, phone) WHERE (phone IS NOT NULL);

CREATE INDEX ix_patients_primary_provider ON patients USING btree (clinic_id, primary_provider_id) WHERE (primary_provider_id IS NOT NULL);

CREATE INDEX ix_products_category ON products USING btree (clinic_id, category_id);

CREATE INDEX ix_products_clinic ON products USING btree (clinic_id) WHERE (is_active = true);

CREATE INDEX ix_providers_clinic_active ON providers USING btree (clinic_id, active);

CREATE INDEX ix_recall_contacts_recall ON recall_contacts USING btree (recall_id, contact_at DESC);

CREATE INDEX ix_recalls_clinic_status ON patient_recalls USING btree (clinic_id, status, due_date);

CREATE INDEX ix_recalls_due_date ON patient_recalls USING btree (clinic_id, due_date);

CREATE INDEX ix_recalls_patient ON patient_recalls USING btree (clinic_id, patient_id);

CREATE INDEX ix_service_bundle_parent ON service_bundle_items USING btree (clinic_id, parent_service_id);

CREATE INDEX ix_service_catalog_clinic_active_category ON service_catalog USING btree (clinic_id, active, category);

CREATE INDEX ix_stock_movements_product ON stock_movements USING btree (clinic_id, product_id, created_at DESC);

CREATE INDEX ix_suppliers_clinic ON suppliers USING btree (clinic_id) WHERE (is_active = true);

CREATE INDEX ix_tooth_conditions_patient_fdi_surface ON tooth_conditions USING btree (clinic_id, patient_id, tooth_fdi, surface);

CREATE INDEX ix_treatment_plan_items_plan_status ON treatment_plan_items USING btree (clinic_id, treatment_plan_id, status, priority);

CREATE INDEX ix_treatment_plan_items_provider ON treatment_plan_items USING btree (clinic_id, provider_id) WHERE (provider_id IS NOT NULL);

CREATE INDEX ix_treatment_plan_items_service ON treatment_plan_items USING btree (clinic_id, service_id);

CREATE INDEX ix_treatment_plans_clinic_patient_status ON treatment_plans USING btree (clinic_id, patient_id, status);

CREATE INDEX ix_treatment_plans_status_updated ON treatment_plans USING btree (clinic_id, status, updated_at DESC);

CREATE UNIQUE INDEX ux_clinics_vat_number ON clinics USING btree (vat_number) WHERE (vat_number IS NOT NULL);

CREATE UNIQUE INDEX ux_patients_clinic_fiscal_code ON patients USING btree (clinic_id, fiscal_code) WHERE (fiscal_code IS NOT NULL);

CREATE TRIGGER trg_ai_conversations_updated_at BEFORE UPDATE ON ai_conversations FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_appointments_updated_at BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_clinical_history_updated_at BEFORE UPDATE ON clinical_history_entries FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_clinics_updated_at BEFORE UPDATE ON clinics FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_estimates_updated_at BEFORE UPDATE ON estimates FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_invoice_line_compute_totals BEFORE INSERT OR UPDATE ON invoice_lines FOR EACH ROW EXECUTE FUNCTION trg_compute_invoice_line_totals();

CREATE TRIGGER trg_invoice_lines_updated_at BEFORE UPDATE ON invoice_lines FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_invoices_recalc_from_lines AFTER INSERT OR DELETE OR UPDATE ON invoice_lines FOR EACH ROW EXECUTE FUNCTION trg_update_invoice_totals_from_lines();

CREATE TRIGGER trg_invoices_set_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_odontogram_updated_at BEFORE UPDATE ON odontogram_teeth FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_patient_anamnesis_selections_updated_at BEFORE UPDATE ON patient_anamnesis_item_selections FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_patient_anamnesis_updated_at BEFORE UPDATE ON patient_anamnesis FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_patient_diagnoses_updated_at BEFORE UPDATE ON patient_diagnoses FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_patient_documents_updated_at BEFORE UPDATE ON patient_documents FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_patient_prescriptions_updated_at BEFORE UPDATE ON patient_prescriptions FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_patients_updated_at BEFORE UPDATE ON patients FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_providers_updated_at BEFORE UPDATE ON providers FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_recalls_updated_at BEFORE UPDATE ON patient_recalls FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_service_catalog_updated_at BEFORE UPDATE ON service_catalog FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_suppliers_updated_at BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_treatment_plan_items_updated_at BEFORE UPDATE ON treatment_plan_items FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

CREATE TRIGGER trg_treatment_plans_updated_at BEFORE UPDATE ON treatment_plans FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();

ALTER TABLE ONLY ai_conversations
    ADD CONSTRAINT ai_conversations_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY ai_conversations
    ADD CONSTRAINT ai_conversations_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE SET NULL;

ALTER TABLE ONLY ai_conversations
    ADD CONSTRAINT ai_conversations_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE SET NULL;

ALTER TABLE ONLY appointments
    ADD CONSTRAINT appointments_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY chat_messages
    ADD CONSTRAINT chat_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE;

ALTER TABLE ONLY clinical_history_entries
    ADD CONSTRAINT clinical_history_entries_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY clinics
    ADD CONSTRAINT clinics_city_id_fkey FOREIGN KEY (city_id) REFERENCES dentalcare.cities(id);

ALTER TABLE ONLY condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY condition_service_defaults
    ADD CONSTRAINT condition_service_defaults_service_id_fkey FOREIGN KEY (service_id) REFERENCES service_catalog(id) ON DELETE CASCADE;

ALTER TABLE ONLY estimate_lines
    ADD CONSTRAINT estimate_lines_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY estimates
    ADD CONSTRAINT estimates_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY appointments
    ADD CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY appointments
    ADD CONSTRAINT fk_appointments_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY appointments
    ADD CONSTRAINT fk_appointments_treatment_item FOREIGN KEY (treatment_plan_item_id) REFERENCES treatment_plan_items(id) ON DELETE SET NULL;

ALTER TABLE ONLY service_bundle_items
    ADD CONSTRAINT fk_bundle_child FOREIGN KEY (child_service_id) REFERENCES service_catalog(id) ON DELETE CASCADE;

ALTER TABLE ONLY service_bundle_items
    ADD CONSTRAINT fk_bundle_parent FOREIGN KEY (parent_service_id) REFERENCES service_catalog(id) ON DELETE CASCADE;

ALTER TABLE ONLY clinical_history_entries
    ADD CONSTRAINT fk_clinical_history_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY clinical_history_entries
    ADD CONSTRAINT fk_clinical_history_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY estimate_lines
    ADD CONSTRAINT fk_estimate_lines_estimate FOREIGN KEY (estimate_id, clinic_id) REFERENCES estimates(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY estimate_lines
    ADD CONSTRAINT fk_estimate_lines_service FOREIGN KEY (service_id, clinic_id) REFERENCES service_catalog(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY estimate_lines
    ADD CONSTRAINT fk_estimate_lines_treatment_item FOREIGN KEY (treatment_plan_item_id, clinic_id) REFERENCES treatment_plan_items(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY estimates
    ADD CONSTRAINT fk_estimates_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY estimates
    ADD CONSTRAINT fk_estimates_treatment_plan FOREIGN KEY (treatment_plan_id, clinic_id) REFERENCES treatment_plans(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY invoice_lines
    ADD CONSTRAINT fk_invoice_lines_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY invoice_lines
    ADD CONSTRAINT fk_invoice_lines_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;

ALTER TABLE ONLY invoices
    ADD CONSTRAINT fk_invoices_estimate FOREIGN KEY (estimate_id, clinic_id) REFERENCES estimates(id, clinic_id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY invoices
    ADD CONSTRAINT fk_invoices_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY invoices
    ADD CONSTRAINT fk_invoices_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE ONLY odontogram_teeth
    ADD CONSTRAINT fk_odontogram_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY odontogram_teeth
    ADD CONSTRAINT fk_odontogram_provider FOREIGN KEY (recorded_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT fk_pais_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_anamnesis
    ADD CONSTRAINT fk_patient_anamnesis_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_anamnesis
    ADD CONSTRAINT fk_patient_anamnesis_provider FOREIGN KEY (recorded_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY patient_diagnoses
    ADD CONSTRAINT fk_patient_diagnoses_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_diagnoses
    ADD CONSTRAINT fk_patient_diagnoses_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_diagnoses
    ADD CONSTRAINT fk_patient_diagnoses_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY patient_documents
    ADD CONSTRAINT fk_patient_documents_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_documents
    ADD CONSTRAINT fk_patient_documents_provider FOREIGN KEY (uploaded_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY patient_prescriptions
    ADD CONSTRAINT fk_patient_prescriptions_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_prescriptions
    ADD CONSTRAINT fk_patient_prescriptions_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_prescriptions
    ADD CONSTRAINT fk_patient_prescriptions_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY products
    ADD CONSTRAINT fk_products_category FOREIGN KEY (category_id, clinic_id) REFERENCES product_categories(id, clinic_id) ON DELETE SET NULL;

ALTER TABLE ONLY products
    ADD CONSTRAINT fk_products_supplier FOREIGN KEY (supplier_id, clinic_id) REFERENCES suppliers(id, clinic_id) ON DELETE SET NULL;

ALTER TABLE ONLY recall_contacts
    ADD CONSTRAINT fk_recall_contacts_recall FOREIGN KEY (recall_id, clinic_id) REFERENCES patient_recalls(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_recalls
    ADD CONSTRAINT fk_recalls_booked_apt FOREIGN KEY (booked_appointment_id) REFERENCES appointments(id) ON DELETE SET NULL;

ALTER TABLE ONLY patient_recalls
    ADD CONSTRAINT fk_recalls_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_recalls
    ADD CONSTRAINT fk_recalls_source_apt FOREIGN KEY (source_appointment_id) REFERENCES appointments(id) ON DELETE SET NULL;

ALTER TABLE ONLY stock_movements
    ADD CONSTRAINT fk_stock_movements_product FOREIGN KEY (product_id, clinic_id) REFERENCES products(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_plan FOREIGN KEY (treatment_plan_id, clinic_id) REFERENCES treatment_plans(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_service FOREIGN KEY (service_id, clinic_id) REFERENCES service_catalog(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY treatment_plans
    ADD CONSTRAINT fk_treatment_plans_patient FOREIGN KEY (patient_id, clinic_id) REFERENCES patients(id, clinic_id) ON DELETE CASCADE;

ALTER TABLE ONLY treatment_plans
    ADD CONSTRAINT fk_treatment_plans_provider FOREIGN KEY (created_by_provider_id, clinic_id) REFERENCES providers(id, clinic_id) ON DELETE RESTRICT;

ALTER TABLE ONLY invoices
    ADD CONSTRAINT invoices_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY odontogram_teeth
    ADD CONSTRAINT odontogram_teeth_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_anamnesis
    ADD CONSTRAINT patient_anamnesis_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey FOREIGN KEY (item_id) REFERENCES dentalcare.anamnesis_items(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_documents
    ADD CONSTRAINT patient_documents_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patient_recalls
    ADD CONSTRAINT patient_recalls_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY patients
    ADD CONSTRAINT patients_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY patients
    ADD CONSTRAINT patients_primary_provider_id_fkey FOREIGN KEY (primary_provider_id) REFERENCES providers(id) ON DELETE SET NULL;

ALTER TABLE ONLY product_categories
    ADD CONSTRAINT product_categories_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY products
    ADD CONSTRAINT products_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY providers
    ADD CONSTRAINT providers_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY recall_contacts
    ADD CONSTRAINT recall_contacts_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY service_bundle_items
    ADD CONSTRAINT service_bundle_items_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY service_catalog
    ADD CONSTRAINT service_catalog_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY stock_movements
    ADD CONSTRAINT stock_movements_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY suppliers
    ADD CONSTRAINT suppliers_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE RESTRICT;

ALTER TABLE ONLY treatment_plan_items
    ADD CONSTRAINT treatment_plan_items_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;

ALTER TABLE ONLY treatment_plans
    ADD CONSTRAINT treatment_plans_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE;
$ddl$;
    EXECUTE l_ddl;

    INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active)
    VALUES (p_tenant_id, p_studio_name, p_schema, p_email, p_phone, COALESCE(NULLIF(p_plan, ''), 'professional'), true);

    EXECUTE format(
        'INSERT INTO %I.clinics (id, name, legal_name, vat_number, fiscal_code, phone, email, '
        || 'address_line1, city, province, country) '
        || 'VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,''IT'')', p_schema)
    USING p_clinic_id, p_studio_name, p_studio_name, p_vat, p_vat, p_phone, p_email, p_address, p_city, p_province;

    INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id) VALUES (p_clinic_id, p_tenant_id);

    EXECUTE format(
        'INSERT INTO %I.providers (id, clinic_id, first_name, last_name, email, role, active, password_hash) '
        || 'VALUES ($1,$2,$3,$4,$5,''tenant_admin''::dentalcare.provider_role,true,$6)', p_schema)
    USING l_admin_id, p_clinic_id, p_admin_first, p_admin_last, p_admin_email, p_admin_pw_hash;

    RETURN l_admin_id;
END $provision$;
