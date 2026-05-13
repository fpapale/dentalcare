-- DentalCare PostgreSQL demo seed data
-- Compatibile con dentalcare_schema.sql
-- Uso consigliato:
--   psql -d dentalcare -f dentalcare_schema.sql
--   psql -d dentalcare -f dentalcare_seed_demo_data.sql
--
-- Nota: lo script è rieseguibile. Cancella e ricrea solo le cliniche demo
-- identificate dai VAT number DEMO-ROMA-001 e DEMO-MILANO-001.

BEGIN;

SET search_path TO dentalcare, public;

-- Ripulisce esclusivamente i dati demo generati da questo script.
-- Cancelliamo in ordine esplicito perché alcune FK cliniche usano ON DELETE RESTRICT
-- per proteggere dati sanitari e preventivi già prodotti.
DELETE FROM estimate_lines el
USING clinics c
WHERE el.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM estimates e
USING clinics c
WHERE e.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM treatment_plan_items tpi
USING clinics c
WHERE tpi.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM treatment_plans tp
USING clinics c
WHERE tp.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM service_catalog sc
USING clinics c
WHERE sc.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM providers pr
USING clinics c
WHERE pr.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM patients p
USING clinics c
WHERE p.clinic_id = c.id
  AND c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DELETE FROM clinics
WHERE vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001');

DO $$
DECLARE
    v_clinic_id uuid;
    v_patient_id uuid;
    v_provider_id uuid;
    v_plan_id uuid;
    v_estimate_id uuid;

    v_clinic_index integer;
    v_provider_index integer;
    v_patient_index integer;
    v_plan_index integer;
    v_item_index integer;
    v_line_position integer;
    v_plan_count integer;
    v_item_count integer;
    v_estimate_counter integer;
    v_patients_per_clinic integer;

    v_plan_status treatment_plan_status;
    v_item_status treatment_item_status;
    v_estimate_status estimate_status;
    v_role provider_role;

    v_sc record;
    v_tpi record;

    v_tooth text;
    v_quadrant smallint;
    v_surfaces text[];
    v_price numeric(12,2);
    v_discount numeric(12,2);
    v_clinic_prefix text;

    v_first_names text[] := ARRAY[
        'Alessandro','Alessia','Andrea','Anna','Antonio','Beatrice','Camilla','Carlo','Chiara','Claudio',
        'Davide','Elena','Federica','Francesca','Francesco','Gabriele','Giulia','Giorgio','Lorenzo','Lucia',
        'Marco','Maria','Martina','Matteo','Michela','Nicola','Paola','Riccardo','Sara','Simone',
        'Sofia','Stefano','Valentina','Vittoria','Luca','Marta','Roberto','Silvia','Tommaso','Giovanni'
    ];

    v_last_names text[] := ARRAY[
        'Rossi','Bianchi','Romano','Colombo','Ricci','Marino','Greco','Bruno','Gallo','Conti',
        'De Luca','Mancini','Costa','Giordano','Rizzo','Lombardi','Moretti','Barbieri','Fontana','Santoro',
        'Mariani','Rinaldi','Caruso','Ferrara','Galli','Martini','Leone','Longo','Gentile','Martinelli',
        'Vitale','Lombardo','Serra','Coppola','De Santis','D''Angelo','Fiore','Palumbo','Monti','Testa'
    ];

    v_provider_first_names text[] := ARRAY[
        'Federico','Laura','Michele','Serena','Paolo','Ilaria','Roberto','Giada','Enrico','Valeria',
        'Massimo','Elisa','Daniele','Carlotta','Davide','Monica'
    ];

    v_provider_last_names text[] := ARRAY[
        'Morelli','Ferri','Gentili','Amato','Marchetti','Villa','Ruggeri','Sanna','Pellegrini','Sala',
        'Grassi','Cattaneo','Mazza','Riva','Fabbri','Bernardi'
    ];

    v_teeth text[] := ARRAY[
        '11','12','13','14','15','16','17','18',
        '21','22','23','24','25','26','27','28',
        '31','32','33','34','35','36','37','38',
        '41','42','43','44','45','46','47','48'
    ];
BEGIN
    -- Due cliniche demo per simulare un gestionale multi-studio / multi-tenant.
    FOR v_clinic_index IN 1..2 LOOP
        v_estimate_counter := 0;
        v_clinic_prefix := CASE WHEN v_clinic_index = 1 THEN 'ROMA' ELSE 'MILANO' END;
        v_patients_per_clinic := CASE WHEN v_clinic_index = 1 THEN 60 ELSE 45 END;

        INSERT INTO clinics (
            name,
            legal_name,
            vat_number,
            fiscal_code,
            phone,
            email,
            address_line1,
            city,
            province,
            postal_code,
            country
        ) VALUES (
            CASE WHEN v_clinic_index = 1 THEN 'Studio Demo DentalCare Roma' ELSE 'Studio Demo DentalCare Milano' END,
            CASE WHEN v_clinic_index = 1 THEN 'DentalCare Roma S.r.l.' ELSE 'DentalCare Milano S.r.l.' END,
            CASE WHEN v_clinic_index = 1 THEN 'DEMO-ROMA-001' ELSE 'DEMO-MILANO-001' END,
            CASE WHEN v_clinic_index = 1 THEN 'DEMOROMA001' ELSE 'DEMOMILANO001' END,
            CASE WHEN v_clinic_index = 1 THEN '+39 06 5550101' ELSE '+39 02 5550101' END,
            CASE WHEN v_clinic_index = 1 THEN 'roma@dentalcare.demo' ELSE 'milano@dentalcare.demo' END,
            CASE WHEN v_clinic_index = 1 THEN 'Via Nomentana 123' ELSE 'Corso Buenos Aires 45' END,
            CASE WHEN v_clinic_index = 1 THEN 'Roma' ELSE 'Milano' END,
            CASE WHEN v_clinic_index = 1 THEN 'RM' ELSE 'MI' END,
            CASE WHEN v_clinic_index = 1 THEN '00162' ELSE '20124' END,
            'IT'
        ) RETURNING id INTO v_clinic_id;

        -- Staff: dentisti, igienisti, ortodontista, chirurgo, assistente e amministrazione.
        FOR v_provider_index IN 1..8 LOOP
            v_role := CASE
                WHEN v_provider_index IN (1, 2) THEN 'dentist'::provider_role
                WHEN v_provider_index = 3 THEN 'hygienist'::provider_role
                WHEN v_provider_index = 4 THEN 'orthodontist'::provider_role
                WHEN v_provider_index = 5 THEN 'surgeon'::provider_role
                WHEN v_provider_index IN (6, 7) THEN 'assistant'::provider_role
                ELSE 'admin'::provider_role
            END;

            INSERT INTO providers (
                clinic_id,
                first_name,
                last_name,
                role,
                phone,
                email,
                active
            ) VALUES (
                v_clinic_id,
                v_provider_first_names[((v_clinic_index - 1) * 8) + v_provider_index],
                v_provider_last_names[((v_clinic_index - 1) * 8) + v_provider_index],
                v_role,
                '+39 3' || lpad((100000000 + floor(random() * 899999999)::bigint)::text, 9, '0'),
                lower(v_provider_first_names[((v_clinic_index - 1) * 8) + v_provider_index] || '.' || v_provider_last_names[((v_clinic_index - 1) * 8) + v_provider_index] || '.' || lower(v_clinic_prefix) || '@dentalcare.demo'),
                true
            );
        END LOOP;

        -- Catalogo prestazioni / listino: codici volutamente ampi per testare filtri e preventivi.
        INSERT INTO service_catalog (clinic_id, code, name, category, description, default_price, default_vat_rate) VALUES
            (v_clinic_id, 'VIS-001', 'Prima visita odontoiatrica', 'Diagnostica', 'Prima visita con valutazione generale del cavo orale', 50.00, 0),
            (v_clinic_id, 'VIS-002', 'Visita di controllo', 'Diagnostica', 'Controllo periodico odontoiatrico', 35.00, 0),
            (v_clinic_id, 'RX-OPT', 'Ortopanoramica', 'Diagnostica', 'Radiografia panoramica digitale', 45.00, 0),
            (v_clinic_id, 'RX-ENDO', 'Radiografia endorale', 'Diagnostica', 'Radiografia endorale singola', 25.00, 0),
            (v_clinic_id, 'CBCT-001', 'CBCT arcata singola', 'Diagnostica', 'Tomografia computerizzata cone beam arcata singola', 120.00, 0),
            (v_clinic_id, 'IGI-001', 'Igiene orale professionale', 'Igiene', 'Ablazione tartaro e lucidatura', 80.00, 0),
            (v_clinic_id, 'IGI-002', 'Igiene orale profonda', 'Igiene', 'Seduta di igiene approfondita', 110.00, 0),
            (v_clinic_id, 'IGI-003', 'Fluoroprofilassi', 'Igiene', 'Applicazione topica di fluoro', 35.00, 0),
            (v_clinic_id, 'PAR-001', 'Levigatura radicolare per quadrante', 'Parodontologia', 'Scaling e root planing per quadrante', 160.00, 0),
            (v_clinic_id, 'PAR-002', 'Terapia parodontale di mantenimento', 'Parodontologia', 'Richiamo parodontale periodico', 95.00, 0),
            (v_clinic_id, 'CONS-001', 'Otturazione composito monofacciale', 'Conservativa', 'Restauro diretto in composito a una superficie', 100.00, 0),
            (v_clinic_id, 'CONS-002', 'Otturazione composito bifacciale', 'Conservativa', 'Restauro diretto in composito a due superfici', 130.00, 0),
            (v_clinic_id, 'CONS-003', 'Otturazione composito trifacciale', 'Conservativa', 'Restauro diretto in composito a tre superfici', 160.00, 0),
            (v_clinic_id, 'CONS-004', 'Ricostruzione estetica anteriore', 'Conservativa', 'Ricostruzione estetica diretta settore anteriore', 220.00, 0),
            (v_clinic_id, 'ENDO-001', 'Devitalizzazione monoradicolare', 'Endodonzia', 'Trattamento canalare dente monoradicolare', 280.00, 0),
            (v_clinic_id, 'ENDO-002', 'Devitalizzazione biradicolare', 'Endodonzia', 'Trattamento canalare dente biradicolare', 360.00, 0),
            (v_clinic_id, 'ENDO-003', 'Devitalizzazione pluriradicolare', 'Endodonzia', 'Trattamento canalare dente pluriradicolare', 450.00, 0),
            (v_clinic_id, 'ENDO-004', 'Ritrattamento canalare', 'Endodonzia', 'Ritrattamento endodontico', 520.00, 0),
            (v_clinic_id, 'CHIR-001', 'Estrazione semplice', 'Chirurgia', 'Estrazione dentaria semplice', 120.00, 0),
            (v_clinic_id, 'CHIR-002', 'Estrazione complessa', 'Chirurgia', 'Estrazione chirurgica complessa', 250.00, 0),
            (v_clinic_id, 'CHIR-003', 'Estrazione ottavo incluso', 'Chirurgia', 'Estrazione chirurgica di terzo molare incluso', 380.00, 0),
            (v_clinic_id, 'CHIR-004', 'Frenulectomia', 'Chirurgia', 'Intervento di frenulectomia', 280.00, 0),
            (v_clinic_id, 'IMP-001', 'Impianto osteointegrato', 'Implantologia', 'Inserimento impianto dentale', 950.00, 0),
            (v_clinic_id, 'IMP-002', 'Moncone implantare', 'Implantologia', 'Moncone protesico su impianto', 280.00, 0),
            (v_clinic_id, 'IMP-003', 'Corona su impianto', 'Implantologia', 'Corona definitiva su impianto', 750.00, 0),
            (v_clinic_id, 'IMP-004', 'Rigenerazione ossea guidata', 'Implantologia', 'Procedura di rigenerazione ossea', 650.00, 0),
            (v_clinic_id, 'PROT-001', 'Corona in zirconia', 'Protesi', 'Corona definitiva in zirconia', 650.00, 0),
            (v_clinic_id, 'PROT-002', 'Corona metallo-ceramica', 'Protesi', 'Corona metallo-ceramica', 520.00, 0),
            (v_clinic_id, 'PROT-003', 'Intarsio in composito', 'Protesi', 'Intarsio indiretto in composito', 420.00, 0),
            (v_clinic_id, 'PROT-004', 'Faccetta in ceramica', 'Protesi', 'Faccetta estetica in ceramica', 700.00, 0),
            (v_clinic_id, 'PROT-005', 'Protesi mobile parziale', 'Protesi', 'Protesi mobile parziale in resina', 850.00, 0),
            (v_clinic_id, 'PROT-006', 'Protesi totale', 'Protesi', 'Protesi totale in resina', 1200.00, 0),
            (v_clinic_id, 'ORTO-001', 'Studio ortodontico', 'Ortodontia', 'Analisi caso ortodontico con piano terapeutico', 180.00, 0),
            (v_clinic_id, 'ORTO-002', 'Apparecchio fisso arcata singola', 'Ortodontia', 'Terapia ortodontica fissa per arcata', 1700.00, 0),
            (v_clinic_id, 'ORTO-003', 'Allineatori trasparenti lite', 'Ortodontia', 'Terapia con allineatori caso semplice', 2200.00, 0),
            (v_clinic_id, 'ORTO-004', 'Allineatori trasparenti full', 'Ortodontia', 'Terapia con allineatori caso completo', 3900.00, 0),
            (v_clinic_id, 'PED-001', 'Sigillatura solchi', 'Pedodonzia', 'Sigillatura preventiva dei solchi', 45.00, 0),
            (v_clinic_id, 'PED-002', 'Otturazione dente deciduo', 'Pedodonzia', 'Restauro conservativo dente deciduo', 90.00, 0),
            (v_clinic_id, 'EST-001', 'Sbiancamento professionale', 'Estetica', 'Sbiancamento dentale professionale', 350.00, 0),
            (v_clinic_id, 'EST-002', 'Mascherine sbiancamento domiciliare', 'Estetica', 'Kit domiciliare con mascherine personalizzate', 240.00, 0),
            (v_clinic_id, 'GNAT-001', 'Bite notturno', 'Gnatologia', 'Bite occlusale personalizzato', 380.00, 0),
            (v_clinic_id, 'URG-001', 'Urgenza odontoiatrica', 'Urgenza', 'Visita e gestione urgenza odontoiatrica', 90.00, 0),
            (v_clinic_id, 'MED-001', 'Medicazione provvisoria', 'Urgenza', 'Medicazione temporanea', 70.00, 0),
            (v_clinic_id, 'SUT-001', 'Rimozione punti', 'Chirurgia', 'Rimozione suture post intervento', 30.00, 0);

        -- Pazienti, piani di cura, trattamenti pianificati e preventivi collegati.
        FOR v_patient_index IN 1..v_patients_per_clinic LOOP
            INSERT INTO patients (
                clinic_id,
                first_name,
                last_name,
                fiscal_code,
                birth_date,
                phone,
                email,
                address_line1,
                city,
                province,
                postal_code,
                country,
                notes
            ) VALUES (
                v_clinic_id,
                v_first_names[1 + ((v_patient_index + v_clinic_index - 2) % array_length(v_first_names, 1))],
                v_last_names[1 + ((v_patient_index * 3 + v_clinic_index - 2) % array_length(v_last_names, 1))],
                'DEMO' || v_clinic_prefix || lpad(v_patient_index::text, 4, '0'),
                current_date - ((18 * 365) + floor(random() * 58 * 365)::integer),
                '+39 3' || lpad((100000000 + floor(random() * 899999999)::bigint)::text, 9, '0'),
                'paziente.' || lower(v_clinic_prefix) || '.' || lpad(v_patient_index::text, 4, '0') || '@example.test',
                'Via Demo ' || v_patient_index,
                CASE WHEN v_clinic_index = 1 THEN 'Roma' ELSE 'Milano' END,
                CASE WHEN v_clinic_index = 1 THEN 'RM' ELSE 'MI' END,
                CASE WHEN v_clinic_index = 1 THEN '00100' ELSE '20100' END,
                'IT',
                CASE
                    WHEN random() < 0.18 THEN 'Paziente ansioso: preferisce spiegazioni dettagliate prima delle cure.'
                    WHEN random() < 0.35 THEN 'Richiamare per controlli periodici ogni 6 mesi.'
                    ELSE NULL
                END
            ) RETURNING id INTO v_patient_id;

            v_plan_count := 1 + floor(random() * 3)::integer; -- da 1 a 3 piani per paziente

            FOR v_plan_index IN 1..v_plan_count LOOP
                v_plan_status := (ARRAY[
                    'draft','proposed','accepted','in_progress','completed','rejected'
                ]::treatment_plan_status[])[1 + floor(random() * 6)::integer];

                SELECT id
                INTO v_provider_id
                FROM providers
                WHERE clinic_id = v_clinic_id
                  AND role IN ('dentist','orthodontist','surgeon')
                  AND active = true
                ORDER BY random()
                LIMIT 1;

                INSERT INTO treatment_plans (
                    clinic_id,
                    patient_id,
                    name,
                    description,
                    status,
                    created_by_provider_id,
                    proposed_at,
                    accepted_at,
                    completed_at,
                    rejected_at
                ) VALUES (
                    v_clinic_id,
                    v_patient_id,
                    CASE
                        WHEN v_plan_index = 1 THEN 'Piano di cura principale'
                        WHEN v_plan_index = 2 THEN 'Piano alternativo conservativo'
                        ELSE 'Piano riabilitativo esteso'
                    END,
                    CASE
                        WHEN v_plan_index = 1 THEN 'Piano clinico principale generato per dati demo.'
                        WHEN v_plan_index = 2 THEN 'Alternativa con minore invasività e priorità alle urgenze.'
                        ELSE 'Piano completo con più fasi terapeutiche.'
                    END,
                    v_plan_status,
                    v_provider_id,
                    CASE WHEN v_plan_status IN ('proposed','accepted','in_progress','completed','rejected') THEN now() - (floor(random() * 120)::integer || ' days')::interval ELSE NULL END,
                    CASE WHEN v_plan_status IN ('accepted','in_progress','completed') THEN now() - (floor(random() * 80)::integer || ' days')::interval ELSE NULL END,
                    CASE WHEN v_plan_status = 'completed' THEN now() - (floor(random() * 20)::integer || ' days')::interval ELSE NULL END,
                    CASE WHEN v_plan_status = 'rejected' THEN now() - (floor(random() * 60)::integer || ' days')::interval ELSE NULL END
                ) RETURNING id INTO v_plan_id;

                v_item_count := 3 + floor(random() * 6)::integer; -- da 3 a 8 trattamenti per piano

                FOR v_item_index IN 1..v_item_count LOOP
                    SELECT id, code, name, category, default_price, default_vat_rate
                    INTO v_sc
                    FROM service_catalog
                    WHERE clinic_id = v_clinic_id
                      AND active = true
                    ORDER BY random()
                    LIMIT 1;

                    SELECT id
                    INTO v_provider_id
                    FROM providers
                    WHERE clinic_id = v_clinic_id
                      AND active = true
                      AND (
                          (v_sc.category = 'Igiene' AND role = 'hygienist') OR
                          (v_sc.category = 'Ortodontia' AND role = 'orthodontist') OR
                          (v_sc.category IN ('Chirurgia','Implantologia') AND role = 'surgeon') OR
                          (v_sc.category NOT IN ('Igiene','Ortodontia','Chirurgia','Implantologia') AND role IN ('dentist','surgeon'))
                      )
                    ORDER BY random()
                    LIMIT 1;

                    IF v_provider_id IS NULL THEN
                        SELECT id INTO v_provider_id
                        FROM providers
                        WHERE clinic_id = v_clinic_id AND role IN ('dentist','surgeon','orthodontist')
                        ORDER BY random()
                        LIMIT 1;
                    END IF;

                    IF v_sc.category IN ('Diagnostica','Igiene','Ortodontia','Estetica','Gnatologia','Urgenza') THEN
                        v_tooth := NULL;
                        v_quadrant := NULL;
                    ELSE
                        v_tooth := v_teeth[1 + floor(random() * array_length(v_teeth, 1))::integer];
                        v_quadrant := substring(v_tooth from 1 for 1)::smallint;
                    END IF;

                    IF v_sc.category = 'Conservativa' THEN
                        v_surfaces := CASE floor(random() * 6)::integer
                            WHEN 0 THEN ARRAY['O']
                            WHEN 1 THEN ARRAY['M','O']
                            WHEN 2 THEN ARRAY['D','O']
                            WHEN 3 THEN ARRAY['M','O','D']
                            WHEN 4 THEN ARRAY['V']
                            ELSE ARRAY['L']
                        END;
                    ELSE
                        v_surfaces := NULL;
                    END IF;

                    v_item_status := CASE
                        WHEN v_plan_status = 'completed' THEN 'completed'::treatment_item_status
                        WHEN v_plan_status = 'in_progress' THEN
                            (ARRAY['completed','scheduled','accepted']::treatment_item_status[])[1 + floor(random() * 3)::integer]
                        WHEN v_plan_status = 'accepted' THEN
                            (ARRAY['accepted','scheduled','planned']::treatment_item_status[])[1 + floor(random() * 3)::integer]
                        WHEN v_plan_status = 'rejected' THEN
                            (ARRAY['cancelled','planned']::treatment_item_status[])[1 + floor(random() * 2)::integer]
                        ELSE 'planned'::treatment_item_status
                    END;

                    v_price := round(v_sc.default_price * (0.90 + random() * 0.25)::numeric, 2);

                    INSERT INTO treatment_plan_items (
                        clinic_id,
                        treatment_plan_id,
                        service_id,
                        provider_id,
                        tooth_number,
                        quadrant,
                        surfaces,
                        quantity,
                        planned_price,
                        planned_vat_rate,
                        clinical_notes,
                        status,
                        priority,
                        planned_date,
                        completed_at
                    ) VALUES (
                        v_clinic_id,
                        v_plan_id,
                        v_sc.id,
                        v_provider_id,
                        v_tooth,
                        v_quadrant,
                        v_surfaces,
                        CASE WHEN v_sc.category = 'Igiene' AND random() < 0.15 THEN 2 ELSE 1 END,
                        v_price,
                        v_sc.default_vat_rate,
                        CASE
                            WHEN v_sc.category = 'Endodonzia' THEN 'Valutare RX endorale prima della seduta.'
                            WHEN v_sc.category = 'Implantologia' THEN 'Richiesta valutazione ossea e consenso informato.'
                            WHEN v_sc.category = 'Parodontologia' THEN 'Associare istruzioni di igiene domiciliare.'
                            WHEN random() < 0.12 THEN 'Nota clinica demo per test interfaccia.'
                            ELSE NULL
                        END,
                        v_item_status,
                        v_item_index * 10,
                        current_date + (floor(random() * 90)::integer),
                        CASE WHEN v_item_status = 'completed' THEN now() - (floor(random() * 30)::integer || ' days')::interval ELSE NULL END
                    );
                END LOOP;

                -- Preventivo versione 1, collegato al piano di cura.
                v_estimate_counter := v_estimate_counter + 1;
                v_estimate_status := CASE
                    WHEN v_plan_status = 'draft' THEN 'draft'::estimate_status
                    WHEN v_plan_status = 'rejected' THEN 'rejected'::estimate_status
                    WHEN v_plan_status IN ('accepted','in_progress','completed') THEN 'accepted'::estimate_status
                    ELSE 'sent'::estimate_status
                END;

                INSERT INTO estimates (
                    clinic_id,
                    patient_id,
                    treatment_plan_id,
                    estimate_number,
                    version,
                    status,
                    title,
                    notes,
                    currency,
                    issued_at,
                    sent_at,
                    valid_until,
                    accepted_at,
                    rejected_at
                ) VALUES (
                    v_clinic_id,
                    v_patient_id,
                    v_plan_id,
                    v_clinic_prefix || '-2026-' || lpad(v_estimate_counter::text, 5, '0'),
                    1,
                    v_estimate_status,
                    'Preventivo piano di cura - versione 1',
                    'Preventivo demo generato dalle righe del piano di cura.',
                    'EUR',
                    CASE WHEN v_estimate_status <> 'draft' THEN now() - (floor(random() * 90)::integer || ' days')::interval ELSE NULL END,
                    CASE WHEN v_estimate_status IN ('sent','accepted','rejected') THEN now() - (floor(random() * 75)::integer || ' days')::interval ELSE NULL END,
                    current_date + 30,
                    CASE WHEN v_estimate_status = 'accepted' THEN now() - (floor(random() * 60)::integer || ' days')::interval ELSE NULL END,
                    CASE WHEN v_estimate_status = 'rejected' THEN now() - (floor(random() * 45)::integer || ' days')::interval ELSE NULL END
                ) RETURNING id INTO v_estimate_id;

                v_line_position := 0;
                FOR v_tpi IN
                    SELECT
                        tpi.id AS treatment_plan_item_id,
                        tpi.service_id,
                        tpi.tooth_number,
                        tpi.quantity,
                        tpi.planned_price,
                        tpi.planned_vat_rate,
                        sc.name AS service_name,
                        sc.category AS service_category
                    FROM treatment_plan_items tpi
                    JOIN service_catalog sc
                      ON sc.id = tpi.service_id
                     AND sc.clinic_id = tpi.clinic_id
                    WHERE tpi.clinic_id = v_clinic_id
                      AND tpi.treatment_plan_id = v_plan_id
                    ORDER BY tpi.priority, tpi.created_at
                LOOP
                    v_line_position := v_line_position + 1;
                    v_discount := CASE
                        WHEN random() < 0.10 THEN round((v_tpi.quantity * v_tpi.planned_price * 0.05)::numeric, 2)
                        ELSE 0
                    END;

                    INSERT INTO estimate_lines (
                        clinic_id,
                        estimate_id,
                        treatment_plan_item_id,
                        service_id,
                        line_position,
                        description_snapshot,
                        tooth_snapshot,
                        quantity,
                        unit_price,
                        discount_amount,
                        vat_rate
                    ) VALUES (
                        v_clinic_id,
                        v_estimate_id,
                        v_tpi.treatment_plan_item_id,
                        v_tpi.service_id,
                        v_line_position,
                        v_tpi.service_name || COALESCE(' - dente ' || v_tpi.tooth_number, ''),
                        v_tpi.tooth_number,
                        v_tpi.quantity,
                        v_tpi.planned_price,
                        v_discount,
                        v_tpi.planned_vat_rate
                    );
                END LOOP;

                -- Circa un terzo dei piani non bozza/non rifiutati ha una seconda versione del preventivo.
                IF random() < 0.35 AND v_plan_status NOT IN ('draft','rejected') THEN
                    v_estimate_counter := v_estimate_counter + 1;
                    v_estimate_status := CASE
                        WHEN v_plan_status IN ('accepted','in_progress','completed') THEN 'accepted'::estimate_status
                        ELSE 'sent'::estimate_status
                    END;

                    INSERT INTO estimates (
                        clinic_id,
                        patient_id,
                        treatment_plan_id,
                        estimate_number,
                        version,
                        status,
                        title,
                        notes,
                        currency,
                        issued_at,
                        sent_at,
                        valid_until,
                        accepted_at
                    ) VALUES (
                        v_clinic_id,
                        v_patient_id,
                        v_plan_id,
                        v_clinic_prefix || '-2026-' || lpad(v_estimate_counter::text, 5, '0'),
                        2,
                        v_estimate_status,
                        'Preventivo piano di cura - versione 2',
                        'Seconda versione demo con sconto o rimodulazione del piano.',
                        'EUR',
                        now() - (floor(random() * 45)::integer || ' days')::interval,
                        now() - (floor(random() * 40)::integer || ' days')::interval,
                        current_date + 45,
                        CASE WHEN v_estimate_status = 'accepted' THEN now() - (floor(random() * 30)::integer || ' days')::interval ELSE NULL END
                    ) RETURNING id INTO v_estimate_id;

                    v_line_position := 0;
                    FOR v_tpi IN
                        SELECT
                            tpi.id AS treatment_plan_item_id,
                            tpi.service_id,
                            tpi.tooth_number,
                            tpi.quantity,
                            tpi.planned_price,
                            tpi.planned_vat_rate,
                            sc.name AS service_name,
                            sc.category AS service_category
                        FROM treatment_plan_items tpi
                        JOIN service_catalog sc
                          ON sc.id = tpi.service_id
                         AND sc.clinic_id = tpi.clinic_id
                        WHERE tpi.clinic_id = v_clinic_id
                          AND tpi.treatment_plan_id = v_plan_id
                        ORDER BY tpi.priority, tpi.created_at
                    LOOP
                        v_line_position := v_line_position + 1;
                        v_discount := round((v_tpi.quantity * v_tpi.planned_price * (0.08 + random() * 0.07)::numeric)::numeric, 2);

                        INSERT INTO estimate_lines (
                            clinic_id,
                            estimate_id,
                            treatment_plan_item_id,
                            service_id,
                            line_position,
                            description_snapshot,
                            tooth_snapshot,
                            quantity,
                            unit_price,
                            discount_amount,
                            vat_rate
                        ) VALUES (
                            v_clinic_id,
                            v_estimate_id,
                            v_tpi.treatment_plan_item_id,
                            v_tpi.service_id,
                            v_line_position,
                            v_tpi.service_name || COALESCE(' - dente ' || v_tpi.tooth_number, '') || ' - versione rimodulata',
                            v_tpi.tooth_number,
                            v_tpi.quantity,
                            v_tpi.planned_price,
                            v_discount,
                            v_tpi.planned_vat_rate
                        );
                    END LOOP;
                END IF;
            END LOOP;
        END LOOP;

        -- Alcuni preventivi rapidi non collegati a un piano, per testare treatment_plan_id nullable.
        FOR v_patient_index IN 1..8 LOOP
            SELECT id
            INTO v_patient_id
            FROM patients
            WHERE clinic_id = v_clinic_id
            ORDER BY random()
            LIMIT 1;

            v_estimate_counter := v_estimate_counter + 1;
            INSERT INTO estimates (
                clinic_id,
                patient_id,
                treatment_plan_id,
                estimate_number,
                version,
                status,
                title,
                notes,
                currency,
                issued_at,
                sent_at,
                valid_until
            ) VALUES (
                v_clinic_id,
                v_patient_id,
                NULL,
                v_clinic_prefix || '-RAPIDO-2026-' || lpad(v_patient_index::text, 3, '0'),
                1,
                (ARRAY['draft','sent','accepted']::estimate_status[])[1 + floor(random() * 3)::integer],
                'Preventivo rapido non collegato a piano di cura',
                'Esempio di preventivo libero, utile per testare casi commerciali preliminari.',
                'EUR',
                now() - (floor(random() * 30)::integer || ' days')::interval,
                now() - (floor(random() * 25)::integer || ' days')::interval,
                current_date + 30
            ) RETURNING id INTO v_estimate_id;

            v_line_position := 0;
            FOR v_sc IN
                SELECT id, name, category, default_price, default_vat_rate
                FROM service_catalog
                WHERE clinic_id = v_clinic_id
                  AND code IN ('VIS-001','RX-OPT','IGI-001','EST-001','GNAT-001','URG-001')
                ORDER BY random()
                LIMIT 2 + floor(random() * 3)::integer
            LOOP
                v_line_position := v_line_position + 1;
                INSERT INTO estimate_lines (
                    clinic_id,
                    estimate_id,
                    treatment_plan_item_id,
                    service_id,
                    line_position,
                    description_snapshot,
                    tooth_snapshot,
                    quantity,
                    unit_price,
                    discount_amount,
                    vat_rate
                ) VALUES (
                    v_clinic_id,
                    v_estimate_id,
                    NULL,
                    v_sc.id,
                    v_line_position,
                    v_sc.name || ' - preventivo rapido',
                    NULL,
                    1,
                    v_sc.default_price,
                    CASE WHEN random() < 0.20 THEN round((v_sc.default_price * 0.05)::numeric, 2) ELSE 0 END,
                    v_sc.default_vat_rate
                );
            END LOOP;
        END LOOP;
    END LOOP;
END $$;

COMMIT;

-- Riepilogo dati demo caricati.
SET search_path TO dentalcare, public;

SELECT 'clinics' AS table_name, COUNT(*) AS rows_count FROM clinics WHERE vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'providers', COUNT(*) FROM providers p JOIN clinics c ON c.id = p.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'patients', COUNT(*) FROM patients p JOIN clinics c ON c.id = p.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'service_catalog', COUNT(*) FROM service_catalog s JOIN clinics c ON c.id = s.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'treatment_plans', COUNT(*) FROM treatment_plans tp JOIN clinics c ON c.id = tp.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'treatment_plan_items', COUNT(*) FROM treatment_plan_items tpi JOIN clinics c ON c.id = tpi.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'estimates', COUNT(*) FROM estimates e JOIN clinics c ON c.id = e.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
UNION ALL
SELECT 'estimate_lines', COUNT(*) FROM estimate_lines el JOIN clinics c ON c.id = el.clinic_id WHERE c.vat_number IN ('DEMO-ROMA-001', 'DEMO-MILANO-001')
ORDER BY table_name;
