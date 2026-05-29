-- =============================================================================
-- Patch: trigger function search_path
-- Le funzioni trigger (recalc totali preventivo/fattura, update richiamo)
-- usavano nomi di tabella NON qualificati. La connessione applicativa non imposta
-- search_path sullo schema tenant => "relation does not exist" a runtime.
-- Fix: ogni funzione imposta search_path = <schema tabella>, dentalcare, public
-- tramite TG_TABLE_SCHEMA all'inizio del corpo.
-- Idempotente (CREATE OR REPLACE). Applica a tutti gli schemi tenant t_%.
-- Eseguire in pgAdmin sul database dentalcarepro.
-- =============================================================================

DO $patch$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name LIKE 't\_%'
    LOOP
        EXECUTE format('SET search_path TO %I, dentalcare, public', r.schema_name);

        EXECUTE $body$
            CREATE OR REPLACE FUNCTION recalc_estimate_totals()
            RETURNS trigger AS $$
            DECLARE
                v_estimate_id uuid;
            BEGIN
                PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
                v_estimate_id := COALESCE(NEW.estimate_id, OLD.estimate_id);
                UPDATE estimates
                SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)   FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    discount_amount = COALESCE((SELECT SUM(discount_amount) FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    taxable_amount  = COALESCE((SELECT SUM(line_taxable)    FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    vat_amount      = COALESCE((SELECT SUM(line_vat_amount) FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    total_amount    = COALESCE((SELECT SUM(line_total)      FROM estimate_lines WHERE estimate_id = v_estimate_id), 0),
                    updated_at      = now()
                WHERE id = v_estimate_id;
                RETURN NULL;
            END;
            $$ LANGUAGE plpgsql;
        $body$;

        EXECUTE $body$
            CREATE OR REPLACE FUNCTION trg_update_invoice_totals_from_lines()
            RETURNS trigger AS $$
            DECLARE
                v_invoice_id uuid;
            BEGIN
                PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
                v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
                UPDATE invoices
                SET subtotal_amount = COALESCE((SELECT SUM(line_subtotal)   FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    discount_amount = COALESCE((SELECT SUM(discount_amount) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    taxable_amount  = COALESCE((SELECT SUM(line_taxable)    FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    vat_amount      = COALESCE((SELECT SUM(line_vat_amount) FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    total_amount    = COALESCE((SELECT SUM(line_total)      FROM invoice_lines WHERE invoice_id = v_invoice_id), 0),
                    updated_at      = now()
                WHERE id = v_invoice_id;
                RETURN NULL;
            END;
            $$ LANGUAGE plpgsql;
        $body$;

        EXECUTE $body$
            CREATE OR REPLACE FUNCTION update_recall_on_contact()
            RETURNS trigger AS $$
            BEGIN
                PERFORM set_config('search_path', TG_TABLE_SCHEMA || ', dentalcare, public', true);
                IF NEW.outcome = 'booked' THEN
                    UPDATE patient_recalls
                    SET status     = 'booked'::dentalcare.recall_status,
                        updated_at = now()
                    WHERE id = NEW.recall_id;
                ELSIF NEW.outcome IN ('refused', 'already_booked', 'scheduled_later') THEN
                    UPDATE patient_recalls
                    SET status       = 'completed'::dentalcare.recall_status,
                        completed_at = now(),
                        updated_at   = now()
                    WHERE id = NEW.recall_id;
                END IF;
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        $body$;

        RAISE NOTICE 'patched trigger functions in schema %', r.schema_name;
    END LOOP;

    RESET search_path;
END $patch$;
