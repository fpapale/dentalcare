-- =============================================================================
-- DentalCare Pro - Provisioning Nuovo Tenant
-- File: 06_install_new_tenant.sql
-- Descrizione: Crea un nuovo tenant con schema operativo e clinica iniziale.
--
-- Uso:
--   1. Modifica le variabili nella sezione CONFIGURAZIONE qui sotto
--   2. Esegui:
--        psql -U postgres -d dentalcarepro -f 06_install_new_tenant.sql
--
-- Prerequisiti:
--   - 01_schema_applicative.sql applicato (schema dentalcare esistente)
--   - 02_schema_tenant.sql disponibile nella stessa directory
--   - 03_seed_global.sql applicato (dati di riferimento globali presenti)
-- =============================================================================

\set ON_ERROR_STOP on

-- =============================================================================
-- CONFIGURAZIONE NUOVO TENANT - MODIFICA QUESTI VALORI
-- =============================================================================

\set new_tenant_name       'Nome Studio Dentistico'
\set new_tenant_email      'info@studio.it'
\set new_tenant_phone      '+39 0XX XXXXXXX'
\set new_tenant_plan       'professional'

\set new_clinic_name       'Studio Dentistico Nome'
\set new_clinic_legal_name 'Studio Dentistico Nome S.r.l.'
\set new_clinic_vat        'IT01234567890'
\set new_clinic_fiscal     'IT01234567890'
\set new_clinic_phone      '+39 0XX XXXXXXX'
\set new_clinic_email      'info@studio.it'
\set new_clinic_address    'Via Roma 1'
\set new_clinic_city       'Roma'
\set new_clinic_province   'RM'
\set new_clinic_postal     '00100'
\set new_clinic_country    'IT'
\set new_clinic_timezone   'Europe/Rome'

-- Tablespace dedicato (opzionale).
-- Lascia vuoto ('') per usare pg_default (stesso disco del DB principale).
-- Se valorizzato, il path deve esistere sul filesystem del server PostgreSQL
-- ed essere di proprieta' dell'utente postgres:
--   mkdir -p /mnt/tenants/t_XXXXXXXX && chown postgres:postgres /mnt/tenants/t_XXXXXXXX
-- Esempio:
--   \set new_tenant_tablespace_path '/mnt/tenants'
\set new_tenant_tablespace_path ''

-- =============================================================================
-- FINE CONFIGURAZIONE - NON MODIFICARE SOTTO QUESTA RIGA
-- =============================================================================

BEGIN;

SET search_path TO dentalcare, public;

-- Genera UUID tenant e clinica, crea schema, registra in dentalcare.tenants
DO $$
DECLARE
    v_tenant_id        uuid := gen_random_uuid();
    v_clinic_id        uuid := gen_random_uuid();
    v_schema_name      text;
    v_tablespace_name  text;
    v_tablespace_path  text;
    v_hex              text;
BEGIN
    -- Deriva nome schema dai primi 8 caratteri esadecimali del clinic UUID
    v_hex         := replace(v_clinic_id::text, '-', '');
    v_schema_name := 't_' || substring(v_hex, 1, 8);

    -- Validazione formato schema
    IF v_schema_name !~ '^t_[0-9a-f]{8}$' THEN
        RAISE EXCEPTION 'Schema name % non rispetta il formato t_XXXXXXXX', v_schema_name;
    END IF;

    -- Controlla collisione di nome schema
    IF EXISTS (SELECT 1 FROM dentalcare.tenants WHERE schema_name = v_schema_name) THEN
        RAISE EXCEPTION
            'Schema name % gia'' in uso. Riesegui lo script (verra'' generato un nuovo UUID).',
            v_schema_name;
    END IF;

    RAISE NOTICE '=== Provisioning nuovo tenant ===';
    RAISE NOTICE '  Tenant ID  : %', v_tenant_id;
    RAISE NOTICE '  Clinic ID  : %', v_clinic_id;
    RAISE NOTICE '  Schema     : %', v_schema_name;

    -- Registra tenant
    INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active)
    VALUES (
        v_tenant_id,
        :'new_tenant_name',
        v_schema_name,
        :'new_tenant_email',
        :'new_tenant_phone',
        :'new_tenant_plan',
        true
    );

    -- Crea tablespace dedicato se il path e' stato configurato
    IF length(trim(:'new_tenant_tablespace_path')) > 0 THEN
        v_tablespace_name := 'ts_' || v_schema_name;
        v_tablespace_path := rtrim(:'new_tenant_tablespace_path', '/') || '/' || v_schema_name;
        EXECUTE format(
            'CREATE TABLESPACE %I OWNER CURRENT_USER LOCATION %L',
            v_tablespace_name, v_tablespace_path
        );
        RAISE NOTICE '  Tablespace     : % -> %', v_tablespace_name, v_tablespace_path;
    ELSE
        v_tablespace_name := 'pg_default';
        RAISE NOTICE '  Tablespace     : pg_default (nessun path configurato)';
    END IF;

    -- Crea schema
    EXECUTE format('CREATE SCHEMA %I', v_schema_name);

    RAISE NOTICE '  Tenant registrato. Schema e tablespace creati.';

    -- Salva valori in config sessione per uso nei blocchi successivi
    PERFORM set_config('app.new_tenant_id',        v_tenant_id::text,    true);
    PERFORM set_config('app.new_clinic_id',         v_clinic_id::text,    true);
    PERFORM set_config('app.new_schema_name',       v_schema_name,        true);
    PERFORM set_config('app.new_tablespace_name',   v_tablespace_name,    true);
END;
$$;

-- Esporta schema name e tablespace name come variabili psql tramite \gset
SELECT
    current_setting('app.new_schema_name')     AS tenant_schema,
    current_setting('app.new_tablespace_name') AS tenant_tablespace
\gset

-- Crea le tabelle nel tenant schema usando 02_schema_tenant.sql
-- (usa sia :tenant_schema sia :tenant_tablespace, entrambi settati da \gset)
\echo ''
\echo '-- Creazione struttura tabelle tenant schema --'
\i 02_schema_tenant.sql
\echo '-- Struttura tabelle creata --'
\echo ''

-- Ripristina search_path al context globale per le operazioni successive
SET search_path TO dentalcare, public;

-- Inserisce i dati iniziali della clinica nel tenant schema appena creato
DO $$
DECLARE
    v_tenant_id   uuid := current_setting('app.new_tenant_id')::uuid;
    v_clinic_id   uuid := current_setting('app.new_clinic_id')::uuid;
    v_schema_name text := current_setting('app.new_schema_name');
BEGIN
    -- Inserisce clinica nel tenant schema (search_path = tenant schema)
    EXECUTE format(
        $SQL$
        INSERT INTO %I.clinics (id, name, legal_name, vat_number, fiscal_code,
            phone, email, address_line1, city, province, postal_code, country, timezone)
        VALUES (
            %L, %L, %L, %L, %L,
            %L, %L, %L, %L, %L, %L, %L, %L
        )
        $SQL$,
        v_schema_name,
        v_clinic_id,
        :'new_clinic_name',
        :'new_clinic_legal_name',
        :'new_clinic_vat',
        :'new_clinic_fiscal',
        :'new_clinic_phone',
        :'new_clinic_email',
        :'new_clinic_address',
        :'new_clinic_city',
        :'new_clinic_province',
        :'new_clinic_postal',
        :'new_clinic_country',
        :'new_clinic_timezone'
    );

    -- Registra la clinica in tenant_clinics
    INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id)
    VALUES (v_clinic_id, v_tenant_id);

    RAISE NOTICE '  Clinica creata: % (ID: %)', :'new_clinic_name', v_clinic_id;
    RAISE NOTICE '  Registrata in tenant_clinics.';
END;
$$;

-- =============================================================================
-- RIEPILOGO
-- =============================================================================

\echo ''
\echo '============================================================'
\echo '  Provisioning completato.'
\echo '============================================================'

-- Mostra i dettagli del tenant appena creato
SELECT
    t.id            AS tenant_id,
    t.name          AS tenant_name,
    t.schema_name,
    t.plan,
    t.active,
    tc.clinic_id
FROM dentalcare.tenants t
JOIN dentalcare.tenant_clinics tc ON tc.tenant_id = t.id
WHERE t.id = current_setting('app.new_tenant_id')::uuid;

\echo ''
\echo '  Passi successivi:'
\echo '    1. Aggiungere provider (operatori) al tenant via applicazione'
\echo '    2. Configurare il catalogo prestazioni'
\echo '    3. Importare pazienti se necessario'
\echo '    4. Configurare orari apertura clinica'
\echo ''
\echo '  Per verificare lo schema creato:'
\echo '    SELECT tablename FROM pg_tables WHERE schemaname = current_setting(''app.new_schema_name'');'
\echo ''

-- Verifica numero tabelle create
SELECT
    schemaname  AS schema,
    COUNT(*)    AS tabelle_create
FROM pg_tables
WHERE schemaname = current_setting('app.new_schema_name')
GROUP BY schemaname;

COMMIT;
