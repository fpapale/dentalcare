-- V6: Add created_by_provider_id to estimates for doctor-scoped visibility

SET search_path TO dentalcare, public;

ALTER TABLE estimates
ADD COLUMN IF NOT EXISTS created_by_provider_id uuid;

CREATE INDEX IF NOT EXISTS ix_estimates_provider
ON estimates(clinic_id, created_by_provider_id)
WHERE created_by_provider_id IS NOT NULL;
