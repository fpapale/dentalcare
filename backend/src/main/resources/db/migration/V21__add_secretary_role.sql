-- V21: add secretary to provider_role enum
DO $$ BEGIN
    ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'secretary';
EXCEPTION WHEN others THEN NULL;
END $$;
