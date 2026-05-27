-- V19: add billing/contact columns to tenant clinics tables
-- tenant-schema-template.sql has these columns but existing DBs may be missing them

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
            'ALTER TABLE %I.clinics
                ADD COLUMN IF NOT EXISTS legal_name    text,
                ADD COLUMN IF NOT EXISTS vat_number    text,
                ADD COLUMN IF NOT EXISTS fiscal_code   text,
                ADD COLUMN IF NOT EXISTS phone         text,
                ADD COLUMN IF NOT EXISTS email         text,
                ADD COLUMN IF NOT EXISTS address_line1 text,
                ADD COLUMN IF NOT EXISTS address_line2 text,
                ADD COLUMN IF NOT EXISTS city          text,
                ADD COLUMN IF NOT EXISTS province      text,
                ADD COLUMN IF NOT EXISTS postal_code   text,
                ADD COLUMN IF NOT EXISTS country       text NOT NULL DEFAULT ''IT'',
                ADD COLUMN IF NOT EXISTS updated_at    timestamptz NOT NULL DEFAULT now()',
            r.schema_name
        );
    END LOOP;
END $$;
