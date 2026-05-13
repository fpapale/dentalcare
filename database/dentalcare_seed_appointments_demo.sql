-- Seed appuntamenti demo: oggi, domani, dopodomani
-- Eseguire con:
--   psql -h 192.168.0.173 -U postgres -d dentalcarepro -f dentalcare_seed_appointments_demo.sql

BEGIN;

SET search_path TO dentalcare, public;

DO $$
DECLARE
    v_clinic_id  uuid;
    v_patients   uuid[];
    v_providers  uuid[];
    v_services   record;

    v_days       integer[] := ARRAY[0, 1, 2];
    v_day        integer;
    v_chairs     text[] := ARRAY['Poltrona 1', 'Poltrona 2', 'Poltrona 3'];

    -- Slot orari per ogni poltrona
    type_slot record;

    v_appt_data record;

BEGIN
    -- Usa la clinica configurata nel backend (environment.clinicId del frontend)
    v_clinic_id := '9d754153-6579-4b7e-a56b-025f00299cd9';

    -- Verifica che la clinica esista
    IF NOT EXISTS (SELECT 1 FROM clinics WHERE id = v_clinic_id) THEN
        -- Fallback: prende DEMO-ROMA-001
        SELECT id INTO v_clinic_id FROM clinics WHERE vat_number = 'DEMO-ROMA-001' LIMIT 1;
        IF v_clinic_id IS NULL THEN
            RAISE EXCEPTION 'Nessuna clinica trovata. Verificare i dati nel database.';
        END IF;
    END IF;

    RAISE NOTICE 'Clinic ID: %', v_clinic_id;

    -- Raccoglie i primi 12 pazienti della clinica
    SELECT ARRAY(
        SELECT id FROM patients
        WHERE clinic_id = v_clinic_id
        ORDER BY last_name, first_name
        LIMIT 12
    ) INTO v_patients;

    IF array_length(v_patients, 1) IS NULL THEN
        RAISE EXCEPTION 'Nessun paziente trovato per la clinica %', v_clinic_id;
    END IF;

    -- Raccoglie i provider attivi
    SELECT ARRAY(
        SELECT id FROM providers
        WHERE clinic_id = v_clinic_id AND active = true
        ORDER BY last_name
        LIMIT 4
    ) INTO v_providers;

    IF array_length(v_providers, 1) IS NULL THEN
        RAISE EXCEPTION 'Nessun provider trovato per la clinica %', v_clinic_id;
    END IF;

    -- Rimuove gli appuntamenti demo dei 3 giorni target
    DELETE FROM appointments
    WHERE clinic_id = v_clinic_id
      AND starts_at::date BETWEEN CURRENT_DATE AND CURRENT_DATE + 2;

    RAISE NOTICE 'Appuntamenti esistenti rimossi per i 3 giorni.';

    -- ====================================================
    -- OGGI
    -- ====================================================
    INSERT INTO appointments (clinic_id, patient_id, provider_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (v_clinic_id, v_patients[1],  v_providers[1], 'Poltrona 1', CURRENT_DATE + TIME '08:30', CURRENT_DATE + TIME '09:15', 'completed',  'Igiene professionale completata'),
      (v_clinic_id, v_patients[2],  v_providers[2], 'Poltrona 2', CURRENT_DATE + TIME '09:00', CURRENT_DATE + TIME '09:45', 'completed',  NULL),
      (v_clinic_id, v_patients[3],  v_providers[1], 'Poltrona 1', CURRENT_DATE + TIME '09:30', CURRENT_DATE + TIME '10:15', 'completed',  'Visita di controllo'),
      (v_clinic_id, v_patients[4],  v_providers[3], 'Poltrona 3', CURRENT_DATE + TIME '10:00', CURRENT_DATE + TIME '11:00', 'confirmed',  NULL),
      (v_clinic_id, v_patients[5],  v_providers[2], 'Poltrona 2', CURRENT_DATE + TIME '10:30', CURRENT_DATE + TIME '11:30', 'confirmed',  'Paziente preferisce anestesia topica preventiva'),
      (v_clinic_id, v_patients[6],  v_providers[1], 'Poltrona 1', CURRENT_DATE + TIME '11:00', CURRENT_DATE + TIME '11:45', 'scheduled',  NULL),
      (v_clinic_id, v_patients[7],  v_providers[3], 'Poltrona 3', CURRENT_DATE + TIME '11:30', CURRENT_DATE + TIME '12:30', 'scheduled',  NULL),
      (v_clinic_id, v_patients[8],  v_providers[2], 'Poltrona 2', CURRENT_DATE + TIME '14:00', CURRENT_DATE + TIME '15:00', 'scheduled',  NULL),
      (v_clinic_id, v_patients[9],  v_providers[1], 'Poltrona 1', CURRENT_DATE + TIME '14:30', CURRENT_DATE + TIME '15:15', 'scheduled',  NULL),
      (v_clinic_id, v_patients[10], v_providers[3], 'Poltrona 3', CURRENT_DATE + TIME '15:00', CURRENT_DATE + TIME '16:00', 'confirmed',  NULL),
      (v_clinic_id, v_patients[1],  v_providers[4], 'Poltrona 2', CURRENT_DATE + TIME '15:30', CURRENT_DATE + TIME '16:15', 'confirmed',  NULL),
      (v_clinic_id, v_patients[11], v_providers[1], 'Poltrona 1', CURRENT_DATE + TIME '16:00', CURRENT_DATE + TIME '16:45', 'scheduled',  NULL);

    -- ====================================================
    -- DOMANI
    -- ====================================================
    INSERT INTO appointments (clinic_id, patient_id, provider_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (v_clinic_id, v_patients[3],  v_providers[2], 'Poltrona 1', CURRENT_DATE + 1 + TIME '08:30', CURRENT_DATE + 1 + TIME '09:30', 'scheduled', NULL),
      (v_clinic_id, v_patients[5],  v_providers[1], 'Poltrona 2', CURRENT_DATE + 1 + TIME '09:00', CURRENT_DATE + 1 + TIME '09:45', 'scheduled', NULL),
      (v_clinic_id, v_patients[7],  v_providers[3], 'Poltrona 3', CURRENT_DATE + 1 + TIME '09:30', CURRENT_DATE + 1 + TIME '10:30', 'confirmed', 'Richiamo semestrale'),
      (v_clinic_id, v_patients[2],  v_providers[1], 'Poltrona 1', CURRENT_DATE + 1 + TIME '10:00', CURRENT_DATE + 1 + TIME '11:00', 'confirmed', NULL),
      (v_clinic_id, v_patients[9],  v_providers[2], 'Poltrona 2', CURRENT_DATE + 1 + TIME '10:30', CURRENT_DATE + 1 + TIME '11:15', 'scheduled', NULL),
      (v_clinic_id, v_patients[4],  v_providers[3], 'Poltrona 3', CURRENT_DATE + 1 + TIME '11:00', CURRENT_DATE + 1 + TIME '12:00', 'scheduled', NULL),
      (v_clinic_id, v_patients[6],  v_providers[1], 'Poltrona 1', CURRENT_DATE + 1 + TIME '14:00', CURRENT_DATE + 1 + TIME '15:00', 'scheduled', NULL),
      (v_clinic_id, v_patients[10], v_providers[4], 'Poltrona 2', CURRENT_DATE + 1 + TIME '14:30', CURRENT_DATE + 1 + TIME '15:15', 'confirmed', NULL),
      (v_clinic_id, v_patients[12], v_providers[3], 'Poltrona 3', CURRENT_DATE + 1 + TIME '15:00', CURRENT_DATE + 1 + TIME '16:00', 'scheduled', NULL),
      (v_clinic_id, v_patients[1],  v_providers[2], 'Poltrona 1', CURRENT_DATE + 1 + TIME '15:30', CURRENT_DATE + 1 + TIME '16:30', 'scheduled', NULL);

    -- ====================================================
    -- DOPODOMANI
    -- ====================================================
    INSERT INTO appointments (clinic_id, patient_id, provider_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (v_clinic_id, v_patients[2],  v_providers[3], 'Poltrona 1', CURRENT_DATE + 2 + TIME '08:30', CURRENT_DATE + 2 + TIME '09:15', 'scheduled', NULL),
      (v_clinic_id, v_patients[4],  v_providers[1], 'Poltrona 2', CURRENT_DATE + 2 + TIME '09:00', CURRENT_DATE + 2 + TIME '09:45', 'scheduled', NULL),
      (v_clinic_id, v_patients[8],  v_providers[2], 'Poltrona 3', CURRENT_DATE + 2 + TIME '09:30', CURRENT_DATE + 2 + TIME '10:30', 'confirmed', NULL),
      (v_clinic_id, v_patients[11], v_providers[1], 'Poltrona 1', CURRENT_DATE + 2 + TIME '10:00', CURRENT_DATE + 2 + TIME '11:00', 'scheduled', NULL),
      (v_clinic_id, v_patients[6],  v_providers[3], 'Poltrona 2', CURRENT_DATE + 2 + TIME '10:30', CURRENT_DATE + 2 + TIME '11:30', 'confirmed', NULL),
      (v_clinic_id, v_patients[3],  v_providers[4], 'Poltrona 3', CURRENT_DATE + 2 + TIME '11:00', CURRENT_DATE + 2 + TIME '12:00', 'scheduled', NULL),
      (v_clinic_id, v_patients[7],  v_providers[2], 'Poltrona 1', CURRENT_DATE + 2 + TIME '14:00', CURRENT_DATE + 2 + TIME '14:45', 'scheduled', NULL),
      (v_clinic_id, v_patients[9],  v_providers[1], 'Poltrona 2', CURRENT_DATE + 2 + TIME '14:30', CURRENT_DATE + 2 + TIME '15:30', 'scheduled', NULL),
      (v_clinic_id, v_patients[12], v_providers[3], 'Poltrona 3', CURRENT_DATE + 2 + TIME '15:00', CURRENT_DATE + 2 + TIME '16:00', 'confirmed', NULL),
      (v_clinic_id, v_patients[5],  v_providers[2], 'Poltrona 1', CURRENT_DATE + 2 + TIME '15:30', CURRENT_DATE + 2 + TIME '16:15', 'scheduled', NULL);

    RAISE NOTICE 'Appuntamenti inseriti: 12 oggi, 10 domani, 10 dopodomani.';

END $$;

COMMIT;
