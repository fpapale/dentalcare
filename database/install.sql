-- =============================================================================
-- DentalCare - Installazione completa parametrica
-- =============================================================================
-- Crea un nuovo database, lo schema globale "dentalcare" (enum, funzioni,
-- tabelle di riferimento + dati) e il tenant demo "t_9d754153" con tutti i
-- dati di esempio. La tabella dentalcare.tenants contiene SOLO il tenant demo.
--
-- USO:
--   psql -U postgres -d postgres -v dbname=NOME_DB -f database/install.sql
--
-- Se ometti -v dbname=..., il database si chiama "dentalcare".
--
-- Generato da pg_dump del DB di riferimento (schemi dentalcare + t_9d754153).
-- Rigenerare con lo stesso comando dopo modifiche allo schema/seed.
-- =============================================================================

\set ON_ERROR_STOP on

\if :{?dbname}
\else
  \set dbname dentalcare
\endif

\echo 'Creazione database' :dbname
CREATE DATABASE :"dbname";
\connect :"dbname"

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

--
-- PostgreSQL database dump
--


-- Dumped from database version 15.18 (Debian 15.18-0+deb12u1)
-- Dumped by pg_dump version 17.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
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
    'tenant_admin'
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
    general_notes text,
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
    tpi.tooth_number,
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
     LEFT JOIN t_9d754153.service_catalog sc ON ((sc.id = tpi.service_id)));


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
    pa.general_notes AS anamnesis_notes,
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
     LEFT JOIN t_9d754153.treatment_plan_items tpi ON (((tpi.treatment_plan_id = tp.id) AND (tpi.clinic_id = p.clinic_id))))
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
9d754153-6579-4b7e-a56b-025f00299cd9	Clinica Demo DentalCare Roma	DentalCare Roma S.r.l.	DEMO-ROMA-001	DEMOROMA001	+39 06 5550101	Via Nomentana 123	\N	Roma	RM	00162	IT	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N
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

COPY t_9d754153.patient_anamnesis (id, clinic_id, patient_id, recorded_at, recorded_by_provider_id, blood_type, smoker, cigarettes_per_day, alcohol_use, drug_use, hypertension, diabetes, diabetes_type, heart_disease, coagulopathy, immunodeficiency, osteoporosis, thyroid_disease, epilepsy, hepatitis, hiv_positive, tumor_history, autoimmune_disease, other_diseases, taking_anticoagulants, taking_bisphosphonates, taking_cortisone, current_medications, allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin, other_allergies, bruxism, mouth_breathing, nail_biting, pacifier_use, general_notes, signed_at, signature_notes, is_current, created_at, updated_at) FROM stdin;
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
3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	9d754153-6579-4b7e-a56b-025f00299cd9	Papale	Fabrizio	pplfrz63d09h501w	1963-04-09	+393483448500	Via Millevie 801	\N	Roma	RM	00100	IT	Pasta e patate	2026-05-29 17:28:16.854142+00	2026-05-29 17:28:16.854142+00	\N	fabrizio.papale@gmail.com	t	b1000001-0000-0000-0000-000000000003
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
b1000001-0000-0000-0000-000000000001	9d754153-6579-4b7e-a56b-025f00299cd9	Laura	Ferretti	dentist	+39 334 1001001	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
b1000001-0000-0000-0000-000000000002	9d754153-6579-4b7e-a56b-025f00299cd9	Paolo	Marchetti	surgeon	+39 334 1001002	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
b1000001-0000-0000-0000-000000000003	9d754153-6579-4b7e-a56b-025f00299cd9	Serena	Amato	orthodontist	+39 334 1001003	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
b1000001-0000-0000-0000-000000000004	9d754153-6579-4b7e-a56b-025f00299cd9	Michele	Gentili	hygienist	+39 334 1001004	t	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	PARC	\N	\N	\N	f
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
\.


--
-- Data for Name: treatment_plan_items; Type: TABLE DATA; Schema: t_9d754153; Owner: -
--

COPY t_9d754153.treatment_plan_items (id, clinic_id, treatment_plan_id, service_id, provider_id, tooth_number, quadrant, surfaces, quantity, planned_price, planned_vat_rate, clinical_notes, status, priority, planned_date, completed_at, created_at, updated_at) FROM stdin;
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
e1000001-0000-0000-0000-000000000012	9d754153-6579-4b7e-a56b-025f00299cd9	c1000001-0000-0000-0000-000000000018	Urgenza 26 devitalizzazione - Barbieri Sara	\N	proposed	b1000001-0000-0000-0000-000000000001	\N	\N	\N	\N	2026-05-29 13:52:49.31794+00	2026-05-29 13:52:49.31794+00
1a124ae0-1eaa-4c5a-bfe1-ad5d500509d0	9d754153-6579-4b7e-a56b-025f00299cd9	3ad7ac7c-09ba-4c45-a91f-e7e063c44b0b	Riabilitazione	Nota mia	draft	\N	\N	\N	\N	\N	2026-05-29 17:29:34.46128+00	2026-05-29 17:29:34.46128+00
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

CREATE INDEX ix_treatment_plan_items_plan_status ON t_9d754153.treatment_plan_items USING btree (clinic_id, treatment_plan_id, status, priority);


--
-- Name: ix_treatment_plan_items_provider; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plan_items_provider ON t_9d754153.treatment_plan_items USING btree (clinic_id, provider_id) WHERE (provider_id IS NOT NULL);


--
-- Name: ix_treatment_plan_items_service; Type: INDEX; Schema: t_9d754153; Owner: -
--

CREATE INDEX ix_treatment_plan_items_service ON t_9d754153.treatment_plan_items USING btree (clinic_id, service_id);


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
    ADD CONSTRAINT fk_treatment_plan_items_plan FOREIGN KEY (treatment_plan_id, clinic_id) REFERENCES t_9d754153.treatment_plans(id, clinic_id) ON DELETE CASCADE;


--
-- Name: treatment_plan_items fk_treatment_plan_items_provider; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_provider FOREIGN KEY (provider_id, clinic_id) REFERENCES t_9d754153.providers(id, clinic_id) ON DELETE RESTRICT;


--
-- Name: treatment_plan_items fk_treatment_plan_items_service; Type: FK CONSTRAINT; Schema: t_9d754153; Owner: -
--

ALTER TABLE ONLY t_9d754153.treatment_plan_items
    ADD CONSTRAINT fk_treatment_plan_items_service FOREIGN KEY (service_id, clinic_id) REFERENCES t_9d754153.service_catalog(id, clinic_id) ON DELETE RESTRICT;


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




-- =============================================================================
-- Tenant demo (UNICO tenant) + mapping clinica
-- =============================================================================
INSERT INTO dentalcare.tenants
    (id, name, schema_name, email, phone, plan, active, created_at, updated_at)
VALUES
    ('a0000001-0000-0000-0000-000000000001', 'Clinica Demo DentalCare',
     't_9d754153', 'demo@dentalcare.it', NULL, 'professional', true, now(), now());

INSERT INTO dentalcare.tenant_clinics
    (clinic_id, tenant_id, created_at)
VALUES
    ('9d754153-6579-4b7e-a56b-025f00299cd9',
     'a0000001-0000-0000-0000-000000000001', now());

\echo 'Installazione completata. Database:' :dbname
