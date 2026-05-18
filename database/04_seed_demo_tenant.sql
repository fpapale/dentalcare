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
    'Studio Demo DentalCare',
    't_9d754153',
    'demo@dentalcare.it',
    '+39 06 5550100',
    'professional',
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
    USING patient_anamnesis pa
    WHERE patient_anamnesis_item_selections.anamnesis_id = pa.id
      AND pa.clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_anamnesis       WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM invoice_lines il
    USING invoices i
    WHERE il.invoice_id = i.id AND i.clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM invoices                WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
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
-- =============================================================================

INSERT INTO clinics (id, name, legal_name, vat_number, fiscal_code, phone, email,
    address_line1, city, province, postal_code, country, timezone,
    opening_time, closing_time, slot_minutes, invoice_prefix, invoice_counter)
VALUES (
    '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid,
    'Studio Demo DentalCare Roma',
    'DentalCare Roma S.r.l.',
    'DEMO-ROMA-001',
    'DEMOROMA001',
    '+39 06 5550101',
    'roma@dentalcare.demo',
    'Via Nomentana 123',
    'Roma', 'RM', '00162', 'IT',
    'Europe/Rome',
    '08:00', '20:00', 30,
    'FC', 0
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
    -- =========================================================================

    INSERT INTO providers (id, clinic_id, first_name, last_name, role, specialization,
        phone, email, license_number, color_hex, active)
    VALUES
      (v_pr1, v_clinic, 'Laura',   'Ferretti',  'dentist',       'Odontoiatria generale',
       '+39 334 1001001', 'laura.ferretti@dentalcare.demo',   'OMC-RM-12345', '#4F46E5', true),
      (v_pr2, v_clinic, 'Paolo',   'Marchetti', 'surgeon',       'Chirurgia orale e implantologia',
       '+39 334 1001002', 'paolo.marchetti@dentalcare.demo',  'OMC-RM-12346', '#EF4444', true),
      (v_pr3, v_clinic, 'Serena',  'Amato',     'orthodontist',  'Ortodonzia fissa e mobile',
       '+39 334 1001003', 'serena.amato@dentalcare.demo',     'OMC-RM-12347', '#10B981', true),
      (v_pr4, v_clinic, 'Michele', 'Gentili',   'hygienist',     'Igiene orale professionale',
       '+39 334 1001004', 'michele.gentili@dentalcare.demo',  'OMC-RM-12348', '#F59E0B', true);

    -- =========================================================================
    -- PATIENTS (20 pazienti con nomi italiani realistici)
    -- =========================================================================

    INSERT INTO patients (id, clinic_id, first_name, last_name, fiscal_code,
        birth_date, gender, phone, email, city, province, postal_code, active)
    VALUES
      (v_p01, v_clinic, 'Marco',     'Rossi',      'RSSMRC85A01H501X', '1985-01-01', 'M', '+39 348 1110001', 'marco.rossi@email.it',      'Roma',    'RM', '00100', true),
      (v_p02, v_clinic, 'Giulia',    'Bianchi',    'BNCGLI90B41H501Y', '1990-02-28', 'F', '+39 348 1110002', 'giulia.bianchi@email.it',   'Roma',    'RM', '00144', true),
      (v_p03, v_clinic, 'Luca',      'Romano',     'RMNLCU78C03H501Z', '1978-03-15', 'M', '+39 348 1110003', 'luca.romano@email.it',      'Roma',    'RM', '00162', true),
      (v_p04, v_clinic, 'Chiara',    'Colombo',    'CLMCHR92D44H501W', '1992-04-10', 'F', '+39 348 1110004', 'chiara.colombo@email.it',   'Milano',  'MI', '20100', true),
      (v_p05, v_clinic, 'Andrea',    'Ricci',      'RCCNDR80E05H501V', '1980-05-22', 'M', '+39 348 1110005', 'andrea.ricci@email.it',     'Roma',    'RM', '00185', true),
      (v_p06, v_clinic, 'Valentina', 'Marino',     'MRNVNT88F46H501U', '1988-06-05', 'F', '+39 348 1110006', 'valentina.marino@email.it', 'Napoli',  'NA', '80100', true),
      (v_p07, v_clinic, 'Stefano',   'Greco',      'GRCSFN75G07H501T', '1975-07-18', 'M', '+39 348 1110007', 'stefano.greco@email.it',    'Roma',    'RM', '00136', true),
      (v_p08, v_clinic, 'Francesca', 'Bruno',      'BRNFNC95H48H501S', '1995-08-30', 'F', '+39 348 1110008', 'francesca.bruno@email.it',  'Roma',    'RM', '00167', true),
      (v_p09, v_clinic, 'Matteo',    'Gallo',      'GLLMTT82I09H501R', '1982-09-12', 'M', '+39 348 1110009', 'matteo.gallo@email.it',     'Firenze', 'FI', '50100', true),
      (v_p10, v_clinic, 'Silvia',    'Conti',      'CNTSLV91L50H501Q', '1991-11-25', 'F', '+39 348 1110010', 'silvia.conti@email.it',     'Roma',    'RM', '00192', true),
      (v_p11, v_clinic, 'Roberto',   'De Luca',    'DLCRBT68A11H501P', '1968-01-20', 'M', '+39 348 1110011', 'roberto.deluca@email.it',   'Roma',    'RM', '00118', true),
      (v_p12, v_clinic, 'Elena',     'Mancini',    'MNCLNE86B52H501N', '1986-02-14', 'F', '+39 348 1110012', 'elena.mancini@email.it',    'Roma',    'RM', '00176', true),
      (v_p13, v_clinic, 'Daniele',   'Costa',      'CSTDNL79C13H501M', '1979-03-08', 'M', '+39 348 1110013', 'daniele.costa@email.it',    'Torino',  'TO', '10100', true),
      (v_p14, v_clinic, 'Martina',   'Giordano',   'GRDMTN93D54H501L', '1993-04-02', 'F', '+39 348 1110014', 'martina.giordano@email.it', 'Roma',    'RM', '00154', true),
      (v_p15, v_clinic, 'Paolo',     'Rizzo',      'RZZPLA70E15H501K', '1970-05-16', 'M', '+39 348 1110015', 'paolo.rizzo@email.it',      'Roma',    'RM', '00122', true),
      (v_p16, v_clinic, 'Alessia',   'Lombardi',   'LMBLSS97F56H501J', '1997-06-28', 'F', '+39 348 1110016', 'alessia.lombardi@email.it', 'Roma',    'RM', '00145', true),
      (v_p17, v_clinic, 'Giovanni',  'Moretti',    'MRTGNN65G17H501I', '1965-07-04', 'M', '+39 348 1110017', 'giovanni.moretti@email.it', 'Bologna', 'BO', '40100', true),
      (v_p18, v_clinic, 'Sara',      'Barbieri',   'BRBSRA89H58H501H', '1989-08-19', 'F', '+39 348 1110018', 'sara.barbieri@email.it',    'Roma',    'RM', '00159', true),
      (v_p19, v_clinic, 'Nicola',    'Fontana',    'FNTNCL83I19H501G', '1983-09-11', 'M', '+39 348 1110019', 'nicola.fontana@email.it',   'Roma',    'RM', '00173', true),
      (v_p20, v_clinic, 'Beatrice',  'Santoro',    'SNTBRC96L60H501F', '1996-12-03', 'F', '+39 348 1110020', 'beatrice.santoro@email.it', 'Roma',    'RM', '00141', true);

    -- =========================================================================
    -- SERVICE CATALOG (25 prestazioni in 8 categorie)
    -- =========================================================================

    INSERT INTO service_catalog (id, clinic_id, code, name, category, price, duration_minutes,
        min_tooth_digit, max_tooth_digit, applicable_to_deciduous, is_active)
    VALUES
      -- Igiene
      (v_s01, v_clinic, 'IGI-01', 'Igiene orale professionale',       'Igiene',       80.00,  45, NULL, NULL, true,  true),
      (v_s02, v_clinic, 'IGI-02', 'Igiene orale profonda',            'Igiene',      120.00,  60, NULL, NULL, true,  true),
      (v_s03, v_clinic, 'IGI-03', 'Fluoroprofilassi',                  'Igiene',       30.00,  15, NULL, NULL, true,  true),
      -- Diagnostica
      (v_s04, v_clinic, 'DIA-01', 'Radiografia endorale',             'Diagnostica',  25.00,  10, NULL, NULL, true,  true),
      (v_s05, v_clinic, 'DIA-02', 'Ortopantomografia',                'Diagnostica',  80.00,  15, NULL, NULL, true,  true),
      (v_s06, v_clinic, 'DIA-03', 'CBCT arcata singola',              'Diagnostica', 180.00,  20, NULL, NULL, false, true),
      -- Conservativa
      (v_s07, v_clinic, 'CON-01', 'Otturazione composito monofacciale','Conservativa',  90.00, 45, NULL, NULL, true,  true),
      (v_s08, v_clinic, 'CON-02', 'Otturazione composito bifacciale', 'Conservativa', 130.00,  60, NULL, NULL, true,  true),
      (v_s09, v_clinic, 'CON-03', 'Otturazione composito trifacciale','Conservativa', 160.00,  75, NULL, NULL, true,  true),
      -- Endodonzia
      (v_s10, v_clinic, 'END-01', 'Devitalizzazione monoradicolare',  'Endodonzia',  280.00,  90, 1,    5,    true,  true),
      (v_s11, v_clinic, 'END-02', 'Devitalizzazione biradicolare',    'Endodonzia',  380.00, 120, 4,    6,    false, true),
      (v_s12, v_clinic, 'END-03', 'Devitalizzazione pluriradicolare', 'Endodonzia',  480.00, 150, 6,    8,    false, true),
      (v_s13, v_clinic, 'END-04', 'Ritrattamento canalare',           'Endodonzia',  380.00, 120, NULL, NULL, false, true),
      -- Protesi
      (v_s14, v_clinic, 'PRO-01', 'Corona in zirconia',               'Protesi',     650.00,  60, NULL, NULL, false, true),
      (v_s15, v_clinic, 'PRO-02', 'Faccetta in ceramica',             'Protesi',     550.00,  90, 1,    3,    false, true),
      -- Implantologia
      (v_s16, v_clinic, 'IMP-01', 'Impianto osteointegrato',          'Implantologia',1200.00, 90, NULL, NULL, false, true),
      (v_s17, v_clinic, 'IMP-02', 'Moncone implantare',               'Implantologia', 350.00, 45, NULL, NULL, false, true),
      -- Chirurgia
      (v_s18, v_clinic, 'CHI-01', 'Estrazione semplice',              'Chirurgia',   100.00,  30, NULL, NULL, true,  true),
      (v_s19, v_clinic, 'CHI-02', 'Estrazione complessa',             'Chirurgia',   200.00,  60, NULL, NULL, false, true),
      (v_s25, v_clinic, 'CHI-03', 'Rimozione punti di sutura',        'Chirurgia',    30.00,  15, NULL, NULL, true,  true),
      -- Parodontologia
      (v_s20, v_clinic, 'PAR-01', 'Levigatura radicolare per quadrante','Parodontologia',180.00, 60, NULL, NULL, false, true),
      (v_s21, v_clinic, 'PAR-02', 'Terapia parodontale di mantenimento','Parodontologia', 80.00, 45, NULL, NULL, false, true),
      -- Ortodonzia
      (v_s22, v_clinic, 'ORT-01', 'Apparecchio mobile rimovibile',    'Ortodonzia',  450.00,  60, NULL, NULL, true,  true),
      (v_s23, v_clinic, 'ORT-02', 'Apparecchio fisso multibrackets',  'Ortodonzia', 2800.00,  90, NULL, NULL, false, true),
      -- Estetica
      (v_s24, v_clinic, 'EST-01', 'Sbiancamento professionale',       'Estetica',    250.00,  60, NULL, NULL, false, true);

    -- =========================================================================
    -- SERVICE BUNDLE ITEMS (prestazioni correlate automatiche)
    -- =========================================================================

    INSERT INTO service_bundle_items (id, clinic_id, bundle_service_id, component_service_id, quantity)
    VALUES
      (gen_random_uuid(), v_clinic, v_s18, v_s25, 1),  -- Estrazione semplice → Rimozione punti
      (gen_random_uuid(), v_clinic, v_s19, v_s25, 1),  -- Estrazione complessa → Rimozione punti
      (gen_random_uuid(), v_clinic, v_s10, v_s04, 1),  -- Devit. mono → RX endorale
      (gen_random_uuid(), v_clinic, v_s10, v_s07, 1),  -- Devit. mono → Otturazione mono
      (gen_random_uuid(), v_clinic, v_s11, v_s04, 1),  -- Devit. bi → RX endorale
      (gen_random_uuid(), v_clinic, v_s12, v_s04, 1),  -- Devit. pluri → RX endorale
      (gen_random_uuid(), v_clinic, v_s16, v_s06, 1),  -- Impianto → CBCT
      (gen_random_uuid(), v_clinic, v_s16, v_s17, 1),  -- Impianto → Moncone
      (gen_random_uuid(), v_clinic, v_s16, v_s14, 1),  -- Impianto → Corona su impianto
      (gen_random_uuid(), v_clinic, v_s02, v_s03, 1);  -- Igiene profonda → Fluoroprofilassi

    -- =========================================================================
    -- CONDITION SERVICE DEFAULTS (prestazioni suggerite per condizione)
    -- =========================================================================

    INSERT INTO condition_service_defaults (id, clinic_id, condition, service_catalog_id, sort_order)
    VALUES
      (gen_random_uuid(), v_clinic, 'caries',       v_s07, 10),
      (gen_random_uuid(), v_clinic, 'caries',       v_s04, 20),
      (gen_random_uuid(), v_clinic, 'to_extract',   v_s18, 10),
      (gen_random_uuid(), v_clinic, 'to_extract',   v_s25, 20),
      (gen_random_uuid(), v_clinic, 'devitalized',  v_s13, 10),
      (gen_random_uuid(), v_clinic, 'devitalized',  v_s04, 20),
      (gen_random_uuid(), v_clinic, 'missing',      v_s06, 10),
      (gen_random_uuid(), v_clinic, 'missing',      v_s16, 20),
      (gen_random_uuid(), v_clinic, 'missing',      v_s17, 30),
      (gen_random_uuid(), v_clinic, 'missing',      v_s14, 40),
      (gen_random_uuid(), v_clinic, 'crown',        v_s14, 10),
      (gen_random_uuid(), v_clinic, 'fracture',     v_s08, 10),
      (gen_random_uuid(), v_clinic, 'fracture',     v_s04, 20);

    -- =========================================================================
    -- TREATMENT PLANS
    -- =========================================================================

    INSERT INTO treatment_plans (id, clinic_id, patient_id, provider_id, title, status, version, notes)
    VALUES
      (v_tp1, v_clinic, v_p01, v_pr1, 'Piano carie multiple - Rossi Marco',
       'in_progress', 1, 'Trattamento carie quadrante superiore destro'),
      (v_tp2, v_clinic, v_p03, v_pr2, 'Implantologia - Romano Luca',
       'accepted', 1, 'Impianto 36 - pre-chirurgica completata'),
      (v_tp3, v_clinic, v_p05, v_pr1, 'Conservativa e igiene - Ricci Andrea',
       'proposed', 1, 'Preventivo inviato, in attesa accettazione'),
      (v_tp4, v_clinic, v_p07, v_pr3, 'Ortodonzia adulti - Greco Stefano',
       'in_progress', 1, 'Apparecchio fisso applicato 3 mesi fa'),
      (v_tp5, v_clinic, v_p02, v_pr1, 'Sbiancamento e faccette - Bianchi Giulia',
       'draft', 1, 'In valutazione estetica');

    -- =========================================================================
    -- TREATMENT PLAN ITEMS
    -- =========================================================================

    INSERT INTO treatment_plan_items (id, clinic_id, plan_id, service_catalog_id,
        tooth_fdi, surfaces, description, price, status, sort_order, completed_at)
    VALUES
      -- Piano 1: Rossi Marco - carie multiple
      (v_tpi1, v_clinic, v_tp1, v_s04, '16',  NULL,        'Radiografia endorale 16',        25.00, 'completed', 10,
       (CURRENT_DATE - INTERVAL '10 days')::timestamptz + TIME '10:00'),
      (v_tpi2, v_clinic, v_tp1, v_s08, '16',  ARRAY['O','D'], 'Otturazione composito bifacciale 16', 130.00, 'completed', 20,
       (CURRENT_DATE - INTERVAL '10 days')::timestamptz + TIME '10:30'),
      (v_tpi3, v_clinic, v_tp1, v_s07, '14',  ARRAY['O'], 'Otturazione composito monofacciale 14', 90.00, 'scheduled', 30, NULL),
      (v_tpi4, v_clinic, v_tp1, v_s01, NULL,  NULL,        'Igiene professionale di mantenimento', 80.00, 'planned', 40, NULL),

      -- Piano 2: Romano Luca - impianto
      (v_tpi5, v_clinic, v_tp2, v_s06, '36',  NULL,        'CBCT arcata inferiore pre-implantare', 180.00, 'completed', 10,
       (CURRENT_DATE - INTERVAL '20 days')::timestamptz + TIME '09:00'),
      (v_tpi6, v_clinic, v_tp2, v_s16, '36',  NULL,        'Inserimento impianto 36',          1200.00, 'scheduled', 20, NULL),

      -- Piano 4: Greco Stefano - ortodonzia
      (v_tpi7, v_clinic, v_tp4, v_s23, NULL,  NULL,        'Apparecchio fisso multibrackets arcata superiore', 2800.00, 'accepted', 10, NULL),

      -- Piano 3: Ricci Andrea
      (v_tpi8, v_clinic, v_tp3, v_s01, NULL,  NULL,        'Igiene orale professionale',       80.00, 'planned', 10, NULL);

    -- =========================================================================
    -- ESTIMATES
    -- =========================================================================

    INSERT INTO estimates (id, clinic_id, patient_id, created_by_provider_id, plan_id,
        version, status, title, notes, valid_until, subtotal, discount_total, total)
    VALUES
      (v_est1, v_clinic, v_p01, v_pr1, v_tp1,
       1, 'accepted', 'Preventivo piano carie - Rossi Marco',
       'Sconto 10% applicato su totale',
       CURRENT_DATE + 30,
       325.00, 32.50, 292.50),

      (v_est2, v_clinic, v_p03, v_pr2, v_tp2,
       1, 'sent', 'Preventivo implantologia - Romano Luca',
       'Include CBCT, impianto, moncone, corona',
       CURRENT_DATE + 45,
       1730.00, 0, 1730.00),

      (v_est3, v_clinic, v_p05, v_pr1, v_tp3,
       1, 'draft', 'Bozza preventivo igiene e conservativa - Ricci Andrea',
       NULL,
       NULL,
       80.00, 0, 80.00),

      (v_est4, v_clinic, v_p02, v_pr1, v_tp5,
       1, 'draft', 'Preventivo estetica - Bianchi Giulia',
       'In fase di valutazione',
       CURRENT_DATE + 60,
       1350.00, 0, 1350.00);

    -- Righe preventivo 1 (Rossi - accettato)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_catalog_id,
        description, tooth_fdi, quantity, unit_price, discount_pct, line_total, position)
    VALUES
      (v_est1, v_clinic, v_tpi1, v_s04, 'Radiografia endorale 16', '16', 1, 25.00, 0, 25.00, 1),
      (v_est1, v_clinic, v_tpi2, v_s08, 'Otturazione composito bifacciale 16', '16', 1, 130.00, 10, 117.00, 2),
      (v_est1, v_clinic, v_tpi3, v_s07, 'Otturazione composito monofacciale 14', '14', 1, 90.00, 10, 81.00, 3),
      (v_est1, v_clinic, v_tpi4, v_s01, 'Igiene professionale', NULL, 1, 80.00, 10, 72.00, 4);

    -- Righe preventivo 2 (Romano - inviato)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_catalog_id,
        description, tooth_fdi, quantity, unit_price, discount_pct, line_total, position)
    VALUES
      (v_est2, v_clinic, v_tpi5, v_s06, 'CBCT arcata inferiore', '36', 1, 180.00, 0, 180.00, 1),
      (v_est2, v_clinic, v_tpi6, v_s16, 'Impianto osteointegrato 36', '36', 1, 1200.00, 0, 1200.00, 2),
      (v_est2, v_clinic, NULL,   v_s17, 'Moncone implantare', '36', 1, 350.00, 0, 350.00, 3);

    -- Riga preventivo 3 (Ricci - bozza)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_catalog_id,
        description, quantity, unit_price, discount_pct, line_total, position)
    VALUES
      (v_est3, v_clinic, v_tpi8, v_s01, 'Igiene orale professionale', 1, 80.00, 0, 80.00, 1);

    -- Righe preventivo 4 (Bianchi - estetica)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_catalog_id,
        description, quantity, unit_price, discount_pct, line_total, position)
    VALUES
      (v_est4, v_clinic, NULL, v_s24, 'Sbiancamento professionale', 1, 250.00, 0, 250.00, 1),
      (v_est4, v_clinic, NULL, v_s15, 'Faccette in ceramica 11-12-21-22', 4, 550.00, 0, 2200.00, 2);

    -- =========================================================================
    -- APPOINTMENTS
    -- Usano CURRENT_DATE per essere sempre freschi.
    -- Passati (7 gg fa): completed/no_show
    -- Ieri: completed
    -- Oggi: completed (mattina) e confirmed (pomeriggio)
    -- Domani: scheduled
    -- +2 giorni: scheduled
    -- +5/+7 giorni: scheduled
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
      -- Mattina (completed)
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
      -- Pomeriggio (confirmed)
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
    -- =========================================================================

    INSERT INTO patient_anamnesis (id, clinic_id, patient_id, recorded_by_provider_id,
        blood_type, smoker, hypertension, diabetes, heart_disease,
        taking_anticoagulants, taking_bisphosphonates,
        allergy_penicillin, allergy_latex, allergy_anesthetic, allergy_aspirin, other_allergies,
        pacemaker, is_current, recorded_at)
    VALUES
      (gen_random_uuid(), v_clinic, v_p01, v_pr1,
       'A+', false, false, false, false, false, false,
       false, false, false, false, NULL, false, true, CURRENT_DATE - 365),
      (gen_random_uuid(), v_clinic, v_p02, v_pr1,
       'B+', false, false, false, false, false, false,
       true, false, false, false, NULL, false, true, CURRENT_DATE - 180),
      (gen_random_uuid(), v_clinic, v_p03, v_pr2,
       '0+', false, true, false, false, true, false,
       false, false, false, false, NULL, false, true, CURRENT_DATE - 90),
      (gen_random_uuid(), v_clinic, v_p04, v_pr1,
       'AB-', false, false, false, false, false, false,
       false, false, true, false, NULL, false, true, CURRENT_DATE - 200),
      (gen_random_uuid(), v_clinic, v_p05, v_pr1,
       'A-', true, false, false, false, false, false,
       false, false, false, true, 'Ibuprofene', false, true, CURRENT_DATE - 150),
      (gen_random_uuid(), v_clinic, v_p06, v_pr4,
       '0-', false, false, true, false, false, false,
       false, false, false, false, NULL, false, true, CURRENT_DATE - 45),
      (gen_random_uuid(), v_clinic, v_p07, v_pr3,
       'A+', false, false, false, false, false, false,
       false, false, false, false, NULL, false, true, CURRENT_DATE - 300),
      (gen_random_uuid(), v_clinic, v_p08, v_pr2,
       'B-', false, false, false, true, false, true,
       false, true, false, false, NULL, true, true, CURRENT_DATE - 30),
      (gen_random_uuid(), v_clinic, v_p09, v_pr4,
       '0+', false, false, false, false, false, false,
       false, false, false, false, NULL, false, true, CURRENT_DATE - 400),
      (gen_random_uuid(), v_clinic, v_p10, v_pr1,
       'AB+', false, false, false, false, false, false,
       false, false, false, false, NULL, false, true, CURRENT_DATE - 60);

    -- =========================================================================
    -- ODONTOGRAMMA (pazienti p01, p03, p07 con alcune condizioni)
    -- =========================================================================

    INSERT INTO odontogram_teeth (clinic_id, patient_id, tooth_fdi, condition, surfaces, notes,
        recorded_by_provider_id, recorded_at)
    VALUES
      -- Rossi Marco (p01) - carie e otturazioni
      (v_clinic, v_p01, '16', 'filling',     ARRAY['O','D'],   'Otturazione composito recente', v_pr1, CURRENT_DATE - 3),
      (v_clinic, v_p01, '14', 'caries',      ARRAY['O'],       'Carie intercuspale iniziale',   v_pr1, CURRENT_DATE - 3),
      (v_clinic, v_p01, '36', 'healthy',     NULL,             NULL,                            v_pr1, CURRENT_DATE - 365),
      (v_clinic, v_p01, '46', 'filling',     ARRAY['O'],       'Otturazione amalgama vecchia',  v_pr1, CURRENT_DATE - 365),

      -- Romano Luca (p03) - impianto in pianificazione
      (v_clinic, v_p03, '36', 'missing',     NULL,             'Sito implantare - impianto pianificato', v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '37', 'healthy',     NULL,             NULL,                            v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '46', 'crown',       NULL,             'Corona in PFM 2018',            v_pr2, CURRENT_DATE - 20),

      -- Greco Stefano (p07) - in ortodonzia
      (v_clinic, v_p07, '13', 'healthy',     NULL,             NULL,                            v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '23', 'healthy',     NULL,             NULL,                            v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '34', 'healthy',     NULL,             NULL,                            v_pr3, CURRENT_DATE - 300),

      -- Papale Fabrizio non e' nel demo - aggiungiamo Barbieri Sara (p18)
      (v_clinic, v_p18, '26', 'caries',      ARRAY['O','M','D'], 'Dolore da freddo - carie profonda', v_pr1, CURRENT_DATE),
      (v_clinic, v_p18, '25', 'devitalized', NULL,              'Devitalizzazione precedente',   v_pr1, CURRENT_DATE);

    -- =========================================================================
    -- CLINICAL HISTORY ENTRIES
    -- =========================================================================

    INSERT INTO clinical_history_entries (clinic_id, patient_id, provider_id, entry_type, title, body)
    VALUES
      (v_clinic, v_p01, v_pr1, 'treatment',
       'Otturazione 16 - completata',
       'Otturazione composito bifacciale completata su 16. Paziente ha tollerato bene la seduta. Nessuna complicazione.'),
      (v_clinic, v_p01, v_pr1, 'note',
       'Piano di cura in corso',
       'Ancora da trattare: 14 monofacciale. Da programmare igiene di mantenimento.'),
      (v_clinic, v_p03, v_pr2, 'treatment',
       'CBCT pre-implantare 36',
       'CBCT eseguita. Osso disponibile: altezza 12mm, larghezza 7mm. Pianificata inserzione impianto 3.8x11mm.'),
      (v_clinic, v_p07, v_pr3, 'note',
       'Controllo ortodonzia mensile',
       'Allineamento progredisce regolarmente. Sostituito archwire 0.16 in NiTi. Prossimo controllo tra 4 settimane.'),
      (v_clinic, v_p08, v_pr2, 'alert',
       'ATTENZIONE: Portatore di pacemaker + bifosfonati',
       'Paziente portatore di pacemaker e in terapia con bifosfonati. Consultare cardiologo prima di chirurgia. Evitare bisturi elettrico.'),
      (v_clinic, v_p18, v_pr1, 'treatment',
       'Prima visita urgente - dolore 26',
       'Paziente riferisce dolore acuto su 26 da 3 giorni. All''esame: carie profonda prossima alla polpa. Probabile devitalizzazione necessaria. RX eseguita.');

    -- =========================================================================
    -- SUPPLIERS
    -- =========================================================================

    INSERT INTO suppliers (id, clinic_id, name, contact_name, phone, email, vat_number, active)
    VALUES
      (v_sup1, v_clinic, 'Dental Supply Italia S.r.l.',
       'Marco Betti', '+39 06 5550200', 'ordini@dentalsupply.it', 'IT04567890123', true),
      (v_sup2, v_clinic, 'Implantec Medical S.p.A.',
       'Anna Ferrara', '+39 02 5550300', 'ordini@implantec.it', 'IT09876543210', true);

    -- =========================================================================
    -- PRODUCT CATEGORIES
    -- =========================================================================

    INSERT INTO product_categories (id, clinic_id, name, color_hex, sort_order)
    VALUES
      (v_cat1, v_clinic, 'Materiali Compositi',   '#4F46E5', 10),
      (v_cat2, v_clinic, 'Anestesia',             '#EF4444', 20),
      (v_cat3, v_clinic, 'Igiene Professionale',  '#10B981', 30),
      (v_cat4, v_clinic, 'Chirurgia',             '#F59E0B', 40),
      (v_cat5, v_clinic, 'Radiologia',            '#6B7280', 50),
      (v_cat6, v_clinic, 'Monouso e DPI',         '#8B5CF6', 60);

    -- =========================================================================
    -- PRODUCTS (22 prodotti in 6 categorie)
    -- =========================================================================

    INSERT INTO products (id, clinic_id, supplier_id, category_id, sku, name,
        description, unit, min_stock, price_unit, is_active)
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
    -- =========================================================================

    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, moved_at, created_by_provider_id)
    SELECT
        v_clinic,
        p.id,
        'carico',
        CASE p.min_stock WHEN 0 THEN 10 ELSE p.min_stock * 5 END,
        p.price_unit * 0.7,
        'DDT-INIT-001',
        'Carico iniziale magazzino',
        CURRENT_DATE - 30,
        v_pr1
    FROM products p
    WHERE p.clinic_id = v_clinic;

    -- Alcuni scarichi realistici
    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, moved_at, created_by_provider_id)
    SELECT
        v_clinic,
        p.id,
        'scarico',
        CASE p.category_id
            WHEN v_cat6 THEN 3   -- monouso: alto consumo
            WHEN v_cat2 THEN 2   -- anestesia: medio consumo
            ELSE 1               -- altri: consumo unitario
        END,
        p.price_unit * 0.7,
        NULL,
        'Utilizzo sedute',
        CURRENT_DATE - 1,
        v_pr1
    FROM products p
    WHERE p.clinic_id = v_clinic AND p.is_active = true;

    -- =========================================================================
    -- PATIENT RECALLS
    -- =========================================================================

    INSERT INTO patient_recalls (clinic_id, patient_id, provider_id, recall_type,
        status, priority, due_date, notes)
    VALUES
      -- Scaduti (urgenti)
      (v_clinic, v_p09, v_pr4, 'routine_checkup', 'pending', 'urgent',
       CURRENT_DATE - 30, 'Igiene semestrale scaduta da un mese'),
      (v_clinic, v_p13, v_pr4, 'routine_checkup', 'pending', 'urgent',
       CURRENT_DATE - 7, 'Igiene - paziente no-show da ricontattare'),

      -- In scadenza (alta priorita')
      (v_clinic, v_p15, v_pr1, 'post_treatment', 'contacted', 'high',
       CURRENT_DATE + 3, 'Follow-up post-otturazione 37'),
      (v_clinic, v_p17, v_pr4, 'routine_checkup', 'pending', 'high',
       CURRENT_DATE + 5, 'Igiene annuale - paziente anziano'),

      -- Media priorita'
      (v_clinic, v_p04, v_pr4, 'routine_checkup', 'booked', 'medium',
       CURRENT_DATE + 10, 'Igiene programmata - appuntamento fissato'),
      (v_clinic, v_p06, v_pr1, 'post_treatment', 'pending', 'medium',
       CURRENT_DATE + 14, 'Controllo post-igiene profonda'),
      (v_clinic, v_p11, v_pr4, 'routine_checkup', 'pending', 'medium',
       CURRENT_DATE + 20, 'Igiene semestrale programmata'),

      -- Bassa priorita' (futura)
      (v_clinic, v_p19, v_pr1, 'routine_checkup', 'pending', 'low',
       CURRENT_DATE + 45, 'Visita annuale di controllo'),
      (v_clinic, v_p20, v_pr3, 'orthodontic_check', 'pending', 'low',
       CURRENT_DATE + 60, 'Prima visita ortodontica di controllo'),

      -- Completati
      (v_clinic, v_p01, v_pr1, 'post_treatment', 'completed', 'low',
       CURRENT_DATE - 5, 'Follow-up completato - paziente tornato in cura');

    -- Aggiungi un contatto per il richiamo di p15
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        contacted_by_provider_id, contacted_at, notes)
    SELECT
        pr.id,
        v_clinic,
        'phone',
        'left_message',
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
ORDER BY tabella;

COMMIT;
