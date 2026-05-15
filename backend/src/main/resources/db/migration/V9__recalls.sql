-- V9: Patient recalls module — recall tracking, contact log, auto-priority

SET search_path TO dentalcare, public;

-- =========================================================
-- 1. ENUMs
-- =========================================================

DO $$ BEGIN
    CREATE TYPE recall_status AS ENUM (
        'da_contattare', 'contattato', 'in_attesa', 'confermato', 'chiuso', 'annullato'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_priority AS ENUM ('alta', 'media', 'bassa');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_contact_type AS ENUM ('telefono', 'sms', 'email', 'whatsapp');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE recall_outcome AS ENUM (
        'risposto', 'non_risposto', 'messaggio_lasciato', 'confermato', 'rifiutato'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================
-- 2. patient_recalls TABLE
-- =========================================================

CREATE TABLE IF NOT EXISTS patient_recalls (
    id                      uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid            NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    patient_id              uuid            NOT NULL,
    recall_type             text            NOT NULL DEFAULT 'Controllo periodico',
    due_date                date            NOT NULL,
    status                  recall_status   NOT NULL DEFAULT 'da_contattare',
    priority                recall_priority NOT NULL DEFAULT 'media',
    notes                   text,
    source_appointment_id   uuid,
    booked_appointment_id   uuid,
    last_contact_at         date,
    contact_count           integer         NOT NULL DEFAULT 0,
    created_at              timestamptz     NOT NULL DEFAULT now(),
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    CONSTRAINT patient_recalls_unique_per_clinic UNIQUE (id, clinic_id)
);

-- FK: patient (composite — patients has UNIQUE(id, clinic_id) from clinical_extension)
ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS fk_recalls_patient;
ALTER TABLE patient_recalls
    ADD CONSTRAINT fk_recalls_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE;

-- FK: source_appointment (simple — appointments.id is PK)
ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS fk_recalls_source_apt;
ALTER TABLE patient_recalls
    ADD CONSTRAINT fk_recalls_source_apt
        FOREIGN KEY (source_appointment_id)
        REFERENCES appointments(id)
        ON DELETE SET NULL;

-- FK: booked_appointment (simple)
ALTER TABLE patient_recalls
    DROP CONSTRAINT IF EXISTS fk_recalls_booked_apt;
ALTER TABLE patient_recalls
    ADD CONSTRAINT fk_recalls_booked_apt
        FOREIGN KEY (booked_appointment_id)
        REFERENCES appointments(id)
        ON DELETE SET NULL;

-- =========================================================
-- 3. recall_contacts TABLE
-- =========================================================

CREATE TABLE IF NOT EXISTS recall_contacts (
    id                      uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid                NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    recall_id               uuid                NOT NULL,
    contact_type            recall_contact_type NOT NULL DEFAULT 'telefono',
    contact_at              timestamptz         NOT NULL DEFAULT now(),
    outcome                 recall_outcome      NOT NULL,
    notes                   text,
    created_by_provider_id  uuid,
    created_at              timestamptz         NOT NULL DEFAULT now(),
    CONSTRAINT recall_contacts_unique_per_clinic UNIQUE (id, clinic_id)
);

-- FK: recall (composite)
ALTER TABLE recall_contacts
    DROP CONSTRAINT IF EXISTS fk_recall_contacts_recall;
ALTER TABLE recall_contacts
    ADD CONSTRAINT fk_recall_contacts_recall
        FOREIGN KEY (recall_id, clinic_id)
        REFERENCES patient_recalls(id, clinic_id)
        ON DELETE CASCADE;

-- =========================================================
-- 4. INDEXES
-- =========================================================

CREATE INDEX IF NOT EXISTS ix_recalls_clinic_status
    ON patient_recalls(clinic_id, status, due_date);

CREATE INDEX IF NOT EXISTS ix_recalls_patient
    ON patient_recalls(clinic_id, patient_id);

CREATE INDEX IF NOT EXISTS ix_recalls_due_date
    ON patient_recalls(clinic_id, due_date)
    WHERE status::text NOT IN ('chiuso', 'annullato');

CREATE INDEX IF NOT EXISTS ix_recall_contacts_recall
    ON recall_contacts(recall_id, contact_at DESC);

-- =========================================================
-- 5. FUNCTION: priority auto-compute helper
-- =========================================================

CREATE OR REPLACE FUNCTION compute_recall_priority(p_due_date date)
RETURNS dentalcare.recall_priority AS $$
BEGIN
    IF p_due_date < current_date THEN
        RETURN 'alta'::dentalcare.recall_priority;
    ELSIF p_due_date <= current_date + interval '30 days' THEN
        RETURN 'media'::dentalcare.recall_priority;
    ELSE
        RETURN 'bassa'::dentalcare.recall_priority;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- =========================================================
-- 6. FUNCTION + TRIGGER: update recall on new contact
-- =========================================================

CREATE OR REPLACE FUNCTION update_recall_on_contact()
RETURNS trigger AS $$
BEGIN
    UPDATE dentalcare.patient_recalls
    SET
        contact_count   = contact_count + 1,
        last_contact_at = NEW.contact_at::date,
        status          = CASE
                            WHEN NEW.outcome = 'confermato' THEN 'confermato'::dentalcare.recall_status
                            WHEN status = 'da_contattare'  THEN 'contattato'::dentalcare.recall_status
                            ELSE status
                          END,
        updated_at      = now()
    WHERE id = NEW.recall_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recall_contact_update ON recall_contacts;
CREATE TRIGGER trg_recall_contact_update
AFTER INSERT ON recall_contacts
FOR EACH ROW EXECUTE FUNCTION update_recall_on_contact();

-- =========================================================
-- 7. TRIGGER: updated_at on patient_recalls
-- =========================================================

DROP TRIGGER IF EXISTS trg_recalls_updated_at ON patient_recalls;
CREATE TRIGGER trg_recalls_updated_at
BEFORE UPDATE ON patient_recalls
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- VERIFY
-- =========================================================

SELECT
    (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'dentalcare'
          AND table_name   = 'patient_recalls')                             AS patient_recalls_exists,
    (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'dentalcare'
          AND table_name   = 'recall_contacts')                             AS recall_contacts_exists,
    (SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = 'dentalcare'
          AND routine_name   = 'compute_recall_priority')                   AS compute_priority_fn_exists,
    (SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = 'dentalcare'
          AND routine_name   = 'update_recall_on_contact')                  AS update_on_contact_fn_exists,
    (SELECT COUNT(*) FROM information_schema.triggers
        WHERE trigger_schema = 'dentalcare'
          AND trigger_name   = 'trg_recall_contact_update')                 AS contact_trigger_exists,
    (SELECT COUNT(*) FROM information_schema.triggers
        WHERE trigger_schema = 'dentalcare'
          AND trigger_name   = 'trg_recalls_updated_at')                    AS updated_at_trigger_exists;
