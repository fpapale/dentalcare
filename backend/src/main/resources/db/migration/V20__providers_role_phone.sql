-- V20: add provider_role enum + role/phone/updated_at columns to tenant providers
-- EstimateSchemaInitializer adds most columns but misses role (needs enum) and phone

-- 1. Create dentalcare.provider_role enum (idempotent)
DO $$ BEGIN
    CREATE TYPE dentalcare.provider_role AS ENUM (
        'dentist', 'hygienist', 'orthodontist', 'surgeon',
        'assistant', 'admin', 'tenant_admin', 'other'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add any values that may be missing from older enum definitions
DO $$ BEGIN ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'tenant_admin';   EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'orthodontist';   EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'surgeon';        EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'assistant';      EXCEPTION WHEN others THEN NULL; END $$;
DO $$ BEGIN ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'other';          EXCEPTION WHEN others THEN NULL; END $$;

-- 2. Add columns to all active tenant schemas
DO $$
DECLARE
    r RECORD;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'dentalcare' AND table_name = 'tenants'
    ) THEN
        RETURN;
    END IF;

    FOR r IN
        SELECT t.schema_name
        FROM dentalcare.tenants t
        WHERE t.active = true
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.schemata WHERE schema_name = r.schema_name
        ) THEN
            CONTINUE;
        END IF;

        EXECUTE format(
            'ALTER TABLE %I.providers
                ADD COLUMN IF NOT EXISTS role        dentalcare.provider_role NOT NULL DEFAULT ''dentist'',
                ADD COLUMN IF NOT EXISTS phone       text,
                ADD COLUMN IF NOT EXISTS updated_at  timestamptz NOT NULL DEFAULT now()',
            r.schema_name
        );
    END LOOP;
END $$;
