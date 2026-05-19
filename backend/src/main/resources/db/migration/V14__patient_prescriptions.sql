-- V14: patient prescriptions table

SET search_path TO t_9d754153, dentalcare, public;

CREATE TABLE IF NOT EXISTS patient_prescriptions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       UUID NOT NULL,
    patient_id      UUID NOT NULL,
    provider_id     UUID NOT NULL,
    drug_name       VARCHAR(255) NOT NULL,
    dosage          VARCHAR(100),
    frequency       VARCHAR(100),
    duration        VARCHAR(100),
    notes           TEXT,
    prescribed_at   DATE NOT NULL DEFAULT CURRENT_DATE,
    expires_at      DATE,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_patient_prescriptions_patient ON patient_prescriptions (clinic_id, patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_prescriptions_active  ON patient_prescriptions (clinic_id, patient_id, active);
