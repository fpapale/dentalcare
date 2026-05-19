-- =============================================================================
-- DentalCare Pro - Installazione Completa Sistema
-- File: 05_install_new_system.sql
-- Descrizione: Orchestratore per installazione fresh su un database vuoto.
--              Esegue in sequenza gli script base e configura Flyway.
--
-- Uso (dalla directory database/):
--   psql -U postgres -d dentalcarepro -f 05_install_new_system.sql
--
-- Oppure manualmente passo per passo:
--   psql -U postgres -d dentalcarepro -f 01_schema_applicative.sql
--   psql -U postgres -d dentalcarepro -f 03_seed_global.sql
--   psql -v tenant_schema=t_9d754153 -v tenant_tablespace=pg_default \
--        -U postgres -d dentalcarepro -f 02_schema_tenant.sql
--   psql -U postgres -d dentalcarepro -f 04_seed_demo_tenant.sql
--
-- Prerequisiti:
--   - Database dentalcarepro gia' creato:
--       createdb -U postgres dentalcarepro
--   - Utente postgres con ruolo superuser o owner del database
--   - File presenti nella stessa directory di questo script
--
-- ATTENZIONE: Questo script e' pensato per un'installazione fresh.
--   Su database esistente, ogni script e' idempotente ma potrebbe
--   sovrascrivere dati demo.
-- =============================================================================

\set ON_ERROR_STOP on

\echo ''
\echo '============================================================'
\echo '  DentalCare Pro - Installazione Sistema'
\echo '============================================================'
\echo ''

-- =============================================================================
-- Step 1: Schema applicativo globale (enum, funzioni, tabelle dentalcare)
-- =============================================================================

\echo '-- Step 1/5: Schema applicativo globale (01_schema_applicative.sql) --'
\i 01_schema_applicative.sql
\echo '-- Step 1/5: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 2: Dati di riferimento globali (stati, regioni, festivi, anamnesi)
-- =============================================================================

\echo '-- Step 2/5: Dati globali di riferimento (03_seed_global.sql) --'
\i 03_seed_global.sql
\echo '-- Step 2/5: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 3: Schema operativo tenant demo
-- Imposta la variabile tenant_schema prima di richiamare lo script.
-- =============================================================================

\echo '-- Step 3/5: Schema tenant demo t_9d754153 (02_schema_tenant.sql) --'
\set tenant_schema t_9d754153
\set tenant_tablespace pg_default
\i 02_schema_tenant.sql
\echo '-- Step 3/5: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 4: Dati demo del tenant (clinica, pazienti, appuntamenti, prodotti)
-- =============================================================================

\echo '-- Step 4/5: Seed dati demo (04_seed_demo_tenant.sql) --'
\i 04_seed_demo_tenant.sql
\echo '-- Step 4/5: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 5: Seed Flyway schema history (segna V1-V11 come gia' applicati)
-- =============================================================================

\echo '-- Step 5/5: Seed Flyway schema history --'

SET search_path TO dentalcare, public;

CREATE TABLE IF NOT EXISTS flyway_schema_history (
    installed_rank INTEGER       NOT NULL,
    version        VARCHAR(50),
    description    VARCHAR(200)  NOT NULL,
    type           VARCHAR(20)   NOT NULL,
    script         VARCHAR(1000) NOT NULL,
    checksum       INTEGER,
    installed_by   VARCHAR(100)  NOT NULL,
    installed_on   TIMESTAMP     NOT NULL DEFAULT now(),
    execution_time INTEGER       NOT NULL,
    success        BOOLEAN       NOT NULL,
    CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank)
);

CREATE INDEX IF NOT EXISTS flyway_schema_history_s_idx
    ON flyway_schema_history (success);

-- checksum=0: flyway.repair() ricalcola i checksum reali al primo avvio
INSERT INTO flyway_schema_history
    (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success)
VALUES
    (1,  '1',  'init schema',              'SQL', 'V1__init_schema.sql',                  0, 'postgres', 100, true),
    (2,  '2',  'tooth conditions',         'SQL', 'V2__tooth_conditions.sql',              0, 'postgres', 100, true),
    (3,  '3',  'geo holidays',             'SQL', 'V3__geo_holidays.sql',                  0, 'postgres', 100, true),
    (4,  '4',  'service duration',         'SQL', 'V4__service_duration.sql',              0, 'postgres', 100, true),
    (5,  '5',  'estimates views and patch','SQL', 'V5__estimates_views_and_patch.sql',     0, 'postgres', 100, true),
    (6,  '6',  'estimates provider column','SQL', 'V6__estimates_provider_column.sql',     0, 'postgres', 100, true),
    (7,  '7',  'invoices',                 'SQL', 'V7__invoices.sql',                      0, 'postgres', 100, true),
    (8,  '8',  'inventory',               'SQL', 'V8__inventory.sql',                     0, 'postgres', 100, true),
    (9,  '9',  'recalls',                 'SQL', 'V9__recalls.sql',                       0, 'postgres', 100, true),
    (10, '10', 'inventory seed',           'SQL', 'V10__inventory_seed.sql',               0, 'postgres', 100, true),
    (11, '11', 'schema updates',           'SQL', 'V11__schema_updates.sql',               0, 'postgres', 100, true)
ON CONFLICT (installed_rank) DO NOTHING;

\echo '-- Step 5/5: COMPLETATO --'
\echo ''

-- =============================================================================
-- RIEPILOGO INSTALLAZIONE
-- =============================================================================

\echo '============================================================'
\echo '  Installazione completata con successo.'
\echo '============================================================'
\echo ''
\echo '  Tenant demo creato:'
\echo '    Nome:        Studio Demo DentalCare Roma'
\echo '    Schema:      t_9d754153'
\echo '    Clinic UUID: 9d754153-6579-4b7e-a56b-025f00299cd9'
\echo '    Email:       roma@dentalcare.demo'
\echo ''
\echo '  Passi successivi:'
\echo '    1. Configurare backend application.yml con credenziali DB'
\echo '    2. Impostare spring.datasource.url con dentalcarepro'
\echo '    3. Verificare search_path: dentalcare, public'
\echo '    4. Avviare il backend: docker compose up -d'
\echo '    5. Per aggiungere un nuovo tenant: psql -f 06_install_new_tenant.sql'
\echo ''
\echo '  Struttura schema:'
\echo '    dentalcare   -> tabelle globali (tenants, geo, anamnesis catalog)'
\echo '    t_9d754153   -> dati operativi tenant demo'
\echo ''

-- Riepilogo conteggio oggetti creati
SELECT
    schemaname   AS schema,
    COUNT(*)     AS numero_tabelle
FROM pg_tables
WHERE schemaname IN ('dentalcare', 't_9d754153')
GROUP BY schemaname
ORDER BY schemaname;
