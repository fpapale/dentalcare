-- Patch: crea la tabella per-tenant ai_audit_log (audit azioni del Copilot AI) in ogni schema tenant esistente.
-- Tabella per-tenant (dentro ogni schema t_xxxxxxxx), non nello schema condiviso dentalcare.
-- Idempotente: usa IF NOT EXISTS su tabella e indice, sicura da rieseguire.
-- Applicare sia in dev che in prod.

SET search_path TO dentalcare, public;

DO $$
DECLARE
    v_schema text;
BEGIN
    FOR v_schema IN
        SELECT nspname
        FROM pg_namespace
        WHERE nspname ~ '^t_[0-9a-f]{8}$'
    LOOP
        EXECUTE format($ddl$
            CREATE TABLE IF NOT EXISTS %I.ai_audit_log (
                id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id    uuid NOT NULL,
                provider_id  uuid,
                action_type  text NOT NULL,
                tool_name    text,
                args_summary text,
                result       text,
                created_at   timestamptz NOT NULL DEFAULT now()
            )
        $ddl$, v_schema);

        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS ix_ai_audit_log_clinic_created ON %I.ai_audit_log (clinic_id, created_at DESC)',
            v_schema
        );
    END LOOP;
END;
$$;

-- Verifica: elenca la tabella ai_audit_log e il relativo indice creati in ogni schema tenant.
SELECT n.nspname AS tenant_schema,
       c.relname AS object_name,
       c.relkind AS kind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname ~ '^t_[0-9a-f]{8}$'
  AND c.relname IN ('ai_audit_log', 'ix_ai_audit_log_clinic_created')
ORDER BY n.nspname, c.relname;
