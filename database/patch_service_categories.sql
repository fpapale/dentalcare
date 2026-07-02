-- Patch: tabella per-tenant service_categories (catalogo categorie prestazioni) + seed
-- dalle categorie distinte già presenti in service_catalog. Idempotente.
-- Applicare a dev e prod.

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT nspname FROM pg_namespace WHERE nspname ~ '^t_[0-9a-f]{8}$' ORDER BY nspname LOOP
    EXECUTE format($ddl$
      CREATE TABLE IF NOT EXISTS %1$I.service_categories (
        id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        clinic_id  uuid NOT NULL,
        name       text NOT NULL,
        sort_order integer NOT NULL DEFAULT 10,
        active     boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE UNIQUE INDEX IF NOT EXISTS ux_service_categories_clinic_name
        ON %1$I.service_categories (clinic_id, lower(name));
      INSERT INTO %1$I.service_categories (clinic_id, name)
        SELECT DISTINCT clinic_id, category
        FROM %1$I.service_catalog
        WHERE category IS NOT NULL AND btrim(category) <> ''
        ON CONFLICT (clinic_id, lower(name)) DO NOTHING;
    $ddl$, r.nspname);
  END LOOP;
END$$;

-- Verifica
SELECT n.nspname AS tenant_schema, count(*) AS categorie
FROM pg_namespace n
JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = 'service_categories'
WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
GROUP BY n.nspname ORDER BY n.nspname;
