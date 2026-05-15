-- V10: Seed inventory — suppliers + products linked to dental service catalog

SET search_path TO dentalcare, public;

DO $$
DECLARE
    v_clinic_id     uuid;
    v_s_dentsply    uuid;
    v_s_voco        uuid;
    v_s_septodont   uuid;
    v_c_farmaci     uuid;
    v_c_materiali   uuid;
    v_c_dpi         uuid;
    v_c_chirurgia   uuid;
    v_c_medicazione uuid;
    v_c_strumentario uuid;
BEGIN
    SELECT id INTO v_clinic_id FROM dentalcare.clinics LIMIT 1;
    IF v_clinic_id IS NULL THEN RETURN; END IF;

    -- Skip if products already seeded
    IF EXISTS (SELECT 1 FROM dentalcare.products WHERE clinic_id = v_clinic_id) THEN RETURN; END IF;

    -- ── Fornitori ───────────────────────────────────────────────────────────────

    INSERT INTO dentalcare.suppliers (id, clinic_id, name, contact_person, phone, email, notes)
    VALUES
        (gen_random_uuid(), v_clinic_id, 'Dentsply Sirona Italia',  'Marco Ferretti',  '02 1234 5678', 'ordini@dentsply.it',  'Fornitore principale materiali endodonzia e conservativa'),
        (gen_random_uuid(), v_clinic_id, 'VOCO GmbH Italia',        'Giulia Marini',   '02 9876 5432', 'info@voco.it',        'Compositi e materiali restaurativi'),
        (gen_random_uuid(), v_clinic_id, 'Septodont Italia',        'Andrea Conti',    '06 5555 1234', 'ordini@septodont.it', 'Anestetici e farmaci per uso odontoiatrico')
    ON CONFLICT DO NOTHING;

    SELECT id INTO v_s_dentsply  FROM dentalcare.suppliers WHERE clinic_id = v_clinic_id AND name = 'Dentsply Sirona Italia' LIMIT 1;
    SELECT id INTO v_s_voco      FROM dentalcare.suppliers WHERE clinic_id = v_clinic_id AND name = 'VOCO GmbH Italia'       LIMIT 1;
    SELECT id INTO v_s_septodont FROM dentalcare.suppliers WHERE clinic_id = v_clinic_id AND name = 'Septodont Italia'       LIMIT 1;

    -- ── Categorie ───────────────────────────────────────────────────────────────

    SELECT id INTO v_c_farmaci      FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Farmaci'      LIMIT 1;
    SELECT id INTO v_c_materiali    FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Materiali'    LIMIT 1;
    SELECT id INTO v_c_dpi          FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'DPI'          LIMIT 1;
    SELECT id INTO v_c_chirurgia    FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Chirurgia'    LIMIT 1;
    SELECT id INTO v_c_medicazione  FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Medicazione'  LIMIT 1;
    SELECT id INTO v_c_strumentario FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Strumentario' LIMIT 1;

    -- ── Farmaci (anestetici, antibiotici, antinfiammatori) ───────────────────────
    -- Usati in: tutte le prestazioni con iniezione, CHIR-*, ENDO-*, IMP-*

    INSERT INTO dentalcare.products
        (clinic_id, category_id, supplier_id, name, description, sku, unit,
         min_stock_quantity, reorder_quantity, unit_cost, is_active)
    VALUES
        (v_clinic_id, v_c_farmaci, v_s_septodont,
         'Articaina 4% + epinefrina 1:100.000 (Septanest)',
         'Anestetico locale con vasocostrittore — uso standard. Impiegato in CHIR, ENDO, CONS, IMP.',
         'SEPT-ART100', 'carpule', 20, 50, 0.55, true),

        (v_clinic_id, v_c_farmaci, v_s_septodont,
         'Mepivacaina 3% senza vasocostrittore (Scandonest)',
         'Anestetico locale senza epinefrina — pazienti cardiopatici o gravide.',
         'SEPT-MEP3', 'carpule', 10, 30, 0.60, true),

        (v_clinic_id, v_c_farmaci, v_s_septodont,
         'Gel anestetico topico',
         'Anestesia di superficie pre-iniezione. Gusto neutro.',
         'SEPT-GEL', 'flacone', 3, 6, 4.50, true),

        (v_clinic_id, v_c_farmaci, NULL,
         'Amoxicillina 1g + Acido clavulanico (cpr)',
         'Profilassi antibiotica post-chirurgica: CHIR-002, CHIR-003, IMP-001, IMP-004.',
         'FARM-AMX1G', 'conf', 5, 10, 8.20, true),

        (v_clinic_id, v_c_farmaci, NULL,
         'Ibuprofene 600mg (cpr)',
         'Antidolorifico/antinfiammatorio post-intervento.',
         'FARM-IBU600', 'conf', 5, 10, 4.80, true),

        (v_clinic_id, v_c_farmaci, NULL,
         'Idrossido di calcio pasta',
         'Medicazione intracanalare tra sedute endodontiche (ENDO-*).',
         'FARM-CAOH', 'siringa', 5, 10, 3.20, true),

        (v_clinic_id, v_c_farmaci, v_s_dentsply,
         'Ipoclorito di sodio 5.25%',
         'Irrigante canalare in endodonzia (ENDO-*). Flacone 1L.',
         'ENDO-NAOCL', 'flacone', 2, 4, 6.50, true);

    -- ── Materiali restaurativi e clinici ────────────────────────────────────────
    -- Usati in: CONS-*, ENDO-*, PROT-*, IMP-*, EST-*, PED-*

    INSERT INTO dentalcare.products
        (clinic_id, category_id, supplier_id, name, description, sku, unit,
         min_stock_quantity, reorder_quantity, unit_cost, is_active)
    VALUES
        (v_clinic_id, v_c_materiali, v_s_voco,
         'Composito nanoriempito A1 (Grandio)',
         'Restauro diretto conservativa (CONS-001/002/003). Tonalità A1.',
         'VOCO-GRA-A1', 'siringa 4g', 3, 8, 14.50, true),

        (v_clinic_id, v_c_materiali, v_s_voco,
         'Composito nanoriempito A2 (Grandio)',
         'Restauro diretto conservativa (CONS-001/002/003). Tonalità A2.',
         'VOCO-GRA-A2', 'siringa 4g', 3, 8, 14.50, true),

        (v_clinic_id, v_c_materiali, v_s_voco,
         'Composito nanoriempito A3 (Grandio)',
         'Restauro diretto conservativa (CONS-001/002/003). Tonalità A3.',
         'VOCO-GRA-A3', 'siringa 4g', 2, 6, 14.50, true),

        (v_clinic_id, v_c_materiali, v_s_voco,
         'Adesivo universale monocomponente (Futurabond U)',
         'Bonding per restauri in composito. Compatibile con tecnica total-etch e self-etch.',
         'VOCO-FUT-U', 'flacone 5ml', 2, 4, 22.00, true),

        (v_clinic_id, v_c_materiali, v_s_voco,
         'Acido ortofosforico 37% (Vococid)',
         'Mordenzatura smalto/dentina prima del bonding.',
         'VOCO-ACID37', 'siringa', 3, 6, 6.80, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'Cemento vetroionomero fotopolimerizzabile',
         'Otturazioni decidue (PED-002), base/liner sotto composito.',
         'DENT-GIC', 'set polvere+liquido', 2, 4, 18.00, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'Coni di gutaperca standardizzati (assortiti)',
         'Otturazione canalare (ENDO-001/002/003/004). Box 120 coni.',
         'ENDO-GUTTA', 'box', 3, 6, 9.50, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'File NiTi rotanti ProTaper Next (set completo)',
         'Sagomatura canalare meccanica per endodonzia (ENDO-*).',
         'ENDO-PTN', 'set/6 pz', 5, 12, 7.20, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'Cemento canalare AH Plus',
         'Sigillante endodontico per otturazione canalare.',
         'ENDO-AHPLUS', 'set basi A+B 4g', 2, 4, 16.50, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'Materiale da impronta vinilpolisilossano (pesante + leggero)',
         'Impronte per protesi fissa e mobile (PROT-001/002/003/004).',
         'PROT-VPS', 'kit 2 cartucce', 4, 8, 28.00, true),

        (v_clinic_id, v_c_materiali, NULL,
         'Alginato cromoforo (Hydrogum 5)',
         'Impronta diagnostica, studio modelli, protesi mobile (PROT-005/006).',
         'PROT-ALG', 'busta 450g', 3, 6, 12.00, true),

        (v_clinic_id, v_c_materiali, NULL,
         'Cemento provvisorio (Temp Bond NE)',
         'Cementazione provvisoria corone e intarsi durante fase protesica.',
         'PROT-TMPBND', 'siringa', 2, 4, 9.80, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'Membrana riassorbibile in collagene (Bio-Gide)',
         'Rigenerazione ossea guidata (IMP-004). 25x25mm.',
         'IMP-BIOGIDE', 'pz', 3, 5, 95.00, true),

        (v_clinic_id, v_c_materiali, v_s_dentsply,
         'Granuli ossei sintetici bifasici (Bio-Oss)',
         'Augmentazione ossea (IMP-004). Flacone 0.5g.',
         'IMP-BIOOSS', 'flacone', 3, 5, 110.00, true),

        (v_clinic_id, v_c_materiali, NULL,
         'Gel fluoruro fosfato acidulato 1.23%',
         'Fluoroprofilassi (IGI-003), sigillatura solchi (PED-001).',
         'IGI-FLU', 'gel 250ml', 2, 4, 14.00, true),

        (v_clinic_id, v_c_materiali, NULL,
         'Gel sigillante per solchi (sealant)',
         'Sigillatura preventiva solchi e fessure (PED-001).',
         'PED-SEAL', 'siringa', 2, 4, 18.50, true),

        (v_clinic_id, v_c_materiali, NULL,
         'Gel sbiancante carbamide perossido 16%',
         'Mascherine sbiancamento domiciliare (EST-002).',
         'EST-BLEA16', 'kit 3 siringhe', 4, 8, 22.00, true),

        (v_clinic_id, v_c_materiali, NULL,
         'Resina acrilica termopolimerizzabile rosa',
         'Base protesi totale e parziale (PROT-005/006).',
         'PROT-ACRI', 'kit 250g', 2, 4, 28.00, true);

    -- ── DPI ─────────────────────────────────────────────────────────────────────

    INSERT INTO dentalcare.products
        (clinic_id, category_id, supplier_id, name, description, sku, unit,
         min_stock_quantity, reorder_quantity, unit_cost, is_active)
    VALUES
        (v_clinic_id, v_c_dpi, NULL,
         'Guanti in nitrile taglia S (box 100)',
         'Guanti monouso senza polvere. Taglia S.',
         'DPI-GLV-S', 'box', 2, 4, 8.50, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Guanti in nitrile taglia M (box 100)',
         'Guanti monouso senza polvere. Taglia M.',
         'DPI-GLV-M', 'box', 3, 6, 8.50, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Guanti in nitrile taglia L (box 100)',
         'Guanti monouso senza polvere. Taglia L.',
         'DPI-GLV-L', 'box', 2, 4, 8.50, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Mascherine chirurgiche tipo IIR (box 50)',
         'Protezione vie aeree operatore. Conformi EN 14683.',
         'DPI-MASK-IIR', 'box', 3, 6, 12.00, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Mascherine FFP2 (box 20)',
         'Alta protezione per procedure aerosol-generanti.',
         'DPI-FFP2', 'box', 2, 4, 18.00, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Occhiali protettivi monouso',
         'Protezione occhi operatore e paziente.',
         'DPI-GOGG', 'pz', 10, 20, 0.90, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Camici monouso TNT taglia unica (box 10)',
         'Protezione abiti operatore.',
         'DPI-CAMICE', 'box', 2, 4, 24.00, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Cuffie monouso (box 100)',
         'Protezione capelli.',
         'DPI-CUFFIA', 'box', 2, 4, 5.00, true),

        (v_clinic_id, v_c_dpi, NULL,
         'Occhiali protettivi paziente (acetato riutilizzabile)',
         'Da sterilizzare tra un paziente e l altro.',
         'DPI-PATOCC', 'pz', 5, 10, 4.50, true);

    -- ── Chirurgia ────────────────────────────────────────────────────────────────
    -- Usati in: CHIR-*, IMP-*

    INSERT INTO dentalcare.products
        (clinic_id, category_id, supplier_id, name, description, sku, unit,
         min_stock_quantity, reorder_quantity, unit_cost, is_active)
    VALUES
        (v_clinic_id, v_c_chirurgia, NULL,
         'Bisturi monouso lama n.15 (box 10)',
         'Incisione tessuti molli. Usato in CHIR-002/003/004, IMP-001/004.',
         'CHIR-BIST15', 'box', 3, 6, 12.00, true),

        (v_clinic_id, v_c_chirurgia, NULL,
         'Filo di sutura 4/0 non riassorbibile (seta, ago curvo)',
         'Chiusura ferita post-chirurgica. CHIR-002/003/004, IMP-001.',
         'CHIR-SUT4S', 'busta', 10, 20, 2.80, true),

        (v_clinic_id, v_c_chirurgia, NULL,
         'Filo di sutura 4/0 riassorbibile (Vicryl, ago curvo)',
         'Chiusura piani profondi. IMP-001/004.',
         'CHIR-SUT4V', 'busta', 5, 10, 4.20, true),

        (v_clinic_id, v_c_chirurgia, v_s_septodont,
         'Spugna emostatica in gelatina (Gelaspon)',
         'Emostasi alveolare post-estrazione (CHIR-001/002/003).',
         'CHIR-GEL', 'box 14 pz', 3, 5, 18.00, true),

        (v_clinic_id, v_c_chirurgia, v_s_dentsply,
         'Viti di copertura implant (assortite, compatibili Nobel Biocare)',
         'Copertura fixture impianto tra prima e seconda fase (IMP-001).',
         'IMP-VITE', 'pz', 5, 10, 8.50, true),

        (v_clinic_id, v_c_chirurgia, NULL,
         'Aghi per siringhe carpule 27G short (box 100)',
         'Somministrazione anestetico locale. Monouso.',
         'CHIR-AGHI27S', 'box', 2, 4, 14.00, true),

        (v_clinic_id, v_c_chirurgia, NULL,
         'Aghi per siringhe carpule 27G long (box 100)',
         'Anestesia tronculare. Monouso.',
         'CHIR-AGHI27L', 'box', 2, 4, 14.00, true);

    -- ── Medicazione ─────────────────────────────────────────────────────────────

    INSERT INTO dentalcare.products
        (clinic_id, category_id, supplier_id, name, description, sku, unit,
         min_stock_quantity, reorder_quantity, unit_cost, is_active)
    VALUES
        (v_clinic_id, v_c_medicazione, NULL,
         'Garze sterili 10x10cm (conf 25 pz)',
         'Medicazione ferite, tamponamento emorragie.',
         'MED-GARZE', 'conf', 5, 10, 2.50, true),

        (v_clinic_id, v_c_medicazione, NULL,
         'Cotone in rotoli (500g)',
         'Isolamento, tamponamento, assorbimento.',
         'MED-COTONE', 'rotolo', 3, 6, 4.80, true),

        (v_clinic_id, v_c_medicazione, NULL,
         'Bavaglini monouso plastificati (box 500)',
         'Protezione paziente durante le prestazioni.',
         'MED-BAVAG', 'box', 2, 4, 18.00, true),

        (v_clinic_id, v_c_medicazione, NULL,
         'Pellicole barriera (box 300)',
         'Copertura superfici riunito (lampada, manipoli, tastiere).',
         'MED-BARRIER', 'box', 2, 4, 12.00, true),

        (v_clinic_id, v_c_medicazione, NULL,
         'Salviette disinfettanti riunito (wipes, box 150)',
         'Disinfezione superfici tra un paziente e l altro.',
         'MED-WIPES', 'box', 3, 6, 9.50, true),

        (v_clinic_id, v_c_medicazione, NULL,
         'Pasta profilattica fluorurata (igiene professionale)',
         'Lucidatura e profilassi (IGI-001/002). Gusto menta.',
         'IGI-PASTA', 'coppetta monouso', 20, 50, 0.60, true),

        (v_clinic_id, v_c_medicazione, NULL,
         'Strisce di cellulosa (Cottonoid, box 250)',
         'Isolamento e assorbimento in conservativa e endodonzia.',
         'MED-COTTON', 'box', 3, 6, 8.00, true);

    -- ── Strumentario ─────────────────────────────────────────────────────────────

    INSERT INTO dentalcare.products
        (clinic_id, category_id, supplier_id, name, description, sku, unit,
         min_stock_quantity, reorder_quantity, unit_cost, is_active)
    VALUES
        (v_clinic_id, v_c_strumentario, NULL,
         'Frese diamantate cilindriche assortite (set 12)',
         'Preparazione cavità, rifinitura margini corone (CONS-*, PROT-*).',
         'STRUM-FRD-CIL', 'set', 3, 6, 28.00, true),

        (v_clinic_id, v_c_strumentario, NULL,
         'Frese diamantate a fiamma assortite (set 6)',
         'Preparazione conicità per corone (PROT-001/002).',
         'STRUM-FRD-FIA', 'set', 3, 6, 22.00, true),

        (v_clinic_id, v_c_strumentario, NULL,
         'Frese al carburo tungsteno turbina assortite (set 10)',
         'Rimozione carie, preparazioni conservative.',
         'STRUM-FRC-TRB', 'set', 3, 6, 18.00, true),

        (v_clinic_id, v_c_strumentario, v_s_dentsply,
         'Punte ultrasuoni per detartrasi (set 5)',
         'Ablazione tartaro (IGI-001/002), levigatura radicolare (PAR-001).',
         'STRUM-ULTRA', 'set', 2, 4, 45.00, true),

        (v_clinic_id, v_c_strumentario, NULL,
         'Specchietti monouso (box 25)',
         'Esame clinico e retroilluminazione. Monouso sterili.',
         'STRUM-SPEC', 'box', 3, 6, 18.00, true),

        (v_clinic_id, v_c_strumentario, NULL,
         'Sonde parodontali monouso (box 25)',
         'Rilevazione profondità tasche (PAR-*), valutazione diagnostica.',
         'STRUM-SONDA', 'box', 2, 4, 22.00, true);

    -- ── Carico stock iniziale ──────────────────────────────────────────────────
    -- Inserisce un movimento di carico iniziale per ogni prodotto

    INSERT INTO dentalcare.stock_movements
        (clinic_id, product_id, movement_type, quantity, notes)
    SELECT
        p.clinic_id,
        p.id,
        'carico'::dentalcare.stock_movement_type,
        CASE
            WHEN p.unit IN ('carpule','pz','busta','coppetta monouso') THEN p.reorder_quantity * 2
            ELSE p.reorder_quantity
        END,
        'Stock iniziale al collaudo sistema'
    FROM dentalcare.products p
    WHERE p.clinic_id = v_clinic_id;

END $$;
