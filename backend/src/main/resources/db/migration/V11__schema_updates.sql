-- V11: Schema updates — cities, holidays, ai_conversations

SET search_path TO dentalcare, public;

-- =========================================================
-- 1. cities: add missing columns
-- =========================================================

ALTER TABLE dentalcare.cities
    ADD COLUMN IF NOT EXISTS postal_code text,
    ADD COLUMN IF NOT EXISTS is_capital  boolean NOT NULL DEFAULT false;

-- =========================================================
-- 2. national_holidays: add is_fixed alias column
--    (original schema uses is_recurring; new code uses is_fixed)
-- =========================================================

ALTER TABLE dentalcare.national_holidays
    ADD COLUMN IF NOT EXISTS is_fixed boolean;

UPDATE dentalcare.national_holidays
SET is_fixed = NOT is_recurring
WHERE is_fixed IS NULL;

-- =========================================================
-- 3. Easter 2036 (Pasqua + Pasquetta)
-- =========================================================

INSERT INTO dentalcare.national_holidays (state_id, name, is_recurring, holiday_date, is_fixed)
SELECT '00000001-0000-0000-0000-000000000001', 'Pasqua',    false, '2036-04-13', false
WHERE NOT EXISTS (
    SELECT 1 FROM dentalcare.national_holidays
    WHERE holiday_date = '2036-04-13'
      AND state_id = '00000001-0000-0000-0000-000000000001'
);

INSERT INTO dentalcare.national_holidays (state_id, name, is_recurring, holiday_date, is_fixed)
SELECT '00000001-0000-0000-0000-000000000001', 'Pasquetta', false, '2036-04-14', false
WHERE NOT EXISTS (
    SELECT 1 FROM dentalcare.national_holidays
    WHERE holiday_date = '2036-04-14'
      AND state_id = '00000001-0000-0000-0000-000000000001'
);

-- =========================================================
-- 4. set_updated_at function in dentalcare schema (idempotent)
-- =========================================================

CREATE OR REPLACE FUNCTION dentalcare.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- =========================================================
-- 5. ai_conversations — create in tenant schema
-- =========================================================

SET search_path TO t_9d754153, dentalcare, public;

CREATE TABLE IF NOT EXISTS ai_conversations (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id   uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    patient_id  uuid REFERENCES patients(id)  ON DELETE SET NULL,
    provider_id uuid REFERENCES providers(id) ON DELETE SET NULL,
    title       text,
    messages    jsonb NOT NULL DEFAULT '[]',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_ai_conversations_clinic
    ON ai_conversations (clinic_id);

DO $$ BEGIN
    CREATE TRIGGER trg_ai_conversations_updated_at
    BEFORE UPDATE ON ai_conversations
    FOR EACH ROW EXECUTE FUNCTION dentalcare.set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
