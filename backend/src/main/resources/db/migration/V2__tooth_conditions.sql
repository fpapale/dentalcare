-- Tooth conditions per patient, per FDI tooth number, per surface
-- Surface values: 'B' (buccal), 'L' (lingual/palatal), 'M' (mesial), 'D' (distal), 'O' (occlusal), 'WHOLE' (whole tooth)
-- Condition values: healthy, cavity, filling, crown, missing, extracted, implant, bridge_pillar, bridge_pontic, root_canal, to_extract
-- Only non-healthy conditions are stored (absence = healthy)
CREATE TABLE IF NOT EXISTS dentalcare.tooth_conditions (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id   UUID        NOT NULL,
    patient_id  UUID        NOT NULL,
    tooth_fdi   SMALLINT    NOT NULL,
    surface     VARCHAR(10) NOT NULL,
    condition   VARCHAR(50) NOT NULL,
    notes       TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_tooth_surface UNIQUE (clinic_id, patient_id, tooth_fdi, surface)
);

CREATE INDEX IF NOT EXISTS idx_tooth_conditions_patient
    ON dentalcare.tooth_conditions (clinic_id, patient_id);
