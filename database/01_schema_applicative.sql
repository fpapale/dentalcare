-- =============================================================================
-- DentalCare Pro - Schema Applicativo Globale
-- File: 01_schema_applicative.sql
-- Descrizione: Crea lo schema globale `dentalcare` con tutte le tabelle
--              applicative condivise tra tenant: tenants, geo, anamnesi.
-- Uso: psql -U postgres -d dentalcarepro -f 01_schema_applicative.sql
-- Requisiti: PostgreSQL 14+, superuser o owner del database dentalcarepro
-- Idempotente: SI (IF NOT EXISTS / EXCEPTION WHEN duplicate_object)
-- =============================================================================

BEGIN;

-- Estensioni necessarie
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- Schema globale
CREATE SCHEMA IF NOT EXISTS dentalcare;

SET search_path TO dentalcare, public;

-- =============================================================================
-- ENUM GLOBALI
-- Tutti gli enum vivono nello schema dentalcare e sono referenziati dagli
-- schema tenant tramite search_path (dentalcare e' nel path).
-- =============================================================================

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
        'accepted',     -- accettato dal paziente
        'scheduled',    -- schedulato in agenda
        'completed',    -- eseguito
        'cancelled'     -- annullato
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE estimate_status AS ENUM (
        'draft',        -- bozza
        'sent',         -- inviato/consegnato al paziente
        'accepted',     -- accettato
        'rejected',     -- rifiutato
        'expired',      -- scaduto per data
        'cancelled'     -- annullato manualmente
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

DO $$ BEGIN
    CREATE TYPE appointment_status AS ENUM (
        'scheduled',    -- prenotato
        'confirmed',    -- confermato dal paziente
        'presente',     -- paziente arrivato in sala d'attesa
        'in_progress',  -- seduta in corso
        'completed',    -- seduta completata
        'no_show',      -- paziente non presentato
        'cancelled'     -- annullato
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE tooth_condition AS ENUM (
        'healthy',       -- sano
        'caries',        -- carie
        'filling',       -- otturazione
        'crown',         -- corona
        'missing',       -- mancante/estratto
        'implant',       -- impianto
        'devitalized',   -- devitalizzato
        'fracture',      -- frattura
        'to_extract',    -- da estrarre
        'bridge_anchor'  -- pilastro/pontile di ponte
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE document_type AS ENUM (
        'radiograph',       -- radiografia generica
        'photo',            -- foto clinica
        'consent_form',     -- consenso informato
        'report',           -- referto/relazione
        'other'             -- altro documento
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_document_type AS ENUM (
        'fattura',
        'ricevuta',
        'nota_credito'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_status AS ENUM (
        'draft',    -- bozza
        'issued',   -- emessa
        'sent',     -- inviata al paziente
        'paid',     -- pagata
        'cancelled',-- annullata
        'overdue'   -- scaduta non pagata
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_issuer_type AS ENUM (
        'clinic',    -- emessa dalla clinica (persona giuridica)
        'provider'   -- emessa dal professionista (libero professionista)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE stock_movement_type AS ENUM (
        'carico',    -- ingresso merce (acquisto/ricevimento)
        'scarico',   -- uscita merce (utilizzo/consumo)
        'rientro',   -- reso/rientro in magazzino
        'rettifica'  -- rettifica inventariale (puo' essere positiva o negativa)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_status AS ENUM (
        'pending',      -- da contattare
        'contacted',    -- contattato, in attesa risposta
        'booked',       -- appuntamento prenotato
        'completed',    -- richiamo completato
        'cancelled',    -- richiamo annullato
        'unreachable'   -- irraggiungibile dopo piu' tentativi
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_priority AS ENUM (
        'low',      -- bassa priorita'
        'medium',   -- media priorita'
        'high',     -- alta priorita'
        'urgent'    -- urgente (scaduto o quasi)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_contact_type AS ENUM (
        'phone',      -- telefonata
        'sms',        -- SMS
        'email',      -- email
        'whatsapp',   -- WhatsApp
        'in_person'   -- contatto di persona
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_outcome AS ENUM (
        'no_answer',       -- nessuna risposta
        'left_message',    -- messaggio lasciato
        'refused',         -- paziente rifiuta
        'booked',          -- appuntamento prenotato
        'already_booked',  -- gia' prenotato altrove
        'scheduled_later'  -- vuole essere ricontattato piu' tardi
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- FUNZIONE DI SERVIZIO: aggiornamento automatico updated_at
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- TABELLA: tenants
-- Registro di tutti i tenant (studi dentistici) del SaaS.
-- =============================================================================

CREATE TABLE IF NOT EXISTS tenants (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text        NOT NULL,
    schema_name text        NOT NULL UNIQUE,
    email       citext,
    phone       text,
    -- piano abbonamento: trial, professional, enterprise
    plan        text        NOT NULL DEFAULT 'trial'
                            CHECK (plan IN ('trial', 'professional', 'enterprise')),
    active      boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tenants_name_not_empty CHECK (length(trim(name)) > 0),
    -- schema_name deve avere formato t_XXXXXXXX (8 hex chars)
    CONSTRAINT tenants_schema_name_format
        CHECK (schema_name ~ '^t_[0-9a-f]{8}$')
);

DROP TRIGGER IF EXISTS trg_tenants_updated_at ON tenants;
CREATE TRIGGER trg_tenants_updated_at
BEFORE UPDATE ON tenants
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- TABELLA: tenant_clinics
-- Mappa tenant → clinic_id (la clinica vive nel tenant schema).
-- Permette join veloci senza dover interrogare ogni schema tenant.
-- =============================================================================

CREATE TABLE IF NOT EXISTS tenant_clinics (
    clinic_id   uuid        PRIMARY KEY,
    tenant_id   uuid        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_tenant_clinics_tenant_id
    ON tenant_clinics (tenant_id);

-- =============================================================================
-- TABELLA: anamnesis_categories
-- Categorie delle voci amnestiche (globali, condivise tra tutti i tenant).
-- =============================================================================

CREATE TABLE IF NOT EXISTS anamnesis_categories (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text    NOT NULL UNIQUE,
    sort_order  integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT anamnesis_categories_name_not_empty CHECK (length(trim(name)) > 0)
);

-- =============================================================================
-- TABELLA: anamnesis_items
-- Singole voci amnestiche legate a una categoria.
-- code: identificatore univoco leggibile (es. SIS_01, FAR_01)
-- has_detail: se true il frontend mostra campo testo libero aggiuntivo
-- =============================================================================

CREATE TABLE IF NOT EXISTS anamnesis_items (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id uuid    NOT NULL REFERENCES anamnesis_categories(id) ON DELETE CASCADE,
    code        text    NOT NULL UNIQUE,
    label       text    NOT NULL,
    description text,
    has_detail  boolean NOT NULL DEFAULT false,
    sort_order  integer NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT anamnesis_items_code_not_empty  CHECK (length(trim(code)) > 0),
    CONSTRAINT anamnesis_items_label_not_empty CHECK (length(trim(label)) > 0)
);

CREATE INDEX IF NOT EXISTS ix_anamnesis_items_category
    ON anamnesis_items (category_id, sort_order);

-- =============================================================================
-- TABELLA: states
-- Nazioni/stati (anagrafica geografica).
-- code: ISO 3166-1 alpha-2 (es. IT, DE, FR)
-- =============================================================================

CREATE TABLE IF NOT EXISTS states (
    id      uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    code    char(2) NOT NULL UNIQUE,
    name    text    NOT NULL
);

-- =============================================================================
-- TABELLA: regions
-- Regioni geografiche di uno stato.
-- =============================================================================

CREATE TABLE IF NOT EXISTS regions (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id    uuid    NOT NULL REFERENCES states(id),
    name        text    NOT NULL,
    code        text    NOT NULL,
    UNIQUE (state_id, code)
);

-- =============================================================================
-- TABELLA: cities
-- Comuni/citta'. Usata per autocompletamento indirizzi.
-- =============================================================================

CREATE TABLE IF NOT EXISTS cities (
    id              uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id       uuid    NOT NULL REFERENCES regions(id),
    name            text    NOT NULL,
    province_code   char(2),
    postal_code     text,
    is_capital      boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS ix_cities_region
    ON cities (region_id);

CREATE INDEX IF NOT EXISTS ix_cities_name
    ON cities (name);

-- =============================================================================
-- TABELLA: national_holidays
-- Giorni festivi nazionali. Usata per il calcolo degli slot agenda.
-- is_fixed=false per Pasqua e Lunedi' dell'Angelo (calcolati).
-- =============================================================================

CREATE TABLE IF NOT EXISTS national_holidays (
    id           uuid     PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id     uuid     NOT NULL REFERENCES states(id),
    name         text     NOT NULL,
    is_recurring boolean  NOT NULL DEFAULT true,
    -- recurring holidays: month+day repeat every year
    month        smallint,
    day          smallint,
    -- non-recurring holidays: specific date (e.g. Easter)
    holiday_date date,
    -- alias column added by V11 for backwards compat: is_fixed = NOT is_recurring
    is_fixed     boolean,
    CONSTRAINT chk_holiday_def CHECK (
        (is_recurring = TRUE  AND month IS NOT NULL AND day IS NOT NULL AND holiday_date IS NULL) OR
        (is_recurring = FALSE AND holiday_date IS NOT NULL AND month IS NULL AND day IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS ix_holidays_recurring
    ON national_holidays (state_id, month, day)
    WHERE is_recurring = TRUE;

CREATE INDEX IF NOT EXISTS ix_holidays_date
    ON national_holidays (state_id, holiday_date)
    WHERE holiday_date IS NOT NULL;

-- =============================================================================
-- NOTA: dentalcare.invoice_lines
-- =============================================================================
-- NOTE: dentalcare.invoice_lines was an artifact of early migrations (V7).
-- It was explicitly dropped by V17__create_tenant_invoice_lines.sql.
-- invoice_lines now lives exclusively in each tenant schema.

-- =============================================================================
-- VERIFICA
-- =============================================================================

SELECT
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname = 'dentalcare'
ORDER BY tablename;

COMMIT;
