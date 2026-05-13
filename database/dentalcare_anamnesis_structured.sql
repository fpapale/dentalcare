-- DentalCare - Anamnesi Strutturata per Categorie e Voci
-- Aggiunge le tabelle per categorie amnestiche configurabili e selezioni per paziente.
-- Uso:
--   psql -d dentalcarepro -f dentalcare_anamnesis_structured.sql

BEGIN;

SET search_path TO dentalcare, public;

-- =========================================================
-- CATEGORIE AMNESTICHE (globali, non per clinic)
-- =========================================================

CREATE TABLE IF NOT EXISTS anamnesis_categories (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code        text NOT NULL,
    name        text NOT NULL,
    description text,
    icon        text NOT NULL DEFAULT 'medical_information',
    sort_order  integer NOT NULL DEFAULT 100,
    enabled     boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT anamnesis_categories_code_unique UNIQUE (code),
    CONSTRAINT anamnesis_categories_name_not_empty CHECK (length(trim(name)) > 0)
);

CREATE INDEX IF NOT EXISTS ix_anamnesis_categories_sort
    ON anamnesis_categories (sort_order, code)
    WHERE enabled = true;

-- =========================================================
-- VOCI AMNESTICHE (globali, legate a categoria)
-- =========================================================

CREATE TABLE IF NOT EXISTS anamnesis_items (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id uuid NOT NULL REFERENCES anamnesis_categories(id) ON DELETE CASCADE,
    code        text NOT NULL,
    label       text NOT NULL,
    description text,
    is_alert    boolean NOT NULL DEFAULT false,
    sort_order  integer NOT NULL DEFAULT 100,
    enabled     boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT anamnesis_items_code_unique UNIQUE (code),
    CONSTRAINT anamnesis_items_label_not_empty CHECK (length(trim(label)) > 0)
);

CREATE INDEX IF NOT EXISTS ix_anamnesis_items_category_sort
    ON anamnesis_items (category_id, sort_order)
    WHERE enabled = true;

-- =========================================================
-- SELEZIONI PER PAZIENTE (per clinic, per paziente)
-- =========================================================

CREATE TABLE IF NOT EXISTS patient_anamnesis_item_selections (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid NOT NULL,
    item_id                 uuid NOT NULL REFERENCES anamnesis_items(id) ON DELETE CASCADE,
    notes                   text,
    recorded_at             timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    recorded_by_provider_id uuid,
    CONSTRAINT patient_anamnesis_item_selections_unique
        UNIQUE (clinic_id, patient_id, item_id),
    CONSTRAINT fk_pais_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_selections_patient
    ON patient_anamnesis_item_selections (clinic_id, patient_id);

DROP TRIGGER IF EXISTS trg_patient_anamnesis_selections_updated_at ON patient_anamnesis_item_selections;
CREATE TRIGGER trg_patient_anamnesis_selections_updated_at
BEFORE UPDATE ON patient_anamnesis_item_selections
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
