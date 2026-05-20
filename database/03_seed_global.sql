-- =============================================================================
-- DentalCare Pro - Seed Dati Globali
-- File: 03_seed_global.sql
-- Descrizione: Popola lo schema dentalcare con dati di riferimento globali:
--              stato Italia, regioni, citta' principali, festivi, categorie
--              e voci amnestiche.
-- Idempotente: SI (INSERT ... ON CONFLICT DO NOTHING)
-- =============================================================================

BEGIN;

SET search_path TO dentalcare, public;

-- =============================================================================
-- STATO: Italia
-- =============================================================================

INSERT INTO states (id, code, name)
VALUES ('00000001-0000-0000-0000-000000000001'::uuid, 'IT', 'Italia')
ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- REGIONI ITALIANE (20 regioni con UUID fissi)
-- =============================================================================

INSERT INTO regions (id, state_id, name, code)
VALUES
  ('00000002-0000-0000-0000-000000000001'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Valle d''Aosta',        'VDA'),
  ('00000002-0000-0000-0000-000000000002'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Piemonte',              'PMN'),
  ('00000002-0000-0000-0000-000000000003'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Lombardia',             'LOM'),
  ('00000002-0000-0000-0000-000000000004'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Trentino-Alto Adige',   'TAA'),
  ('00000002-0000-0000-0000-000000000005'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Veneto',                'VEN'),
  ('00000002-0000-0000-0000-000000000006'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Friuli-Venezia Giulia', 'FVG'),
  ('00000002-0000-0000-0000-000000000007'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Liguria',               'LIG'),
  ('00000002-0000-0000-0000-000000000008'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Emilia-Romagna',        'EMR'),
  ('00000002-0000-0000-0000-000000000009'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Toscana',               'TOS'),
  ('00000002-0000-0000-0000-000000000010'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Umbria',                'UMB'),
  ('00000002-0000-0000-0000-000000000011'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Marche',                'MAR'),
  ('00000002-0000-0000-0000-000000000012'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Lazio',                 'LAZ'),
  ('00000002-0000-0000-0000-000000000013'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Abruzzo',               'ABR'),
  ('00000002-0000-0000-0000-000000000014'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Molise',                'MOL'),
  ('00000002-0000-0000-0000-000000000015'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Campania',              'CAM'),
  ('00000002-0000-0000-0000-000000000016'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Puglia',                'PUG'),
  ('00000002-0000-0000-0000-000000000017'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Basilicata',            'BAS'),
  ('00000002-0000-0000-0000-000000000018'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Calabria',              'CAL'),
  ('00000002-0000-0000-0000-000000000019'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Sicilia',               'SIC'),
  ('00000002-0000-0000-0000-000000000020'::uuid, '00000001-0000-0000-0000-000000000001'::uuid, 'Sardegna',              'SAR')
ON CONFLICT (state_id, code) DO NOTHING;

-- =============================================================================
-- CITTA' PRINCIPALI
-- =============================================================================

INSERT INTO cities (id, region_id, name, province_code, postal_code, is_capital)
VALUES
  ('00000003-0000-0000-0000-000000000001'::uuid, '00000002-0000-0000-0000-000000000012'::uuid, 'Roma',    'RM', '00100', true),
  ('00000003-0000-0000-0000-000000000002'::uuid, '00000002-0000-0000-0000-000000000003'::uuid, 'Milano',  'MI', '20100', true),
  ('00000003-0000-0000-0000-000000000003'::uuid, '00000002-0000-0000-0000-000000000015'::uuid, 'Napoli',  'NA', '80100', true),
  ('00000003-0000-0000-0000-000000000004'::uuid, '00000002-0000-0000-0000-000000000016'::uuid, 'Bari',    'BA', '70100', true),
  ('00000003-0000-0000-0000-000000000005'::uuid, '00000002-0000-0000-0000-000000000009'::uuid, 'Firenze', 'FI', '50100', true),
  ('00000003-0000-0000-0000-000000000006'::uuid, '00000002-0000-0000-0000-000000000005'::uuid, 'Venezia', 'VE', '30100', true),
  ('00000003-0000-0000-0000-000000000007'::uuid, '00000002-0000-0000-0000-000000000005'::uuid, 'Verona',  'VR', '37100', false),
  ('00000003-0000-0000-0000-000000000008'::uuid, '00000002-0000-0000-0000-000000000002'::uuid, 'Torino',  'TO', '10100', true),
  ('00000003-0000-0000-0000-000000000009'::uuid, '00000002-0000-0000-0000-000000000007'::uuid, 'Genova',  'GE', '16100', true),
  ('00000003-0000-0000-0000-000000000010'::uuid, '00000002-0000-0000-0000-000000000008'::uuid, 'Bologna', 'BO', '40100', true),
  ('00000003-0000-0000-0000-000000000011'::uuid, '00000002-0000-0000-0000-000000000019'::uuid, 'Palermo', 'PA', '90100', true),
  ('00000003-0000-0000-0000-000000000012'::uuid, '00000002-0000-0000-0000-000000000020'::uuid, 'Cagliari','CA', '09100', true)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- FESTIVI NAZIONALI ITALIANI
-- Festivi fissi: 2025-2036
-- Festivi variabili (Pasqua e Lunedi' dell'Angelo): precalcolati per 2025-2036
-- Date Pasqua calcolate con algoritmo di Gauss (Gregoriano)
-- =============================================================================

-- Festivi fissi (si ripetono ogni anno)
DO $$
DECLARE
    v_state_id uuid := '00000001-0000-0000-0000-000000000001'::uuid;
    v_year     integer;
BEGIN
    FOR v_year IN 2025..2036 LOOP
        INSERT INTO national_holidays (state_id, holiday_date, name, is_recurring, is_fixed)
        VALUES
          (v_state_id, make_date(v_year, 1,  1), 'Capodanno',               false, true),
          (v_state_id, make_date(v_year, 1,  6), 'Epifania',                false, true),
          (v_state_id, make_date(v_year, 4, 25), 'Festa della Liberazione', false, true),
          (v_state_id, make_date(v_year, 5,  1), 'Festa del Lavoro',        false, true),
          (v_state_id, make_date(v_year, 6,  2), 'Festa della Repubblica',  false, true),
          (v_state_id, make_date(v_year, 8, 15), 'Ferragosto',              false, true),
          (v_state_id, make_date(v_year, 11, 1), 'Ognissanti',              false, true),
          (v_state_id, make_date(v_year, 12, 8), 'Immacolata Concezione',   false, true),
          (v_state_id, make_date(v_year, 12,25), 'Natale',                  false, true),
          (v_state_id, make_date(v_year, 12,26), 'Santo Stefano',           false, true)
        ON CONFLICT (state_id, holiday_date) DO NOTHING;
    END LOOP;
END $$;

-- Festivi variabili: Pasqua e Lunedi' dell'Angelo 2025-2036
INSERT INTO national_holidays (state_id, holiday_date, name, is_recurring, is_fixed)
VALUES
  -- 2025
  ('00000001-0000-0000-0000-000000000001'::uuid, '2025-04-20', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2025-04-21', 'Lunedi'' dell''Angelo',   false, false),
  -- 2026
  ('00000001-0000-0000-0000-000000000001'::uuid, '2026-04-05', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2026-04-06', 'Lunedi'' dell''Angelo',   false, false),
  -- 2027
  ('00000001-0000-0000-0000-000000000001'::uuid, '2027-03-28', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2027-03-29', 'Lunedi'' dell''Angelo',   false, false),
  -- 2028
  ('00000001-0000-0000-0000-000000000001'::uuid, '2028-04-16', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2028-04-17', 'Lunedi'' dell''Angelo',   false, false),
  -- 2029
  ('00000001-0000-0000-0000-000000000001'::uuid, '2029-04-01', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2029-04-02', 'Lunedi'' dell''Angelo',   false, false),
  -- 2030
  ('00000001-0000-0000-0000-000000000001'::uuid, '2030-04-21', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2030-04-22', 'Lunedi'' dell''Angelo',   false, false),
  -- 2031
  ('00000001-0000-0000-0000-000000000001'::uuid, '2031-04-13', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2031-04-14', 'Lunedi'' dell''Angelo',   false, false),
  -- 2032
  ('00000001-0000-0000-0000-000000000001'::uuid, '2032-03-28', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2032-03-29', 'Lunedi'' dell''Angelo',   false, false),
  -- 2033
  ('00000001-0000-0000-0000-000000000001'::uuid, '2033-04-17', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2033-04-18', 'Lunedi'' dell''Angelo',   false, false),
  -- 2034
  ('00000001-0000-0000-0000-000000000001'::uuid, '2034-04-09', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2034-04-10', 'Lunedi'' dell''Angelo',   false, false),
  -- 2035
  ('00000001-0000-0000-0000-000000000001'::uuid, '2035-03-25', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2035-03-26', 'Lunedi'' dell''Angelo',   false, false),
  -- 2036
  ('00000001-0000-0000-0000-000000000001'::uuid, '2036-04-13', 'Pasqua',                  false, false),
  ('00000001-0000-0000-0000-000000000001'::uuid, '2036-04-14', 'Lunedi'' dell''Angelo',   false, false)
ON CONFLICT (state_id, holiday_date) DO NOTHING;

-- =============================================================================
-- CATEGORIE AMNESTICHE
-- =============================================================================

INSERT INTO anamnesis_categories (id, name, sort_order)
VALUES
  ('00000010-0000-0000-0000-000000000001'::uuid, 'Malattie Sistemiche',            10),
  ('00000010-0000-0000-0000-000000000002'::uuid, 'Farmaci e Terapie',              20),
  ('00000010-0000-0000-0000-000000000003'::uuid, 'Allergie',                       30),
  ('00000010-0000-0000-0000-000000000004'::uuid, 'Abitudini di Vita',              40),
  ('00000010-0000-0000-0000-000000000005'::uuid, 'Apparato Cardiovascolare',       50),
  ('00000010-0000-0000-0000-000000000006'::uuid, 'Apparato Respiratorio',          60),
  ('00000010-0000-0000-0000-000000000007'::uuid, 'Apparato Gastrointestinale',     70),
  ('00000010-0000-0000-0000-000000000008'::uuid, 'Apparato Endocrino',             80),
  ('00000010-0000-0000-0000-000000000009'::uuid, 'Gravidanza e Ginecologia',       90),
  ('00000010-0000-0000-0000-000000000010'::uuid, 'Stato Psicologico',             100)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- VOCI AMNESTICHE
-- Formato code: CAT_NN dove CAT = prefisso categoria, NN = numero progressivo
-- =============================================================================

INSERT INTO anamnesis_items (id, category_id, code, label, description, has_detail, sort_order)
VALUES

  -- Malattie Sistemiche (SIS_)
  ('00000011-0000-0000-0000-000000000001'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_01', 'Ipertensione arteriosa', 'Pressione sistolica cronicamente elevata', false, 10),
  ('00000011-0000-0000-0000-000000000002'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_02', 'Diabete di tipo 1', 'Diabete mellito insulino-dipendente', true, 20),
  ('00000011-0000-0000-0000-000000000003'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_03', 'Diabete di tipo 2', 'Diabete mellito non insulino-dipendente', true, 30),
  ('00000011-0000-0000-0000-000000000004'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_04', 'Cardiopatia', 'Malattia cardiaca di qualsiasi tipo', true, 40),
  ('00000011-0000-0000-0000-000000000005'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_05', 'Epatite B/C', 'Epatite virale cronica B o C', false, 50),
  ('00000011-0000-0000-0000-000000000006'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_06', 'HIV / AIDS', 'Sieropositivo o malattia conclamata', false, 60),
  ('00000011-0000-0000-0000-000000000007'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_07', 'Osteoporosi', 'Riduzione della densita'' ossea', false, 70),
  ('00000011-0000-0000-0000-000000000008'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_08', 'Epilessia', 'Disturbo epilettico diagnosticato', true, 80),
  ('00000011-0000-0000-0000-000000000009'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_09', 'Insufficienza renale', 'IRC o dialisi', true, 90),
  ('00000011-0000-0000-0000-000000000010'::uuid, '00000010-0000-0000-0000-000000000001'::uuid,
   'SIS_10', 'Asma bronchiale', 'Asma diagnosticata o in terapia', false, 100),

  -- Farmaci e Terapie (FAR_)
  ('00000011-0000-0000-0000-000000000011'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_01', 'Anticoagulanti orali', 'Warfarin, NAO (rivaroxaban, apixaban)', true, 10),
  ('00000011-0000-0000-0000-000000000012'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_02', 'Antiaggreganti piastrinici', 'Aspirina, clopidogrel, ticagrelor', true, 20),
  ('00000011-0000-0000-0000-000000000013'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_03', 'Bifosfonati', 'Alendronato, zoledronato e simili', true, 30),
  ('00000011-0000-0000-0000-000000000014'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_04', 'Cortisonici', 'Steroidi sistemici (prednisone, desametasone)', true, 40),
  ('00000011-0000-0000-0000-000000000015'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_05', 'Immunosoppressori', 'Ciclosporina, azatioprina, metotrexato', true, 50),
  ('00000011-0000-0000-0000-000000000016'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_06', 'Antipertensivi', 'ACE-inibitori, sartani, beta-bloccanti', true, 60),
  ('00000011-0000-0000-0000-000000000017'::uuid, '00000010-0000-0000-0000-000000000002'::uuid,
   'FAR_07', 'Insulina', 'Terapia insulinica per diabete', true, 70),

  -- Allergie (ALL_)
  ('00000011-0000-0000-0000-000000000021'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_01', 'Penicillina / Amoxicillina', 'Allergia ad antibiotici betalattamici', false, 10),
  ('00000011-0000-0000-0000-000000000022'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_02', 'Lattice', 'Allergia al lattice (guanti, presidi)', false, 20),
  ('00000011-0000-0000-0000-000000000023'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_03', 'Anestetici locali', 'Lidocaina, articaina e simili', false, 30),
  ('00000011-0000-0000-0000-000000000024'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_04', 'Aspirina / FANS', 'Ibuprofene, diclofenac, ketoprofene', false, 40),
  ('00000011-0000-0000-0000-000000000025'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_05', 'Nichel', 'Allergia al nichel (metalli per protesi)', false, 50),
  ('00000011-0000-0000-0000-000000000026'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_06', 'Metalli dentali', 'Allergia a oro, palladio, amalgama', true, 60),
  ('00000011-0000-0000-0000-000000000027'::uuid, '00000010-0000-0000-0000-000000000003'::uuid,
   'ALL_07', 'Acrilici', 'Allergia a resine acriliche (protesi rimovibili)', false, 70),

  -- Abitudini di Vita (ABT_)
  ('00000011-0000-0000-0000-000000000031'::uuid, '00000010-0000-0000-0000-000000000004'::uuid,
   'ABT_01', 'Fumatore attivo', 'Fumo di sigaretta o sigaro', true, 10),
  ('00000011-0000-0000-0000-000000000032'::uuid, '00000010-0000-0000-0000-000000000004'::uuid,
   'ABT_02', 'Ex fumatore', 'Ha smesso di fumare', true, 20),
  ('00000011-0000-0000-0000-000000000033'::uuid, '00000010-0000-0000-0000-000000000004'::uuid,
   'ABT_03', 'Consumo regolare di alcolici', 'Piu'' di 2 unita'' alcoliche/giorno', false, 30),
  ('00000011-0000-0000-0000-000000000034'::uuid, '00000010-0000-0000-0000-000000000004'::uuid,
   'ABT_04', 'Bruxismo', 'Digrignamento notturno o diurno', false, 40),
  ('00000011-0000-0000-0000-000000000035'::uuid, '00000010-0000-0000-0000-000000000004'::uuid,
   'ABT_05', 'Sportivo agonista', 'Sport agonistici con rischio trauma', false, 50),

  -- Apparato Cardiovascolare (CAR_)
  ('00000011-0000-0000-0000-000000000041'::uuid, '00000010-0000-0000-0000-000000000005'::uuid,
   'CAR_01', 'Pacemaker / ICD', 'Portatore di pacemaker o defibrillatore', false, 10),
  ('00000011-0000-0000-0000-000000000042'::uuid, '00000010-0000-0000-0000-000000000005'::uuid,
   'CAR_02', 'Protesi valvolare cardiaca', 'Valvola meccanica o biologica', false, 20),
  ('00000011-0000-0000-0000-000000000043'::uuid, '00000010-0000-0000-0000-000000000005'::uuid,
   'CAR_03', 'Infarto pregresso', 'Episodio infartuale nella storia clinica', true, 30),
  ('00000011-0000-0000-0000-000000000044'::uuid, '00000010-0000-0000-0000-000000000005'::uuid,
   'CAR_04', 'Angina pectoris', 'Angina stabile o instabile', false, 40),
  ('00000011-0000-0000-0000-000000000045'::uuid, '00000010-0000-0000-0000-000000000005'::uuid,
   'CAR_05', 'Insufficienza cardiaca', 'Scompenso cardiaco congestizio', true, 50),

  -- Apparato Respiratorio (RES_)
  ('00000011-0000-0000-0000-000000000051'::uuid, '00000010-0000-0000-0000-000000000006'::uuid,
   'RES_01', 'Asma bronchiale', 'In terapia con broncodilatatori', true, 10),
  ('00000011-0000-0000-0000-000000000052'::uuid, '00000010-0000-0000-0000-000000000006'::uuid,
   'RES_02', 'BPCO', 'Broncopneumopatia cronica ostruttiva', false, 20),
  ('00000011-0000-0000-0000-000000000053'::uuid, '00000010-0000-0000-0000-000000000006'::uuid,
   'RES_03', 'Apnee notturne', 'OSAS con o senza CPAP', false, 30),

  -- Apparato Gastrointestinale (GAS_)
  ('00000011-0000-0000-0000-000000000061'::uuid, '00000010-0000-0000-0000-000000000007'::uuid,
   'GAS_01', 'Reflusso gastroesofageo', 'GERD in terapia o sintomatico', false, 10),
  ('00000011-0000-0000-0000-000000000062'::uuid, '00000010-0000-0000-0000-000000000007'::uuid,
   'GAS_02', 'Ulcera peptica', 'Ulcera gastrica o duodenale', false, 20),
  ('00000011-0000-0000-0000-000000000063'::uuid, '00000010-0000-0000-0000-000000000007'::uuid,
   'GAS_03', 'Morbo di Crohn', 'Malattia infiammatoria intestinale', false, 30),

  -- Apparato Endocrino (END_)
  ('00000011-0000-0000-0000-000000000071'::uuid, '00000010-0000-0000-0000-000000000008'::uuid,
   'END_01', 'Ipotiroidismo', 'Tiroidite cronica o ipotiroidismo idiopatico', false, 10),
  ('00000011-0000-0000-0000-000000000072'::uuid, '00000010-0000-0000-0000-000000000008'::uuid,
   'END_02', 'Ipertiroidismo', 'Morbo di Basedow o adenoma tossico', false, 20),
  ('00000011-0000-0000-0000-000000000073'::uuid, '00000010-0000-0000-0000-000000000008'::uuid,
   'END_03', 'Sindrome di Cushing', 'Ipercortisolismo endogeno o iatrogeno', false, 30),

  -- Gravidanza e Ginecologia (GRA_)
  ('00000011-0000-0000-0000-000000000081'::uuid, '00000010-0000-0000-0000-000000000009'::uuid,
   'GRA_01', 'Gravidanza in corso', 'Specificare trimestre', true, 10),
  ('00000011-0000-0000-0000-000000000082'::uuid, '00000010-0000-0000-0000-000000000009'::uuid,
   'GRA_02', 'Allattamento', 'Periodo di allattamento al seno', false, 20),

  -- Stato Psicologico (PSI_)
  ('00000011-0000-0000-0000-000000000091'::uuid, '00000010-0000-0000-0000-000000000010'::uuid,
   'PSI_01', 'Ansia da studio dentistico', 'Ansia clinicamente significativa', false, 10),
  ('00000011-0000-0000-0000-000000000092'::uuid, '00000010-0000-0000-0000-000000000010'::uuid,
   'PSI_02', 'Fobia degli aghi', 'Belonefobia / fobia iniezioni', false, 20),
  ('00000011-0000-0000-0000-000000000093'::uuid, '00000010-0000-0000-0000-000000000010'::uuid,
   'PSI_03', 'Claustrofobia', 'Difficolta'' con bocca aperta / dentale chiuso', false, 30)

ON CONFLICT (code) DO NOTHING;

-- =============================================================================
-- VERIFICA
-- =============================================================================

SELECT
    'states'             AS tabella, COUNT(*)::text AS righe FROM states
UNION ALL SELECT
    'regions',                       COUNT(*)::text FROM regions
UNION ALL SELECT
    'cities',                        COUNT(*)::text FROM cities
UNION ALL SELECT
    'national_holidays',             COUNT(*)::text FROM national_holidays
UNION ALL SELECT
    'anamnesis_categories',          COUNT(*)::text FROM anamnesis_categories
UNION ALL SELECT
    'anamnesis_items',               COUNT(*)::text FROM anamnesis_items
ORDER BY tabella;

COMMIT;
