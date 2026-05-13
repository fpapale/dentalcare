-- Rimuove i duplicati di Papale Fabrizio senza anamnesi.
-- Mantiene il paziente con id fisso 'f4b21000-0000-0000-0000-000000000001'.
-- Rieseguibile senza effetti collaterali.

BEGIN;

SET search_path TO dentalcare, public;

DO $$
DECLARE
    v_clinic_id uuid;
    v_deleted   integer;
BEGIN
    SELECT id INTO v_clinic_id
    FROM clinics
    WHERE vat_number = 'DEMO-ROMA-001'
    LIMIT 1;

    IF v_clinic_id IS NULL THEN
        RAISE NOTICE 'Clinic DEMO-ROMA-001 non trovata. Nulla da fare.';
        RETURN;
    END IF;

    -- Cancella ogni Papale nella clinic che:
    --   1. NON è il paziente con UUID fisso (quello con anamnesi)
    --   2. NON ha alcun record in patient_anamnesis
    DELETE FROM patients p
    WHERE p.clinic_id = v_clinic_id
      AND p.id <> 'f4b21000-0000-0000-0000-000000000001'
      AND lower(p.last_name) = 'papale'
      AND NOT EXISTS (
          SELECT 1
          FROM patient_anamnesis pa
          WHERE pa.patient_id = p.id
            AND pa.clinic_id  = p.clinic_id
      );

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RAISE NOTICE 'Papale duplicati cancellati: %', v_deleted;
END $$;

COMMIT;
