-- =============================================================================
-- DentalCare Pro - Seed Tenant Demo
-- File: 04_seed_demo_tenant.sql
-- Descrizione: Popola il tenant demo t_9d754153 con dati realistici.
--              Gli appuntamenti usano CURRENT_DATE per restare sempre freschi.
--
-- Prerequisiti:
--   - 01_schema_applicative.sql applicato
--   - 02_schema_tenant.sql applicato con tenant_schema=t_9d754153
--   - 03_seed_global.sql applicato
--
-- Idempotente: Cancella e ricrea i dati demo identificati da UUID fissi.
-- Uso: psql -U postgres -d dentalcarepro -f 04_seed_demo_tenant.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- PARTE 1: Registra tenant nella tabella globale
-- =============================================================================

SET search_path TO dentalcare, public;

INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active)
VALUES (
    'a0000001-0000-0000-0000-000000000001'::uuid,
    'Clinica Demo DentalCare',
    't_9d754153',
    'demo@dentalcare.it',
    '+39 06 5550100',
    'base',
    true
)
ON CONFLICT (id) DO UPDATE SET active = true, name = EXCLUDED.name;

-- Crea lo schema tenant se non esiste (idempotente)
DO $$ BEGIN
    EXECUTE 'CREATE SCHEMA IF NOT EXISTS t_9d754153';
END $$;

-- =============================================================================
-- PARTE 2: Dati operativi nel tenant schema
-- =============================================================================

SET search_path TO t_9d754153, dentalcare, public;

-- Cancella dati demo precedenti in ordine sicuro (FK)
DELETE FROM ai_conversations        WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM recall_contacts         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_recalls         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM stock_movements         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM condition_service_defaults WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM service_bundle_items    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_documents       WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM clinical_history_entries WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM tooth_conditions        WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM odontogram_teeth        WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_anamnesis_item_selections
    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_anamnesis       WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM estimate_lines          WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM estimates               WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM appointments            WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM treatment_plan_items    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM treatment_plans         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM products                WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM product_categories      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM suppliers               WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM service_catalog         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patients                WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM providers               WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM clinics                 WHERE id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;

DELETE FROM dentalcare.tenant_clinics
    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;

-- =============================================================================
-- CLINICA DEMO
-- Colonne allineate al live DB: no email, timezone, opening_time, etc.
-- =============================================================================

INSERT INTO clinics (id, name, legal_name, vat_number, fiscal_code, phone,
    address_line1, city, province, postal_code, country)
VALUES (
    '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid,
    'Clinica Demo DentalCare Roma',
    'DentalCare Roma S.r.l.',
    'DEMO-ROMA-001',
    'DEMOROMA001',
    '+39 06 5550101',
    'Via Nomentana 123',
    'Roma', 'RM', '00162', 'IT'
);

INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id)
VALUES (
    '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid,
    'a0000001-0000-0000-0000-000000000001'::uuid
)
ON CONFLICT (clinic_id) DO NOTHING;

-- =============================================================================
-- DATI DEMO (all within a single DO block for variable sharing)
-- =============================================================================

DO $$
DECLARE
    v_clinic uuid := '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;

    -- Provider IDs
    v_pr0 uuid := 'a0000001-0000-0000-0000-000000000010'::uuid; -- Admin Demo (tenant_admin)
    v_pr0a uuid := 'a0000001-0000-0000-0000-000000000011'::uuid; -- Admin Demo (admin clinica)
    v_pr1 uuid := 'b1000001-0000-0000-0000-000000000001'::uuid; -- Ferretti Laura (dentist)
    v_pr2 uuid := 'b1000001-0000-0000-0000-000000000002'::uuid; -- Marchetti Paolo (surgeon)
    v_pr3 uuid := 'b1000001-0000-0000-0000-000000000003'::uuid; -- Amato Serena (orthodontist)
    v_pr4 uuid := 'b1000001-0000-0000-0000-000000000004'::uuid; -- Gentili Michele (hygienist)

    -- Patient IDs (p01..p20)
    v_p01 uuid := 'c1000001-0000-0000-0000-000000000001'::uuid;
    v_p02 uuid := 'c1000001-0000-0000-0000-000000000002'::uuid;
    v_p03 uuid := 'c1000001-0000-0000-0000-000000000003'::uuid;
    v_p04 uuid := 'c1000001-0000-0000-0000-000000000004'::uuid;
    v_p05 uuid := 'c1000001-0000-0000-0000-000000000005'::uuid;
    v_p06 uuid := 'c1000001-0000-0000-0000-000000000006'::uuid;
    v_p07 uuid := 'c1000001-0000-0000-0000-000000000007'::uuid;
    v_p08 uuid := 'c1000001-0000-0000-0000-000000000008'::uuid;
    v_p09 uuid := 'c1000001-0000-0000-0000-000000000009'::uuid;
    v_p10 uuid := 'c1000001-0000-0000-0000-000000000010'::uuid;
    v_p11 uuid := 'c1000001-0000-0000-0000-000000000011'::uuid;
    v_p12 uuid := 'c1000001-0000-0000-0000-000000000012'::uuid;
    v_p13 uuid := 'c1000001-0000-0000-0000-000000000013'::uuid;
    v_p14 uuid := 'c1000001-0000-0000-0000-000000000014'::uuid;
    v_p15 uuid := 'c1000001-0000-0000-0000-000000000015'::uuid;
    v_p16 uuid := 'c1000001-0000-0000-0000-000000000016'::uuid;
    v_p17 uuid := 'c1000001-0000-0000-0000-000000000017'::uuid;
    v_p18 uuid := 'c1000001-0000-0000-0000-000000000018'::uuid;
    v_p19 uuid := 'c1000001-0000-0000-0000-000000000019'::uuid;
    v_p20 uuid := 'c1000001-0000-0000-0000-000000000020'::uuid;

    -- Service catalog IDs
    v_s01 uuid := 'd1000001-0000-0000-0000-000000000001'::uuid; -- Igiene orale professionale
    v_s02 uuid := 'd1000001-0000-0000-0000-000000000002'::uuid; -- Igiene orale profonda
    v_s03 uuid := 'd1000001-0000-0000-0000-000000000003'::uuid; -- Fluoroprofilassi
    v_s04 uuid := 'd1000001-0000-0000-0000-000000000004'::uuid; -- Radiografia endorale
    v_s05 uuid := 'd1000001-0000-0000-0000-000000000005'::uuid; -- Ortopantomografia
    v_s06 uuid := 'd1000001-0000-0000-0000-000000000006'::uuid; -- CBCT arcata singola
    v_s07 uuid := 'd1000001-0000-0000-0000-000000000007'::uuid; -- Otturazione composito monofacciale
    v_s08 uuid := 'd1000001-0000-0000-0000-000000000008'::uuid; -- Otturazione composito bifacciale
    v_s09 uuid := 'd1000001-0000-0000-0000-000000000009'::uuid; -- Otturazione composito trifacciale
    v_s10 uuid := 'd1000001-0000-0000-0000-000000000010'::uuid; -- Devitalizzazione monoradicolare
    v_s11 uuid := 'd1000001-0000-0000-0000-000000000011'::uuid; -- Devitalizzazione biradicolare
    v_s12 uuid := 'd1000001-0000-0000-0000-000000000012'::uuid; -- Devitalizzazione pluriradicolare
    v_s13 uuid := 'd1000001-0000-0000-0000-000000000013'::uuid; -- Ritrattamento canalare
    v_s14 uuid := 'd1000001-0000-0000-0000-000000000014'::uuid; -- Corona in zirconia
    v_s15 uuid := 'd1000001-0000-0000-0000-000000000015'::uuid; -- Faccetta in ceramica
    v_s16 uuid := 'd1000001-0000-0000-0000-000000000016'::uuid; -- Impianto osteointegrato
    v_s17 uuid := 'd1000001-0000-0000-0000-000000000017'::uuid; -- Moncone implantare
    v_s18 uuid := 'd1000001-0000-0000-0000-000000000018'::uuid; -- Estrazione semplice
    v_s19 uuid := 'd1000001-0000-0000-0000-000000000019'::uuid; -- Estrazione complessa
    v_s20 uuid := 'd1000001-0000-0000-0000-000000000020'::uuid; -- Levigatura radicolare per quadrante
    v_s21 uuid := 'd1000001-0000-0000-0000-000000000021'::uuid; -- Terapia parodontale di mantenimento
    v_s22 uuid := 'd1000001-0000-0000-0000-000000000022'::uuid; -- Apparecchio mobile rimovibile
    v_s23 uuid := 'd1000001-0000-0000-0000-000000000023'::uuid; -- Apparecchio fisso multibrackets
    v_s24 uuid := 'd1000001-0000-0000-0000-000000000024'::uuid; -- Sbiancamento professionale
    v_s25 uuid := 'd1000001-0000-0000-0000-000000000025'::uuid; -- Rimozione punti di sutura

    -- Treatment plan IDs
    v_tp1 uuid := 'e1000001-0000-0000-0000-000000000001'::uuid;
    v_tp2 uuid := 'e1000001-0000-0000-0000-000000000002'::uuid;
    v_tp3 uuid := 'e1000001-0000-0000-0000-000000000003'::uuid;
    v_tp4 uuid := 'e1000001-0000-0000-0000-000000000004'::uuid;
    v_tp5 uuid := 'e1000001-0000-0000-0000-000000000005'::uuid;

    -- Treatment plan item IDs
    v_tpi1  uuid := 'f1000001-0000-0000-0000-000000000001'::uuid;
    v_tpi2  uuid := 'f1000001-0000-0000-0000-000000000002'::uuid;
    v_tpi3  uuid := 'f1000001-0000-0000-0000-000000000003'::uuid;
    v_tpi4  uuid := 'f1000001-0000-0000-0000-000000000004'::uuid;
    v_tpi5  uuid := 'f1000001-0000-0000-0000-000000000005'::uuid;
    v_tpi6  uuid := 'f1000001-0000-0000-0000-000000000006'::uuid;
    v_tpi7  uuid := 'f1000001-0000-0000-0000-000000000007'::uuid;
    v_tpi8  uuid := 'f1000001-0000-0000-0000-000000000008'::uuid;

    -- Estimate IDs
    v_est1 uuid := 'a2000001-0000-0000-0000-000000000001'::uuid;
    v_est2 uuid := 'a2000001-0000-0000-0000-000000000002'::uuid;
    v_est3 uuid := 'a2000001-0000-0000-0000-000000000003'::uuid;
    v_est4 uuid := 'a2000001-0000-0000-0000-000000000004'::uuid;

    -- Supplier / product category IDs
    v_sup1 uuid := 'a3000001-0000-0000-0000-000000000001'::uuid;
    v_sup2 uuid := 'a3000001-0000-0000-0000-000000000002'::uuid;
    v_cat1 uuid := 'a4000001-0000-0000-0000-000000000001'::uuid;
    v_cat2 uuid := 'a4000001-0000-0000-0000-000000000002'::uuid;
    v_cat3 uuid := 'a4000001-0000-0000-0000-000000000003'::uuid;
    v_cat4 uuid := 'a4000001-0000-0000-0000-000000000004'::uuid;
    v_cat5 uuid := 'a4000001-0000-0000-0000-000000000005'::uuid;
    v_cat6 uuid := 'a4000001-0000-0000-0000-000000000006'::uuid;

BEGIN

    -- =========================================================================
    -- PROVIDERS
    -- Live DB columns: id, clinic_id, first_name, last_name, role, phone, active,
    --   vat_number, fiscal_code, professional_register, register_number,
    --   billing_address_street, billing_address_zip, billing_address_city,
    --   billing_address_province, billing_pec, billing_iban, billing_sdi_code,
    --   invoice_prefix, photo_url
    -- =========================================================================

    INSERT INTO providers (id, clinic_id, first_name, last_name, email, password_hash, role, phone, active)
    VALUES
      (v_pr0,  v_clinic, 'Admin',   'Demo', 'admin@demo.dentalcare.it',
       '$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O',
       CAST('tenant_admin' AS dentalcare.provider_role), NULL, true),
      (v_pr0a, v_clinic, 'Admin',   'Demo', 'admin@demo.dentalcare.it',
       '$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O',
       CAST('admin' AS dentalcare.provider_role), NULL, true),
      (v_pr1, v_clinic, 'Laura',   'Ferretti',  NULL, NULL, CAST('dentist'      AS dentalcare.provider_role), '+39 334 1001001', true),
      (v_pr2, v_clinic, 'Paolo',   'Marchetti', NULL, NULL, CAST('surgeon'      AS dentalcare.provider_role), '+39 334 1001002', true),
      (v_pr3, v_clinic, 'Serena',  'Amato',     NULL, NULL, CAST('orthodontist' AS dentalcare.provider_role), '+39 334 1001003', true),
      (v_pr4, v_clinic, 'Michele', 'Gentili',   NULL, NULL, CAST('hygienist'    AS dentalcare.provider_role), '+39 334 1001004', true);

    -- =========================================================================
    -- PATIENTS (20 pazienti con nomi italiani realistici)
    -- Live DB columns: id, clinic_id, first_name, last_name, fiscal_code,
    --   birth_date, phone, address_line1, address_line2, city, province,
    --   postal_code, country, notes, photo_url
    -- NOTE: no email, gender, active in live DB
    -- =========================================================================

    INSERT INTO patients (id, clinic_id, first_name, last_name, fiscal_code,
        birth_date, phone, city, province, postal_code)
    VALUES
      (v_p01, v_clinic, 'Marco',     'Rossi',      'RSSMRC85A01H501X', '1985-01-01', '+39 348 1110001', 'Roma',    'RM', '00100'),
      (v_p02, v_clinic, 'Giulia',    'Bianchi',    'BNCGLI90B41H501Y', '1990-02-28', '+39 348 1110002', 'Roma',    'RM', '00144'),
      (v_p03, v_clinic, 'Luca',      'Romano',     'RMNLCU78C03H501Z', '1978-03-15', '+39 348 1110003', 'Roma',    'RM', '00162'),
      (v_p04, v_clinic, 'Chiara',    'Colombo',    'CLMCHR92D44H501W', '1992-04-10', '+39 348 1110004', 'Milano',  'MI', '20100'),
      (v_p05, v_clinic, 'Andrea',    'Ricci',      'RCCNDR80E05H501V', '1980-05-22', '+39 348 1110005', 'Roma',    'RM', '00185'),
      (v_p06, v_clinic, 'Valentina', 'Marino',     'MRNVNT88F46H501U', '1988-06-05', '+39 348 1110006', 'Napoli',  'NA', '80100'),
      (v_p07, v_clinic, 'Stefano',   'Greco',      'GRCSFN75G07H501T', '1975-07-18', '+39 348 1110007', 'Roma',    'RM', '00136'),
      (v_p08, v_clinic, 'Francesca', 'Bruno',      'BRNFNC95H48H501S', '1995-08-30', '+39 348 1110008', 'Roma',    'RM', '00167'),
      (v_p09, v_clinic, 'Matteo',    'Gallo',      'GLLMTT82I09H501R', '1982-09-12', '+39 348 1110009', 'Firenze', 'FI', '50100'),
      (v_p10, v_clinic, 'Silvia',    'Conti',      'CNTSLV91L50H501Q', '1991-11-25', '+39 348 1110010', 'Roma',    'RM', '00192'),
      (v_p11, v_clinic, 'Roberto',   'De Luca',    'DLCRBT68A11H501P', '1968-01-20', '+39 348 1110011', 'Roma',    'RM', '00118'),
      (v_p12, v_clinic, 'Elena',     'Mancini',    'MNCLNE86B52H501N', '1986-02-14', '+39 348 1110012', 'Roma',    'RM', '00176'),
      (v_p13, v_clinic, 'Daniele',   'Costa',      'CSTDNL79C13H501M', '1979-03-08', '+39 348 1110013', 'Torino',  'TO', '10100'),
      (v_p14, v_clinic, 'Martina',   'Giordano',   'GRDMTN93D54H501L', '1993-04-02', '+39 348 1110014', 'Roma',    'RM', '00154'),
      (v_p15, v_clinic, 'Paolo',     'Rizzo',      'RZZPLA70E15H501K', '1970-05-16', '+39 348 1110015', 'Roma',    'RM', '00122'),
      (v_p16, v_clinic, 'Alessia',   'Lombardi',   'LMBLSS97F56H501J', '1997-06-28', '+39 348 1110016', 'Roma',    'RM', '00145'),
      (v_p17, v_clinic, 'Giovanni',  'Moretti',    'MRTGNN65G17H501I', '1965-07-04', '+39 348 1110017', 'Bologna', 'BO', '40100'),
      (v_p18, v_clinic, 'Sara',      'Barbieri',   'BRBSRA89H58H501H', '1989-08-19', '+39 348 1110018', 'Roma',    'RM', '00159'),
      (v_p19, v_clinic, 'Nicola',    'Fontana',    'FNTNCL83I19H501G', '1983-09-11', '+39 348 1110019', 'Roma',    'RM', '00173'),
      (v_p20, v_clinic, 'Beatrice',  'Santoro',    'SNTBRC96L60H501F', '1996-12-03', '+39 348 1110020', 'Roma',    'RM', '00141');

    -- =========================================================================
    -- SERVICE CATALOG (25 prestazioni in 8 categorie)
    -- Live DB columns: id, clinic_id, code, name, category, description,
    --   default_price, default_vat_rate, active, duration_minutes,
    --   min_tooth_digit, max_tooth_digit, applicable_to_deciduous
    -- NOTE: no 'price' or 'is_active' — uses default_price and active
    -- =========================================================================

    INSERT INTO service_catalog (id, clinic_id, code, name, category, default_price,
        duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, active)
    VALUES
      -- Igiene
      (v_s01, v_clinic, 'IGI-01', 'Igiene orale professionale',       'Igiene',        80.00,  45, NULL, NULL, true,  true),
      (v_s02, v_clinic, 'IGI-02', 'Igiene orale profonda',            'Igiene',       120.00,  60, NULL, NULL, true,  true),
      (v_s03, v_clinic, 'IGI-03', 'Fluoroprofilassi',                  'Igiene',        30.00,  15, NULL, NULL, true,  true),
      -- Diagnostica
      (v_s04, v_clinic, 'DIA-01', 'Radiografia endorale',             'Diagnostica',   25.00,  10, NULL, NULL, true,  true),
      (v_s05, v_clinic, 'DIA-02', 'Ortopantomografia',                'Diagnostica',   80.00,  15, NULL, NULL, true,  true),
      (v_s06, v_clinic, 'DIA-03', 'CBCT arcata singola',              'Diagnostica',  180.00,  20, NULL, NULL, false, true),
      -- Conservativa
      (v_s07, v_clinic, 'CON-01', 'Otturazione composito monofacciale','Conservativa',  90.00,  45, NULL, NULL, true,  true),
      (v_s08, v_clinic, 'CON-02', 'Otturazione composito bifacciale', 'Conservativa', 130.00,  60, NULL, NULL, true,  true),
      (v_s09, v_clinic, 'CON-03', 'Otturazione composito trifacciale','Conservativa', 160.00,  75, NULL, NULL, true,  true),
      -- Endodonzia
      (v_s10, v_clinic, 'END-01', 'Devitalizzazione monoradicolare',  'Endodonzia',   280.00,  90, 1,    5,    true,  true),
      (v_s11, v_clinic, 'END-02', 'Devitalizzazione biradicolare',    'Endodonzia',   380.00, 120, 4,    6,    false, true),
      (v_s12, v_clinic, 'END-03', 'Devitalizzazione pluriradicolare', 'Endodonzia',   480.00, 150, 6,    8,    false, true),
      (v_s13, v_clinic, 'END-04', 'Ritrattamento canalare',           'Endodonzia',   380.00, 120, NULL, NULL, false, true),
      -- Protesi
      (v_s14, v_clinic, 'PRO-01', 'Corona in zirconia',               'Protesi',      650.00,  60, NULL, NULL, false, true),
      (v_s15, v_clinic, 'PRO-02', 'Faccetta in ceramica',             'Protesi',      550.00,  90, 1,    3,    false, true),
      -- Implantologia
      (v_s16, v_clinic, 'IMP-01', 'Impianto osteointegrato',          'Implantologia',1200.00, 90, NULL, NULL, false, true),
      (v_s17, v_clinic, 'IMP-02', 'Moncone implantare',               'Implantologia', 350.00, 45, NULL, NULL, false, true),
      -- Chirurgia
      (v_s18, v_clinic, 'CHI-01', 'Estrazione semplice',              'Chirurgia',    100.00,  30, NULL, NULL, true,  true),
      (v_s19, v_clinic, 'CHI-02', 'Estrazione complessa',             'Chirurgia',    200.00,  60, NULL, NULL, false, true),
      (v_s25, v_clinic, 'CHI-03', 'Rimozione punti di sutura',        'Chirurgia',     30.00,  15, NULL, NULL, true,  true),
      -- Parodontologia
      (v_s20, v_clinic, 'PAR-01', 'Levigatura radicolare per quadrante','Parodontologia',180.00, 60, NULL, NULL, false, true),
      (v_s21, v_clinic, 'PAR-02', 'Terapia parodontale di mantenimento','Parodontologia', 80.00, 45, NULL, NULL, false, true),
      -- Ortodonzia
      (v_s22, v_clinic, 'ORT-01', 'Apparecchio mobile rimovibile',    'Ortodonzia',   450.00,  60, NULL, NULL, true,  true),
      (v_s23, v_clinic, 'ORT-02', 'Apparecchio fisso multibrackets',  'Ortodonzia',  2800.00,  90, NULL, NULL, false, true),
      -- Estetica
      (v_s24, v_clinic, 'EST-01', 'Sbiancamento professionale',       'Estetica',     250.00,  60, NULL, NULL, false, true);

    -- =========================================================================
    -- SERVICE BUNDLE ITEMS
    -- Live DB columns: id, clinic_id, parent_service_id, child_service_id, sort_order
    -- =========================================================================

    INSERT INTO service_bundle_items (id, clinic_id, parent_service_id, child_service_id, sort_order)
    VALUES
      (gen_random_uuid(), v_clinic, v_s18, v_s25, 10),  -- Estrazione semplice -> Rimozione punti
      (gen_random_uuid(), v_clinic, v_s19, v_s25, 10),  -- Estrazione complessa -> Rimozione punti
      (gen_random_uuid(), v_clinic, v_s10, v_s04, 10),  -- Devit. mono -> RX endorale
      (gen_random_uuid(), v_clinic, v_s10, v_s07, 20),  -- Devit. mono -> Otturazione mono
      (gen_random_uuid(), v_clinic, v_s11, v_s04, 10),  -- Devit. bi -> RX endorale
      (gen_random_uuid(), v_clinic, v_s12, v_s04, 10),  -- Devit. pluri -> RX endorale
      (gen_random_uuid(), v_clinic, v_s16, v_s06, 10),  -- Impianto -> CBCT
      (gen_random_uuid(), v_clinic, v_s16, v_s17, 20),  -- Impianto -> Moncone
      (gen_random_uuid(), v_clinic, v_s16, v_s14, 30),  -- Impianto -> Corona su impianto
      (gen_random_uuid(), v_clinic, v_s02, v_s03, 10);  -- Igiene profonda -> Fluoroprofilassi

    -- =========================================================================
    -- CONDITION SERVICE DEFAULTS
    -- Live DB columns: id, clinic_id, condition_name, service_id, sort_order
    -- =========================================================================

    INSERT INTO condition_service_defaults (id, clinic_id, condition_name, service_id, sort_order)
    VALUES
      (gen_random_uuid(), v_clinic, 'caries',      v_s07, 10),
      (gen_random_uuid(), v_clinic, 'caries',      v_s04, 20),
      (gen_random_uuid(), v_clinic, 'to_extract',  v_s18, 10),
      (gen_random_uuid(), v_clinic, 'to_extract',  v_s25, 20),
      (gen_random_uuid(), v_clinic, 'devitalized', v_s13, 10),
      (gen_random_uuid(), v_clinic, 'devitalized', v_s04, 20),
      (gen_random_uuid(), v_clinic, 'missing',     v_s06, 10),
      (gen_random_uuid(), v_clinic, 'missing',     v_s16, 20),
      (gen_random_uuid(), v_clinic, 'missing',     v_s17, 30),
      (gen_random_uuid(), v_clinic, 'missing',     v_s14, 40),
      (gen_random_uuid(), v_clinic, 'crown',       v_s14, 10),
      (gen_random_uuid(), v_clinic, 'fracture',    v_s08, 10),
      (gen_random_uuid(), v_clinic, 'fracture',    v_s04, 20);

    -- =========================================================================
    -- TREATMENT PLANS
    -- Live DB columns: id, clinic_id, patient_id, name, description, status,
    --   created_by_provider_id, proposed_at, accepted_at, completed_at, rejected_at
    -- NOTE: no 'title', 'version', 'provider_id' directly; 'name' not 'title'
    -- =========================================================================

    INSERT INTO treatment_plans (id, clinic_id, patient_id, created_by_provider_id, name, status)
    VALUES
      (v_tp1, v_clinic, v_p01, v_pr1, 'Piano carie multiple - Rossi Marco',    'in_progress'),
      (v_tp2, v_clinic, v_p03, v_pr2, 'Implantologia - Romano Luca',            'accepted'),
      (v_tp3, v_clinic, v_p05, v_pr1, 'Conservativa e igiene - Ricci Andrea',   'proposed'),
      (v_tp4, v_clinic, v_p07, v_pr3, 'Ortodonzia adulti - Greco Stefano',      'in_progress'),
      (v_tp5, v_clinic, v_p02, v_pr1, 'Sbiancamento e faccette - Bianchi Giulia','draft');

    -- =========================================================================
    -- TREATMENT PLAN ITEMS
    -- Live DB columns: id, clinic_id, treatment_plan_id, service_id, provider_id,
    --   tooth_number, quadrant, surfaces, quantity, planned_price, planned_vat_rate,
    --   clinical_notes, status, priority, planned_date, completed_at
    -- NOTE: no 'plan_id', 'service_catalog_id', 'tooth_fdi', 'description', 'price', 'sort_order'
    -- =========================================================================

    INSERT INTO treatment_plan_items (id, clinic_id, treatment_plan_id, service_id,
        tooth_number, surfaces, planned_price, status, priority, completed_at)
    VALUES
      -- Piano 1: Rossi Marco - carie multiple
      (v_tpi1, v_clinic, v_tp1, v_s04, '16',  NULL,           25.00,   'completed', 10,
       (CURRENT_DATE - INTERVAL '10 days')::timestamptz + TIME '10:00'),
      (v_tpi2, v_clinic, v_tp1, v_s08, '16',  ARRAY['O','D'], 130.00,  'completed', 20,
       (CURRENT_DATE - INTERVAL '10 days')::timestamptz + TIME '10:30'),
      (v_tpi3, v_clinic, v_tp1, v_s07, '14',  ARRAY['O'],     90.00,   'scheduled', 30, NULL),
      (v_tpi4, v_clinic, v_tp1, v_s01, NULL,  NULL,           80.00,   'planned',   40, NULL),

      -- Piano 2: Romano Luca - impianto
      (v_tpi5, v_clinic, v_tp2, v_s06, '36',  NULL,           180.00,  'completed', 10,
       (CURRENT_DATE - INTERVAL '20 days')::timestamptz + TIME '09:00'),
      (v_tpi6, v_clinic, v_tp2, v_s16, '36',  NULL,           1200.00, 'scheduled', 20, NULL),

      -- Piano 4: Greco Stefano - ortodonzia
      (v_tpi7, v_clinic, v_tp4, v_s23, NULL,  NULL,           2800.00, 'accepted',  10, NULL),

      -- Piano 3: Ricci Andrea
      (v_tpi8, v_clinic, v_tp3, v_s01, NULL,  NULL,           80.00,   'planned',   10, NULL);

    -- =========================================================================
    -- ESTIMATES
    -- Live DB columns: id, clinic_id, patient_id, treatment_plan_id, estimate_number,
    --   version, status, title, notes, currency, subtotal_amount, discount_amount,
    --   taxable_amount, vat_amount, total_amount, issued_at, sent_at, valid_until,
    --   accepted_at, rejected_at, created_by_provider_id
    -- NOTE: old script used subtotal/discount_total/total — now subtotal_amount/discount_amount/total_amount
    -- =========================================================================

    INSERT INTO estimates (id, clinic_id, patient_id, created_by_provider_id, treatment_plan_id,
        estimate_number, version, status, title, notes, valid_until,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency)
    VALUES
      (v_est1, v_clinic, v_p01, v_pr1, v_tp1,
       'PRE-2024-0001', 1, 'accepted', 'Preventivo piano carie - Rossi Marco',
       'Sconto 10% applicato su totale',
       CURRENT_DATE + 30,
       325.00, 32.50, 292.50, 0.00, 292.50, 'EUR'),

      (v_est2, v_clinic, v_p03, v_pr2, v_tp2,
       'PRE-2024-0002', 1, 'sent', 'Preventivo implantologia - Romano Luca',
       'Include CBCT, impianto, moncone, corona',
       CURRENT_DATE + 45,
       1730.00, 0.00, 1730.00, 0.00, 1730.00, 'EUR'),

      (v_est3, v_clinic, v_p05, v_pr1, v_tp3,
       'PRE-2024-0003', 1, 'draft', 'Bozza preventivo igiene e conservativa - Ricci Andrea',
       NULL,
       NULL,
       80.00, 0.00, 80.00, 0.00, 80.00, 'EUR'),

      (v_est4, v_clinic, v_p02, v_pr1, v_tp5,
       'PRE-2024-0004', 1, 'draft', 'Preventivo estetica - Bianchi Giulia',
       'In fase di valutazione',
       CURRENT_DATE + 60,
       1350.00, 0.00, 1350.00, 0.00, 1350.00, 'EUR');

    -- =========================================================================
    -- ESTIMATE LINES
    -- Live DB columns: id, clinic_id, estimate_id, treatment_plan_item_id, service_id,
    --   line_position, description_snapshot, tooth_snapshot, quantity, unit_price,
    --   discount_amount, vat_rate (GENERATED: line_subtotal, line_taxable, line_vat_amount, line_total)
    -- NOTE: old script used description/tooth_fdi/discount_pct/line_total/position
    --       now: description_snapshot/tooth_snapshot/discount_amount(fixed)/line_position
    --       line_total is GENERATED — do NOT insert it
    -- =========================================================================

    -- Righe preventivo 1 (Rossi - accettato, sconto 10% come valore assoluto)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est1, v_clinic, v_tpi1, v_s04, 'Radiografia endorale 16',              '16',  1, 25.00,   0.00, 0, 1),
      (v_est1, v_clinic, v_tpi2, v_s08, 'Otturazione composito bifacciale 16',  '16',  1, 130.00, 13.00, 0, 2),
      (v_est1, v_clinic, v_tpi3, v_s07, 'Otturazione composito monofacciale 14','14',  1, 90.00,   9.00, 0, 3),
      (v_est1, v_clinic, v_tpi4, v_s01, 'Igiene professionale',                 NULL,  1, 80.00,   8.00, 0, 4);

    -- Righe preventivo 2 (Romano - inviato)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est2, v_clinic, v_tpi5, v_s06, 'CBCT arcata inferiore',       '36', 1, 180.00,  0.00, 0, 1),
      (v_est2, v_clinic, v_tpi6, v_s16, 'Impianto osteointegrato 36',  '36', 1, 1200.00, 0.00, 0, 2),
      (v_est2, v_clinic, NULL,   v_s17, 'Moncone implantare',           '36', 1, 350.00,  0.00, 0, 3);

    -- Riga preventivo 3 (Ricci - bozza)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est3, v_clinic, v_tpi8, v_s01, 'Igiene orale professionale', 1, 80.00, 0.00, 0, 1);

    -- Righe preventivo 4 (Bianchi - estetica)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est4, v_clinic, NULL, v_s24, 'Sbiancamento professionale',         1, 250.00,  0.00, 0, 1),
      (v_est4, v_clinic, NULL, v_s15, 'Faccette in ceramica 11-12-21-22',   4, 550.00,  0.00, 0, 2);

    -- =========================================================================
    -- APPOINTMENTS
    -- Live DB columns: id, clinic_id, patient_id, provider_id,
    --   treatment_plan_item_id, chair_label, starts_at, ends_at, status,
    --   notes, cancellation_reason
    -- NOTE: patient_id and provider_id are NOT NULL in live DB
    -- =========================================================================

    -- 7 giorni fa
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p09, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE - 7 + TIME '09:00', CURRENT_DATE - 7 + TIME '09:45', 'completed',
       'Igiene professionale eseguita'),
      (gen_random_uuid(), v_clinic, v_p11, v_pr2, NULL, 'Poltrona 2',
       CURRENT_DATE - 7 + TIME '10:00', CURRENT_DATE - 7 + TIME '11:00', 'completed',
       'Estrazione 48 eseguita senza complicazioni'),
      (gen_random_uuid(), v_clinic, v_p13, v_pr4, NULL, 'Poltrona 3',
       CURRENT_DATE - 7 + TIME '11:00', CURRENT_DATE - 7 + TIME '11:45', 'no_show',
       'Paziente non presentato - da ricontattare'),
      (gen_random_uuid(), v_clinic, v_p15, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE - 7 + TIME '15:00', CURRENT_DATE - 7 + TIME '15:45', 'completed',
       'Otturazione composito eseguita'),
      (gen_random_uuid(), v_clinic, v_p17, v_pr3, NULL, 'Poltrona 2',
       CURRENT_DATE - 7 + TIME '16:00', CURRENT_DATE - 7 + TIME '17:00', 'completed',
       'Controllo ortodonzia - archwire sostituito');

    -- 3 giorni fa
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p01, v_pr1, v_tpi2, 'Poltrona 1',
       CURRENT_DATE - 3 + TIME '09:30', CURRENT_DATE - 3 + TIME '10:30', 'completed',
       'Otturazione 16 completata con successo'),
      (gen_random_uuid(), v_clinic, v_p03, v_pr2, v_tpi5, 'Poltrona 2',
       CURRENT_DATE - 3 + TIME '10:00', CURRENT_DATE - 3 + TIME '10:30', 'completed',
       'CBCT eseguita - risultato nella documentazione'),
      (gen_random_uuid(), v_clinic, v_p06, v_pr4, NULL, 'Poltrona 3',
       CURRENT_DATE - 3 + TIME '14:30', CURRENT_DATE - 3 + TIME '15:15', 'completed',
       'Prima igiene - molto tartaro'),
      (gen_random_uuid(), v_clinic, v_p19, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE - 3 + TIME '16:00', CURRENT_DATE - 3 + TIME '16:45', 'cancelled',
       'Annullato per impegno paziente');

    -- Ieri
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p04, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE - 1 + TIME '08:30', CURRENT_DATE - 1 + TIME '09:15', 'completed',
       'Visita di controllo - programmata igiene'),
      (gen_random_uuid(), v_clinic, v_p07, v_pr3, v_tpi7, 'Poltrona 2',
       CURRENT_DATE - 1 + TIME '10:00', CURRENT_DATE - 1 + TIME '11:00', 'completed',
       'Controllo mensile ortodonzia'),
      (gen_random_uuid(), v_clinic, v_p12, v_pr4, NULL, 'Poltrona 3',
       CURRENT_DATE - 1 + TIME '11:30', CURRENT_DATE - 1 + TIME '12:15', 'completed',
       'Igiene profonda quadrante sup. sinistro'),
      (gen_random_uuid(), v_clinic, v_p14, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE - 1 + TIME '15:00', CURRENT_DATE - 1 + TIME '15:30', 'completed',
       'Radiografia di controllo post-otturazione'),
      (gen_random_uuid(), v_clinic, v_p16, v_pr2, NULL, 'Poltrona 2',
       CURRENT_DATE - 1 + TIME '16:00', CURRENT_DATE - 1 + TIME '17:00', 'completed',
       'Visita chirurgica pre-impianto 46');

    -- Oggi: mattina completed, pomeriggio confirmed
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p02, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + TIME '08:30', CURRENT_DATE + TIME '09:15', 'completed',
       'Visita estetica - raccolta impronte'),
      (gen_random_uuid(), v_clinic, v_p05, v_pr4, v_tpi8, 'Poltrona 2',
       CURRENT_DATE + TIME '09:00', CURRENT_DATE + TIME '09:45', 'completed',
       'Igiene professionale eseguita'),
      (gen_random_uuid(), v_clinic, v_p08, v_pr2, NULL, 'Poltrona 3',
       CURRENT_DATE + TIME '09:30', CURRENT_DATE + TIME '10:30', 'completed',
       'Estrazione 18 - paziente sotto anestesia locale'),
      (gen_random_uuid(), v_clinic, v_p10, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + TIME '10:00', CURRENT_DATE + TIME '10:45', 'completed',
       'Otturazione 25 - composito'),
      (gen_random_uuid(), v_clinic, v_p01, v_pr1, v_tpi3, 'Poltrona 1',
       CURRENT_DATE + TIME '11:00', CURRENT_DATE + TIME '11:45', 'in_progress',
       'Otturazione 14 - in corso'),
      (gen_random_uuid(), v_clinic, v_p03, v_pr2, v_tpi6, 'Poltrona 2',
       CURRENT_DATE + TIME '14:30', CURRENT_DATE + TIME '16:00', 'confirmed',
       'Inserimento impianto 36 - procedura chirurgica'),
      (gen_random_uuid(), v_clinic, v_p11, v_pr4, NULL, 'Poltrona 3',
       CURRENT_DATE + TIME '15:00', CURRENT_DATE + TIME '15:45', 'confirmed',
       'Igiene semestrale'),
      (gen_random_uuid(), v_clinic, v_p18, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + TIME '16:00', CURRENT_DATE + TIME '16:30', 'confirmed',
       'Prima visita - dolore dente 26'),
      (gen_random_uuid(), v_clinic, v_p20, v_pr3, NULL, 'Poltrona 2',
       CURRENT_DATE + TIME '17:00', CURRENT_DATE + TIME '18:00', 'confirmed',
       'Visita ortodontica per valutazione trattamento');

    -- Domani
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p06, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + 1 + TIME '09:00', CURRENT_DATE + 1 + TIME '10:00', 'scheduled',
       'Devitalizzazione 26 - prima seduta'),
      (gen_random_uuid(), v_clinic, v_p09, v_pr4, NULL, 'Poltrona 2',
       CURRENT_DATE + 1 + TIME '10:00', CURRENT_DATE + 1 + TIME '10:45', 'scheduled',
       'Igiene professionale semestrale'),
      (gen_random_uuid(), v_clinic, v_p13, v_pr2, NULL, 'Poltrona 3',
       CURRENT_DATE + 1 + TIME '14:30', CURRENT_DATE + 1 + TIME '16:00', 'scheduled',
       'Estrazione 38 incluso - riprenotato dopo no-show'),
      (gen_random_uuid(), v_clinic, v_p15, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + 1 + TIME '15:30', CURRENT_DATE + 1 + TIME '16:30', 'scheduled',
       'Otturazione 37 bifacciale');

    -- +2 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p07, v_pr3, v_tpi7, 'Poltrona 1',
       CURRENT_DATE + 2 + TIME '09:00', CURRENT_DATE + 2 + TIME '10:00', 'scheduled',
       'Controllo mensile apparecchio fisso'),
      (gen_random_uuid(), v_clinic, v_p14, v_pr1, NULL, 'Poltrona 2',
       CURRENT_DATE + 2 + TIME '10:30', CURRENT_DATE + 2 + TIME '11:15', 'scheduled',
       'Otturazione 35 monofacciale'),
      (gen_random_uuid(), v_clinic, v_p17, v_pr2, NULL, 'Poltrona 3',
       CURRENT_DATE + 2 + TIME '15:00', CURRENT_DATE + 2 + TIME '16:00', 'scheduled',
       'Chirurgia parodontale quadrante inf. destro');

    -- +5 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p04, v_pr4, NULL, 'Poltrona 1',
       CURRENT_DATE + 5 + TIME '09:30', CURRENT_DATE + 5 + TIME '10:15', 'scheduled',
       'Igiene professionale'),
      (gen_random_uuid(), v_clinic, v_p16, v_pr2, NULL, 'Poltrona 2',
       CURRENT_DATE + 5 + TIME '14:00', CURRENT_DATE + 5 + TIME '15:30', 'scheduled',
       'Inserimento impianto 46'),
      (gen_random_uuid(), v_clinic, v_p20, v_pr3, NULL, 'Poltrona 3',
       CURRENT_DATE + 5 + TIME '16:00', CURRENT_DATE + 5 + TIME '17:00', 'scheduled',
       'Prima valutazione ortodontica e foto intraorali');

    -- +7 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p19, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + 7 + TIME '10:00', CURRENT_DATE + 7 + TIME '11:00', 'scheduled',
       'Otturazione 46 trifacciale'),
      (gen_random_uuid(), v_clinic, v_p12, v_pr4, NULL, 'Poltrona 2',
       CURRENT_DATE + 7 + TIME '11:00', CURRENT_DATE + 7 + TIME '11:45', 'scheduled',
       'Igiene profonda completamento');

    -- +14 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p01, v_pr1, v_tpi4, 'Poltrona 1',
       CURRENT_DATE + 14 + TIME '09:00', CURRENT_DATE + 14 + TIME '09:45', 'scheduled',
       'Igiene di mantenimento - completamento piano cura'),
      (gen_random_uuid(), v_clinic, v_p03, v_pr2, NULL, 'Poltrona 2',
       CURRENT_DATE + 14 + TIME '10:00', CURRENT_DATE + 14 + TIME '10:30', 'scheduled',
       'Controllo post-chirurgia impianto 36');

    -- =========================================================================
    -- ANAMNESI (primi 10 pazienti)
    -- Live DB columns: id, clinic_id, patient_id, recorded_at, recorded_by_provider_id,
    --   blood_type, smoker, cigarettes_per_day, alcohol_use, drug_use,
    --   hypertension, diabetes, diabetes_type, heart_disease, coagulopathy,
    --   immunodeficiency, osteoporosis, thyroid_disease, epilepsy, hepatitis,
    --   hiv_positive, tumor_history, autoimmune_disease, other_diseases,
    --   taking_anticoagulants, taking_bisphosphonates, taking_cortisone, current_medications,
    --   allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin, other_allergies,
    --   bruxism, mouth_breathing, nail_biting, pacifier_use, general_notes,
    --   signed_at, signature_notes, is_current
    -- NOTE: no pacemaker, pregnancy, asthma, kidney_disease in live DB
    -- =========================================================================

    INSERT INTO patient_anamnesis (id, clinic_id, patient_id, recorded_by_provider_id,
        blood_type, smoker, hypertension, diabetes, heart_disease,
        taking_anticoagulants, taking_bisphosphonates,
        allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin, other_allergies,
        is_current, recorded_at)
    VALUES
      (gen_random_uuid(), v_clinic, v_p01, v_pr1,
       'A+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 365),
      (gen_random_uuid(), v_clinic, v_p02, v_pr1,
       'B+', false, false, false, false, false, false,
       true, false, false, false, NULL, true, CURRENT_DATE - 180),
      (gen_random_uuid(), v_clinic, v_p03, v_pr2,
       '0+', false, true, false, false, true, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 90),
      (gen_random_uuid(), v_clinic, v_p04, v_pr1,
       'AB-', false, false, false, false, false, false,
       false, false, true, false, NULL, true, CURRENT_DATE - 200),
      (gen_random_uuid(), v_clinic, v_p05, v_pr1,
       'A-', true, false, false, false, false, false,
       false, false, false, true, 'Ibuprofene', true, CURRENT_DATE - 150),
      (gen_random_uuid(), v_clinic, v_p06, v_pr4,
       '0-', false, false, true, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 45),
      (gen_random_uuid(), v_clinic, v_p07, v_pr3,
       'A+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 300),
      (gen_random_uuid(), v_clinic, v_p08, v_pr2,
       'B-', false, false, false, true, false, true,
       false, false, false, false, NULL, true, CURRENT_DATE - 30),
      (gen_random_uuid(), v_clinic, v_p09, v_pr4,
       '0+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 400),
      (gen_random_uuid(), v_clinic, v_p10, v_pr1,
       'AB+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 60);

    -- =========================================================================
    -- ODONTOGRAMMA
    -- Live DB columns: id, clinic_id, patient_id, tooth_number, quadrant,
    --   is_deciduous, condition, surfaces, bridge_group_id, implant_ref,
    --   notes, recorded_at, recorded_by_provider_id
    -- NOTE: uses 'tooth_number' not 'tooth_fdi'; needs 'quadrant' (NOT NULL)
    -- =========================================================================

    INSERT INTO odontogram_teeth (clinic_id, patient_id, tooth_number, quadrant, condition, surfaces, notes,
        recorded_by_provider_id, recorded_at)
    VALUES
      -- Rossi Marco (p01) - carie e otturazioni (quadrant derived from FDI tooth number)
      (v_clinic, v_p01, '16', 1, 'filling',     ARRAY['O','D'],   'Otturazione composito recente', v_pr1, CURRENT_DATE - 3),
      (v_clinic, v_p01, '14', 1, 'caries',      ARRAY['O'],       'Carie intercuspale iniziale',   v_pr1, CURRENT_DATE - 3),
      (v_clinic, v_p01, '36', 3, 'healthy',     NULL,             NULL,                            v_pr1, CURRENT_DATE - 365),
      (v_clinic, v_p01, '46', 4, 'filling',     ARRAY['O'],       'Otturazione amalgama vecchia',  v_pr1, CURRENT_DATE - 365),

      -- Romano Luca (p03) - impianto in pianificazione
      (v_clinic, v_p03, '36', 3, 'missing',     NULL,             'Sito implantare - impianto pianificato', v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '37', 3, 'healthy',     NULL,             NULL,                            v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '46', 4, 'crown',       NULL,             'Corona in PFM 2018',            v_pr2, CURRENT_DATE - 20),

      -- Greco Stefano (p07) - in ortodonzia
      (v_clinic, v_p07, '13', 1, 'healthy',     NULL,             NULL,                            v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '23', 2, 'healthy',     NULL,             NULL,                            v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '34', 3, 'healthy',     NULL,             NULL,                            v_pr3, CURRENT_DATE - 300),

      -- Barbieri Sara (p18) - urgenza
      (v_clinic, v_p18, '26', 2, 'caries',      ARRAY['O','M','D'], 'Dolore da freddo - carie profonda', v_pr1, CURRENT_DATE),
      (v_clinic, v_p18, '25', 2, 'devitalized', NULL,              'Devitalizzazione precedente',   v_pr1, CURRENT_DATE);

    -- =========================================================================
    -- CLINICAL HISTORY ENTRIES
    -- Live DB columns: id, clinic_id, patient_id, appointment_id, provider_id,
    --   entry_date, tooth_number, service_code, service_name,
    --   clinical_notes, materials_used, next_visit_notes
    -- NOTE: no entry_type, title, body in live DB
    -- =========================================================================

    INSERT INTO clinical_history_entries (clinic_id, patient_id, provider_id,
        entry_date, tooth_number, service_name, clinical_notes)
    VALUES
      (v_clinic, v_p01, v_pr1, CURRENT_DATE - 3, '16', 'Otturazione composito bifacciale',
       'Otturazione composito bifacciale completata su 16. Paziente ha tollerato bene la seduta. Nessuna complicazione.'),
      (v_clinic, v_p01, v_pr1, CURRENT_DATE - 3, NULL, NULL,
       'Piano di cura in corso. Ancora da trattare: 14 monofacciale. Da programmare igiene di mantenimento.'),
      (v_clinic, v_p03, v_pr2, CURRENT_DATE - 3, '36', 'CBCT pre-implantare',
       'CBCT eseguita. Osso disponibile: altezza 12mm, larghezza 7mm. Pianificata inserzione impianto 3.8x11mm.'),
      (v_clinic, v_p07, v_pr3, CURRENT_DATE - 1, NULL, 'Controllo ortodonzia mensile',
       'Allineamento progredisce regolarmente. Sostituito archwire 0.16 in NiTi. Prossimo controllo tra 4 settimane.'),
      (v_clinic, v_p08, v_pr2, CURRENT_DATE - 30, NULL, NULL,
       'ATTENZIONE: paziente in terapia con bifosfonati e portatore di patologia cardiaca. Consultare cardiologo prima di chirurgia.'),
      (v_clinic, v_p18, v_pr1, CURRENT_DATE, '26', 'Visita urgente',
       'Paziente riferisce dolore acuto su 26 da 3 giorni. Carie profonda prossima alla polpa. Probabile devitalizzazione necessaria. RX eseguita.');

    -- =========================================================================
    -- SUPPLIERS
    -- Live DB columns: id, clinic_id, name, contact_person, phone, email,
    --   notes, is_active
    -- NOTE: no contact_name (uses contact_person), no vat_number
    -- =========================================================================

    INSERT INTO suppliers (id, clinic_id, name, contact_person, phone, email, is_active)
    VALUES
      (v_sup1, v_clinic, 'Dental Supply Italia S.r.l.',
       'Marco Betti', '+39 06 5550200', 'ordini@dentalsupply.it', true),
      (v_sup2, v_clinic, 'Implantec Medical S.p.A.',
       'Anna Ferrara', '+39 02 5550300', 'ordini@implantec.it', true);

    -- =========================================================================
    -- PRODUCT CATEGORIES
    -- Live DB columns: id, clinic_id, name
    -- NOTE: no color_hex, sort_order in live DB
    -- =========================================================================

    INSERT INTO product_categories (id, clinic_id, name)
    VALUES
      (v_cat1, v_clinic, 'Materiali Compositi'),
      (v_cat2, v_clinic, 'Anestesia'),
      (v_cat3, v_clinic, 'Igiene Professionale'),
      (v_cat4, v_clinic, 'Chirurgia'),
      (v_cat5, v_clinic, 'Radiologia'),
      (v_cat6, v_clinic, 'Monouso e DPI');

    -- =========================================================================
    -- PRODUCTS (22 prodotti in 6 categorie)
    -- Live DB columns: id, clinic_id, category_id, supplier_id, name, description,
    --   sku, unit, min_stock_quantity, reorder_quantity, unit_cost, is_active
    -- NOTE: no min_stock (uses min_stock_quantity), no price_unit (uses unit_cost)
    -- =========================================================================

    INSERT INTO products (id, clinic_id, supplier_id, category_id, sku, name,
        description, unit, min_stock_quantity, unit_cost, is_active)
    VALUES
      -- Compositi
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'COMP-A2-4G',   'Filtek Supreme A2 4g',
       'Composito universale 3M', 'siringa', 5, 38.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'COMP-A3-4G',   'Filtek Supreme A3 4g',
       'Composito universale 3M', 'siringa', 5, 38.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'BOND-SBU',     'Single Bond Universal 5ml',
       'Adesivo universale 3M', 'flacone', 3, 52.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'ETCH-GEL',     'Gel mordenzante 37% 5ml',
       'Acido ortofosforico 37%', 'siringa', 10, 8.50, true),

      -- Anestesia
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'ANEST-ART-100', 'Articaina 4% 1:100.000 bx50',
       'Carpule anestesia locale', 'confezione', 3, 45.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'ANEST-ART-200', 'Articaina 4% 1:200.000 bx50',
       'Carpule anestesia vasocostrittore ridotto', 'confezione', 2, 45.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'AGO-SHORT',    'Aghi 30G corti bx100',
       'Aghi per siringa carpule', 'confezione', 5, 12.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'AGO-LONG',     'Aghi 27G lunghi bx100',
       'Aghi per blocco mandibolare', 'confezione', 3, 12.00, true),

      -- Igiene
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'PAS-IGIENE-C', 'Pasta lucidante grossolana 200g',
       'Pasta profilassi grossa', 'vaso', 5, 18.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'PAS-IGIENE-F', 'Pasta lucidante fine 200g',
       'Pasta profilassi fine', 'vaso', 5, 18.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'FLUORO-GEL',   'Gel fluoruro 1,23% 200g',
       'Fluoruro applicazione professionale', 'vaso', 3, 22.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'COPETTE-PL',   'Copette profilassi bx144',
       'Copette monouso per profilassi', 'confezione', 4, 14.00, true),

      -- Chirurgia
      (gen_random_uuid(), v_clinic, v_sup1, v_cat4, 'SUTURA-4-0',   'Filo sutura 4/0 VICRYL bx36',
       'Sutura riassorbibile poliglactina', 'confezione', 3, 48.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat4, 'SUTURA-3-0',   'Filo sutura 3/0 VICRYL bx36',
       'Sutura riassorbibile calibro maggiore', 'confezione', 2, 48.00, true),
      (gen_random_uuid(), v_clinic, v_sup2, v_cat4, 'IMP-3814',     'Impianto Straumann BLT 3.8x14',
       'Impianto osteointegrato tissue level', 'pezzo', 2, 320.00, true),
      (gen_random_uuid(), v_clinic, v_sup2, v_cat4, 'IMP-4111',     'Impianto Straumann BLT 4.1x11',
       'Impianto osteointegrato tissue level', 'pezzo', 2, 320.00, true),

      -- Radiologia
      (gen_random_uuid(), v_clinic, v_sup1, v_cat5, 'PELLICOLA-E0', 'Pellicole endorali E-speed bx150',
       'Pellicole radiografiche endorali', 'confezione', 2, 85.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat5, 'GUANTI-RX',    'Guanti piombo 0.5mm taglia M',
       'Protezione radiazioni', 'paio', 2, 95.00, true),

      -- Monouso e DPI
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'GUANTI-NIT-M', 'Guanti nitrile M bx100',
       'Guanti da visita senza polvere', 'confezione', 10, 8.50, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'GUANTI-NIT-L', 'Guanti nitrile L bx100',
       'Guanti da visita senza polvere', 'confezione', 8, 8.50, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'MASCHERINE-FF', 'Mascherine FFP2 bx10',
       'Mascherine filtranti FFP2 certificate', 'confezione', 20, 12.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'BAVAGLIO',     'Bavagli plastificati bx500',
       'Bavagli monouso plastificati', 'confezione', 5, 18.00, true);

    -- =========================================================================
    -- STOCK MOVEMENTS (carico iniziale per ogni prodotto)
    -- Live DB columns: id, clinic_id, product_id, movement_type, quantity,
    --   unit_cost, notes, reference_doc, created_by_provider_id, created_at
    -- NOTE: no 'moved_at' in live DB
    -- =========================================================================

    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, created_by_provider_id)
    SELECT
        v_clinic,
        p.id,
        'carico',
        CASE p.min_stock_quantity WHEN 0 THEN 10 ELSE p.min_stock_quantity * 5 END,
        p.unit_cost * 0.7,
        'DDT-INIT-001',
        'Carico iniziale magazzino',
        v_pr1
    FROM products p
    WHERE p.clinic_id = v_clinic;

    -- Alcuni scarichi realistici
    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, created_by_provider_id)
    SELECT
        v_clinic,
        p.id,
        'scarico',
        CASE p.category_id
            WHEN v_cat6 THEN 3   -- monouso: alto consumo
            WHEN v_cat2 THEN 2   -- anestesia: medio consumo
            ELSE 1               -- altri: consumo unitario
        END,
        p.unit_cost * 0.7,
        NULL,
        'Utilizzo sedute',
        v_pr1
    FROM products p
    WHERE p.clinic_id = v_clinic AND p.is_active = true;

    -- =========================================================================
    -- PATIENT RECALLS
    -- Live DB columns: id, clinic_id, patient_id, recall_type, due_date,
    --   status, priority, notes, source_appointment_id, booked_appointment_id,
    --   last_contact_at, contact_count
    -- NOTE: enum values in live DB: status='da_contattare'/'contattato'/'confermato'/'chiuso'/'annullato'
    --       priority='alta'/'media'/'bassa'
    --       no provider_id, appointment_id, completed_at in live DB recalls
    -- =========================================================================

    INSERT INTO patient_recalls (clinic_id, patient_id, recall_type,
        status, priority, due_date, notes)
    VALUES
      -- Scaduti (alta priorita')
      (v_clinic, v_p09, 'Controllo periodico', 'da_contattare', 'alta',
       CURRENT_DATE - 30, 'Igiene semestrale scaduta da un mese'),
      (v_clinic, v_p13, 'Controllo periodico', 'da_contattare', 'alta',
       CURRENT_DATE - 7,  'Igiene - paziente no-show da ricontattare'),

      -- In scadenza
      (v_clinic, v_p15, 'Controllo post-trattamento', 'contattato', 'media',
       CURRENT_DATE + 3,  'Follow-up post-otturazione 37'),
      (v_clinic, v_p17, 'Controllo periodico', 'da_contattare', 'media',
       CURRENT_DATE + 5,  'Igiene annuale - paziente anziano'),

      -- Media priorita'
      (v_clinic, v_p04, 'Controllo periodico', 'confermato', 'media',
       CURRENT_DATE + 10, 'Igiene programmata - appuntamento fissato'),
      (v_clinic, v_p06, 'Controllo post-trattamento', 'da_contattare', 'media',
       CURRENT_DATE + 14, 'Controllo post-igiene profonda'),
      (v_clinic, v_p11, 'Controllo periodico', 'da_contattare', 'media',
       CURRENT_DATE + 20, 'Igiene semestrale programmata'),

      -- Bassa priorita' (futura)
      (v_clinic, v_p19, 'Controllo periodico', 'da_contattare', 'bassa',
       CURRENT_DATE + 45, 'Visita annuale di controllo'),
      (v_clinic, v_p20, 'Controllo ortodontico', 'da_contattare', 'bassa',
       CURRENT_DATE + 60, 'Prima visita ortodontica di controllo'),

      -- Chiusi
      (v_clinic, v_p01, 'Controllo post-trattamento', 'chiuso', 'bassa',
       CURRENT_DATE - 5,  'Follow-up completato - paziente tornato in cura');

    -- =========================================================================
    -- PATIENT_DIAGNOSES
    -- =========================================================================

    INSERT INTO patient_diagnoses
        (clinic_id, patient_id, provider_id, tooth_number, title, description, icd_code, status, diagnosed_at)
    VALUES
        (v_clinic, v_p01, v_pr1, '16', 'Carie occlusale', 'Carie di I grado sulla fossa centrale del 16', 'K02.1', 'active',   CURRENT_DATE - 30),
        (v_clinic, v_p01, v_pr1, '36', 'Carie interprossimale', 'Carie mesiale del 36 con coinvolgimento della dentina', 'K02.1', 'active', CURRENT_DATE - 15),
        (v_clinic, v_p02, v_pr1, '21', 'Pulpite irreversibile', 'Pulpite irreversibile sintomatica del 21', 'K04.0', 'active',   CURRENT_DATE - 10),
        (v_clinic, v_p02, v_pr3, NULL, 'Malocclusione classe II', 'Malocclusione scheletrica classe II divisione 1', 'K07.2', 'chronic', CURRENT_DATE - 180),
        (v_clinic, v_p03, v_pr1, '46', 'Parodontite localizzata', 'Parodontite cronica localizzata al 46', 'K05.3', 'active',   CURRENT_DATE - 45),
        (v_clinic, v_p03, v_pr1, '11', 'Carie guarita', 'Otturazione composito 11 eseguita', 'K02.1', 'resolved', CURRENT_DATE - 90),
        (v_clinic, v_p04, v_pr2, '18', 'Dente del giudizio incluso', 'Terzo molare inferiore sinistro incluso in osso', 'K01.1', 'active', CURRENT_DATE - 20),
        (v_clinic, v_p05, v_pr4, NULL, 'Gengivite generalizzata', 'Gengivite da placca batterica, generalizzata', 'K05.1', 'active', CURRENT_DATE - 7);

    -- =========================================================================
    -- PATIENT_PRESCRIPTIONS
    -- =========================================================================

    INSERT INTO patient_prescriptions
        (clinic_id, patient_id, provider_id, drug_name, dosage, frequency, duration, notes, prescribed_at, expires_at, active)
    VALUES
        (v_clinic, v_p01, v_pr1, 'Amoxicillina', '1g', '3 volte al giorno', '7 giorni',
         'Assumere lontano dai pasti. In caso di allergia sospendere e contattare lo studio.',
         CURRENT_DATE - 30, CURRENT_DATE + 60, true),
        (v_clinic, v_p01, v_pr1, 'Ibuprofene', '600mg', 'Al bisogno, max 3 al giorno', '5 giorni',
         'Non superare la dose massima giornaliera.',
         CURRENT_DATE - 15, CURRENT_DATE + 30, true),
        (v_clinic, v_p02, v_pr1, 'Metronidazolo', '250mg', '3 volte al giorno', '7 giorni',
         'Evitare alcol durante il trattamento.',
         CURRENT_DATE - 10, CURRENT_DATE + 20, true),
        (v_clinic, v_p03, v_pr1, 'Clorexidina collutorio 0.2%', NULL, '2 volte al giorno dopo i pasti', '30 giorni',
         'Risciacquare per 1 minuto. Non ingerire.',
         CURRENT_DATE - 45, CURRENT_DATE - 15, false),
        (v_clinic, v_p04, v_pr2, 'Nimesulide', '100mg', '2 volte al giorno', '5 giorni',
         'Assumere dopo i pasti. Controindicato in caso di insufficienza epatica.',
         CURRENT_DATE - 5, CURRENT_DATE + 25, true),
        (v_clinic, v_p05, v_pr4, 'Clorexidina gel 1%', NULL, '2 applicazioni al giorno', '14 giorni',
         'Applicare sui bordi gengivali con spazzolino morbido.',
         CURRENT_DATE - 7, CURRENT_DATE + 7, true);

    -- Aggiungi un contatto per il richiamo di p15
    -- Live DB recall_contacts columns: id, clinic_id, recall_id, contact_type,
    --   contact_at, outcome, notes, created_by_provider_id, created_at
    -- NOTE: no 'contacted_by_provider_id' or 'contacted_at' — uses 'created_by_provider_id' and 'contact_at'
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT
        pr.id,
        v_clinic,
        'telefono',
        'messaggio_lasciato',
        v_pr4,
        now() - INTERVAL '2 days',
        'Lasciato messaggio in segreteria'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p15
    LIMIT 1;

END $$;

-- =============================================================================
-- VERIFICA FINALE
-- =============================================================================

SELECT 'clinics'            AS tabella, COUNT(*)::text AS righe FROM t_9d754153.clinics            WHERE id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'providers',                     COUNT(*)::text FROM t_9d754153.providers            WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'patients',                      COUNT(*)::text FROM t_9d754153.patients             WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'service_catalog',               COUNT(*)::text FROM t_9d754153.service_catalog      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'treatment_plans',               COUNT(*)::text FROM t_9d754153.treatment_plans      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'treatment_plan_items',          COUNT(*)::text FROM t_9d754153.treatment_plan_items WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'estimates',                     COUNT(*)::text FROM t_9d754153.estimates            WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'estimate_lines',                COUNT(*)::text FROM t_9d754153.estimate_lines       WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'appointments',                  COUNT(*)::text FROM t_9d754153.appointments         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'patient_anamnesis',             COUNT(*)::text FROM t_9d754153.patient_anamnesis    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'odontogram_teeth',              COUNT(*)::text FROM t_9d754153.odontogram_teeth     WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'products',                      COUNT(*)::text FROM t_9d754153.products             WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'stock_movements',               COUNT(*)::text FROM t_9d754153.stock_movements      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'patient_recalls',               COUNT(*)::text FROM t_9d754153.patient_recalls      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'patient_diagnoses',             COUNT(*)::text FROM t_9d754153.patient_diagnoses    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL
SELECT 'patient_prescriptions',         COUNT(*)::text FROM t_9d754153.patient_prescriptions WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
ORDER BY tabella;

COMMIT;
