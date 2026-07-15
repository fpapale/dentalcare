-- =============================================================================
-- purge_patients_before.sql
-- Elimina pazienti registrati PRIMA di una data + tutti i dati correlati.
-- Parametrico: DB (connessione), schema tenant, data cutoff, opzioni.
--
-- DISTRUTTIVO. Default SICURO: dry-run (nessuna cancellazione) e skip fatture.
--
-- Parametri (psql -v):
--   schema          schema tenant, es. t_9d754153            [OBBLIGATORIO]
--   cutoff          data ISO: elimina created_at < cutoff    [OBBLIGATORIO]
--   dry_run         true|false  (default true  = simula + rollback)
--   purge_invoices  true|false  (default false = NON cancella fatture:
--                                i pazienti con fatture vengono SALTATI)
--
-- Il DB si sceglie con -d (dev vs prod) → parametrico via connessione.
--
-- USO:
--   -- DEV, simulazione (nessuna modifica):
--   psql -h 192.168.0.173 -U postgres -d dentalcarepro \
--        -v schema=t_9d754153 -v cutoff=2024-01-01 \
--        -f database/purge_patients_before.sql
--
--   -- PROD, esecuzione reale (salta pazienti con fatture):
--   psql -h 192.168.0.173 -U postgres -d dentalcare_prod \
--        -v schema=t_9d754153 -v cutoff=2024-01-01 -v dry_run=false \
--        -f database/purge_patients_before.sql
--
--   -- Forzare anche la cancellazione delle fatture (SCONSIGLIATO, valuta obblighi fiscali):
--        ... -v dry_run=false -v purge_invoices=true
--
-- NOTA: fare SEMPRE un backup prima dell'esecuzione reale:
--   pg_dump -h <host> -U postgres -d <db> -Fc -f backup_pre_purge.dump
-- =============================================================================

\set ON_ERROR_STOP on

-- Default sicuri se i flag non sono passati -----------------------------------
\if :{?dry_run}
\else
  \set dry_run true
\endif
\if :{?purge_invoices}
\else
  \set purge_invoices false
\endif

-- Verifica parametri obbligatori ----------------------------------------------
\if :{?schema}
\else
  \echo 'ERRORE: parametro -v schema=<tenant> mancante.'
  \quit
\endif
\if :{?cutoff}
\else
  \echo 'ERRORE: parametro -v cutoff=<YYYY-MM-DD> mancante.'
  \quit
\endif

BEGIN;

-- Passa i parametri al blocco PL/pgSQL via GUC di sessione (transazione locale)
SELECT set_config('purge.schema',   :'schema',         true);
SELECT set_config('purge.cutoff',   :'cutoff',         true);
SELECT set_config('purge.dry_run',  :'dry_run',        true);
SELECT set_config('purge.purge_inv',:'purge_invoices', true);

DO $$
DECLARE
  v_schema    text := current_setting('purge.schema');
  v_cutoff    date := current_setting('purge.cutoff')::date;
  v_dry       bool := current_setting('purge.dry_run')::bool;
  v_purge_inv bool := current_setting('purge.purge_inv')::bool;
  v_total     int;
  v_with_inv  int;
  v_deletable int;
  v_inv_del   int := 0;
  v_pat_del   int;
BEGIN
  -- Candidati: pazienti registrati prima del cutoff (tabella di lavoro con dettagli)
  EXECUTE format($q$
    CREATE TEMP TABLE _purge_ids ON COMMIT DROP AS
    SELECT p.id, p.clinic_id, p.last_name, p.first_name, p.created_at,
           EXISTS (SELECT 1 FROM %1$I.invoices i
                   WHERE i.patient_id = p.id AND i.clinic_id = p.clinic_id) AS has_invoice
    FROM %1$I.patients p
    WHERE p.created_at < %2$L
  $q$, v_schema, v_cutoff);

  SELECT count(*), count(*) FILTER (WHERE has_invoice)
    INTO v_total, v_with_inv
    FROM _purge_ids;

  RAISE NOTICE '--------------------------------------------------------------';
  RAISE NOTICE 'Schema=%  cutoff=<%  candidati=%  con_fatture=%',
               v_schema, v_cutoff, v_total, v_with_inv;
  RAISE NOTICE 'Opzioni: dry_run=%  purge_invoices=%', v_dry, v_purge_inv;

  -- Se non si forzano le fatture, escludi i pazienti che ne hanno (RESTRICT/fiscale)
  IF v_with_inv > 0 AND NOT v_purge_inv THEN
    DELETE FROM _purge_ids WHERE has_invoice;
    RAISE NOTICE 'SALTATI % pazienti con fatture (obbligo conservazione fiscale).', v_with_inv;
    RAISE NOTICE 'Per forzarne la rimozione: -v purge_invoices=true';
  END IF;

  SELECT count(*) INTO v_deletable FROM _purge_ids;
  RAISE NOTICE 'Pazienti da eliminare (con dati correlati in CASCADE): %', v_deletable;
  RAISE NOTICE '--------------------------------------------------------------';

  -- Se forziamo le fatture: eliminarle prima (invoice_lines CASCADE dietro invoices)
  IF v_purge_inv THEN
    EXECUTE format($q$
      DELETE FROM %1$I.invoices i USING _purge_ids p
      WHERE i.patient_id = p.id AND i.clinic_id = p.clinic_id
    $q$, v_schema);
    GET DIAGNOSTICS v_inv_del = ROW_COUNT;
    RAISE NOTICE 'Fatture eliminate: %', v_inv_del;
  END IF;

  -- Cancellazione pazienti. In CASCADE spariscono: appointments, clinical_history_entries,
  -- estimates(->estimate_lines), treatment_plans(->items), odontogram_teeth,
  -- patient_anamnesis, patient_diagnoses, patient_documents, patient_prescriptions,
  -- recalls, pais. ai_conversations.patient_id -> NULL (chat conservata, deidentificata).
  EXECUTE format($q$
    DELETE FROM %1$I.patients pt USING _purge_ids p
    WHERE pt.id = p.id AND pt.clinic_id = p.clinic_id
  $q$, v_schema);
  GET DIAGNOSTICS v_pat_del = ROW_COUNT;
  RAISE NOTICE 'Pazienti eliminati: %  (fatture: %)', v_pat_del, v_inv_del;
END $$;

-- Anteprima dei pazienti coinvolti (la temp table vive fino a fine transazione)
\echo ''
\echo 'Elenco pazienti interessati (max 200):'
SELECT id, last_name, first_name, created_at, has_invoice
FROM _purge_ids
ORDER BY created_at
LIMIT 200;

-- Commit solo se NON dry-run ---------------------------------------------------
\if :dry_run
  ROLLBACK;
  \echo ''
  \echo '### DRY RUN: transazione annullata (ROLLBACK). Nessuna modifica al DB.'
  \echo '### Per eseguire davvero: aggiungi -v dry_run=false'
\else
  COMMIT;
  \echo ''
  \echo '### ESEGUITO: modifiche committate.'
\endif
