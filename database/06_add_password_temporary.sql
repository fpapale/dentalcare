-- Add password_temporary flag to providers in all existing tenant schemas
-- Run once against the dentalcarepro database

DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT schema_name FROM dentalcare.tenants WHERE active = true
    LOOP
        EXECUTE format(
            'ALTER TABLE %I.providers ADD COLUMN IF NOT EXISTS password_temporary BOOLEAN NOT NULL DEFAULT FALSE',
            rec.schema_name
        );
    END LOOP;
END;
$$;
