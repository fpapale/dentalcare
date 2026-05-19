-- V13: patient diagnoses table

SET search_path TO t_9d754153, dentalcare, public;

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
