-- Aggiunge patients.foreign_patient a tutti gli schemi tenant esistenti. Idempotente.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schema_name FROM dentalcare.tenants LOOP
    EXECUTE format(
      'ALTER TABLE %I.patients ADD COLUMN IF NOT EXISTS foreign_patient boolean NOT NULL DEFAULT false',
      r.schema_name);
  END LOOP;
END $$;
