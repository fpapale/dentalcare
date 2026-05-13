-- DentalCare - Seed dati clinici demo
-- Popola: appointments, patient_anamnesis, odontogram_teeth, clinical_history_entries, patient_documents
-- Eseguire DOPO:
--   dentalcare_schema.sql
--   dentalcare_seed_demo_data.sql
--   dentalcare_clinical_extension.sql
--
-- psql -h 172.168.0.173 -U postgres -d dentalcarepro -f dentalcare_seed_clinical.sql

BEGIN;

SET search_path TO dentalcare, public;

-- Rimuove dati demo clinici precedenti per idempotenza
DELETE FROM patient_documents pd
USING clinics c
WHERE pd.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM clinical_history_entries che
USING clinics c
WHERE che.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM odontogram_teeth ot
USING clinics c
WHERE ot.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM patient_anamnesis pa
USING clinics c
WHERE pa.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM appointments a
USING clinics c
WHERE a.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DO $$
DECLARE
    v_clinic_id     uuid;
    v_patient_id    uuid;
    v_provider_id   uuid;
    v_apt_id        uuid;
    v_tpi_id        uuid;
    v_tooth         text;
    v_chair         text;
    v_day_offset    integer;
    v_hour          integer;
    v_chair_idx     integer;
    v_condition     tooth_condition;

    v_teeth text[] := ARRAY[
        '11','12','13','14','15','16','17','18',
        '21','22','23','24','25','26','27','28',
        '31','32','33','34','35','36','37','38',
        '41','42','43','44','45','46','47','48'
    ];

    v_conditions tooth_condition[] := ARRAY[
        'healthy','caries','filling','crown','missing',
        'implant','devitalized','fracture','to_extract','bridge_anchor'
    ]::tooth_condition[];

    v_chairs text[] := ARRAY['Poltrona 1','Poltrona 2','Poltrona 3'];
    v_apt_statuses appointment_status[] := ARRAY[
        'completed','completed','completed','scheduled','confirmed','no_show','cancelled'
    ]::appointment_status[];

    v_selected_surfaces text[];

    r_patient record;
    r_provider record;
BEGIN

    FOR v_clinic_id IN
        SELECT id FROM clinics WHERE vat_number IN ('DEMO-ROMA-001','DEMO-MILANO-001')
    LOOP

        -- ===== ANAMNESI per i primi 30 pazienti di ogni clinica =====
        FOR r_patient IN
            SELECT p.id, p.clinic_id
            FROM patients p
            WHERE p.clinic_id = v_clinic_id
            ORDER BY p.created_at
            LIMIT 30
        LOOP
            SELECT id INTO v_provider_id
            FROM providers
            WHERE clinic_id = v_clinic_id AND role IN ('dentist','admin')
            ORDER BY random() LIMIT 1;

            INSERT INTO patient_anamnesis (
                clinic_id, patient_id, recorded_by_provider_id,
                blood_type, smoker, cigarettes_per_day, alcohol_use,
                hypertension, diabetes, heart_disease, coagulopathy,
                taking_anticoagulants, taking_bisphosphonates, taking_cortisone,
                current_medications,
                allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin,
                other_allergies,
                bruxism, mouth_breathing,
                general_notes, is_current, signed_at
            ) VALUES (
                v_clinic_id, r_patient.id, v_provider_id,
                (ARRAY['A+','A-','B+','B-','0+','0-','AB+','AB-'])[1 + floor(random()*8)::int],
                random() < 0.25,
                CASE WHEN random() < 0.25 THEN (5 + floor(random()*15)::int) ELSE NULL END,
                random() < 0.30,
                random() < 0.20,  -- hypertension
                random() < 0.12,  -- diabetes
                random() < 0.08,  -- heart_disease
                random() < 0.05,  -- coagulopathy
                random() < 0.10,  -- anticoagulants
                random() < 0.04,  -- bisphosphonates
                random() < 0.06,  -- cortisone
                CASE WHEN random() < 0.30 THEN
                    (ARRAY['Amoxicillina 1g/die','Metformina 850mg','Ramipril 5mg','Aspirina 100mg','Omeprazolo 20mg'])[1+floor(random()*5)::int]
                ELSE NULL END,
                random() < 0.08,  -- allergy_penicillin
                random() < 0.05,  -- allergy_latex
                random() < 0.06,  -- allergy_anesthetic
                random() < 0.10,  -- allergy_aspirin
                CASE WHEN random() < 0.10 THEN 'Allergia a nichel' ELSE NULL END,
                random() < 0.18,  -- bruxism
                random() < 0.12,  -- mouth_breathing
                CASE WHEN random() < 0.20 THEN 'Paziente richiede sedazione ansiolitica preventiva.' ELSE NULL END,
                true,
                now() - (floor(random()*365)::int || ' days')::interval
            );
        END LOOP;

        -- ===== ODONTOGRAMMA per i primi 20 pazienti =====
        FOR r_patient IN
            SELECT id, clinic_id
            FROM patients
            WHERE clinic_id = v_clinic_id
            ORDER BY created_at
            LIMIT 20
        LOOP
            SELECT id INTO v_provider_id
            FROM providers
            WHERE clinic_id = v_clinic_id AND role = 'dentist'
            ORDER BY random() LIMIT 1;

            FOR i IN 1..array_length(v_teeth, 1) LOOP
                -- ~70% dei denti presenti e documentati
                IF random() < 0.70 THEN
                    v_condition := v_conditions[1 + floor(random() * array_length(v_conditions, 1))::int];
                    -- Denti anteriori (11-13, 21-23, 31-33, 41-43) raramente mancanti
                    IF v_teeth[i] IN ('11','12','13','21','22','23','31','32','33','41','42','43')
                       AND v_condition = 'missing' THEN
                        v_condition := 'filling';
                    END IF;

                    -- Calcola superfici prima dell'INSERT
                    IF v_condition IN ('caries','filling') AND random() < 0.60 THEN
                        v_selected_surfaces := CASE (floor(random()*4)::int)
                            WHEN 0 THEN ARRAY['O']
                            WHEN 1 THEN ARRAY['M','O']
                            WHEN 2 THEN ARRAY['D','O']
                            ELSE ARRAY['M','O','D']
                        END;
                    ELSE
                        v_selected_surfaces := NULL;
                    END IF;

                    INSERT INTO odontogram_teeth (
                        clinic_id, patient_id, tooth_number, quadrant, is_deciduous,
                        condition, surfaces, notes, recorded_by_provider_id, recorded_at
                    ) VALUES (
                        v_clinic_id, r_patient.id, v_teeth[i],
                        substring(v_teeth[i] from 1 for 1)::smallint,
                        false,
                        v_condition,
                        v_selected_surfaces,
                        CASE
                            WHEN v_condition = 'implant' THEN 'Impianto Nobel Biocare'
                            WHEN v_condition = 'crown' THEN 'Corona in zirconia'
                            WHEN v_condition = 'devitalized' THEN 'Devitalizzazione completata'
                            ELSE NULL
                        END,
                        v_provider_id,
                        now() - (floor(random()*200)::int || ' days')::interval
                    ) ON CONFLICT DO NOTHING;
                END IF;
            END LOOP;
        END LOOP;

        -- ===== APPUNTAMENTI =====
        -- ~6 appuntamenti per paziente distribuiti -60..+30 giorni da oggi
        FOR r_patient IN
            SELECT p.id, p.clinic_id
            FROM patients p
            WHERE p.clinic_id = v_clinic_id
        LOOP
            FOR apt_i IN 1..(3 + floor(random()*5)::int) LOOP
                SELECT id INTO v_provider_id
                FROM providers
                WHERE clinic_id = v_clinic_id AND role IN ('dentist','hygienist','orthodontist','surgeon')
                ORDER BY random() LIMIT 1;

                SELECT tpi.id INTO v_tpi_id
                FROM treatment_plan_items tpi
                JOIN treatment_plans tp ON tp.id = tpi.treatment_plan_id
                WHERE tp.patient_id = r_patient.id
                  AND tpi.clinic_id = v_clinic_id
                ORDER BY random()
                LIMIT 1;

                v_day_offset := -60 + floor(random()*90)::int;  -- -60..+30
                v_hour := 8 + floor(random()*9)::int;            -- 08..16
                v_chair := v_chairs[1 + floor(random()*3)::int];

                DECLARE
                    v_apt_start timestamptz := date_trunc('day', now()) + (v_day_offset || ' days')::interval + (v_hour || ' hours')::interval;
                    v_apt_end   timestamptz := v_apt_start + '45 minutes'::interval;
                    v_status    appointment_status;
                BEGIN
                    v_status := CASE
                        WHEN v_day_offset < -2 THEN
                            v_apt_statuses[1 + floor(random()*7)::int]
                        WHEN v_day_offset BETWEEN -2 AND 0 THEN 'confirmed'
                        ELSE
                            (ARRAY['scheduled','confirmed']::appointment_status[])[1 + floor(random()*2)::int]
                    END;

                    INSERT INTO appointments (
                        clinic_id, patient_id, provider_id, treatment_plan_item_id,
                        chair_label, starts_at, ends_at, status, notes
                    ) VALUES (
                        v_clinic_id, r_patient.id, v_provider_id, v_tpi_id,
                        v_chair, v_apt_start, v_apt_end, v_status,
                        CASE WHEN random() < 0.15 THEN 'Paziente ansioso - preferisce anestesia topica prima della puntuta.' ELSE NULL END
                    ) RETURNING id INTO v_apt_id;

                    -- Se l'appuntamento è completato, aggiungi nota storico clinico
                    IF v_status = 'completed' THEN
                        INSERT INTO clinical_history_entries (
                            clinic_id, patient_id, appointment_id, provider_id,
                            entry_date, tooth_number, service_code, service_name,
                            clinical_notes, next_visit_notes
                        )
                        SELECT
                            v_clinic_id, r_patient.id, v_apt_id, v_provider_id,
                            v_apt_start::date,
                            tpi.tooth_number,
                            sc.code,
                            sc.name,
                            'Seduta completata regolarmente. ' || CASE
                                WHEN random() < 0.3 THEN 'Paziente collaborante. Tecnica anestesia infiltrativa.'
                                WHEN random() < 0.5 THEN 'Visita di controllo con aggiornamento odontogramma.'
                                ELSE 'Nessuna complicazione intraoperatoria.'
                            END,
                            CASE WHEN random() < 0.4 THEN 'Richiamare entro 3 mesi per controllo.' ELSE NULL END
                        FROM treatment_plan_items tpi
                        JOIN service_catalog sc ON sc.id = tpi.service_id AND sc.clinic_id = tpi.clinic_id
                        WHERE tpi.id = v_tpi_id AND tpi.clinic_id = v_clinic_id
                        LIMIT 1;

                        -- Se non c'era tpi, inserisci nota generica
                        IF NOT FOUND THEN
                            INSERT INTO clinical_history_entries (
                                clinic_id, patient_id, appointment_id, provider_id,
                                entry_date, clinical_notes
                            ) VALUES (
                                v_clinic_id, r_patient.id, v_apt_id, v_provider_id,
                                v_apt_start::date,
                                'Visita di controllo. Igiene orale nella norma. Consigliato controllo periodico semestrale.'
                            );
                        END IF;
                    END IF;
                END;
            END LOOP;
        END LOOP;

        -- ===== DOCUMENTI / RX Demo (5 per paziente, pazienti 1..15) =====
        FOR r_patient IN
            SELECT id, clinic_id
            FROM patients
            WHERE clinic_id = v_clinic_id
            ORDER BY created_at
            LIMIT 15
        LOOP
            SELECT id INTO v_provider_id
            FROM providers
            WHERE clinic_id = v_clinic_id AND role IN ('dentist','surgeon')
            ORDER BY random() LIMIT 1;

            -- Ortopanoramica
            INSERT INTO patient_documents (
                clinic_id, patient_id, uploaded_by_provider_id,
                document_type, title, description, file_name, file_path, mime_type,
                taken_at, notes
            ) VALUES (
                v_clinic_id, r_patient.id, v_provider_id,
                'rx_panoramica',
                'Ortopanoramica ' || to_char(current_date - floor(random()*400)::int, 'DD/MM/YYYY'),
                'Radiografia panoramica per valutazione generale.',
                'OPT_' || replace(r_patient.id::text, '-', '') || '.dcm',
                'documents/' || v_clinic_id || '/rx/' || r_patient.id || '/opt_' || gen_random_uuid() || '.dcm',
                'application/dicom',
                current_date - floor(random()*400)::int,
                'Valutazione ortodontica e implantologica.'
            );

            -- 2-3 RX endorali
            FOR rx_i IN 1..(2 + floor(random()*2)::int) LOOP
                v_tooth := v_teeth[1 + floor(random()*array_length(v_teeth,1))::int];
                INSERT INTO patient_documents (
                    clinic_id, patient_id, uploaded_by_provider_id,
                    document_type, title, description, file_name, file_path, mime_type,
                    tooth_number, taken_at
                ) VALUES (
                    v_clinic_id, r_patient.id, v_provider_id,
                    'rx_endorale',
                    'RX Endorale dente ' || v_tooth,
                    'Radiografia periapicale dente ' || v_tooth,
                    'RX_' || v_tooth || '_' || replace(r_patient.id::text,'-','') || '.dcm',
                    'documents/' || v_clinic_id || '/rx/' || r_patient.id || '/endo_' || gen_random_uuid() || '.dcm',
                    'application/dicom',
                    v_tooth,
                    current_date - floor(random()*300)::int
                );
            END LOOP;

            -- 1-2 foto cliniche
            FOR foto_i IN 1..(1 + floor(random()*2)::int) LOOP
                INSERT INTO patient_documents (
                    clinic_id, patient_id, uploaded_by_provider_id,
                    document_type, title, description, file_name, file_path, mime_type,
                    taken_at
                ) VALUES (
                    v_clinic_id, r_patient.id, v_provider_id,
                    'foto_clinica',
                    'Foto clinica intraorale',
                    'Documentazione fotografica clinica intraorale.',
                    'FOTO_' || replace(r_patient.id::text,'-','') || '_' || foto_i || '.jpg',
                    'documents/' || v_clinic_id || '/foto/' || r_patient.id || '/foto_' || gen_random_uuid() || '.jpg',
                    'image/jpeg',
                    current_date - floor(random()*200)::int
                );
            END LOOP;

            -- Consenso informato
            IF random() < 0.70 THEN
                INSERT INTO patient_documents (
                    clinic_id, patient_id, uploaded_by_provider_id,
                    document_type, title, description, file_name, file_path, mime_type,
                    taken_at
                ) VALUES (
                    v_clinic_id, r_patient.id, v_provider_id,
                    'consenso_informato',
                    'Consenso informato trattamento',
                    'Consenso informato firmato dal paziente.',
                    'CONSENSO_' || replace(r_patient.id::text,'-','') || '.pdf',
                    'documents/' || v_clinic_id || '/docs/' || r_patient.id || '/consenso_' || gen_random_uuid() || '.pdf',
                    'application/pdf',
                    current_date - floor(random()*365)::int
                );
            END IF;
        END LOOP;

    END LOOP; -- fine loop cliniche
END $$;

COMMIT;

-- Riepilogo
SET search_path TO dentalcare, public;

SELECT 'appointments' AS table_name, COUNT(*) AS rows FROM appointments
UNION ALL
SELECT 'patient_anamnesis', COUNT(*) FROM patient_anamnesis
UNION ALL
SELECT 'odontogram_teeth', COUNT(*) FROM odontogram_teeth
UNION ALL
SELECT 'clinical_history_entries', COUNT(*) FROM clinical_history_entries
UNION ALL
SELECT 'patient_documents', COUNT(*) FROM patient_documents
ORDER BY table_name;
