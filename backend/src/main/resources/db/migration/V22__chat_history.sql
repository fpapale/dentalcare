DO $$
DECLARE
    r RECORD;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'dentalcare' AND table_name = 'tenants'
    ) THEN RETURN; END IF;

    FOR r IN SELECT t.schema_name FROM dentalcare.tenants t WHERE t.active = true
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = r.schema_name)
        THEN CONTINUE; END IF;

        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.chat_sessions (
            id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            provider_id  UUID        NOT NULL,
            title        TEXT        NOT NULL,
            message_count INT        NOT NULL DEFAULT 0,
            created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
        )', r.schema_name);

        EXECUTE format('CREATE TABLE IF NOT EXISTS %I.chat_messages (
            id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
            session_id UUID        NOT NULL REFERENCES %I.chat_sessions(id) ON DELETE CASCADE,
            role       TEXT        NOT NULL CHECK (role IN (''user'', ''assistant'')),
            content    TEXT        NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )', r.schema_name, r.schema_name);

        EXECUTE format('CREATE INDEX IF NOT EXISTS chat_messages_session_idx ON %I.chat_messages(session_id)', r.schema_name);
        EXECUTE format('CREATE INDEX IF NOT EXISTS chat_sessions_provider_idx ON %I.chat_sessions(provider_id, created_at DESC)', r.schema_name);

    END LOOP;
END $$;
