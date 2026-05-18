-- =============================================================================
-- DentalCare Pro - Installazione Completa Sistema
-- File: 05_install_new_system.sql
-- Descrizione: Orchestratore per installazione fresh su un database vuoto.
--              Esegue in sequenza i 4 script base.
--
-- Uso (dalla directory database/):
--   psql -U postgres -d dentalcarepro -f 05_install_new_system.sql
--
-- Oppure manualmente passo per passo:
--   psql -U postgres -d dentalcarepro -f 01_schema_applicative.sql
--   psql -U postgres -d dentalcarepro -f 03_seed_global.sql
--   psql -v tenant_schema=t_9d754153 -U postgres -d dentalcarepro -f 02_schema_tenant.sql
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

\echo '-- Step 1/4: Schema applicativo globale (01_schema_applicative.sql) --'
\i 01_schema_applicative.sql
\echo '-- Step 1/4: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 2: Dati di riferimento globali (stati, regioni, festivi, anamnesi)
-- =============================================================================

\echo '-- Step 2/4: Dati globali di riferimento (03_seed_global.sql) --'
\i 03_seed_global.sql
\echo '-- Step 2/4: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 3: Schema operativo tenant demo
-- Imposta la variabile tenant_schema prima di richiamare lo script.
-- =============================================================================

\echo '-- Step 3/4: Schema tenant demo t_9d754153 (02_schema_tenant.sql) --'
\set tenant_schema t_9d754153
\set tenant_tablespace pg_default
\i 02_schema_tenant.sql
\echo '-- Step 3/4: COMPLETATO --'
\echo ''

-- =============================================================================
-- Step 4: Dati demo del tenant (clinica, pazienti, appuntamenti, prodotti)
-- =============================================================================

\echo '-- Step 4/4: Seed dati demo (04_seed_demo_tenant.sql) --'
\i 04_seed_demo_tenant.sql
\echo '-- Step 4/4: COMPLETATO --'
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
