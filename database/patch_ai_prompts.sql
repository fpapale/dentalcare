-- Patch: gestione prompt AI multilingua e manutenibili.
--   - dentalcare.ai_prompts        : default globali (chiave, lingua) -> valore
--   - <schema>.ai_prompt_overrides : override per-studio (clinic, chiave, lingua) -> valore
-- Il seed dei default globali è eseguito dall'app (PromptService) dalle risorse bundle,
-- così le patch non devono trasportare il testo dei prompt. Idempotente. Applicare a dev e prod.

CREATE TABLE IF NOT EXISTS dentalcare.ai_prompts (
    prompt_key  text NOT NULL,
    locale      text NOT NULL,
    value       text NOT NULL,
    description text,
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (prompt_key, locale)
);

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT nspname FROM pg_namespace WHERE nspname ~ '^t_[0-9a-f]{8}$' ORDER BY nspname LOOP
    EXECUTE format($ddl$
      CREATE TABLE IF NOT EXISTS %1$I.ai_prompt_overrides (
        clinic_id  uuid NOT NULL,
        prompt_key text NOT NULL,
        locale     text NOT NULL,
        value      text NOT NULL,
        updated_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (clinic_id, prompt_key, locale)
      );
    $ddl$, r.nspname);
  END LOOP;
END$$;

-- Verifica
SELECT count(*) AS tenant_override_tables
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'ai_prompt_overrides' AND n.nspname ~ '^t_[0-9a-f]{8}$';
