-- =============================================================================
-- Patch: medico di riferimento del paziente (primary_provider_id)
-- Aggiunge la colonna + FK + indice a TUTTI gli schemi tenant esistenti (t_%).
-- Idempotente: rieseguibile senza errori.
-- Eseguire in pgAdmin sul database dentalcarepro.
-- =============================================================================

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name LIKE 't\_%'
    LOOP
        EXECUTE format(
            'ALTER TABLE %I.patients ADD COLUMN IF NOT EXISTS primary_provider_id uuid', r.schema_name);

        EXECUTE format(
            'ALTER TABLE %I.patients DROP CONSTRAINT IF EXISTS patients_primary_provider_id_fkey', r.schema_name);

        EXECUTE format(
            'ALTER TABLE %I.patients ADD CONSTRAINT patients_primary_provider_id_fkey '
            'FOREIGN KEY (primary_provider_id) REFERENCES %I.providers(id) ON DELETE SET NULL',
            r.schema_name, r.schema_name);

        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS ix_patients_primary_provider '
            'ON %I.patients (clinic_id, primary_provider_id) WHERE primary_provider_id IS NOT NULL',
            r.schema_name);

        RAISE NOTICE 'patched schema %', r.schema_name;
    END LOOP;
END $$;
