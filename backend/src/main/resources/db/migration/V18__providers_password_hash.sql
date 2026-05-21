-- V18: Add password_hash to providers for real JWT authentication.
SET search_path TO t_9d754153, dentalcare, public;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT t.schema_name
        FROM dentalcare.tenants t
        WHERE t.active = true
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.schemata
            WHERE schema_name = r.schema_name
        ) THEN
            EXECUTE format(
                'ALTER TABLE %I.providers ADD COLUMN IF NOT EXISTS password_hash TEXT',
                r.schema_name
            );
        END IF;
    END LOOP;
END $$;
