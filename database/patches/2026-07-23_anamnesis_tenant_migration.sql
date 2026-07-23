-- Migrazione one-shot: sposta il catalogo anamnesi da dentalcare (globale) a ogni schema tenant.
-- Esecuzione: una volta per DB (dev o prod), NON per singolo tenant — itera su tutti gli schema t_XXXX esistenti.
-- Prerequisito: Task 1 (CREATE TABLE) già applicato via patchSchema o manualmente su ogni schema tenant.
-- Riguarda i tenant reali diversi dal demo t_9d754153 (che e' gia' seedato direttamente in install.sql).
--
-- Nota: questo script copia il catalogo globale COSI' COM'E' (non deduplicato), per non
-- rompere le selezioni pazienti esistenti che referenziano id di dentalcare.anamnesis_items.
-- La ricostruzione/deduplicazione (seed Task 2 Step 1-2, catalogo 15 categorie / 87 voci) va
-- applicata DOPO, tenant per tenant, con UPDATE/INSERT ... ON CONFLICT mirati che disabilitano
-- (enabled=false, mai DELETE) i duplicati solo dopo aver verificato via SELECT count(*) che non
-- siano in uso. Operazione supervisionata dal committente, non automatica: non inclusa in questo script.

DO $$
DECLARE
    tenant_schema text;
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM dentalcare.tenants
    LOOP
        -- Crea le tabelle nello schema tenant se non esistono già (idempotente).
        -- NOTA (fix rispetto alla bozza originale): id con PRIMARY KEY inline, altrimenti la
        -- ADD CONSTRAINT ... FOREIGN KEY su patient_anamnesis_item_selections piu' sotto fallisce
        -- con "there is no unique constraint matching given keys for referenced table" ogni volta
        -- che questo CREATE TABLE crea davvero la tabella (cioe' il caso reale che questo script
        -- gestisce: tenant senza Task 1 gia' applicato). Verificato riproducendo l'errore su un
        -- tenant di test privo delle tabelle. Innocuo quando la tabella esiste gia' (Task 1 gia'
        -- applicato): in quel caso CREATE TABLE IF NOT EXISTS non fa nulla e il PK e' quello
        -- creato da Task 1.
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.anamnesis_categories (
                id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
                code text,
                name text NOT NULL,
                description text,
                icon text DEFAULT ''medical_information''::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                CONSTRAINT %I CHECK ((length(TRIM(BOTH FROM name)) > 0))
            )', tenant_schema, tenant_schema || '_anamnesis_categories_name_not_empty');

        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.anamnesis_items (
                id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
                category_id uuid NOT NULL,
                code text NOT NULL,
                label text NOT NULL,
                description text,
                severity text DEFAULT ''normale''::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                has_detail boolean DEFAULT false NOT NULL,
                CONSTRAINT %I CHECK ((length(TRIM(BOTH FROM label)) > 0)),
                CONSTRAINT %I CHECK ((severity = ANY (ARRAY[''normale''::text, ''grave''::text, ''severa''::text])))
            )', tenant_schema, tenant_schema || '_anamnesis_items_label_not_empty', tenant_schema || '_anamnesis_items_severity_check');

        -- Copia il catalogo globale esistente COSÌ COM'È (non ancora deduplicato) — la
        -- ricostruzione avviene via applicazione dello stesso seed statico di Task 2 Step 1,
        -- eseguito a parte dal committente dopo verifica manuale dei dati già presenti nel tenant
        -- (ogni tenant reale ha selezioni pazienti che referenziano id oggi in dentalcare.anamnesis_items:
        -- questa copia preserva quegli id, la deduplicazione va fatta con un passaggio successivo
        -- di UPDATE + soft-disable, non con un DELETE, per non rompere le selezioni esistenti).
        EXECUTE format('
            INSERT INTO %I.anamnesis_categories (id, code, name, description, icon, sort_order, enabled, created_at)
            SELECT id, code, name, description, icon, sort_order, enabled, created_at
            FROM dentalcare.anamnesis_categories
            ON CONFLICT DO NOTHING', tenant_schema);

        EXECUTE format('
            INSERT INTO %I.anamnesis_items (id, category_id, code, label, description, severity, sort_order, enabled, created_at, has_detail)
            SELECT id, category_id, code, label, description,
                   CASE WHEN is_alert THEN ''grave'' ELSE ''normale'' END,
                   sort_order, enabled, created_at, has_detail
            FROM dentalcare.anamnesis_items
            ON CONFLICT DO NOTHING', tenant_schema);

        -- Ripunta la FK di patient_anamnesis_item_selections allo schema tenant
        EXECUTE format('
            ALTER TABLE %I.patient_anamnesis_item_selections
            DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_item_id_fkey', tenant_schema);
        EXECUTE format('
            ALTER TABLE %I.patient_anamnesis_item_selections
            ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey
                FOREIGN KEY (item_id) REFERENCES %I.anamnesis_items(id) ON DELETE CASCADE', tenant_schema, tenant_schema);

        RAISE NOTICE 'Migrato catalogo anamnesi per schema %', tenant_schema;
    END LOOP;
END $$;

-- Verifica: tabelle per-tenant create e FK di patient_anamnesis_item_selections
-- ripuntata correttamente allo schema tenant (non piu' a dentalcare.anamnesis_items)
SELECT t.schema_name AS tenant_schema,
       EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = t.schema_name AND c.relname = 'anamnesis_categories'
       ) AS has_anamnesis_categories,
       EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = t.schema_name AND c.relname = 'anamnesis_items'
       ) AS has_anamnesis_items,
       EXISTS (
           SELECT 1
           FROM pg_constraint con
           JOIN pg_class rel ON rel.oid = con.conrelid
           JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
           JOIN pg_class frel ON frel.oid = con.confrelid
           JOIN pg_namespace fnsp ON fnsp.oid = frel.relnamespace
           WHERE nsp.nspname = t.schema_name
             AND rel.relname = 'patient_anamnesis_item_selections'
             AND con.conname = 'patient_anamnesis_item_selections_item_id_fkey'
             AND frel.relname = 'anamnesis_items'
             AND fnsp.nspname = t.schema_name
       ) AS fk_repointed_to_tenant
FROM dentalcare.tenants t
ORDER BY t.schema_name;
