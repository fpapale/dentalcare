-- Patch: aggiunge patients.foreign_patient (flag "paziente straniero" per bypassare
-- la validazione del codice fiscale italiano) a tutti gli schemi tenant esistenti.
-- Colonna già presente per i nuovi tenant tramite dentalcare.create_tenant() e nello
-- schema demo t_9d754153 in install.sql. Idempotente: ADD COLUMN IF NOT EXISTS.
-- Applicare sia in dev che in prod.

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT nspname FROM pg_namespace WHERE nspname ~ '^t_[0-9a-f]{8}$' ORDER BY nspname LOOP
    EXECUTE format(
      'ALTER TABLE %I.patients ADD COLUMN IF NOT EXISTS foreign_patient boolean NOT NULL DEFAULT false',
      r.nspname);
  END LOOP;
END$$;

-- Verifica
SELECT n.nspname AS tenant_schema, a.attname AS column_name,
       format_type(a.atttypid, a.atttypmod) AS data_type,
       a.attnotnull AS not_null
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
  AND c.relname = 'patients'
  AND a.attname = 'foreign_patient'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY n.nspname;
