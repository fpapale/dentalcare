-- DentalCare - Seed categorie e voci amnestiche + paziente Papale Fabrizio
-- Prerequisiti: dentalcare_schema.sql + dentalcare_clinical_extension.sql + dentalcare_anamnesis_structured.sql
-- Rieseguibile: usa INSERT ... ON CONFLICT DO NOTHING per le tabelle globali.
-- Uso:
--   psql -d dentalcarepro -f dentalcare_anamnesis_categories_seed.sql

BEGIN;

SET search_path TO dentalcare, public;

-- =========================================================
-- CATEGORIE AMNESTICHE
-- =========================================================

INSERT INTO anamnesis_categories (id, code, name, description, icon, sort_order, enabled) VALUES
    ('a1000000-0000-0000-0000-000000000001', 'ALLERGIE',       'Allergie & Reazioni',           'Allergie a farmaci, materiali e sostanze', 'warning',          10, true),
    ('a1000000-0000-0000-0000-000000000002', 'FARMACI',        'Farmaci in Uso',                 'Terapie farmacologiche in corso',          'medication',       20, true),
    ('a1000000-0000-0000-0000-000000000003', 'PATOLOGIE',      'Patologie Sistemiche',           'Malattie sistemiche e condizioni croniche', 'favorite',        30, true),
    ('a1000000-0000-0000-0000-000000000004', 'CHIRURGIA',      'Interventi Chirurgici',          'Anamnesi chirurgica pregressa',             'healing',         40, true),
    ('a1000000-0000-0000-0000-000000000005', 'ABITUDINI',      'Abitudini Viziate',              'Fumo, alcol e abitudini para-funzionali',   'smoking_rooms',   50, true),
    ('a1000000-0000-0000-0000-000000000006', 'COND_ORALI',     'Condizioni Odontoiatriche',      'Sintomi e condizioni del cavo orale',       'dentistry',       60, true),
    ('a1000000-0000-0000-0000-000000000007', 'SINTOMI',        'Sintomi Attuali',                'Motivo della visita e sintomi in corso',    'personal_injury', 70, true),
    ('a1000000-0000-0000-0000-000000000008', 'ORMONI',         'Gravidanza & Stato Ormonale',    'Gravidanza, allattamento, terapia ormonale','pregnant_woman',  80, true)
ON CONFLICT (code) DO NOTHING;

-- =========================================================
-- VOCI AMNESTICHE
-- =========================================================

-- ALLERGIE
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0001-000000000001', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_PENICILLINA',  'Allergia a Penicillina / Amoxicillina', 'Include tutte le betalattamine', true,  10, true),
    ('b1000000-0000-0000-0001-000000000002', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_ANESTETICI',   'Allergia agli Anestetici Locali',       'Articaina, mepivacaina, lidocaina', true, 20, true),
    ('b1000000-0000-0000-0001-000000000003', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_LATEX',        'Allergia al Lattice',                   NULL,                               true, 30, true),
    ('b1000000-0000-0000-0001-000000000004', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_ASPIRINA',     'Allergia ad Aspirina / FANS',           NULL,                               true, 40, true),
    ('b1000000-0000-0000-0001-000000000005', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_SULFAMIDICI',  'Allergia ai Sulfamidici',               NULL,                               false,50, true),
    ('b1000000-0000-0000-0001-000000000006', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_NICKEL',       'Allergia al Nickel',                    NULL,                               false,60, true),
    ('b1000000-0000-0000-0001-000000000007', 'a1000000-0000-0000-0000-000000000001', 'ALLERG_METACRILATO',  'Allergia al Metacrilato',               'Materiali da restauro / protesi',  false,70, true)
ON CONFLICT (code) DO NOTHING;

-- FARMACI
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0002-000000000001', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_ANTICOAG',     'Anticoagulanti (TAO, EBPM, NAO)',    'Warfarin, Eparina, Dabigatran, Rivaroxaban', true, 10, true),
    ('b1000000-0000-0000-0002-000000000002', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_ANTIAGG',      'Antiaggreganti (Aspirina, Clopidogrel)', NULL,                              true, 20, true),
    ('b1000000-0000-0000-0002-000000000003', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_BISFOSFONATI', 'Bifosfonati (Alendronato, Zolendronato)', 'Rischio ONJ - ONM',              true, 30, true),
    ('b1000000-0000-0000-0002-000000000004', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_ANTIDIABT',    'Antidiabetici / Insulina',           NULL,                                 false,40, true),
    ('b1000000-0000-0000-0002-000000000005', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_ANTIIPERT',    'Antiipertensivi',                    NULL,                                 false,50, true),
    ('b1000000-0000-0000-0002-000000000006', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_CORTISONICI',  'Cortisonici Sistemici',              NULL,                                 true, 60, true),
    ('b1000000-0000-0000-0002-000000000007', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_IMMUNOSOPP',   'Immunosoppressori',                  NULL,                                 true, 70, true),
    ('b1000000-0000-0000-0002-000000000008', 'a1000000-0000-0000-0000-000000000002', 'FARMACI_ALTRI',        'Altra terapia farmacologica in corso', NULL,                               false,80, true)
ON CONFLICT (code) DO NOTHING;

-- PATOLOGIE SISTEMICHE
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0003-000000000001', 'a1000000-0000-0000-0000-000000000003', 'PAT_IPERTENSIONE',  'Ipertensione Arteriosa',               NULL, false,10, true),
    ('b1000000-0000-0000-0003-000000000002', 'a1000000-0000-0000-0000-000000000003', 'PAT_CARDIOPATIA',   'Cardiopatia / Patologie Cardiache',    'Valvole, pace-maker, infarto pregresso', true, 20, true),
    ('b1000000-0000-0000-0003-000000000003', 'a1000000-0000-0000-0000-000000000003', 'PAT_DIABETE',       'Diabete Mellito',                      NULL, false,30, true),
    ('b1000000-0000-0000-0003-000000000004', 'a1000000-0000-0000-0000-000000000003', 'PAT_ASMA',          'Asma Bronchiale / BPCO',               NULL, false,40, true),
    ('b1000000-0000-0000-0003-000000000005', 'a1000000-0000-0000-0000-000000000003', 'PAT_EPATOPATIA',    'Epatopatia (Epatite, Cirrosi)',         NULL, true, 50, true),
    ('b1000000-0000-0000-0003-000000000006', 'a1000000-0000-0000-0000-000000000003', 'PAT_NEFROPATIA',    'Nefropatia / Insufficienza Renale',     NULL, true, 60, true),
    ('b1000000-0000-0000-0003-000000000007', 'a1000000-0000-0000-0000-000000000003', 'PAT_EPILESSIA',     'Epilessia',                             NULL, true, 70, true),
    ('b1000000-0000-0000-0003-000000000008', 'a1000000-0000-0000-0000-000000000003', 'PAT_OSTEOPOROSI',   'Osteoporosi',                           NULL, false,80, true),
    ('b1000000-0000-0000-0003-000000000009', 'a1000000-0000-0000-0000-000000000003', 'PAT_COAGULOP',      'Disturbi della Coagulazione',           NULL, true, 90, true),
    ('b1000000-0000-0000-0003-000000000010', 'a1000000-0000-0000-0000-000000000003', 'PAT_IMMUNODEF',     'Immunodeficienza (HIV, terapie oncologiche)', NULL, true,100, true),
    ('b1000000-0000-0000-0003-000000000011', 'a1000000-0000-0000-0000-000000000003', 'PAT_ONCOLOGICA',    'Patologia Oncologica in trattamento',   NULL, true,110, true),
    ('b1000000-0000-0000-0003-000000000012', 'a1000000-0000-0000-0000-000000000003', 'PAT_TIROIDEA',      'Patologia Tiroidea',                    NULL, false,120, true),
    ('b1000000-0000-0000-0003-000000000013', 'a1000000-0000-0000-0000-000000000003', 'PAT_REFLUSSO',      'Reflusso Gastroesofageo',               NULL, false,130, true)
ON CONFLICT (code) DO NOTHING;

-- CHIRURGIA
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0004-000000000001', 'a1000000-0000-0000-0000-000000000004', 'CHIR_CARDIOCH',    'Cardiochirurgia / Valvole Cardiache',     'Profilassi antibiotica richiesta', true, 10, true),
    ('b1000000-0000-0000-0004-000000000002', 'a1000000-0000-0000-0000-000000000004', 'CHIR_ENDOPROT',    'Protesi Articolari (Anca, Ginocchio)',    NULL,                               true, 20, true),
    ('b1000000-0000-0000-0004-000000000003', 'a1000000-0000-0000-0000-000000000004', 'CHIR_BYPASS',      'Bypass / Angioplastica',                  NULL,                               true, 30, true),
    ('b1000000-0000-0000-0004-000000000004', 'a1000000-0000-0000-0000-000000000004', 'CHIR_TRAPIANTO',   'Trapianto d''Organo',                     NULL,                               true, 40, true),
    ('b1000000-0000-0000-0004-000000000005', 'a1000000-0000-0000-0000-000000000004', 'CHIR_ALTRO',       'Altri Interventi Chirurgici',             NULL,                               false,50, true)
ON CONFLICT (code) DO NOTHING;

-- ABITUDINI VIZIATE
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0005-000000000001', 'a1000000-0000-0000-0000-000000000005', 'ABT_FUMO',         'Fumatore',                 NULL, false,10, true),
    ('b1000000-0000-0000-0005-000000000002', 'a1000000-0000-0000-0000-000000000005', 'ABT_ALCOL',        'Consumo Alcolici',         NULL, false,20, true),
    ('b1000000-0000-0000-0005-000000000003', 'a1000000-0000-0000-0000-000000000005', 'ABT_DROGHE',       'Uso di Sostanze',          NULL, true, 30, true),
    ('b1000000-0000-0000-0005-000000000004', 'a1000000-0000-0000-0000-000000000005', 'ABT_BRUXISMO',     'Bruxismo / Digrignamento', NULL, false,40, true),
    ('b1000000-0000-0000-0005-000000000005', 'a1000000-0000-0000-0000-000000000005', 'ABT_ONICOFAGIA',   'Onicofagia / Morsicatura Labbra', NULL, false,50, true),
    ('b1000000-0000-0000-0005-000000000006', 'a1000000-0000-0000-0000-000000000005', 'ABT_PIERCING',     'Piercing Orale',           NULL, false,60, true)
ON CONFLICT (code) DO NOTHING;

-- CONDIZIONI ODONTOIATRICHE
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0006-000000000001', 'a1000000-0000-0000-0000-000000000006', 'COND_SENSIB',      'Sensibilità Dentinale',           NULL, false,10, true),
    ('b1000000-0000-0000-0006-000000000002', 'a1000000-0000-0000-0000-000000000006', 'COND_SANGU',       'Sanguinamento Gengivale',         NULL, false,20, true),
    ('b1000000-0000-0000-0006-000000000003', 'a1000000-0000-0000-0000-000000000006', 'COND_MOBIL',       'Mobilità Dentale',                NULL, false,30, true),
    ('b1000000-0000-0000-0006-000000000004', 'a1000000-0000-0000-0000-000000000006', 'COND_ALITOSI',     'Alitosi',                         NULL, false,40, true),
    ('b1000000-0000-0000-0006-000000000005', 'a1000000-0000-0000-0000-000000000006', 'COND_APNEA',       'Apnea Notturna / Russamento',     NULL, false,50, true),
    ('b1000000-0000-0000-0006-000000000006', 'a1000000-0000-0000-0000-000000000006', 'COND_ATM',         'Problemi ATM / Dolore Masticatorio', NULL, false,60, true),
    ('b1000000-0000-0000-0006-000000000007', 'a1000000-0000-0000-0000-000000000006', 'COND_XEROSTOMIA',  'Secchezza Orale (Xerostomia)',    NULL, false,70, true),
    ('b1000000-0000-0000-0006-000000000008', 'a1000000-0000-0000-0000-000000000006', 'COND_AFTE',        'Afte Ricorrenti',                 NULL, false,80, true)
ON CONFLICT (code) DO NOTHING;

-- SINTOMI ATTUALI
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0007-000000000001', 'a1000000-0000-0000-0000-000000000007', 'SINT_DOLORE',      'Dolore Dentale',                     NULL, false,10, true),
    ('b1000000-0000-0000-0007-000000000002', 'a1000000-0000-0000-0000-000000000007', 'SINT_GONFIORE',    'Gonfiore / Tumefazione',             NULL, true, 20, true),
    ('b1000000-0000-0000-0007-000000000003', 'a1000000-0000-0000-0000-000000000007', 'SINT_FRATTURA',    'Dente Rotto / Fratturato',           NULL, false,30, true),
    ('b1000000-0000-0000-0007-000000000004', 'a1000000-0000-0000-0000-000000000007', 'SINT_CADUTA',      'Perdita di Otturazione / Corona',    NULL, false,40, true),
    ('b1000000-0000-0000-0007-000000000005', 'a1000000-0000-0000-0000-000000000007', 'SINT_SENSIB_TERM', 'Sensibilità al Caldo / Freddo',      NULL, false,50, true),
    ('b1000000-0000-0000-0007-000000000006', 'a1000000-0000-0000-0000-000000000007', 'SINT_URGENZA',     'Urgenza Odontogena',                 NULL, true, 60, true)
ON CONFLICT (code) DO NOTHING;

-- GRAVIDANZA & ORMONI
INSERT INTO anamnesis_items (id, category_id, code, label, description, is_alert, sort_order, enabled) VALUES
    ('b1000000-0000-0000-0008-000000000001', 'a1000000-0000-0000-0000-000000000008', 'GRAV_GRAVIDANZA',  'Gravidanza in Corso',        'Indicare il trimestre nelle note', true, 10, true),
    ('b1000000-0000-0000-0008-000000000002', 'a1000000-0000-0000-0000-000000000008', 'GRAV_ALLATTAMENTO','Allattamento',                NULL,                               true, 20, true),
    ('b1000000-0000-0000-0008-000000000003', 'a1000000-0000-0000-0000-000000000008', 'GRAV_ORMONI',      'Terapia Ormonale (Pillola, HRT)', NULL,                            false,30, true)
ON CONFLICT (code) DO NOTHING;

-- =========================================================
-- PAZIENTE PAPALE FABRIZIO (demo Roma)
-- =========================================================

DO $$
DECLARE
    v_clinic_id   uuid;
    v_patient_id  uuid := 'f4b21000-0000-0000-0000-000000000001';
    v_provider_id uuid;
BEGIN
    SELECT id INTO v_clinic_id
    FROM clinics
    WHERE vat_number = 'DEMO-ROMA-001'
    LIMIT 1;

    IF v_clinic_id IS NULL THEN
        RAISE NOTICE 'Clinic DEMO-ROMA-001 not found. Skipping Papale Fabrizio insert.';
        RETURN;
    END IF;

    -- Rimuove il paziente demo se già presente per garantire idempotenza
    DELETE FROM patients WHERE id = v_patient_id AND clinic_id = v_clinic_id;

    INSERT INTO patients (
        id, clinic_id, first_name, last_name, fiscal_code, birth_date,
        phone, email, address_line1, city, province, postal_code, country, notes
    ) VALUES (
        v_patient_id,
        v_clinic_id,
        'Fabrizio',
        'Papale',
        'PPLFBR78D15H501Z',
        '1978-04-15',
        '+39 339 1234567',
        'fabrizio.papale@gmail.com',
        'Via Tiburtina 288',
        'Roma',
        'RM',
        '00159',
        'IT',
        'Paziente collaborante. Iperteso in terapia. Fumatore.'
    );

    -- Inserisce l''anamnesi base (tabella legacy)
    SELECT id INTO v_provider_id
    FROM providers
    WHERE clinic_id = v_clinic_id AND role = 'dentist' AND active = true
    ORDER BY last_name
    LIMIT 1;

    INSERT INTO patient_anamnesis (
        clinic_id, patient_id, recorded_by_provider_id,
        blood_type, smoker, cigarettes_per_day, alcohol_use,
        hypertension, diabetes, heart_disease,
        taking_anticoagulants, taking_bisphosphonates,
        allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin,
        other_allergies, general_notes, is_current
    ) VALUES (
        v_clinic_id, v_patient_id, v_provider_id,
        'A+', true, 10, false,
        true, false, false,
        false, false,
        true, false, true, false,
        NULL,
        'Allergia accertata a Penicillina (reazione 2019, orticaria diffusa). Allergia ad anestetici locali tipo amide (testata): usare articaina con adrenalina a bassa concentrazione con cautela. Iperteso in trattamento con Ramipril + Aspirina 100mg.',
        true
    );

    -- =========================================================
    -- SELEZIONI STRUTTURATE PER PAPALE FABRIZIO
    -- =========================================================

    -- Rimuove selezioni precedenti per idempotenza
    DELETE FROM patient_anamnesis_item_selections
    WHERE clinic_id = v_clinic_id AND patient_id = v_patient_id;

    INSERT INTO patient_anamnesis_item_selections
        (clinic_id, patient_id, item_id, notes)
    VALUES
        -- ALLERGIE
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0001-000000000001', 'Reazione 2019: orticaria diffusa. Evitare betalattamine.'),
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0001-000000000002', 'Sensibilità agli amidi. Usare articaina 4% con adrenalina 1:200.000 con cautela.'),
        -- FARMACI
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0002-000000000002', 'Aspirina 100mg/die (antiaggregante). Non sospendere prima di interventi minori.'),
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0002-000000000005', 'Ramipril 5mg/die per ipertensione.'),
        -- PATOLOGIE
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0003-000000000001', 'Ipertensione arteriosa in trattamento farmacologico. PA media 135/85.'),
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0003-000000000013', 'Reflusso gastroesofageo: assume omeprazolo 20mg occasionalmente.'),
        -- ABITUDINI
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0005-000000000001', '10 sigarette/die da circa 15 anni.'),
        -- CONDIZIONI ODONTOIATRICHE
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0006-000000000001', 'Sensibilità al freddo settore posteriore inferiore dx.'),
        (v_clinic_id, v_patient_id, 'b1000000-0000-0000-0006-000000000002', 'Sanguinamento alla spazzolatura, soprattutto settore anteriore superiore.');

    RAISE NOTICE 'Papale Fabrizio inserito con clinic_id=%', v_clinic_id;
END $$;

COMMIT;
