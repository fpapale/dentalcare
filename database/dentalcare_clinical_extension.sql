-- DentalCare - Integrazione schema clinico
-- Aggiunge le tabelle mancanti per:
--   - Agenda (appuntamenti per paziente/provider/poltrona)
--   - Anamnesi
--   - Odontogramma
--   - Documenti / RX
-- Uso:
--   psql -h 172.168.0.173 -U postgres -d dentalcarepro -f dentalcare_clinical_extension.sql

BEGIN;

SET search_path TO dentalcare, public;

-- =========================================================
-- ENUM aggiuntivi
-- =========================================================

DO $$ BEGIN
    CREATE TYPE appointment_status AS ENUM (
        'scheduled',    -- prenotato
        'confirmed',    -- confermato
        'in_progress',  -- in corso
        'completed',    -- completato
        'cancelled',    -- annullato
        'no_show'       -- paziente non presentato
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE tooth_condition AS ENUM (
        'healthy',       -- sano
        'caries',        -- carie
        'filling',       -- otturazione
        'crown',         -- corona
        'missing',       -- mancante
        'implant',       -- impianto
        'devitalized',   -- devitalizzato
        'fracture',      -- frattura
        'to_extract',    -- da estrarre
        'bridge_anchor'  -- ancora di ponte
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE document_type AS ENUM (
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
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================
-- AGENDA (Appuntamenti)
-- =========================================================

CREATE TABLE IF NOT EXISTS appointments (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id          uuid NOT NULL,
    provider_id         uuid NOT NULL,
    treatment_plan_item_id uuid,        -- link opzionale al piano di cura
    chair_label         text NOT NULL DEFAULT 'Poltrona 1',
    starts_at           timestamptz NOT NULL,
    ends_at             timestamptz NOT NULL,
    status              appointment_status NOT NULL DEFAULT 'scheduled',
    notes               text,
    cancellation_reason text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT appointments_dates_valid CHECK (ends_at > starts_at),
    CONSTRAINT appointments_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT fk_appointments_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_appointments_provider
        FOREIGN KEY (provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_treatment_item
        FOREIGN KEY (treatment_plan_item_id)
        REFERENCES treatment_plan_items(id)
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_appointments_clinic_date
    ON appointments (clinic_id, starts_at, ends_at);

CREATE INDEX IF NOT EXISTS ix_appointments_provider_date
    ON appointments (clinic_id, provider_id, starts_at);

CREATE INDEX IF NOT EXISTS ix_appointments_patient
    ON appointments (clinic_id, patient_id, starts_at DESC);

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at
BEFORE UPDATE ON appointments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- ANAMNESI
-- =========================================================

CREATE TABLE IF NOT EXISTS patient_anamnesis (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id              uuid NOT NULL,
    recorded_at             timestamptz NOT NULL DEFAULT now(),
    recorded_by_provider_id uuid,

    -- Dati generali di salute
    blood_type              text,               -- A+, B-, 0+, ...
    smoker                  boolean,
    cigarettes_per_day      smallint,
    alcohol_use             boolean,
    drug_use                boolean,

    -- Patologie sistemiche (checkbox + note)
    hypertension            boolean NOT NULL DEFAULT false,
    diabetes                boolean NOT NULL DEFAULT false,
    diabetes_type           text,               -- tipo 1, tipo 2, gestazionale
    heart_disease           boolean NOT NULL DEFAULT false,
    coagulopathy            boolean NOT NULL DEFAULT false,
    immunodeficiency        boolean NOT NULL DEFAULT false,
    osteoporosis            boolean NOT NULL DEFAULT false,
    thyroid_disease         boolean NOT NULL DEFAULT false,
    epilepsy                boolean NOT NULL DEFAULT false,
    hepatitis               boolean NOT NULL DEFAULT false,
    hiv_positive            boolean NOT NULL DEFAULT false,
    tumor_history           boolean NOT NULL DEFAULT false,
    autoimmune_disease      boolean NOT NULL DEFAULT false,
    other_diseases          text,

    -- Farmaci assunti
    taking_anticoagulants   boolean NOT NULL DEFAULT false,
    taking_bisphosphonates  boolean NOT NULL DEFAULT false,
    taking_cortisone        boolean NOT NULL DEFAULT false,
    current_medications     text,               -- testo libero

    -- Allergie
    allergy_penicillin      boolean NOT NULL DEFAULT false,
    allergy_latex           boolean NOT NULL DEFAULT false,
    allergy_anesthetic      boolean NOT NULL DEFAULT false,
    allergy_aspirin         boolean NOT NULL DEFAULT false,
    other_allergies         text,

    -- Abitudini orali
    bruxism                 boolean NOT NULL DEFAULT false,
    mouth_breathing         boolean NOT NULL DEFAULT false,
    nail_biting             boolean NOT NULL DEFAULT false,
    pacifier_use            boolean,            -- null = non applicabile (adulti)

    -- Note generali aggiuntive
    general_notes           text,
    -- Firma paziente / consenso
    signed_at               timestamptz,
    signature_notes         text,

    is_current              boolean NOT NULL DEFAULT true,   -- true = versione attiva
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT patient_anamnesis_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT fk_patient_anamnesis_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_patient_anamnesis_provider
        FOREIGN KEY (recorded_by_provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_patient_anamnesis_patient_current
    ON patient_anamnesis (clinic_id, patient_id, is_current, recorded_at DESC);

DROP TRIGGER IF EXISTS trg_patient_anamnesis_updated_at ON patient_anamnesis;
CREATE TRIGGER trg_patient_anamnesis_updated_at
BEFORE UPDATE ON patient_anamnesis
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- ODONTOGRAMMA
-- Un record per dente per paziente.
-- Può avere più entry storiche (storico_clinico), l'ultima è quella attiva.
-- =========================================================

CREATE TABLE IF NOT EXISTS odontogram_teeth (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id      uuid NOT NULL,
    tooth_number    text NOT NULL,           -- notazione FDI es. '16', '36', '11'
    quadrant        smallint NOT NULL CHECK (quadrant BETWEEN 1 AND 4),
    is_deciduous    boolean NOT NULL DEFAULT false,
    condition       tooth_condition NOT NULL DEFAULT 'healthy',
    surfaces        text[],                  -- es. ARRAY['O','M','D','V','L']
    bridge_group_id uuid,                    -- collega i denti di un ponte
    implant_ref     text,                    -- riferimento impianto se presente
    notes           text,
    recorded_at     timestamptz NOT NULL DEFAULT now(),
    recorded_by_provider_id uuid,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT odontogram_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT fk_odontogram_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_odontogram_provider
        FOREIGN KEY (recorded_by_provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
);

-- Indice per query dell'odontogramma per paziente (ordinato per dente e data)
CREATE INDEX IF NOT EXISTS ix_odontogram_patient_tooth
    ON odontogram_teeth (clinic_id, patient_id, tooth_number, recorded_at DESC);

DROP TRIGGER IF EXISTS trg_odontogram_updated_at ON odontogram_teeth;
CREATE TRIGGER trg_odontogram_updated_at
BEFORE UPDATE ON odontogram_teeth
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- STORICO CLINICO (Note di seduta)
-- Una entry per ogni visita/seduta eseguita
-- =========================================================

CREATE TABLE IF NOT EXISTS clinical_history_entries (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id          uuid NOT NULL,
    appointment_id      uuid,
    provider_id         uuid NOT NULL,
    entry_date          date NOT NULL DEFAULT current_date,
    tooth_number        text,
    service_code        text,               -- codice prestazione eseguita (snapshot)
    service_name        text,               -- nome prestazione (snapshot)
    clinical_notes      text NOT NULL,
    materials_used      text,
    next_visit_notes    text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT clinical_history_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT fk_clinical_history_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_clinical_history_provider
        FOREIGN KEY (provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_clinical_history_patient_date
    ON clinical_history_entries (clinic_id, patient_id, entry_date DESC);

DROP TRIGGER IF EXISTS trg_clinical_history_updated_at ON clinical_history_entries;
CREATE TRIGGER trg_clinical_history_updated_at
BEFORE UPDATE ON clinical_history_entries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- DOCUMENTI E RADIOGRAFIE
-- =========================================================

CREATE TABLE IF NOT EXISTS patient_documents (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id          uuid NOT NULL,
    appointment_id      uuid,
    uploaded_by_provider_id uuid,
    document_type       document_type NOT NULL DEFAULT 'altro',
    title               text NOT NULL,
    description         text,
    file_name           text NOT NULL,      -- nome file originale
    file_path           text NOT NULL,      -- percorso storage (es. S3 key o path locale)
    file_size_bytes     bigint,
    mime_type           text,
    tooth_number        text,               -- dente di riferimento (per RX endorali)
    taken_at            date,               -- data acquisizione (es. data RX)
    notes               text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT patient_documents_unique_per_clinic UNIQUE (id, clinic_id),
    CONSTRAINT patient_documents_title_not_empty CHECK (length(trim(title)) > 0),
    CONSTRAINT patient_documents_file_name_not_empty CHECK (length(trim(file_name)) > 0),
    CONSTRAINT fk_patient_documents_patient
        FOREIGN KEY (patient_id, clinic_id)
        REFERENCES patients(id, clinic_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_patient_documents_provider
        FOREIGN KEY (uploaded_by_provider_id, clinic_id)
        REFERENCES providers(id, clinic_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ix_patient_documents_patient_type
    ON patient_documents (clinic_id, patient_id, document_type, taken_at DESC);

DROP TRIGGER IF EXISTS trg_patient_documents_updated_at ON patient_documents;
CREATE TRIGGER trg_patient_documents_updated_at
BEFORE UPDATE ON patient_documents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- VISTE CLINICHE AGGIUNTIVE
-- =========================================================

-- Vista agenda giornaliera per poltrona/provider
CREATE OR REPLACE VIEW v_agenda_daily AS
SELECT
    a.id AS appointment_id,
    a.clinic_id,
    c.name AS clinic_name,
    a.starts_at,
    a.ends_at,
    a.chair_label,
    a.status AS appointment_status,
    a.notes,
    p.id AS patient_id,
    p.last_name AS patient_last_name,
    p.first_name AS patient_first_name,
    concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
    p.phone AS patient_phone,
    prov.id AS provider_id,
    concat_ws(' ', prov.last_name, prov.first_name) AS provider_name,
    prov.role AS provider_role,
    sc.name AS service_name,
    sc.category AS service_category,
    tpi.tooth_number,
    tpi.clinical_notes AS treatment_notes,
    -- Alert urgenti dal anamnesi
    (SELECT bool_or(allergy_penicillin OR allergy_anesthetic OR allergy_latex)
     FROM patient_anamnesis pa
     WHERE pa.patient_id = p.id
       AND pa.clinic_id = a.clinic_id
       AND pa.is_current = true) AS has_allergy_alert,
    (SELECT bool_or(taking_anticoagulants OR taking_bisphosphonates)
     FROM patient_anamnesis pa
     WHERE pa.patient_id = p.id
       AND pa.clinic_id = a.clinic_id
       AND pa.is_current = true) AS has_medication_alert
FROM appointments a
JOIN clinics c ON c.id = a.clinic_id
JOIN patients p ON p.id = a.patient_id AND p.clinic_id = a.clinic_id
JOIN providers prov ON prov.id = a.provider_id AND prov.clinic_id = a.clinic_id
LEFT JOIN treatment_plan_items tpi ON tpi.id = a.treatment_plan_item_id AND tpi.clinic_id = a.clinic_id
LEFT JOIN service_catalog sc ON sc.id = tpi.service_id AND sc.clinic_id = tpi.clinic_id;

-- Vista cartella clinica paziente (sommario)
CREATE OR REPLACE VIEW v_patient_clinical_card AS
SELECT
    p.id AS patient_id,
    p.clinic_id,
    p.last_name,
    p.first_name,
    concat_ws(' ', p.last_name, p.first_name) AS full_name,
    p.fiscal_code,
    p.birth_date,
    CASE WHEN p.birth_date IS NULL THEN NULL
         ELSE date_part('year', age(current_date, p.birth_date))::int END AS age_years,
    p.phone,
    p.email,
    p.city,
    p.province,
    p.notes AS patient_notes,
    -- Anamnesi corrente
    ana.blood_type,
    ana.smoker,
    ana.hypertension,
    ana.diabetes,
    ana.heart_disease,
    ana.taking_anticoagulants,
    ana.taking_bisphosphonates,
    ana.allergy_penicillin,
    ana.allergy_latex,
    ana.allergy_anesthetic,
    ana.other_allergies,
    ana.general_notes AS anamnesis_notes,
    ana.recorded_at AS anamnesis_date,
    -- Contatori clinici
    (SELECT COUNT(*) FROM appointments a WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id) AS total_appointments,
    (SELECT COUNT(*) FROM appointments a WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id AND a.status = 'completed') AS completed_appointments,
    (SELECT MAX(starts_at) FROM appointments a WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id AND a.status = 'completed') AS last_visit_at,
    (SELECT MIN(starts_at) FROM appointments a WHERE a.patient_id = p.id AND a.clinic_id = p.clinic_id AND a.starts_at > now() AND a.status IN ('scheduled','confirmed')) AS next_appointment_at,
    (SELECT COUNT(*) FROM patient_documents pd WHERE pd.patient_id = p.id AND pd.clinic_id = p.clinic_id) AS documents_count,
    (SELECT COUNT(*) FROM patient_documents pd WHERE pd.patient_id = p.id AND pd.clinic_id = p.clinic_id AND pd.document_type IN ('rx_endorale','rx_panoramica','cbct')) AS rx_count,
    (SELECT COUNT(*) FROM treatment_plans tp WHERE tp.patient_id = p.id AND tp.clinic_id = p.clinic_id AND tp.status IN ('accepted','in_progress')) AS active_treatment_plans_count,
    p.created_at AS patient_since
FROM patients p
LEFT JOIN patient_anamnesis ana
    ON ana.patient_id = p.id
   AND ana.clinic_id = p.clinic_id
   AND ana.is_current = true;

COMMIT;
