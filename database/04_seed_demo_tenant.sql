-- =============================================================================
-- DentalCare Pro - Seed Tenant Demo (EXPANDED)
-- File: 04_seed_demo_tenant.sql
-- Descrizione: Popola il tenant demo t_9d754153 con dati voluminosi e realistici.
--
-- Contiene:
--   - 20 pazienti, 5 provider, 25 servizi
--   - ~260 appuntamenti storici (loop 65 gg lavorativi x 4 slot/giorno)
--   - Appuntamenti futuri (2 settimane)
--   - Anamnesi per tutti i 20 pazienti
--   - Odontogramma esteso per 12 pazienti
--   - 12 piani di cura, 28 voci piano
--   - 8 preventivi + righe
--   - 10 fatture + righe (VAT 0% odontoiatrico)
--   - 25 documenti clinici
--   - 22 richiami con enum italiani corretti
--   - 15 contatti richiamo
--   - 30 voci cartella clinica
--   - 15 diagnosi, 10 prescrizioni
--
-- ENUM italiani usati (dev DB):
--   recall_status:       da_contattare, contattato, in_attesa, confermato, chiuso, annullato
--   recall_priority:     alta, media, bassa
--   recall_contact_type: telefono, sms, email, whatsapp
--   recall_outcome:      risposto, non_risposto, messaggio_lasciato, confermato, rifiutato
--   document_type:       rx_endorale, rx_panoramica, cbct, foto_clinica, foto_extraorale,
--                        documento_amministrativo, consenso_informato, referto, altro
--   appointment_status:  scheduled, confirmed, presente, in_progress, completed, cancelled, no_show
--   treatment_item_status: planned, accepted, scheduled, completed, cancelled
--   treatment_plan_status: draft, proposed, accepted, in_progress, completed, rejected, archived
--   invoice_status:      draft, issued, paid, cancelled
--   invoice_document_type: fattura, ricevuta, parcella, nota_credito
--   invoice_issuer_type: clinic, provider
--   stock_movement_type: carico, scarico, rettifica, rientro
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

SET search_path TO dentalcare, public;

INSERT INTO dentalcare.tenants (id, name, schema_name, email, phone, plan, active)
VALUES (
    'a0000001-0000-0000-0000-000000000001'::uuid,
    'Clinica Demo DentalCare',
    't_9d754153',
    'demo@dentalcare.it',
    '+39 06 5550100',
    'trial',
    true
)
ON CONFLICT (id) DO UPDATE SET active = true, name = EXCLUDED.name;

DO $$ BEGIN
    EXECUTE 'CREATE SCHEMA IF NOT EXISTS t_9d754153';
END $$;

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
DELETE FROM invoice_lines           WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM invoices                WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM estimate_lines          WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM estimates               WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM appointments            WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM treatment_plan_items    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM treatment_plans         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_diagnoses       WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
DELETE FROM patient_prescriptions   WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;
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
-- BLOCCO PRINCIPALE (tutte le variabili condivise)
-- =============================================================================

DO $$
DECLARE
    v_clinic uuid := '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid;

    -- Provider IDs
    v_pr0a uuid := 'a0000001-0000-0000-0000-000000000011'::uuid;
    v_pr1  uuid := 'b1000001-0000-0000-0000-000000000001'::uuid; -- Ferretti Laura (dentist)
    v_pr2  uuid := 'b1000001-0000-0000-0000-000000000002'::uuid; -- Marchetti Paolo (surgeon)
    v_pr3  uuid := 'b1000001-0000-0000-0000-000000000003'::uuid; -- Amato Serena (orthodontist)
    v_pr4  uuid := 'b1000001-0000-0000-0000-000000000004'::uuid; -- Gentili Michele (hygienist)

    -- Patient IDs
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

    -- Array pazienti per ciclo
    v_patients uuid[];

    -- Service catalog IDs
    v_s01 uuid := 'd1000001-0000-0000-0000-000000000001'::uuid;
    v_s02 uuid := 'd1000001-0000-0000-0000-000000000002'::uuid;
    v_s03 uuid := 'd1000001-0000-0000-0000-000000000003'::uuid;
    v_s04 uuid := 'd1000001-0000-0000-0000-000000000004'::uuid;
    v_s05 uuid := 'd1000001-0000-0000-0000-000000000005'::uuid;
    v_s06 uuid := 'd1000001-0000-0000-0000-000000000006'::uuid;
    v_s07 uuid := 'd1000001-0000-0000-0000-000000000007'::uuid;
    v_s08 uuid := 'd1000001-0000-0000-0000-000000000008'::uuid;
    v_s09 uuid := 'd1000001-0000-0000-0000-000000000009'::uuid;
    v_s10 uuid := 'd1000001-0000-0000-0000-000000000010'::uuid;
    v_s11 uuid := 'd1000001-0000-0000-0000-000000000011'::uuid;
    v_s12 uuid := 'd1000001-0000-0000-0000-000000000012'::uuid;
    v_s13 uuid := 'd1000001-0000-0000-0000-000000000013'::uuid;
    v_s14 uuid := 'd1000001-0000-0000-0000-000000000014'::uuid;
    v_s15 uuid := 'd1000001-0000-0000-0000-000000000015'::uuid;
    v_s16 uuid := 'd1000001-0000-0000-0000-000000000016'::uuid;
    v_s17 uuid := 'd1000001-0000-0000-0000-000000000017'::uuid;
    v_s18 uuid := 'd1000001-0000-0000-0000-000000000018'::uuid;
    v_s19 uuid := 'd1000001-0000-0000-0000-000000000019'::uuid;
    v_s20 uuid := 'd1000001-0000-0000-0000-000000000020'::uuid;
    v_s21 uuid := 'd1000001-0000-0000-0000-000000000021'::uuid;
    v_s22 uuid := 'd1000001-0000-0000-0000-000000000022'::uuid;
    v_s23 uuid := 'd1000001-0000-0000-0000-000000000023'::uuid;
    v_s24 uuid := 'd1000001-0000-0000-0000-000000000024'::uuid;
    v_s25 uuid := 'd1000001-0000-0000-0000-000000000025'::uuid;

    -- Treatment plan IDs
    v_tp1  uuid := 'e1000001-0000-0000-0000-000000000001'::uuid;
    v_tp2  uuid := 'e1000001-0000-0000-0000-000000000002'::uuid;
    v_tp3  uuid := 'e1000001-0000-0000-0000-000000000003'::uuid;
    v_tp4  uuid := 'e1000001-0000-0000-0000-000000000004'::uuid;
    v_tp5  uuid := 'e1000001-0000-0000-0000-000000000005'::uuid;
    v_tp6  uuid := 'e1000001-0000-0000-0000-000000000006'::uuid;
    v_tp7  uuid := 'e1000001-0000-0000-0000-000000000007'::uuid;
    v_tp8  uuid := 'e1000001-0000-0000-0000-000000000008'::uuid;
    v_tp9  uuid := 'e1000001-0000-0000-0000-000000000009'::uuid;
    v_tp10 uuid := 'e1000001-0000-0000-0000-000000000010'::uuid;
    v_tp11 uuid := 'e1000001-0000-0000-0000-000000000011'::uuid;
    v_tp12 uuid := 'e1000001-0000-0000-0000-000000000012'::uuid;

    -- Treatment plan item IDs
    v_tpi1  uuid := 'f1000001-0000-0000-0000-000000000001'::uuid;
    v_tpi2  uuid := 'f1000001-0000-0000-0000-000000000002'::uuid;
    v_tpi3  uuid := 'f1000001-0000-0000-0000-000000000003'::uuid;
    v_tpi4  uuid := 'f1000001-0000-0000-0000-000000000004'::uuid;
    v_tpi5  uuid := 'f1000001-0000-0000-0000-000000000005'::uuid;
    v_tpi6  uuid := 'f1000001-0000-0000-0000-000000000006'::uuid;
    v_tpi7  uuid := 'f1000001-0000-0000-0000-000000000007'::uuid;
    v_tpi8  uuid := 'f1000001-0000-0000-0000-000000000008'::uuid;
    v_tpi9  uuid := 'f1000001-0000-0000-0000-000000000009'::uuid;
    v_tpi10 uuid := 'f1000001-0000-0000-0000-000000000010'::uuid;
    v_tpi11 uuid := 'f1000001-0000-0000-0000-000000000011'::uuid;
    v_tpi12 uuid := 'f1000001-0000-0000-0000-000000000012'::uuid;
    v_tpi13 uuid := 'f1000001-0000-0000-0000-000000000013'::uuid;
    v_tpi14 uuid := 'f1000001-0000-0000-0000-000000000014'::uuid;
    v_tpi15 uuid := 'f1000001-0000-0000-0000-000000000015'::uuid;
    v_tpi16 uuid := 'f1000001-0000-0000-0000-000000000016'::uuid;
    v_tpi17 uuid := 'f1000001-0000-0000-0000-000000000017'::uuid;
    v_tpi18 uuid := 'f1000001-0000-0000-0000-000000000018'::uuid;
    v_tpi19 uuid := 'f1000001-0000-0000-0000-000000000019'::uuid;
    v_tpi20 uuid := 'f1000001-0000-0000-0000-000000000020'::uuid;
    v_tpi21 uuid := 'f1000001-0000-0000-0000-000000000021'::uuid;
    v_tpi22 uuid := 'f1000001-0000-0000-0000-000000000022'::uuid;
    v_tpi23 uuid := 'f1000001-0000-0000-0000-000000000023'::uuid;
    v_tpi24 uuid := 'f1000001-0000-0000-0000-000000000024'::uuid;
    v_tpi25 uuid := 'f1000001-0000-0000-0000-000000000025'::uuid;
    v_tpi26 uuid := 'f1000001-0000-0000-0000-000000000026'::uuid;
    v_tpi27 uuid := 'f1000001-0000-0000-0000-000000000027'::uuid;
    v_tpi28 uuid := 'f1000001-0000-0000-0000-000000000028'::uuid;

    -- Estimate IDs
    v_est1 uuid := 'a2000001-0000-0000-0000-000000000001'::uuid;
    v_est2 uuid := 'a2000001-0000-0000-0000-000000000002'::uuid;
    v_est3 uuid := 'a2000001-0000-0000-0000-000000000003'::uuid;
    v_est4 uuid := 'a2000001-0000-0000-0000-000000000004'::uuid;
    v_est5 uuid := 'a2000001-0000-0000-0000-000000000005'::uuid;
    v_est6 uuid := 'a2000001-0000-0000-0000-000000000006'::uuid;
    v_est7 uuid := 'a2000001-0000-0000-0000-000000000007'::uuid;
    v_est8 uuid := 'a2000001-0000-0000-0000-000000000008'::uuid;

    -- Invoice IDs
    v_inv1  uuid := 'b2000001-0000-0000-0000-000000000001'::uuid;
    v_inv2  uuid := 'b2000001-0000-0000-0000-000000000002'::uuid;
    v_inv3  uuid := 'b2000001-0000-0000-0000-000000000003'::uuid;
    v_inv4  uuid := 'b2000001-0000-0000-0000-000000000004'::uuid;
    v_inv5  uuid := 'b2000001-0000-0000-0000-000000000005'::uuid;
    v_inv6  uuid := 'b2000001-0000-0000-0000-000000000006'::uuid;
    v_inv7  uuid := 'b2000001-0000-0000-0000-000000000007'::uuid;
    v_inv8  uuid := 'b2000001-0000-0000-0000-000000000008'::uuid;
    v_inv9  uuid := 'b2000001-0000-0000-0000-000000000009'::uuid;
    v_inv10 uuid := 'b2000001-0000-0000-0000-000000000010'::uuid;

    -- Supplier / product category IDs
    v_sup1 uuid := 'a3000001-0000-0000-0000-000000000001'::uuid;
    v_sup2 uuid := 'a3000001-0000-0000-0000-000000000002'::uuid;
    v_cat1 uuid := 'a4000001-0000-0000-0000-000000000001'::uuid;
    v_cat2 uuid := 'a4000001-0000-0000-0000-000000000002'::uuid;
    v_cat3 uuid := 'a4000001-0000-0000-0000-000000000003'::uuid;
    v_cat4 uuid := 'a4000001-0000-0000-0000-000000000004'::uuid;
    v_cat5 uuid := 'a4000001-0000-0000-0000-000000000005'::uuid;
    v_cat6 uuid := 'a4000001-0000-0000-0000-000000000006'::uuid;

    -- Variabili loop
    v_i          int;
    v_work_date  date;
    v_slot       int;
    v_pat_idx    int;
    v_pat_id     uuid;
    v_prov_id    uuid;
    v_chair      text;
    v_start_t    time;
    v_end_t      time;
    v_appt_status dentalcare.appointment_status;
    v_slot_notes text;
    v_recall_id  uuid;

BEGIN

    -- =========================================================================
    -- PROVIDERS
    -- =========================================================================
    INSERT INTO providers (id, clinic_id, first_name, last_name, email, password_hash, role, phone, active)
    VALUES
      (v_pr0a, v_clinic, 'Admin',   'Demo',      'admin@demo.dentalcare.it',
       '$2b$10$UbHqgP2xq774oyP29hFhR.IsIw9vf4QWMpbpUqsuxHpDzQ3efAn7O',
       CAST('admin' AS dentalcare.provider_role), NULL, true),
      (v_pr1, v_clinic, 'Laura',   'Ferretti',   NULL, NULL, CAST('dentist'      AS dentalcare.provider_role), '+39 334 1001001', true),
      (v_pr2, v_clinic, 'Paolo',   'Marchetti',  NULL, NULL, CAST('surgeon'      AS dentalcare.provider_role), '+39 334 1001002', true),
      (v_pr3, v_clinic, 'Serena',  'Amato',      NULL, NULL, CAST('orthodontist' AS dentalcare.provider_role), '+39 334 1001003', true),
      (v_pr4, v_clinic, 'Michele', 'Gentili',    NULL, NULL, CAST('hygienist'    AS dentalcare.provider_role), '+39 334 1001004', true);

    -- =========================================================================
    -- PATIENTS (20 pazienti)
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
    -- SERVICE CATALOG (25 prestazioni)
    -- =========================================================================
    INSERT INTO service_catalog (id, clinic_id, code, name, category, default_price,
        duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, active)
    VALUES
      (v_s01, v_clinic, 'IGI-01', 'Igiene orale professionale',         'Igiene',        80.00,  45, NULL, NULL, true,  true),
      (v_s02, v_clinic, 'IGI-02', 'Igiene orale profonda',              'Igiene',       120.00,  60, NULL, NULL, true,  true),
      (v_s03, v_clinic, 'IGI-03', 'Fluoroprofilassi',                   'Igiene',        30.00,  15, NULL, NULL, true,  true),
      (v_s04, v_clinic, 'DIA-01', 'Radiografia endorale',               'Diagnostica',   25.00,  10, NULL, NULL, true,  true),
      (v_s05, v_clinic, 'DIA-02', 'Ortopantomografia',                  'Diagnostica',   80.00,  15, NULL, NULL, true,  true),
      (v_s06, v_clinic, 'DIA-03', 'CBCT arcata singola',                'Diagnostica',  180.00,  20, NULL, NULL, false, true),
      (v_s07, v_clinic, 'CON-01', 'Otturazione composito monofacciale', 'Conservativa',  90.00,  45, NULL, NULL, true,  true),
      (v_s08, v_clinic, 'CON-02', 'Otturazione composito bifacciale',   'Conservativa', 130.00,  60, NULL, NULL, true,  true),
      (v_s09, v_clinic, 'CON-03', 'Otturazione composito trifacciale',  'Conservativa', 160.00,  75, NULL, NULL, true,  true),
      (v_s10, v_clinic, 'END-01', 'Devitalizzazione monoradicolare',    'Endodonzia',   280.00,  90, 1,    5,    true,  true),
      (v_s11, v_clinic, 'END-02', 'Devitalizzazione biradicolare',      'Endodonzia',   380.00, 120, 4,    6,    false, true),
      (v_s12, v_clinic, 'END-03', 'Devitalizzazione pluriradicolare',   'Endodonzia',   480.00, 150, 6,    8,    false, true),
      (v_s13, v_clinic, 'END-04', 'Ritrattamento canalare',             'Endodonzia',   380.00, 120, NULL, NULL, false, true),
      (v_s14, v_clinic, 'PRO-01', 'Corona in zirconia',                 'Protesi',      650.00,  60, NULL, NULL, false, true),
      (v_s15, v_clinic, 'PRO-02', 'Faccetta in ceramica',               'Protesi',      550.00,  90, 1,    3,    false, true),
      (v_s16, v_clinic, 'IMP-01', 'Impianto osteointegrato',            'Implantologia',1200.00, 90, NULL, NULL, false, true),
      (v_s17, v_clinic, 'IMP-02', 'Moncone implantare',                 'Implantologia', 350.00, 45, NULL, NULL, false, true),
      (v_s18, v_clinic, 'CHI-01', 'Estrazione semplice',                'Chirurgia',    100.00,  30, NULL, NULL, true,  true),
      (v_s19, v_clinic, 'CHI-02', 'Estrazione complessa',               'Chirurgia',    200.00,  60, NULL, NULL, false, true),
      (v_s25, v_clinic, 'CHI-03', 'Rimozione punti di sutura',          'Chirurgia',     30.00,  15, NULL, NULL, true,  true),
      (v_s20, v_clinic, 'PAR-01', 'Levigatura radicolare per quadrante','Parodontologia',180.00, 60, NULL, NULL, false, true),
      (v_s21, v_clinic, 'PAR-02', 'Terapia parodontale di mantenimento','Parodontologia', 80.00, 45, NULL, NULL, false, true),
      (v_s22, v_clinic, 'ORT-01', 'Apparecchio mobile rimovibile',      'Ortodonzia',   450.00,  60, NULL, NULL, true,  true),
      (v_s23, v_clinic, 'ORT-02', 'Apparecchio fisso multibrackets',    'Ortodonzia',  2800.00,  90, NULL, NULL, false, true),
      (v_s24, v_clinic, 'EST-01', 'Sbiancamento professionale',         'Estetica',     250.00,  60, NULL, NULL, false, true);

    -- =========================================================================
    -- SERVICE BUNDLE ITEMS
    -- =========================================================================
    INSERT INTO service_bundle_items (id, clinic_id, parent_service_id, child_service_id, sort_order)
    VALUES
      (gen_random_uuid(), v_clinic, v_s18, v_s25, 10),
      (gen_random_uuid(), v_clinic, v_s19, v_s25, 10),
      (gen_random_uuid(), v_clinic, v_s10, v_s04, 10),
      (gen_random_uuid(), v_clinic, v_s10, v_s07, 20),
      (gen_random_uuid(), v_clinic, v_s11, v_s04, 10),
      (gen_random_uuid(), v_clinic, v_s12, v_s04, 10),
      (gen_random_uuid(), v_clinic, v_s16, v_s06, 10),
      (gen_random_uuid(), v_clinic, v_s16, v_s17, 20),
      (gen_random_uuid(), v_clinic, v_s16, v_s14, 30),
      (gen_random_uuid(), v_clinic, v_s02, v_s03, 10);

    -- =========================================================================
    -- CONDITION SERVICE DEFAULTS
    -- =========================================================================
    INSERT INTO condition_service_defaults (id, clinic_id, condition_name, service_id, sort_order)
    VALUES
      (gen_random_uuid(), v_clinic, 'cavity',       v_s07, 10),
      (gen_random_uuid(), v_clinic, 'cavity',       v_s04, 20),
      (gen_random_uuid(), v_clinic, 'to_extract',   v_s18, 10),
      (gen_random_uuid(), v_clinic, 'to_extract',   v_s25, 20),
      (gen_random_uuid(), v_clinic, 'root_canal',   v_s13, 10),
      (gen_random_uuid(), v_clinic, 'root_canal',   v_s04, 20),
      (gen_random_uuid(), v_clinic, 'missing',      v_s06, 10),
      (gen_random_uuid(), v_clinic, 'missing',      v_s16, 20),
      (gen_random_uuid(), v_clinic, 'missing',      v_s17, 30),
      (gen_random_uuid(), v_clinic, 'missing',      v_s14, 40),
      (gen_random_uuid(), v_clinic, 'crown',        v_s14, 10),
      (gen_random_uuid(), v_clinic, 'bridge_pillar',v_s14, 10),
      (gen_random_uuid(), v_clinic, 'bridge_pontic',v_s14, 10),
      (gen_random_uuid(), v_clinic, 'implant',      v_s06, 10),
      (gen_random_uuid(), v_clinic, 'implant',      v_s16, 20);

    -- =========================================================================
    -- TREATMENT PLANS (12 piani)
    -- =========================================================================
    INSERT INTO treatment_plans (id, clinic_id, patient_id, created_by_provider_id, name, status)
    VALUES
      (v_tp1,  v_clinic, v_p01, v_pr1, 'Piano carie multiple - Rossi Marco',          'in_progress'),
      (v_tp2,  v_clinic, v_p03, v_pr2, 'Implantologia 36 - Romano Luca',               'accepted'),
      (v_tp3,  v_clinic, v_p05, v_pr1, 'Conservativa e igiene - Ricci Andrea',         'proposed'),
      (v_tp4,  v_clinic, v_p07, v_pr3, 'Ortodonzia adulti - Greco Stefano',            'in_progress'),
      (v_tp5,  v_clinic, v_p02, v_pr1, 'Sbiancamento e faccette - Bianchi Giulia',     'draft'),
      (v_tp6,  v_clinic, v_p06, v_pr1, 'Devitalizzazione 26 - Marino Valentina',       'accepted'),
      (v_tp7,  v_clinic, v_p08, v_pr2, 'Chirurgia 18 - Bruno Francesca',               'completed'),
      (v_tp8,  v_clinic, v_p10, v_pr1, 'Carie multiple inf. - Conti Silvia',           'in_progress'),
      (v_tp9,  v_clinic, v_p11, v_pr4, 'Parodontite - De Luca Roberto',                'proposed'),
      (v_tp10, v_clinic, v_p15, v_pr1, 'Restauro molare - Rizzo Paolo',                'accepted'),
      (v_tp11, v_clinic, v_p16, v_pr2, 'Impianto 46 - Lombardi Alessia',               'in_progress'),
      (v_tp12, v_clinic, v_p18, v_pr1, 'Urgenza 26 devitalizzazione - Barbieri Sara',  'proposed');

    -- =========================================================================
    -- TREATMENT PLAN ITEMS (28 voci)
    -- =========================================================================
    INSERT INTO treatment_plan_items (id, clinic_id, treatment_plan_id, service_id,
        tooth_number, surfaces, planned_price, status, priority, completed_at)
    VALUES
      -- Piano 1: Rossi Marco
      (v_tpi1,  v_clinic, v_tp1, v_s04, '16',  NULL,               25.00,    'completed', 10,
       (CURRENT_DATE - 10)::timestamptz + TIME '10:00'),
      (v_tpi2,  v_clinic, v_tp1, v_s08, '16',  ARRAY['O','D'],    130.00,    'completed', 20,
       (CURRENT_DATE - 10)::timestamptz + TIME '10:30'),
      (v_tpi3,  v_clinic, v_tp1, v_s07, '14',  ARRAY['O'],         90.00,    'scheduled', 30, NULL),
      (v_tpi4,  v_clinic, v_tp1, v_s01, NULL,  NULL,               80.00,    'planned',   40, NULL),

      -- Piano 2: Romano Luca - impianto
      (v_tpi5,  v_clinic, v_tp2, v_s06, '36',  NULL,              180.00,    'completed', 10,
       (CURRENT_DATE - 20)::timestamptz + TIME '09:00'),
      (v_tpi6,  v_clinic, v_tp2, v_s16, '36',  NULL,             1200.00,    'scheduled', 20, NULL),
      (v_tpi7,  v_clinic, v_tp2, v_s17, '36',  NULL,              350.00,    'planned',   30, NULL),
      (v_tpi8,  v_clinic, v_tp2, v_s14, '36',  NULL,              650.00,    'planned',   40, NULL),

      -- Piano 3: Ricci Andrea
      (v_tpi9,  v_clinic, v_tp3, v_s01, NULL,  NULL,               80.00,    'planned',   10, NULL),
      (v_tpi10, v_clinic, v_tp3, v_s07, '24',  ARRAY['O'],         90.00,    'planned',   20, NULL),

      -- Piano 4: Greco Stefano - ortodonzia
      (v_tpi11, v_clinic, v_tp4, v_s23, NULL,  NULL,             2800.00,    'accepted',  10, NULL),

      -- Piano 5: Bianchi Giulia - estetica
      (v_tpi12, v_clinic, v_tp5, v_s24, NULL,  NULL,              250.00,    'planned',   10, NULL),
      (v_tpi13, v_clinic, v_tp5, v_s15, '11',  NULL,              550.00,    'planned',   20, NULL),
      (v_tpi14, v_clinic, v_tp5, v_s15, '21',  NULL,              550.00,    'planned',   30, NULL),

      -- Piano 6: Marino Valentina - devitalizzazione
      (v_tpi15, v_clinic, v_tp6, v_s04, '26',  NULL,               25.00,    'completed', 10,
       (CURRENT_DATE - 14)::timestamptz + TIME '09:00'),
      (v_tpi16, v_clinic, v_tp6, v_s12, '26',  NULL,              480.00,    'scheduled', 20, NULL),
      (v_tpi17, v_clinic, v_tp6, v_s14, '26',  NULL,              650.00,    'planned',   30, NULL),

      -- Piano 7: Bruno Francesca - chirurgia (completato)
      (v_tpi18, v_clinic, v_tp7, v_s19, '18',  NULL,              200.00,    'completed', 10,
       (CURRENT_DATE - 45)::timestamptz + TIME '10:00'),
      (v_tpi19, v_clinic, v_tp7, v_s25, '18',  NULL,               30.00,    'completed', 20,
       (CURRENT_DATE - 38)::timestamptz + TIME '10:00'),

      -- Piano 8: Conti Silvia
      (v_tpi20, v_clinic, v_tp8, v_s08, '35',  ARRAY['O','M'],    130.00,    'planned',   10, NULL),
      (v_tpi21, v_clinic, v_tp8, v_s07, '45',  ARRAY['O'],         90.00,    'planned',   20, NULL),
      (v_tpi22, v_clinic, v_tp8, v_s04, '35',  NULL,               25.00,    'planned',   30, NULL),

      -- Piano 9: De Luca Roberto - parodontite
      (v_tpi23, v_clinic, v_tp9, v_s20, NULL,  NULL,              180.00,    'planned',   10, NULL),
      (v_tpi24, v_clinic, v_tp9, v_s02, NULL,  NULL,              120.00,    'planned',   20, NULL),

      -- Piano 10: Rizzo Paolo
      (v_tpi25, v_clinic, v_tp10, v_s09, '37', ARRAY['O','M','D'],160.00,    'accepted',  10, NULL),

      -- Piano 11: Lombardi Alessia - impianto 46
      (v_tpi26, v_clinic, v_tp11, v_s06, '46', NULL,              180.00,    'completed', 10,
       (CURRENT_DATE - 7)::timestamptz + TIME '14:00'),
      (v_tpi27, v_clinic, v_tp11, v_s16, '46', NULL,             1200.00,    'scheduled', 20, NULL),

      -- Piano 12: Barbieri Sara - urgenza
      (v_tpi28, v_clinic, v_tp12, v_s10, '26', NULL,              280.00,    'planned',   10, NULL);

    -- =========================================================================
    -- ESTIMATES (8 preventivi)
    -- =========================================================================
    INSERT INTO estimates (id, clinic_id, patient_id, created_by_provider_id, treatment_plan_id,
        estimate_number, version, status, title, notes, valid_until,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency)
    VALUES
      (v_est1, v_clinic, v_p01, v_pr1, v_tp1,
       'PRE-2024-0001', 1, 'accepted', 'Preventivo piano carie - Rossi Marco',
       'Sconto 10% sul totale', CURRENT_DATE + 30,
       325.00, 32.50, 292.50, 0.00, 292.50, 'EUR'),

      (v_est2, v_clinic, v_p03, v_pr2, v_tp2,
       'PRE-2024-0002', 1, 'sent', 'Preventivo implantologia - Romano Luca',
       'Include CBCT, impianto, moncone, corona', CURRENT_DATE + 45,
       2380.00, 0.00, 2380.00, 0.00, 2380.00, 'EUR'),

      (v_est3, v_clinic, v_p05, v_pr1, v_tp3,
       'PRE-2024-0003', 1, 'draft', 'Bozza conservativa - Ricci Andrea',
       NULL, NULL,
       170.00, 0.00, 170.00, 0.00, 170.00, 'EUR'),

      (v_est4, v_clinic, v_p02, v_pr1, v_tp5,
       'PRE-2024-0004', 1, 'draft', 'Preventivo estetica - Bianchi Giulia',
       'In valutazione', CURRENT_DATE + 60,
       1350.00, 0.00, 1350.00, 0.00, 1350.00, 'EUR'),

      (v_est5, v_clinic, v_p06, v_pr1, v_tp6,
       'PRE-2024-0005', 1, 'accepted', 'Preventivo devitalizzazione 26 - Marino Valentina',
       'Urgenza - accettato immediatamente', CURRENT_DATE + 20,
       1155.00, 0.00, 1155.00, 0.00, 1155.00, 'EUR'),

      (v_est6, v_clinic, v_p08, v_pr2, v_tp7,
       'PRE-2024-0006', 1, 'accepted', 'Preventivo estrazione 18 - Bruno Francesca',
       'Procedura eseguita e completata', CURRENT_DATE - 30,
       230.00, 0.00, 230.00, 0.00, 230.00, 'EUR'),

      (v_est7, v_clinic, v_p16, v_pr2, v_tp11,
       'PRE-2024-0007', 1, 'sent', 'Preventivo impianto 46 - Lombardi Alessia',
       'Include CBCT e impianto', CURRENT_DATE + 90,
       1580.00, 0.00, 1580.00, 0.00, 1580.00, 'EUR'),

      (v_est8, v_clinic, v_p11, v_pr4, v_tp9,
       'PRE-2024-0008', 1, 'sent', 'Preventivo parodontologia - De Luca Roberto',
       'Piano parodontale completo in 4 sedute', CURRENT_DATE + 30,
       480.00, 0.00, 480.00, 0.00, 480.00, 'EUR');

    -- =========================================================================
    -- ESTIMATE LINES
    -- =========================================================================
    -- Preventivo 1 (Rossi - sconto 10% unitario)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est1, v_clinic, v_tpi1, v_s04, 'Radiografia endorale 16',              '16', 1,  25.00,  0.00, 0, 1),
      (v_est1, v_clinic, v_tpi2, v_s08, 'Otturazione composito bifacciale 16',  '16', 1, 130.00, 13.00, 0, 2),
      (v_est1, v_clinic, v_tpi3, v_s07, 'Otturazione composito monofacciale 14','14', 1,  90.00,  9.00, 0, 3),
      (v_est1, v_clinic, v_tpi4, v_s01, 'Igiene orale professionale',           NULL, 1,  80.00,  8.00, 0, 4);

    -- Preventivo 2 (Romano - impianto completo)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est2, v_clinic, v_tpi5,  v_s06, 'CBCT arcata inferiore',       '36', 1,  180.00, 0.00, 0, 1),
      (v_est2, v_clinic, v_tpi6,  v_s16, 'Impianto osteointegrato 36',  '36', 1, 1200.00, 0.00, 0, 2),
      (v_est2, v_clinic, v_tpi7,  v_s17, 'Moncone implantare 36',       '36', 1,  350.00, 0.00, 0, 3),
      (v_est2, v_clinic, v_tpi8,  v_s14, 'Corona in zirconia 36',       '36', 1,  650.00, 0.00, 0, 4);

    -- Preventivo 3 (Ricci)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est3, v_clinic, v_tpi9,  v_s01, 'Igiene orale professionale',           1,  80.00, 0.00, 0, 1),
      (v_est3, v_clinic, v_tpi10, v_s07, 'Otturazione composito monofacciale 24',1,  90.00, 0.00, 0, 2);

    -- Preventivo 4 (Bianchi - estetica)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est4, v_clinic, v_tpi12, v_s24, 'Sbiancamento professionale',      1, 250.00, 0.00, 0, 1),
      (v_est4, v_clinic, v_tpi13, v_s15, 'Faccetta in ceramica 11',         1, 550.00, 0.00, 0, 2),
      (v_est4, v_clinic, v_tpi14, v_s15, 'Faccetta in ceramica 21',         1, 550.00, 0.00, 0, 3);

    -- Preventivo 5 (Marino - devitalizzazione)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est5, v_clinic, v_tpi15, v_s04, 'Radiografia endorale 26',            '26', 1,   25.00, 0.00, 0, 1),
      (v_est5, v_clinic, v_tpi16, v_s12, 'Devitalizzazione pluriradicolare 26', '26', 1,  480.00, 0.00, 0, 2),
      (v_est5, v_clinic, v_tpi17, v_s14, 'Corona in zirconia 26',               '26', 1,  650.00, 0.00, 0, 3);

    -- Preventivo 6 (Bruno - estrazione)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est6, v_clinic, v_tpi18, v_s19, 'Estrazione complessa 18',       '18', 1, 200.00, 0.00, 0, 1),
      (v_est6, v_clinic, v_tpi19, v_s25, 'Rimozione punti di sutura 18',  '18', 1,  30.00, 0.00, 0, 2);

    -- Preventivo 7 (Lombardi - impianto 46)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, tooth_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est7, v_clinic, v_tpi26, v_s06, 'CBCT arcata inferiore',      '46', 1,  180.00, 0.00, 0, 1),
      (v_est7, v_clinic, v_tpi27, v_s16, 'Impianto osteointegrato 46', '46', 1, 1200.00, 0.00, 0, 2),
      (v_est7, v_clinic, NULL,    v_s17, 'Moncone implantare 46',      '46', 1,  350.00, 0.00, 0, 3);

    -- Preventivo 8 (De Luca - parodontologia)
    INSERT INTO estimate_lines (estimate_id, clinic_id, treatment_plan_item_id, service_id,
        description_snapshot, quantity, unit_price, discount_amount, vat_rate, line_position)
    VALUES
      (v_est8, v_clinic, v_tpi23, v_s20, 'Levigatura radicolare 4 quadranti (4 sedute)', 4, 180.00, 0.00, 0, 1),
      (v_est8, v_clinic, v_tpi24, v_s02, 'Igiene orale profonda',                         1, 120.00, 0.00, 0, 2);

    -- =========================================================================
    -- FATTURE (10 invoices + righe, VAT=0 odontoiatrico)
    -- Nota: line_subtotal, line_taxable, line_vat_amount, line_total = colonne normali
    -- =========================================================================

    -- Fattura 1: Rossi Marco - otturazioni (pagata)
    INSERT INTO invoices (id, clinic_id, patient_id, estimate_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv1, v_clinic, v_p01, v_est1,
        'FAT-2024-0001', 'fattura', CURRENT_DATE - 8, CURRENT_DATE, 'paid', 'clinic',
        'Marco Rossi', 'RSSMRC85A01H501X',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        292.50, 0.00, 292.50, 0.00, 292.50, 'EUR',
        'carta', (CURRENT_DATE - 8)::timestamptz + TIME '11:00', (CURRENT_DATE - 8)::timestamptz + TIME '11:00');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        tooth_info, quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv1, v_clinic, 1, 'Radiografia endorale 16',              '16', 1,  25.00, 0.00, 0,  25.00,  25.00, 0.00,  25.00),
      (v_inv1, v_clinic, 2, 'Otturazione composito bifacciale 16',  '16', 1, 117.00, 0.00, 0, 117.00, 117.00, 0.00, 117.00),
      (v_inv1, v_clinic, 3, 'Otturazione composito monofacciale 14','14', 1,  81.00, 0.00, 0,  81.00,  81.00, 0.00,  81.00),
      (v_inv1, v_clinic, 4, 'Igiene orale professionale',           NULL, 1,  72.00, 0.00, 0,  72.00,  72.00, 0.00,  72.00);

    -- Fattura 2: Romano Luca - CBCT (pagata parziale anticipo)
    INSERT INTO invoices (id, clinic_id, patient_id, estimate_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv2, v_clinic, v_p03, v_est2,
        'FAT-2024-0002', 'ricevuta', CURRENT_DATE - 20, CURRENT_DATE - 20, 'paid', 'clinic',
        'Luca Romano', 'RMNLCU78C03H501Z',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        180.00, 0.00, 180.00, 0.00, 180.00, 'EUR',
        'bonifico', (CURRENT_DATE - 20)::timestamptz + TIME '10:30', (CURRENT_DATE - 20)::timestamptz + TIME '10:30');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        tooth_info, quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv2, v_clinic, 1, 'CBCT arcata inferiore pre-implantare', '36', 1, 180.00, 0.00, 0, 180.00, 180.00, 0.00, 180.00);

    -- Fattura 3: Bruno Francesca - estrazione (pagata)
    INSERT INTO invoices (id, clinic_id, patient_id, estimate_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv3, v_clinic, v_p08, v_est6,
        'FAT-2024-0003', 'fattura', CURRENT_DATE - 45, CURRENT_DATE - 45, 'paid', 'clinic',
        'Francesca Bruno', 'BRNFNC95H48H501S',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        230.00, 0.00, 230.00, 0.00, 230.00, 'EUR',
        'contanti', (CURRENT_DATE - 45)::timestamptz + TIME '11:30', (CURRENT_DATE - 45)::timestamptz + TIME '11:30');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        tooth_info, quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv3, v_clinic, 1, 'Estrazione complessa dente del giudizio 18', '18', 1, 200.00, 0.00, 0, 200.00, 200.00, 0.00, 200.00),
      (v_inv3, v_clinic, 2, 'Rimozione punti di sutura 18',               '18', 1,  30.00, 0.00, 0,  30.00,  30.00, 0.00,  30.00);

    -- Fattura 4: Gallo Matteo - igiene (pagata)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv4, v_clinic, v_p09,
        'FAT-2024-0004', 'ricevuta', CURRENT_DATE - 7, CURRENT_DATE - 7, 'paid', 'clinic',
        'Matteo Gallo', 'GLLMTT82I09H501R',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        80.00, 0.00, 80.00, 0.00, 80.00, 'EUR',
        'contanti', (CURRENT_DATE - 7)::timestamptz + TIME '09:45', (CURRENT_DATE - 7)::timestamptz + TIME '09:45');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv4, v_clinic, 1, 'Igiene orale professionale semestrale', 1, 80.00, 0.00, 0, 80.00, 80.00, 0.00, 80.00);

    -- Fattura 5: Greco Stefano - controllo ortodonzia (pagata)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv5, v_clinic, v_p07,
        'FAT-2024-0005', 'ricevuta', CURRENT_DATE - 1, CURRENT_DATE - 1, 'paid', 'clinic',
        'Stefano Greco', 'GRCSFN75G07H501T',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        150.00, 0.00, 150.00, 0.00, 150.00, 'EUR',
        'carta', (CURRENT_DATE - 1)::timestamptz + TIME '10:30', (CURRENT_DATE - 1)::timestamptz + TIME '10:30');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv5, v_clinic, 1, 'Controllo mensile apparecchio fisso - archwire cambio', 1, 150.00, 0.00, 0, 150.00, 150.00, 0.00, 150.00);

    -- Fattura 6: Mancini Elena - igiene profonda (emessa non pagata)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        issued_at)
    VALUES (v_inv6, v_clinic, v_p12,
        'FAT-2024-0006', 'fattura', CURRENT_DATE - 1, CURRENT_DATE + 30, 'issued', 'clinic',
        'Elena Mancini', 'MNCLNE86B52H501N',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        120.00, 0.00, 120.00, 0.00, 120.00, 'EUR',
        (CURRENT_DATE - 1)::timestamptz + TIME '12:00');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv6, v_clinic, 1, 'Igiene orale profonda quadrante superiore sinistro', 1, 120.00, 0.00, 0, 120.00, 120.00, 0.00, 120.00);

    -- Fattura 7: Colombo Chiara - visita (bozza)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency)
    VALUES (v_inv7, v_clinic, v_p04,
        'FAT-2024-0007', 'ricevuta', CURRENT_DATE - 1, CURRENT_DATE + 15, 'draft', 'clinic',
        'Chiara Colombo', 'CLMCHR92D44H501W',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        80.00, 0.00, 80.00, 0.00, 80.00, 'EUR');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv7, v_clinic, 1, 'Visita di controllo con compilazione piano di cura', 1, 80.00, 0.00, 0, 80.00, 80.00, 0.00, 80.00);

    -- Fattura 8: Conti Silvia - otturazione (pagata)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv8, v_clinic, v_p10,
        'FAT-2024-0008', 'ricevuta', CURRENT_DATE, CURRENT_DATE, 'paid', 'clinic',
        'Silvia Conti', 'CNTSLV91L50H501Q',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        130.00, 0.00, 130.00, 0.00, 130.00, 'EUR',
        'carta', CURRENT_DATE::timestamptz + TIME '10:45', CURRENT_DATE::timestamptz + TIME '10:45');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        tooth_info, quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv8, v_clinic, 1, 'Otturazione composito bifacciale 25', '25', 1, 130.00, 0.00, 0, 130.00, 130.00, 0.00, 130.00);

    -- Fattura 9: Rizzo Paolo - igiene (pagata)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        payment_method, paid_at, issued_at)
    VALUES (v_inv9, v_clinic, v_p15,
        'FAT-2024-0009', 'ricevuta', CURRENT_DATE - 3, CURRENT_DATE - 3, 'paid', 'clinic',
        'Paolo Rizzo', 'RZZPLA70E15H501K',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        80.00, 0.00, 80.00, 0.00, 80.00, 'EUR',
        'contanti', (CURRENT_DATE - 3)::timestamptz + TIME '10:00', (CURRENT_DATE - 3)::timestamptz + TIME '10:00');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv9, v_clinic, 1, 'Igiene orale professionale', 1, 80.00, 0.00, 0, 80.00, 80.00, 0.00, 80.00);

    -- Fattura 10: Barbieri Sara - visita urgente (emessa)
    INSERT INTO invoices (id, clinic_id, patient_id,
        invoice_number, document_type, invoice_date, due_date, status, issuer_type,
        patient_full_name, patient_fiscal_code,
        issuer_name, issuer_vat_number, issuer_fiscal_code, issuer_address,
        subtotal_amount, discount_amount, taxable_amount, vat_amount, total_amount, currency,
        issued_at)
    VALUES (v_inv10, v_clinic, v_p18,
        'FAT-2024-0010', 'parcella', CURRENT_DATE, CURRENT_DATE + 15, 'issued', 'clinic',
        'Sara Barbieri', 'BRBSRA89H58H501H',
        'Clinica Demo DentalCare Roma', 'DEMO-ROMA-001', 'DEMOROMA001', 'Via Nomentana 123, 00162 Roma',
        105.00, 0.00, 105.00, 0.00, 105.00, 'EUR',
        CURRENT_DATE::timestamptz + TIME '18:30');

    INSERT INTO invoice_lines (invoice_id, clinic_id, line_position, description,
        tooth_info, quantity, unit_price, discount_amount, vat_rate,
        line_subtotal, line_taxable, line_vat_amount, line_total)
    VALUES
      (v_inv10, v_clinic, 1, 'Visita urgente dolore dente 26',  '26', 1,  80.00, 0.00, 0,  80.00,  80.00, 0.00,  80.00),
      (v_inv10, v_clinic, 2, 'Radiografia endorale urgenza 26', '26', 1,  25.00, 0.00, 0,  25.00,  25.00, 0.00,  25.00);

    -- =========================================================================
    -- APPUNTAMENTI STORICI - LOOP 65 GIORNI LAVORATIVI
    -- Crea ~260 appuntamenti completati nei 65 gg lavorativi precedenti
    -- Slot: 09:00, 10:30, 14:30, 16:00 | 4 poltrone (1-4)
    -- =========================================================================

    -- Array dei 20 pazienti
    v_patients := ARRAY[
        v_p01, v_p02, v_p03, v_p04, v_p05,
        v_p06, v_p07, v_p08, v_p09, v_p10,
        v_p11, v_p12, v_p13, v_p14, v_p15,
        v_p16, v_p17, v_p18, v_p19, v_p20
    ];

    v_work_date := CURRENT_DATE - 95; -- parte ~95 gg fa per avere ~65 lavorativi

    FOR v_i IN 0..94 LOOP
        v_work_date := CURRENT_DATE - 95 + v_i;

        -- Salta weekend
        CONTINUE WHEN EXTRACT(DOW FROM v_work_date) IN (0, 6);

        -- Slot mattino 1: 09:00-09:45
        v_pat_idx   := (v_i * 4 + 1) % 20 + 1;
        v_pat_id    := v_patients[v_pat_idx];
        v_prov_id   := CASE v_pat_idx % 4
                         WHEN 1 THEN v_pr1 WHEN 2 THEN v_pr2
                         WHEN 3 THEN v_pr3 ELSE v_pr4 END;
        v_appt_status := CASE WHEN v_i % 15 = 0 THEN 'no_show'
                              WHEN v_i % 10 = 0 THEN 'cancelled'
                              ELSE 'completed' END;
        INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
            chair_label, starts_at, ends_at, status, notes)
        VALUES (gen_random_uuid(), v_clinic, v_pat_id, v_prov_id,
            'Poltrona 1',
            v_work_date::timestamptz + TIME '09:00',
            v_work_date::timestamptz + TIME '09:45',
            v_appt_status,
            CASE v_appt_status
                WHEN 'completed'  THEN 'Seduta eseguita regolarmente'
                WHEN 'no_show'    THEN 'Paziente non presentato'
                WHEN 'cancelled'  THEN 'Annullato per indisponibilità'
            END);

        -- Slot mattino 2: 10:30-11:30
        v_pat_idx   := (v_i * 4 + 2) % 20 + 1;
        v_pat_id    := v_patients[v_pat_idx];
        v_prov_id   := CASE v_pat_idx % 4
                         WHEN 1 THEN v_pr2 WHEN 2 THEN v_pr1
                         WHEN 3 THEN v_pr4 ELSE v_pr3 END;
        v_appt_status := CASE WHEN v_i % 12 = 0 THEN 'no_show' ELSE 'completed' END;
        INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
            chair_label, starts_at, ends_at, status, notes)
        VALUES (gen_random_uuid(), v_clinic, v_pat_id, v_prov_id,
            'Poltrona 2',
            v_work_date::timestamptz + TIME '10:30',
            v_work_date::timestamptz + TIME '11:30',
            v_appt_status,
            CASE v_appt_status
                WHEN 'completed' THEN 'Trattamento eseguito correttamente'
                ELSE 'Paziente non presentato - da ricontattare'
            END);

        -- Slot pomeriggio 1: 14:30-15:15
        v_pat_idx   := (v_i * 4 + 3) % 20 + 1;
        v_pat_id    := v_patients[v_pat_idx];
        v_prov_id   := CASE v_pat_idx % 4
                         WHEN 1 THEN v_pr1 WHEN 2 THEN v_pr4
                         WHEN 3 THEN v_pr2 ELSE v_pr1 END;
        v_appt_status := CASE WHEN v_i % 20 = 0 THEN 'cancelled' ELSE 'completed' END;
        INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
            chair_label, starts_at, ends_at, status, notes)
        VALUES (gen_random_uuid(), v_clinic, v_pat_id, v_prov_id,
            'Poltrona 3',
            v_work_date::timestamptz + TIME '14:30',
            v_work_date::timestamptz + TIME '15:15',
            v_appt_status,
            CASE v_appt_status
                WHEN 'completed' THEN 'Seduta pomeridiana completata'
                ELSE 'Cancellato per emergenza studio'
            END);

        -- Slot pomeriggio 2: 16:00-17:00
        v_pat_idx   := (v_i * 4 + 4) % 20 + 1;
        v_pat_id    := v_patients[v_pat_idx];
        v_prov_id   := CASE v_pat_idx % 4
                         WHEN 1 THEN v_pr3 WHEN 2 THEN v_pr1
                         WHEN 3 THEN v_pr2 ELSE v_pr4 END;
        v_appt_status := 'completed';
        INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
            chair_label, starts_at, ends_at, status, notes)
        VALUES (gen_random_uuid(), v_clinic, v_pat_id, v_prov_id,
            'Poltrona 4',
            v_work_date::timestamptz + TIME '16:00',
            v_work_date::timestamptz + TIME '17:00',
            v_appt_status,
            'Ultima seduta della giornata - eseguita regolarmente');
    END LOOP;

    -- =========================================================================
    -- APPUNTAMENTI RECENTI E FUTURI (specifici)
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
      (gen_random_uuid(), v_clinic, v_p07, v_pr3, v_tpi11, 'Poltrona 2',
       CURRENT_DATE - 1 + TIME '10:00', CURRENT_DATE - 1 + TIME '11:00', 'completed',
       'Controllo mensile ortodonzia'),
      (gen_random_uuid(), v_clinic, v_p12, v_pr4, NULL, 'Poltrona 3',
       CURRENT_DATE - 1 + TIME '11:30', CURRENT_DATE - 1 + TIME '12:15', 'completed',
       'Igiene profonda quadrante sup. sinistro'),
      (gen_random_uuid(), v_clinic, v_p14, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE - 1 + TIME '15:00', CURRENT_DATE - 1 + TIME '15:30', 'completed',
       'Radiografia di controllo post-otturazione'),
      (gen_random_uuid(), v_clinic, v_p16, v_pr2, v_tpi26, 'Poltrona 2',
       CURRENT_DATE - 1 + TIME '16:00', CURRENT_DATE - 1 + TIME '17:00', 'completed',
       'CBCT 46 pre-impianto eseguita');

    -- Oggi
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p02, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + TIME '08:30', CURRENT_DATE + TIME '09:15', 'completed',
       'Visita estetica - raccolta impronte'),
      (gen_random_uuid(), v_clinic, v_p05, v_pr4, v_tpi9, 'Poltrona 2',
       CURRENT_DATE + TIME '09:00', CURRENT_DATE + TIME '09:45', 'completed',
       'Igiene professionale eseguita'),
      (gen_random_uuid(), v_clinic, v_p08, v_pr2, NULL, 'Poltrona 3',
       CURRENT_DATE + TIME '09:30', CURRENT_DATE + TIME '10:30', 'completed',
       'Controllo post-estrazione 18'),
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
      (gen_random_uuid(), v_clinic, v_p18, v_pr1, v_tpi28, 'Poltrona 1',
       CURRENT_DATE + TIME '16:00', CURRENT_DATE + TIME '16:30', 'confirmed',
       'Prima visita - dolore dente 26 - valutazione devitalizzazione'),
      (gen_random_uuid(), v_clinic, v_p20, v_pr3, NULL, 'Poltrona 2',
       CURRENT_DATE + TIME '17:00', CURRENT_DATE + TIME '18:00', 'confirmed',
       'Visita ortodontica per valutazione trattamento');

    -- Domani
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p06, v_pr1, v_tpi16, 'Poltrona 1',
       CURRENT_DATE + 1 + TIME '09:00', CURRENT_DATE + 1 + TIME '10:30', 'scheduled',
       'Devitalizzazione 26 pluriradicolare - prima seduta'),
      (gen_random_uuid(), v_clinic, v_p09, v_pr4, NULL, 'Poltrona 2',
       CURRENT_DATE + 1 + TIME '10:00', CURRENT_DATE + 1 + TIME '10:45', 'scheduled',
       'Igiene professionale semestrale'),
      (gen_random_uuid(), v_clinic, v_p13, v_pr2, NULL, 'Poltrona 3',
       CURRENT_DATE + 1 + TIME '14:30', CURRENT_DATE + 1 + TIME '16:00', 'scheduled',
       'Estrazione 38 incluso - riprenotato dopo no-show'),
      (gen_random_uuid(), v_clinic, v_p15, v_pr1, v_tpi25, 'Poltrona 1',
       CURRENT_DATE + 1 + TIME '15:30', CURRENT_DATE + 1 + TIME '16:30', 'scheduled',
       'Otturazione 37 trifacciale');

    -- +2 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p07, v_pr3, v_tpi11, 'Poltrona 1',
       CURRENT_DATE + 2 + TIME '09:00', CURRENT_DATE + 2 + TIME '10:00', 'scheduled',
       'Controllo mensile apparecchio fisso'),
      (gen_random_uuid(), v_clinic, v_p14, v_pr1, NULL, 'Poltrona 2',
       CURRENT_DATE + 2 + TIME '10:30', CURRENT_DATE + 2 + TIME '11:15', 'scheduled',
       'Otturazione 35 monofacciale'),
      (gen_random_uuid(), v_clinic, v_p17, v_pr2, NULL, 'Poltrona 3',
       CURRENT_DATE + 2 + TIME '15:00', CURRENT_DATE + 2 + TIME '16:00', 'scheduled',
       'Chirurgia parodontale quadrante inf. destro'),
      (gen_random_uuid(), v_clinic, v_p11, v_pr4, v_tpi23, 'Poltrona 4',
       CURRENT_DATE + 2 + TIME '16:00', CURRENT_DATE + 2 + TIME '17:00', 'scheduled',
       'Levigatura radicolare 1° quadrante');

    -- +5 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p04, v_pr4, NULL, 'Poltrona 1',
       CURRENT_DATE + 5 + TIME '09:30', CURRENT_DATE + 5 + TIME '10:15', 'scheduled',
       'Igiene professionale'),
      (gen_random_uuid(), v_clinic, v_p16, v_pr2, v_tpi27, 'Poltrona 2',
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
       'Igiene profonda completamento'),
      (gen_random_uuid(), v_clinic, v_p10, v_pr1, v_tpi20, 'Poltrona 1',
       CURRENT_DATE + 7 + TIME '14:30', CURRENT_DATE + 7 + TIME '15:30', 'scheduled',
       'Otturazione bifacciale 35');

    -- +14 giorni
    INSERT INTO appointments (id, clinic_id, patient_id, provider_id,
        treatment_plan_item_id, chair_label, starts_at, ends_at, status, notes)
    VALUES
      (gen_random_uuid(), v_clinic, v_p01, v_pr1, v_tpi4, 'Poltrona 1',
       CURRENT_DATE + 14 + TIME '09:00', CURRENT_DATE + 14 + TIME '09:45', 'scheduled',
       'Igiene di mantenimento - completamento piano cura'),
      (gen_random_uuid(), v_clinic, v_p03, v_pr2, NULL, 'Poltrona 2',
       CURRENT_DATE + 14 + TIME '10:00', CURRENT_DATE + 14 + TIME '10:30', 'scheduled',
       'Controllo post-chirurgia impianto 36'),
      (gen_random_uuid(), v_clinic, v_p06, v_pr1, v_tpi17, 'Poltrona 3',
       CURRENT_DATE + 14 + TIME '14:30', CURRENT_DATE + 14 + TIME '15:30', 'scheduled',
       'Corona 26 post-devitalizzazione - prova'),
      (gen_random_uuid(), v_clinic, v_p15, v_pr1, NULL, 'Poltrona 1',
       CURRENT_DATE + 14 + TIME '16:00', CURRENT_DATE + 14 + TIME '16:30', 'scheduled',
       'Controllo post-otturazione 37');

    -- =========================================================================
    -- ANAMNESI (tutti 20 pazienti)
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
       false, false, false, false, NULL, true, CURRENT_DATE - 60),
      -- Pazienti 11-20
      (gen_random_uuid(), v_clinic, v_p11, v_pr4,
       'A+', true, true, false, false, false, false,
       false, false, false, false, 'Codeina', true, CURRENT_DATE - 120),
      (gen_random_uuid(), v_clinic, v_p12, v_pr4,
       'B+', false, false, false, false, false, false,
       true, false, false, false, NULL, true, CURRENT_DATE - 80),
      (gen_random_uuid(), v_clinic, v_p13, v_pr1,
       '0+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 250),
      (gen_random_uuid(), v_clinic, v_p14, v_pr1,
       'AB+', false, false, false, false, false, false,
       false, true, false, false, NULL, true, CURRENT_DATE - 35),
      (gen_random_uuid(), v_clinic, v_p15, v_pr1,
       'A-', false, true, true, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 500),
      (gen_random_uuid(), v_clinic, v_p16, v_pr2,
       '0-', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 15),
      (gen_random_uuid(), v_clinic, v_p17, v_pr2,
       'A+', false, true, false, true, true, false,
       false, false, false, false, 'Penicillina e derivati', true, CURRENT_DATE - 600),
      (gen_random_uuid(), v_clinic, v_p18, v_pr1,
       'B+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE),
      (gen_random_uuid(), v_clinic, v_p19, v_pr1,
       '0+', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 70),
      (gen_random_uuid(), v_clinic, v_p20, v_pr3,
       'AB-', false, false, false, false, false, false,
       false, false, false, false, NULL, true, CURRENT_DATE - 10);

    -- =========================================================================
    -- ODONTOGRAMMA (12 pazienti, dati estesi)
    -- =========================================================================
    INSERT INTO odontogram_teeth (clinic_id, patient_id, tooth_number, quadrant, condition, surfaces, notes,
        recorded_by_provider_id, recorded_at)
    VALUES
      -- p01: Rossi Marco - carie e otturazioni
      (v_clinic, v_p01, '16', 1, 'filling',    ARRAY['O','D'],     'Otturazione composito recente', v_pr1, CURRENT_DATE - 3),
      (v_clinic, v_p01, '14', 1, 'caries',     ARRAY['O'],         'Carie intercuspale iniziale',   v_pr1, CURRENT_DATE - 3),
      (v_clinic, v_p01, '36', 3, 'healthy',    NULL,               NULL,                            v_pr1, CURRENT_DATE - 365),
      (v_clinic, v_p01, '46', 4, 'filling',    ARRAY['O'],         'Otturazione amalgama vecchia',  v_pr1, CURRENT_DATE - 365),
      (v_clinic, v_p01, '26', 2, 'healthy',    NULL,               NULL,                            v_pr1, CURRENT_DATE - 365),
      (v_clinic, v_p01, '47', 4, 'caries',     ARRAY['M'],         'Carie mesiale iniziale',        v_pr1, CURRENT_DATE - 3),

      -- p02: Bianchi Giulia - estetica frontale
      (v_clinic, v_p02, '11', 1, 'healthy',    NULL,               'Valutazione faccetta',          v_pr1, CURRENT_DATE - 180),
      (v_clinic, v_p02, '21', 2, 'healthy',    NULL,               'Valutazione faccetta',          v_pr1, CURRENT_DATE - 180),
      (v_clinic, v_p02, '12', 1, 'filling',    ARRAY['M'],         'Otturazione vecchia',           v_pr1, CURRENT_DATE - 180),
      (v_clinic, v_p02, '22', 2, 'filling',    ARRAY['M'],         'Otturazione vecchia',           v_pr1, CURRENT_DATE - 180),

      -- p03: Romano Luca - impianto in pianificazione
      (v_clinic, v_p03, '36', 3, 'missing',    NULL,               'Sito implantare - pianificato', v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '37', 3, 'healthy',    NULL,               NULL,                            v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '46', 4, 'crown',      NULL,               'Corona in PFM 2018',            v_pr2, CURRENT_DATE - 20),
      (v_clinic, v_p03, '17', 1, 'filling',    ARRAY['O','D','M'], 'Otturazione ampia',             v_pr2, CURRENT_DATE - 20),

      -- p05: Ricci Andrea - fumatore, gengivite
      (v_clinic, v_p05, '11', 1, 'healthy',    NULL,               NULL,                            v_pr4, CURRENT_DATE - 150),
      (v_clinic, v_p05, '16', 1, 'filling',    ARRAY['O'],         'Piccola otturazione',           v_pr4, CURRENT_DATE - 150),
      (v_clinic, v_p05, '26', 2, 'caries',     ARRAY['O'],         'Carie iniziale intercuspale',   v_pr4, CURRENT_DATE - 150),

      -- p06: Marino Valentina - devitalizzazione
      (v_clinic, v_p06, '26', 2, 'devitalized', NULL,              'Devitalizzazione in corso',     v_pr1, CURRENT_DATE - 14),
      (v_clinic, v_p06, '25', 2, 'filling',    ARRAY['O'],         'Otturazione esistente',         v_pr1, CURRENT_DATE - 14),
      (v_clinic, v_p06, '27', 2, 'healthy',    NULL,               NULL,                            v_pr1, CURRENT_DATE - 14),

      -- p07: Greco Stefano - in ortodonzia
      (v_clinic, v_p07, '13', 1, 'healthy',    NULL,               'Con bracket',                   v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '23', 2, 'healthy',    NULL,               'Con bracket',                   v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '34', 3, 'healthy',    NULL,               'Con bracket',                   v_pr3, CURRENT_DATE - 300),
      (v_clinic, v_p07, '43', 4, 'healthy',    NULL,               'Con bracket',                   v_pr3, CURRENT_DATE - 300),

      -- p08: Bruno Francesca - post-estrazione
      (v_clinic, v_p08, '18', 1, 'missing',    NULL,               'Estratto 45 gg fa',             v_pr2, CURRENT_DATE - 45),
      (v_clinic, v_p08, '17', 1, 'filling',    ARRAY['O','D'],     'Otturazione composito',         v_pr2, CURRENT_DATE - 45),

      -- p10: Conti Silvia - carie multiple
      (v_clinic, v_p10, '35', 3, 'caries',     ARRAY['O','M'],     'Carie bifacciale',              v_pr1, CURRENT_DATE - 60),
      (v_clinic, v_p10, '45', 4, 'caries',     ARRAY['O'],         'Carie occlusale',               v_pr1, CURRENT_DATE - 60),
      (v_clinic, v_p10, '25', 2, 'filling',    ARRAY['O'],         'Otturazione recente',           v_pr1, CURRENT_DATE),

      -- p11: De Luca Roberto - parodontite
      (v_clinic, v_p11, '31', 3, 'healthy',    NULL,               'Recessione gengivale 2mm',      v_pr4, CURRENT_DATE - 120),
      (v_clinic, v_p11, '41', 4, 'healthy',    NULL,               'Recessione gengivale 1mm',      v_pr4, CURRENT_DATE - 120),
      (v_clinic, v_p11, '36', 3, 'filling',    ARRAY['O'],         'Otturazione vecchia',           v_pr4, CURRENT_DATE - 120),

      -- p16: Lombardi Alessia - impianto 46
      (v_clinic, v_p16, '46', 4, 'missing',    NULL,               'Sito impianto in programma',   v_pr2, CURRENT_DATE - 15),
      (v_clinic, v_p16, '47', 4, 'healthy',    NULL,               NULL,                            v_pr2, CURRENT_DATE - 15),

      -- p18: Barbieri Sara - urgenza
      (v_clinic, v_p18, '26', 2, 'caries',     ARRAY['O','M','D'], 'Carie profonda - dolore',       v_pr1, CURRENT_DATE),
      (v_clinic, v_p18, '25', 2, 'devitalized', NULL,              'Devitalizzazione precedente',   v_pr1, CURRENT_DATE),
      (v_clinic, v_p18, '27', 2, 'healthy',    NULL,               NULL,                            v_pr1, CURRENT_DATE);

    -- =========================================================================
    -- CARTELLA CLINICA (30 voci)
    -- =========================================================================
    INSERT INTO clinical_history_entries (clinic_id, patient_id, provider_id,
        entry_date, tooth_number, service_name, clinical_notes)
    VALUES
      (v_clinic, v_p01, v_pr1, CURRENT_DATE - 10, '16', 'Radiografia endorale',
       'RX 16: carie distale profonda coinvolgente la dentina. Pianificata otturazione bifacciale.'),
      (v_clinic, v_p01, v_pr1, CURRENT_DATE - 3, '16', 'Otturazione composito bifacciale',
       'Otturazione composito bifacciale completata su 16. Paziente ha tollerato bene la seduta. Nessuna complicazione.'),
      (v_clinic, v_p01, v_pr1, CURRENT_DATE - 3, NULL, NULL,
       'Piano di cura in corso. Ancora da trattare: 14 monofacciale. Programmata igiene di mantenimento tra 2 settimane.'),
      (v_clinic, v_p02, v_pr1, CURRENT_DATE - 180, NULL, 'Prima visita',
       'Prima visita paziente. Interesse per trattamenti estetici. Presentate opzioni sbiancamento e faccette 11-21.'),
      (v_clinic, v_p03, v_pr2, CURRENT_DATE - 20, '36', 'CBCT pre-implantare',
       'CBCT eseguita. Osso disponibile: altezza 12mm, larghezza 7mm. Pianificata inserzione impianto 3.8x11mm.'),
      (v_clinic, v_p03, v_pr2, CURRENT_DATE - 3, '36', 'Programmazione impianto',
       'Discusso piano implantare con paziente. Accettato preventivo. Fissata data intervento per oggi.'),
      (v_clinic, v_p04, v_pr1, CURRENT_DATE - 200, NULL, 'Prima visita',
       'Prima visita. Allergia anestetici locali di tipo amidico: verificare uso anestetici esteri. Annotata in anamnesi.'),
      (v_clinic, v_p05, v_pr4, CURRENT_DATE - 150, NULL, 'Visita parodontale',
       'Paziente fumatore. Gengivite generalizzata da placca. Istruzione igiene orale. Programmata igiene profonda.'),
      (v_clinic, v_p06, v_pr1, CURRENT_DATE - 14, '26', 'Visita urgente',
       'Paziente con dolore acuto 26 da 5 gg. RX: carie profonda con probabile interessamento pulpare. Indicata devitalizzazione.'),
      (v_clinic, v_p06, v_pr4, CURRENT_DATE - 3, NULL, 'Igiene orale',
       'Prima igiene professionale. Abbondante tartaro sopragengivale. Istruita sulla tecnica di spazzolamento.'),
      (v_clinic, v_p07, v_pr3, CURRENT_DATE - 300, NULL, 'Visita ortodontica',
       'Prima valutazione ortodontica. Malocclusione classe I con affollamento moderato. Proposto trattamento con apparecchio fisso.'),
      (v_clinic, v_p07, v_pr3, CURRENT_DATE - 1, NULL, 'Controllo ortodonzia mensile',
       'Allineamento progredisce regolarmente. Sostituito archwire 0.16 NiTi. Lieve dolore previsto per 48h. Prossimo controllo tra 4 settimane.'),
      (v_clinic, v_p08, v_pr2, CURRENT_DATE - 45, '18', 'Estrazione complessa 18',
       'Estrazione dente 18 incluso mesioangolato. Osteotomia + odontotomia. Sutura 3/0 Vicryl x3. Istruzioni post-op fornite.'),
      (v_clinic, v_p08, v_pr2, CURRENT_DATE - 38, '18', 'Rimozione punti 18',
       'Guarigione regolare. Rimossi 3 punti Vicryl. Mucosa integra. Nessuna complicazione.'),
      (v_clinic, v_p08, v_pr1, CURRENT_DATE - 30, NULL, 'Annotazione',
       'ATTENZIONE: paziente in terapia con bifosfonati e patologia cardiaca. Consultare cardiologo prima di qualsiasi chirurgia futura.'),
      (v_clinic, v_p09, v_pr4, CURRENT_DATE - 7, NULL, 'Igiene professionale',
       'Igiene semestrale. Buona compliance igienica domiciliare. Lieve tartaro interdentale sup. Nessuna carie rilevata.'),
      (v_clinic, v_p10, v_pr1, CURRENT_DATE - 60, NULL, 'Visita diagnosi carie',
       'RX evidenzia carie 35 bifacciale e 45 occlusale. Pianificato programma restaurativo in 2 sedute.'),
      (v_clinic, v_p10, v_pr1, CURRENT_DATE, '25', 'Otturazione composito bifacciale',
       'Otturazione composito A2 su 25 bifacciale. Isolamento con diga. Buon risultato estetico e occlusale.'),
      (v_clinic, v_p11, v_pr4, CURRENT_DATE - 120, NULL, 'Visita parodontale',
       'Parodontite cronica generalizzata moderata. BOP 60%. Tasche 4-6mm in zona 31-41. Pianificato SRP 4 quadranti.'),
      (v_clinic, v_p12, v_pr4, CURRENT_DATE - 1, NULL, 'Igiene profonda',
       'SRP quadrante superiore sinistro completato. Buona risposta dei tessuti. Seconda seduta pianificata per completare arcata.'),
      (v_clinic, v_p13, v_pr2, CURRENT_DATE - 250, NULL, 'Prima visita',
       'Prima visita. Paziente in buona salute generale. Nessuna patologia significativa. Igiene orale migliorabile.'),
      (v_clinic, v_p14, v_pr1, CURRENT_DATE - 1, NULL, 'Radiografia controllo',
       'RX controllo post-otturazione: contatti prossimali corretti, margini ben sigillati. Tutto nella norma.'),
      (v_clinic, v_p15, v_pr1, CURRENT_DATE - 3, '37', 'Visita pre-restauro',
       'Esaminato 37: carie trifacciale estesa. Pianificata otturazione composito in prossima seduta.'),
      (v_clinic, v_p16, v_pr2, CURRENT_DATE - 1, '46', 'CBCT pre-impianto',
       'CBCT 46: osso disponibile 13mm altezza, 8mm larghezza. Ottimo sito implantare. Programmato intervento tra 5 gg.'),
      (v_clinic, v_p17, v_pr2, CURRENT_DATE - 600, NULL, 'Annotazione importante',
       'Paziente anziano (61aa). Ipertensione in terapia, cardiopatico, anticoagulante. Allergia penicillina. MAX ATTENZIONE in chirurgia.'),
      (v_clinic, v_p18, v_pr1, CURRENT_DATE, '26', 'Visita urgente',
       'Dolore acuto 26 da 3 gg. RX: carie profonda prossima alla polpa. Probabile devitalizzazione necessaria. Programmata per oggi pomeriggio.'),
      (v_clinic, v_p19, v_pr1, CURRENT_DATE - 70, NULL, 'Prima visita',
       'Prima visita. Paziente in buona salute. Ultima visita odontoiatrica 3 anni fa. Controllo completo effettuato.'),
      (v_clinic, v_p20, v_pr3, CURRENT_DATE - 10, NULL, 'Prima visita ortodontica',
       'Prima valutazione. Malocclusione classe II div. 1. Affollamento severo arcata superiore. Programmato approfondimento con radiografie.'),
      (v_clinic, v_p15, v_pr1, CURRENT_DATE - 500, NULL, 'Annotazione cronologia',
       'Paziente con diabete tipo 2 e ipertensione in compenso. Monitorare guarigione in seguito a trattamenti chirurgici.'),
      (v_clinic, v_p17, v_pr3, CURRENT_DATE - 7, NULL, 'Controllo ortodonzia adulti',
       'Paziente non in trattamento ortodontico attivo. Valutazione crowding anteriore inferiore. Escluso trattamento per età e compliance prevista.');

    -- =========================================================================
    -- SUPPLIERS E MAGAZZINO
    -- =========================================================================
    INSERT INTO suppliers (id, clinic_id, name, contact_person, phone, email, is_active)
    VALUES
      (v_sup1, v_clinic, 'Dental Supply Italia S.r.l.',
       'Marco Betti', '+39 06 5550200', 'ordini@dentalsupply.it', true),
      (v_sup2, v_clinic, 'Implantec Medical S.p.A.',
       'Anna Ferrara', '+39 02 5550300', 'ordini@implantec.it', true);

    INSERT INTO product_categories (id, clinic_id, name)
    VALUES
      (v_cat1, v_clinic, 'Materiali Compositi'),
      (v_cat2, v_clinic, 'Anestesia'),
      (v_cat3, v_clinic, 'Igiene Professionale'),
      (v_cat4, v_clinic, 'Chirurgia'),
      (v_cat5, v_clinic, 'Radiologia'),
      (v_cat6, v_clinic, 'Monouso e DPI');

    INSERT INTO products (id, clinic_id, supplier_id, category_id, sku, name,
        description, unit, min_stock_quantity, unit_cost, is_active)
    VALUES
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'COMP-A2-4G',    'Filtek Supreme A2 4g',               'Composito universale 3M', 'siringa',    5, 38.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'COMP-A3-4G',    'Filtek Supreme A3 4g',               'Composito universale 3M', 'siringa',    5, 38.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'BOND-SBU',      'Single Bond Universal 5ml',          'Adesivo universale 3M',   'flacone',    3, 52.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat1, 'ETCH-GEL',      'Gel mordenzante 37% 5ml',            'Acido ortofosforico 37%', 'siringa',   10,  8.50, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'ANEST-ART-100', 'Articaina 4% 1:100.000 bx50',        'Carpule anestesia',       'confezione', 3, 45.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'ANEST-ART-200', 'Articaina 4% 1:200.000 bx50',        'Vasocostrittore ridotto', 'confezione', 2, 45.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'AGO-SHORT',     'Aghi 30G corti bx100',               'Aghi siringa carpule',    'confezione', 5, 12.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat2, 'AGO-LONG',      'Aghi 27G lunghi bx100',              'Aghi blocco mandibolare', 'confezione', 3, 12.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'PAS-IGIENE-C',  'Pasta lucidante grossolana 200g',    'Pasta profilassi grossa', 'vaso',       5, 18.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'PAS-IGIENE-F',  'Pasta lucidante fine 200g',          'Pasta profilassi fine',   'vaso',       5, 18.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'FLUORO-GEL',    'Gel fluoruro 1,23% 200g',            'Fluoruro professionale',  'vaso',       3, 22.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat3, 'COPETTE-PL',    'Copette profilassi bx144',           'Copette monouso',         'confezione', 4, 14.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat4, 'SUTURA-4-0',    'Filo sutura 4/0 VICRYL bx36',        'Sutura riassorbibile',    'confezione', 3, 48.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat4, 'SUTURA-3-0',    'Filo sutura 3/0 VICRYL bx36',        'Calibro maggiore',        'confezione', 2, 48.00, true),
      (gen_random_uuid(), v_clinic, v_sup2, v_cat4, 'IMP-3811',      'Impianto Straumann BLT 3.8x11',      'Tissue level TL',         'pezzo',      2,320.00, true),
      (gen_random_uuid(), v_clinic, v_sup2, v_cat4, 'IMP-4111',      'Impianto Straumann BLT 4.1x11',      'Tissue level TL',         'pezzo',      2,320.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat5, 'PELLICOLA-E0',  'Pellicole endorali E-speed bx150',   'Pellicole radiografiche', 'confezione', 2, 85.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat5, 'GUANTI-RX',     'Guanti piombo 0.5mm taglia M',       'Protezione radiazioni',   'paio',       2, 95.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'GUANTI-NIT-M',  'Guanti nitrile M bx100',             'Guanti senza polvere',    'confezione',10,  8.50, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'GUANTI-NIT-L',  'Guanti nitrile L bx100',             'Guanti senza polvere',    'confezione', 8,  8.50, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'MASCHERINE-FF', 'Mascherine FFP2 bx10',               'FFP2 certificate',        'confezione',20, 12.00, true),
      (gen_random_uuid(), v_clinic, v_sup1, v_cat6, 'BAVAGLIO',      'Bavagli plastificati bx500',         'Bavagli monouso',         'confezione', 5, 18.00, true);

    -- Stock movements: carico iniziale
    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, created_by_provider_id)
    SELECT v_clinic, p.id, 'carico',
        CASE p.min_stock_quantity WHEN 0 THEN 10 ELSE p.min_stock_quantity * 5 END,
        p.unit_cost * 0.7, 'DDT-INIT-001', 'Carico iniziale magazzino', v_pr1
    FROM products p WHERE p.clinic_id = v_clinic;

    -- Scarichi realistici
    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, created_by_provider_id)
    SELECT v_clinic, p.id, 'scarico',
        CASE p.category_id
            WHEN v_cat6 THEN 3 WHEN v_cat2 THEN 2 ELSE 1 END,
        p.unit_cost * 0.7, NULL, 'Utilizzo sedute settimana 1', v_pr1
    FROM products p WHERE p.clinic_id = v_clinic AND p.is_active = true;

    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, created_by_provider_id)
    SELECT v_clinic, p.id, 'scarico',
        CASE p.category_id
            WHEN v_cat6 THEN 4 WHEN v_cat2 THEN 3 ELSE 1 END,
        p.unit_cost * 0.7, NULL, 'Utilizzo sedute settimana 2', v_pr1
    FROM products p WHERE p.clinic_id = v_clinic AND p.is_active = true;

    -- Rettifica inventario
    INSERT INTO stock_movements (clinic_id, product_id, movement_type, quantity, unit_cost,
        reference_doc, notes, created_by_provider_id)
    SELECT v_clinic, p.id, 'rettifica', 2, p.unit_cost * 0.7,
        'INV-2024-01', 'Rettifica inventario mensile', v_pr0a
    FROM products p WHERE p.clinic_id = v_clinic AND p.sku IN ('COMP-A2-4G','ANEST-ART-100','MASCHERINE-FF');

    -- =========================================================================
    -- PATIENT RECALLS (22 richiami, enum italiani corretti)
    -- =========================================================================
    INSERT INTO patient_recalls (clinic_id, patient_id, recall_type,
        status, priority, due_date, notes)
    VALUES
      -- Scaduti (alta priorità)
      (v_clinic, v_p09, 'Controllo periodico',
       'da_contattare', 'alta', CURRENT_DATE - 30,
       'Igiene semestrale scaduta da un mese - paziente non risponde'),
      (v_clinic, v_p13, 'Controllo periodico',
       'da_contattare', 'alta', CURRENT_DATE - 7,
       'Igiene - paziente no-show - da ricontattare urgente'),
      (v_clinic, v_p17, 'Controllo post-trattamento',
       'contattato', 'alta', CURRENT_DATE - 3,
       'Controllo parodontale - paziente anziano con comorbidità'),

      -- In scadenza questa settimana
      (v_clinic, v_p15, 'Controllo post-trattamento',
       'contattato', 'media', CURRENT_DATE + 3,
       'Follow-up post-otturazione 37 - confermato per domani'),
      (v_clinic, v_p04, 'Controllo periodico',
       'confermato', 'media', CURRENT_DATE + 5,
       'Igiene programmata - appuntamento fissato'),
      (v_clinic, v_p06, 'Controllo post-trattamento',
       'da_contattare', 'media', CURRENT_DATE + 7,
       'Controllo post-igiene profonda e devitalizzazione 26'),

      -- Questo mese
      (v_clinic, v_p11, 'Controllo periodico',
       'da_contattare', 'media', CURRENT_DATE + 10,
       'Igiene semestrale - paziente con parodontite cronica'),
      (v_clinic, v_p12, 'Controllo post-trattamento',
       'contattato', 'media', CURRENT_DATE + 14,
       'Controllo post-SRP - valutare risposta parodontale'),
      (v_clinic, v_p03, 'Controllo post-trattamento',
       'confermato', 'alta', CURRENT_DATE + 14,
       'Controllo post-impianto 36 - fondamentale per osteointegrazione'),
      (v_clinic, v_p16, 'Controllo post-trattamento',
       'da_contattare', 'alta', CURRENT_DATE + 21,
       'Controllo post-impianto 46 - pianificato tra 3 settimane'),

      -- Medio termine (1-2 mesi)
      (v_clinic, v_p08, 'Controllo periodico',
       'da_contattare', 'bassa', CURRENT_DATE + 30,
       'Visita annuale di controllo - ultimo accesso 6 mesi fa'),
      (v_clinic, v_p10, 'Controllo post-trattamento',
       'da_contattare', 'media', CURRENT_DATE + 21,
       'Controllo carie 35 e 45 dopo restauro'),
      (v_clinic, v_p19, 'Controllo periodico',
       'da_contattare', 'bassa', CURRENT_DATE + 45,
       'Visita annuale di controllo'),
      (v_clinic, v_p14, 'Controllo periodico',
       'da_contattare', 'bassa', CURRENT_DATE + 35,
       'Igiene semestrale - buona compliance'),

      -- Lungo termine (2-3 mesi)
      (v_clinic, v_p20, 'Controllo ortodontico',
       'da_contattare', 'bassa', CURRENT_DATE + 60,
       'Prima visita ortodontica di controllo post-valutazione'),
      (v_clinic, v_p05, 'Controllo periodico',
       'da_contattare', 'media', CURRENT_DATE + 30,
       'Richiamo igiene - paziente fumatore, rischio parodontale'),
      (v_clinic, v_p07, 'Controllo ortodontico',
       'confermato', 'media', CURRENT_DATE + 30,
       'Controllo mensile apparecchio fisso - già programmato'),
      (v_clinic, v_p02, 'Controllo estetico',
       'in_attesa', 'bassa', CURRENT_DATE + 45,
       'Follow-up valutazione faccette - in attesa risposta preventivo'),

      -- Chiusi/completati
      (v_clinic, v_p01, 'Controllo post-trattamento',
       'chiuso', 'bassa', CURRENT_DATE - 5,
       'Follow-up completato - paziente tornato in cura regolare'),
      (v_clinic, v_p08, 'Controllo post-chirurgia',
       'chiuso', 'alta', CURRENT_DATE - 38,
       'Controllo post-estrazione 18 completato - guarigione ok'),

      -- Annullati
      (v_clinic, v_p13, 'Controllo periodico',
       'annullato', 'media', CURRENT_DATE - 60,
       'Paziente trasferito ad altro studio - chiuso'),
      (v_clinic, v_p17, 'Controllo periodico',
       'annullato', 'bassa', CURRENT_DATE - 90,
       'Doppio richiamo - eliminato duplicato');

    -- =========================================================================
    -- RECALL CONTACTS (15 contatti con enum italiani corretti)
    -- =========================================================================

    -- Contatti per p09 (da_contattare, scaduto)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'non_risposto', v_pr4,
        now() - INTERVAL '25 days', 'Nessuna risposta - squillato 3 volte'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p09 AND pr.status = 'da_contattare'
    LIMIT 1;

    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'sms', 'risposto', v_pr4,
        now() - INTERVAL '20 days', 'SMS inviato - risposto che richiamerà ma non l''ha fatto'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p09 AND pr.status = 'da_contattare'
    LIMIT 1;

    -- Contatti per p13 (no-show)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'messaggio_lasciato', v_pr4,
        now() - INTERVAL '5 days', 'Lasciato messaggio in segreteria per riprenotare'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p13 AND pr.status = 'da_contattare'
    LIMIT 1;

    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'whatsapp', 'risposto', v_pr4,
        now() - INTERVAL '2 days', 'Risposto via WhatsApp - disponibile venerdì mattina'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p13 AND pr.status = 'da_contattare'
    LIMIT 1;

    -- Contatti per p15 (contattato)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'messaggio_lasciato', v_pr4,
        now() - INTERVAL '2 days', 'Lasciato messaggio in segreteria'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p15 AND pr.status = 'contattato'
    LIMIT 1;

    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'confermato', v_pr4,
        now() - INTERVAL '1 day', 'Paziente richiamato - confermato appuntamento per domani'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p15 AND pr.status = 'contattato'
    LIMIT 1;

    -- Contatti per p17
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'risposto', v_pr0a,
        now() - INTERVAL '2 days', 'Paziente contattato - preferisce email per comunicazioni'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p17 AND pr.status = 'contattato'
    LIMIT 1;

    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'email', 'risposto', v_pr0a,
        now() - INTERVAL '1 day', 'Email inviata con disponibilità orari - risposto positivamente'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p17 AND pr.status = 'contattato'
    LIMIT 1;

    -- Contatti per p04 (confermato)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'sms', 'confermato', v_pr0a,
        now() - INTERVAL '3 days', 'SMS promemoria inviato - confermato via risposta SMS'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p04 AND pr.status = 'confermato'
    LIMIT 1;

    -- Contatti per p03 (impianto, confermato)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'confermato', v_pr0a,
        now() - INTERVAL '1 day', 'Confermato controllo post-impianto tra 2 settimane'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p03 AND pr.status = 'confermato'
    LIMIT 1;

    -- Contatti per p12
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'whatsapp', 'risposto', v_pr4,
        now() - INTERVAL '5 days', 'Inviato messaggio WhatsApp per controllo SRP - risposto ok'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p12 AND pr.status = 'contattato'
    LIMIT 1;

    -- Contatti per p07 (ortodonzia, confermato)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'sms', 'confermato', v_pr0a,
        now() - INTERVAL '4 days', 'Promemoria mensile inviato - confermato come di consueto'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p07 AND pr.status = 'confermato'
    LIMIT 1;

    -- Contatti per p02 (in_attesa estetica)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'email', 'risposto', v_pr0a,
        now() - INTERVAL '7 days', 'Email con preventivo inviata - paziente sta valutando'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p02 AND pr.status = 'in_attesa'
    LIMIT 1;

    -- Contatti per p06 (da_contattare post-cura)
    INSERT INTO recall_contacts (recall_id, clinic_id, contact_type, outcome,
        created_by_provider_id, contact_at, notes)
    SELECT pr.id, v_clinic, 'telefono', 'non_risposto', v_pr4,
        now() - INTERVAL '1 day', 'Nessuna risposta - riprovare domani'
    FROM patient_recalls pr
    WHERE pr.clinic_id = v_clinic AND pr.patient_id = v_p06
      AND pr.status = 'da_contattare' AND pr.due_date > CURRENT_DATE
    ORDER BY pr.due_date
    LIMIT 1;

    -- =========================================================================
    -- DOCUMENTI CLINICI (25 documenti)
    -- =========================================================================
    INSERT INTO patient_documents (clinic_id, patient_id, uploaded_by_provider_id,
        document_type, filename, notes, uploaded_at)
    VALUES
      -- p01: Rossi Marco
      (v_clinic, v_p01, v_pr1, 'rx_endorale',           'rx_16_rossi_2024.jpg',
       'RX endorale elemento 16 pre-otturazione', (CURRENT_DATE - 10)::timestamptz + TIME '10:00'),
      (v_clinic, v_p01, v_pr1, 'consenso_informato',    'consenso_rossi_2024.pdf',
       'Consenso informato piano di cura', (CURRENT_DATE - 365)::timestamptz + TIME '09:00'),
      (v_clinic, v_p01, v_pr1, 'foto_clinica',          'foto_16_rossi_post.jpg',
       'Foto post-otturazione 16', (CURRENT_DATE - 3)::timestamptz + TIME '10:30'),

      -- p02: Bianchi Giulia
      (v_clinic, v_p02, v_pr1, 'foto_clinica',          'foto_frontale_bianchi.jpg',
       'Foto frontale sorriso per valutazione estetica', (CURRENT_DATE - 180)::timestamptz + TIME '09:00'),
      (v_clinic, v_p02, v_pr1, 'foto_extraorale',       'foto_profilo_bianchi.jpg',
       'Foto profilo sinistro per valutazione', (CURRENT_DATE - 180)::timestamptz + TIME '09:05'),

      -- p03: Romano Luca
      (v_clinic, v_p03, v_pr2, 'cbct',                  'cbct_36_romano_2024.dcm',
       'CBCT arcata inferiore pre-impianto 36', (CURRENT_DATE - 20)::timestamptz + TIME '09:00'),
      (v_clinic, v_p03, v_pr2, 'rx_panoramica',         'ortopan_romano_2024.jpg',
       'Ortopantomografia di inquadramento', (CURRENT_DATE - 25)::timestamptz + TIME '08:30'),
      (v_clinic, v_p03, v_pr2, 'consenso_informato',    'consenso_impianto_romano.pdf',
       'Consenso informato procedura implantare', (CURRENT_DATE - 20)::timestamptz + TIME '09:30'),

      -- p05: Ricci Andrea
      (v_clinic, v_p05, v_pr4, 'rx_panoramica',         'ortopan_ricci_2024.jpg',
       'OPT di inquadramento - gengivite generalizzata', (CURRENT_DATE - 150)::timestamptz + TIME '10:00'),
      (v_clinic, v_p05, v_pr4, 'foto_clinica',          'foto_gengivite_ricci.jpg',
       'Documentazione fotografica gengivite', (CURRENT_DATE - 150)::timestamptz + TIME '10:15'),

      -- p06: Marino Valentina
      (v_clinic, v_p06, v_pr1, 'rx_endorale',           'rx_26_marino_pre.jpg',
       'RX endorale 26 pre-devitalizzazione', (CURRENT_DATE - 14)::timestamptz + TIME '09:00'),
      (v_clinic, v_p06, v_pr1, 'consenso_informato',    'consenso_devital_marino.pdf',
       'Consenso devitalizzazione 26', (CURRENT_DATE - 14)::timestamptz + TIME '09:15'),

      -- p07: Greco Stefano
      (v_clinic, v_p07, v_pr3, 'rx_panoramica',         'ortopan_greco_pre_orto.jpg',
       'OPT pre-trattamento ortodontico', (CURRENT_DATE - 300)::timestamptz + TIME '09:00'),
      (v_clinic, v_p07, v_pr3, 'foto_clinica',          'foto_intraoral_greco_pre.jpg',
       'Foto intraorali pre-trattamento', (CURRENT_DATE - 300)::timestamptz + TIME '09:30'),
      (v_clinic, v_p07, v_pr3, 'foto_extraorale',       'foto_profilo_greco_pre.jpg',
       'Foto profilo pre-trattamento', (CURRENT_DATE - 300)::timestamptz + TIME '09:35'),
      (v_clinic, v_p07, v_pr3, 'consenso_informato',    'consenso_orto_greco.pdf',
       'Consenso trattamento ortodontico', (CURRENT_DATE - 300)::timestamptz + TIME '10:00'),

      -- p08: Bruno Francesca
      (v_clinic, v_p08, v_pr2, 'rx_endorale',           'rx_18_bruno_pre.jpg',
       'RX endorale 18 incluso pre-estrazione', (CURRENT_DATE - 46)::timestamptz + TIME '09:00'),
      (v_clinic, v_p08, v_pr2, 'consenso_informato',    'consenso_estrazione_bruno.pdf',
       'Consenso estrazione 18', (CURRENT_DATE - 45)::timestamptz + TIME '09:30'),
      (v_clinic, v_p08, v_pr2, 'referto',               'referto_estrazione_bruno.pdf',
       'Referto post-estrazione 18', (CURRENT_DATE - 45)::timestamptz + TIME '11:00'),

      -- p11: De Luca Roberto
      (v_clinic, v_p11, v_pr4, 'rx_panoramica',         'ortopan_deluca_paro.jpg',
       'OPT parodontologica con misurazione tasche', (CURRENT_DATE - 120)::timestamptz + TIME '09:00'),
      (v_clinic, v_p11, v_pr4, 'documento_amministrativo','cartella_paro_deluca.pdf',
       'Cartella parodontale completa con sondaggi', (CURRENT_DATE - 120)::timestamptz + TIME '10:00'),

      -- p16: Lombardi Alessia
      (v_clinic, v_p16, v_pr2, 'cbct',                  'cbct_46_lombardi_2024.dcm',
       'CBCT arcata inferiore pre-impianto 46', (CURRENT_DATE - 1)::timestamptz + TIME '14:00'),
      (v_clinic, v_p16, v_pr2, 'consenso_informato',    'consenso_impianto_lombardi.pdf',
       'Consenso procedura implantare 46', (CURRENT_DATE - 1)::timestamptz + TIME '14:30'),

      -- p18: Barbieri Sara
      (v_clinic, v_p18, v_pr1, 'rx_endorale',           'rx_26_barbieri_urgenza.jpg',
       'RX urgente 26 - dolore acuto', CURRENT_DATE::timestamptz + TIME '16:00'),

      -- p20: Santoro Beatrice
      (v_clinic, v_p20, v_pr3, 'foto_extraorale',       'foto_profilo_santoro_valut.jpg',
       'Foto profilo valutazione ortodontica', (CURRENT_DATE - 10)::timestamptz + TIME '10:00');

    -- =========================================================================
    -- DIAGNOSI (15 diagnosi)
    -- =========================================================================
    INSERT INTO patient_diagnoses
        (clinic_id, patient_id, provider_id, tooth_number, title, description, icd_code, status, diagnosed_at)
    VALUES
      (v_clinic, v_p01, v_pr1, '16', 'Carie occlusale',
       'Carie di I grado sulla fossa centrale del 16', 'K02.1', 'active', CURRENT_DATE - 30),
      (v_clinic, v_p01, v_pr1, '47', 'Carie mesiale iniziale',
       'Carie mesiale del 47 in stadio iniziale', 'K02.1', 'active', CURRENT_DATE - 3),
      (v_clinic, v_p02, v_pr1, '21', 'Pulpite reversibile',
       'Sensibilità aumentata su 21 da stimoli freddi', 'K04.0', 'active', CURRENT_DATE - 10),
      (v_clinic, v_p02, v_pr3, NULL, 'Malocclusione classe II',
       'Malocclusione scheletrica classe II divisione 1', 'K07.2', 'chronic', CURRENT_DATE - 180),
      (v_clinic, v_p03, v_pr1, '46', 'Parodontite localizzata',
       'Parodontite cronica localizzata al 46 con tasca 5mm', 'K05.3', 'active', CURRENT_DATE - 45),
      (v_clinic, v_p04, v_pr2, '18', 'Dente del giudizio incluso',
       'Terzo molare superiore sinistro incluso in osso', 'K01.1', 'active', CURRENT_DATE - 200),
      (v_clinic, v_p05, v_pr4, NULL, 'Gengivite generalizzata',
       'Gengivite da placca batterica generalizzata', 'K05.1', 'active', CURRENT_DATE - 7),
      (v_clinic, v_p06, v_pr1, '26', 'Pulpite irreversibile',
       'Pulpite irreversibile sintomatica 26 con dolore spontaneo', 'K04.0', 'active', CURRENT_DATE - 14),
      (v_clinic, v_p08, v_pr2, '18', 'Terzo molare incluso risolto',
       'Estratto il 18 incluso mesioangolato', 'K01.1', 'resolved', CURRENT_DATE - 45),
      (v_clinic, v_p10, v_pr1, '35', 'Carie bifacciale',
       'Carie dentinale bifacciale OM del 35', 'K02.1', 'active', CURRENT_DATE - 60),
      (v_clinic, v_p10, v_pr1, '45', 'Carie occlusale',
       'Carie occlusale del 45 in stadio dentinale', 'K02.1', 'active', CURRENT_DATE - 60),
      (v_clinic, v_p11, v_pr4, NULL, 'Parodontite cronica moderata',
       'Parodontite cronica generalizzata moderata BOP 60%', 'K05.3', 'chronic', CURRENT_DATE - 120),
      (v_clinic, v_p15, v_pr1, NULL, 'Diabete mellito tipo 2',
       'Paziente diabetico - monitorare guarigione tissutale', 'E11', 'chronic', CURRENT_DATE - 500),
      (v_clinic, v_p17, v_pr2, NULL, 'Cardiopatia con anticoagulante',
       'Paziente in TAO - INR da verificare prima di chirurgia', 'I25.1', 'chronic', CURRENT_DATE - 600),
      (v_clinic, v_p18, v_pr1, '26', 'Carie profonda',
       'Carie profonda 26 prossima alla polpa - probabile devitalizzazione', 'K02.3', 'active', CURRENT_DATE);

    -- =========================================================================
    -- PRESCRIZIONI (10 prescrizioni)
    -- =========================================================================
    INSERT INTO patient_prescriptions
        (clinic_id, patient_id, provider_id, drug_name, dosage, frequency, duration, notes, prescribed_at, expires_at, active)
    VALUES
      (v_clinic, v_p01, v_pr1, 'Amoxicillina', '1g',
       '3 volte al giorno', '7 giorni',
       'Assumere lontano dai pasti. Sospendere e contattare lo studio in caso di reazione allergica.',
       CURRENT_DATE - 30, CURRENT_DATE + 60, true),
      (v_clinic, v_p01, v_pr1, 'Ibuprofene', '600mg',
       'Al bisogno, max 3 al giorno', '5 giorni',
       'Non superare la dose massima giornaliera. Non assumere a stomaco vuoto.',
       CURRENT_DATE - 3, CURRENT_DATE + 5, true),
      (v_clinic, v_p03, v_pr1, 'Clorexidina collutorio 0.2%', NULL,
       '2 volte al giorno dopo i pasti', '30 giorni',
       'Risciacquare per 1 minuto. Non ingerire. Può colorare i denti temporaneamente.',
       CURRENT_DATE - 45, CURRENT_DATE - 15, false),
      (v_clinic, v_p05, v_pr4, 'Clorexidina gel 1%', NULL,
       '2 applicazioni al giorno', '14 giorni',
       'Applicare sui bordi gengivali con spazzolino morbido.',
       CURRENT_DATE - 7, CURRENT_DATE + 7, true),
      (v_clinic, v_p06, v_pr1, 'Nimesulide', '100mg',
       '2 volte al giorno', '5 giorni',
       'Assumere dopo i pasti. Controindicato in insufficienza epatica.',
       CURRENT_DATE - 14, CURRENT_DATE - 9, false),
      (v_clinic, v_p06, v_pr1, 'Amoxicillina + Acido Clavulanico', '1g',
       '2 volte al giorno', '6 giorni',
       'Profilassi post-devitalizzazione. Assumere ai pasti.',
       CURRENT_DATE - 14, CURRENT_DATE - 8, false),
      (v_clinic, v_p08, v_pr2, 'Ibuprofene', '400mg',
       'Ogni 6 ore per le prime 24h, poi al bisogno', '3 giorni',
       'Post-estrazione 18. Ghiaccio applicato esternamente nelle prime 2h.',
       CURRENT_DATE - 45, CURRENT_DATE - 42, false),
      (v_clinic, v_p11, v_pr4, 'Clorexidina collutorio 0.12%', NULL,
       '3 volte al giorno', '14 giorni',
       'Dopo SRP parodontale. Non sostituisce lo spazzolamento.',
       CURRENT_DATE - 120, CURRENT_DATE - 106, false),
      (v_clinic, v_p15, v_pr1, 'Metronidazolo', '250mg',
       '3 volte al giorno', '7 giorni',
       'Evitare alcol durante il trattamento. Assumere ai pasti.',
       CURRENT_DATE - 3, CURRENT_DATE + 4, true),
      (v_clinic, v_p18, v_pr1, 'Ketoprofene', '25mg',
       'Al bisogno, max 3 al giorno', '3 giorni',
       'Antidolorifico per dolore acuto 26. Ripresentarsi se il dolore aumenta.',
       CURRENT_DATE, CURRENT_DATE + 3, true);

END $$;

-- =============================================================================
-- VERIFICA FINALE
-- =============================================================================

SELECT 'clinics'                AS tabella, COUNT(*)::text AS righe
    FROM t_9d754153.clinics WHERE id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'providers',               COUNT(*)::text FROM t_9d754153.providers            WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'patients',                COUNT(*)::text FROM t_9d754153.patients             WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'service_catalog',         COUNT(*)::text FROM t_9d754153.service_catalog      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'treatment_plans',         COUNT(*)::text FROM t_9d754153.treatment_plans      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'treatment_plan_items',    COUNT(*)::text FROM t_9d754153.treatment_plan_items WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'estimates',               COUNT(*)::text FROM t_9d754153.estimates            WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'estimate_lines',          COUNT(*)::text FROM t_9d754153.estimate_lines       WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'invoices',                COUNT(*)::text FROM t_9d754153.invoices             WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'invoice_lines',           COUNT(*)::text FROM t_9d754153.invoice_lines        WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'appointments',            COUNT(*)::text FROM t_9d754153.appointments         WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'patient_anamnesis',       COUNT(*)::text FROM t_9d754153.patient_anamnesis    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'odontogram_teeth',        COUNT(*)::text FROM t_9d754153.odontogram_teeth     WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'patient_documents',       COUNT(*)::text FROM t_9d754153.patient_documents    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'clinical_history_entries',COUNT(*)::text FROM t_9d754153.clinical_history_entries WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'products',                COUNT(*)::text FROM t_9d754153.products             WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'stock_movements',         COUNT(*)::text FROM t_9d754153.stock_movements      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'patient_recalls',         COUNT(*)::text FROM t_9d754153.patient_recalls      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'recall_contacts',         COUNT(*)::text FROM t_9d754153.recall_contacts      WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'patient_diagnoses',       COUNT(*)::text FROM t_9d754153.patient_diagnoses    WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
UNION ALL SELECT 'patient_prescriptions',   COUNT(*)::text FROM t_9d754153.patient_prescriptions WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
ORDER BY tabella;

COMMIT;
