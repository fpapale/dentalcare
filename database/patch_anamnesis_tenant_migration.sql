-- =============================================================================
-- patch_anamnesis_tenant_migration.sql
-- Percorso DBA (manuale) equivalente a EstimateSchemaInitializer.patchAnamnesisCatalog().
--
-- Converge il catalogo anamnesi per-tenant (anamnesis_categories / anamnesis_items),
-- lo storico append-only (patient_anamnesis_item_selections.resolved_at + indice unico
-- parziale) e la FK item_id su OGNI schema tenant. Idempotente: rieseguirlo non produce
-- errori ne' duplica il seed.
--
-- Normalmente NON serve eseguirlo a mano: patchAnamnesisCatalog() applica gli stessi passi
-- allo startup del backend e dopo il provisioning di un nuovo tenant. Questo file esiste
-- come percorso DBA/verifica indipendente dall'applicazione e come documentazione del remap.
--
-- Fonte di verita' del seed: database/install.sql (template create_tenant, 15 categorie / 87 voci).
-- Se il seed cambia la', va aggiornato ANCHE qui e in patchAnamnesisCatalog().
-- =============================================================================

DO $$
DECLARE
    tenant_schema text;
    cat_count integer;
    item_count integer;
    orphan_count integer;
    fk_exists integer;
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM dentalcare.tenants WHERE active = true
    LOOP
        -- 1. Tabelle catalogo (colonne/PK/CHECK/indici identici a install.sql). ---------------
        EXECUTE format($ddl$
            CREATE TABLE IF NOT EXISTS %1$I.anamnesis_categories (
                id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
                code text,
                name text NOT NULL,
                description text,
                icon text DEFAULT 'medical_information'::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                CONSTRAINT anamnesis_categories_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
            )$ddl$, tenant_schema);

        EXECUTE format($ddl$
            CREATE TABLE IF NOT EXISTS %1$I.anamnesis_items (
                id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
                category_id uuid NOT NULL REFERENCES %1$I.anamnesis_categories (id) ON DELETE CASCADE,
                code text NOT NULL,
                label text NOT NULL,
                description text,
                severity text DEFAULT 'normale'::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                has_detail boolean DEFAULT false NOT NULL,
                CONSTRAINT anamnesis_items_label_not_empty CHECK ((length(TRIM(BOTH FROM label)) > 0)),
                CONSTRAINT anamnesis_items_severity_check CHECK ((severity = ANY (ARRAY['normale'::text, 'grave'::text, 'severa'::text])))
            )$ddl$, tenant_schema);

        EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS ux_anamnesis_categories_name ON %1$I.anamnesis_categories (name)', tenant_schema);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_anamnesis_items_category ON %1$I.anamnesis_items (category_id, sort_order)', tenant_schema);
        EXECUTE format('CREATE INDEX IF NOT EXISTS ix_anamnesis_items_category_sort ON %1$I.anamnesis_items (category_id, sort_order) WHERE (enabled = true)', tenant_schema);

        -- 2. Seed 15 categorie / 87 voci — solo se vuote (idempotente). ----------------------
        EXECUTE format('SELECT count(*) FROM %1$I.anamnesis_categories', tenant_schema) INTO cat_count;
        IF cat_count = 0 THEN
            EXECUTE format($seed$
                INSERT INTO %1$I.anamnesis_categories (code, name, sort_order) VALUES
                    ('ALLERGIE', 'Allergie e Reazioni Avverse', 10),
                    ('FARMACI', 'Farmaci e Terapie in Corso', 20),
                    ('CARDIOVASCOLARE', 'Apparato Cardiovascolare', 30),
                    ('RESPIRATORIO', 'Apparato Respiratorio', 40),
                    ('ENDOCRINO', 'Apparato Endocrino-Metabolico', 50),
                    ('RENALE_EPATICO', 'Apparato Renale ed Epatico', 60),
                    ('GASTROINTESTINALE', 'Apparato Gastrointestinale', 70),
                    ('NEUROLOGICO', 'Apparato Neurologico', 80),
                    ('IMMUNO_ONCO_COAG', 'Immunologico, Oncologico e Coagulazione', 90),
                    ('CHIRURGIA', 'Chirurgia Pregressa', 100),
                    ('ABITUDINI', 'Abitudini di Vita e Parafunzioni', 110),
                    ('FATTORI_RISCHIO', 'Fattori di Rischio Odontoiatrico', 120),
                    ('COND_ORALI', 'Condizioni Croniche Odontoiatriche', 130),
                    ('GRAVIDANZA', 'Gravidanza e Stato Ormonale', 140),
                    ('PSICOLOGICO', 'Stato Psicologico e Comportamentale', 150)
            $seed$, tenant_schema);
        END IF;

        EXECUTE format('SELECT count(*) FROM %1$I.anamnesis_items', tenant_schema) INTO item_count;
        IF item_count = 0 THEN
            EXECUTE format($seed$
                INSERT INTO %1$I.anamnesis_items (category_id, code, label, description, severity, sort_order) VALUES
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_PENICILLINA', 'Penicillina / Amoxicillina', 'Include tutte le betalattamine', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ANESTETICI', 'Anestetici locali', 'Articaina, mepivacaina, lidocaina', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_LATEX', 'Lattice', NULL, 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_FANS', 'Aspirina / FANS', NULL, 'grave', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_SULFAMIDICI', 'Sulfamidici', NULL, 'grave', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_SOLFITI', 'Solfiti', 'Metabisolfito, stabilizzante dell''anestetico con vasocostrittore — distinto dai sulfamidici', 'grave', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_CLOREXIDINA', 'Clorexidina', 'Uso quotidiano in collutori/gel — reazioni anafilattiche documentate', 'grave', 70),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ALTRI_ANTIBIOTICI', 'Altri antibiotici', 'Cefalosporine, clindamicina, macrolidi', 'grave', 80),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_BARBITURICI', 'Barbiturici / sedativi', 'Rilevante per sedazione cosciente', 'grave', 90),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_METALLI', 'Metalli', 'Nickel, oro, palladio, cromo-cobalto', 'normale', 100),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ACRILICI', 'Acrilici / resine', 'Metacrilato, protesi rimovibili', 'normale', 110),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_IODIO', 'Iodio / mezzi di contrasto', NULL, 'normale', 120),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTICOAGULANTI', 'Anticoagulanti orali', 'TAO, NAO (warfarin, dabigatran, rivaroxaban, apixaban)', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIAGGREGANTI', 'Antiaggreganti piastrinici', 'Aspirina, clopidogrel, ticagrelor', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_BISFOSFONATI', 'Bifosfonati', 'Alendronato, zoledronato — rischio MRONJ', 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_DENOSUMAB', 'Denosumab', 'Antiriassorbitivo anti-RANKL, stesso rischio MRONJ dei bifosfonati', 'grave', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIANGIOGENETICI', 'Antiangiogenetici', 'Bevacizumab e simili — rientrano nella definizione MRONJ', 'grave', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_CORTISONICI', 'Cortisonici sistemici', NULL, 'grave', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_IMMUNOSOPPRESSORI', 'Immunosoppressori', 'Ciclosporina, azatioprina, metotrexato', 'grave', 70),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIDIABETICI', 'Antidiabetici orali / insulina', NULL, 'grave', 80),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIIPERTENSIVI', 'Antiipertensivi', 'Interazione con vasocostrittore in anestesia locale', 'grave', 90),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_GENGIVOIPERPLASTICI', 'Farmaci con rischio iperplasia gengivale', 'Fenitoina, ciclosporina, nifedipina', 'normale', 100),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_XEROSTOMIZZANTI', 'Farmaci xerostomizzanti', 'Antidepressivi, antistaminici, diuretici', 'normale', 110),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ALTRI', 'Altra terapia farmacologica in corso', NULL, 'normale', 120),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_ENDOCARDITE', 'Endocardite infettiva pregressa', 'Massimo rischio, profilassi antibiotica obbligatoria (ESC 2023)', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_VALVOLARE', 'Protesi valvolare cardiaca', 'Profilassi antibiotica obbligatoria (ESC 2023 Classe I)', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_CONGENITA', 'Cardiopatia congenita', 'Non corretta o corretta con residui — profilassi obbligatoria', 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_PACEMAKER', 'Pacemaker / defibrillatore (ICD)', 'Non richiede profilassi endocardite, ma interferenza con elettrobisturi', 'grave', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_FIBRILLAZIONE', 'Fibrillazione atriale', 'Gestione anticoagulanti/rischio emostatico', 'grave', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_INFARTO', 'Infarto pregresso', NULL, 'grave', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_ANGINA', 'Angina pectoris', NULL, 'grave', 70),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_SCOMPENSO', 'Scompenso cardiaco', 'Insufficienza cardiaca congestizia', 'grave', 80),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_BYPASS', 'Bypass / angioplastica coronarica', 'Gestione antiaggreganti/sanguinamento — non indicazione a profilassi endocardite', 'grave', 90),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_IPERTENSIONE', 'Ipertensione arteriosa', NULL, 'normale', 100),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_ASMA', 'Asma bronchiale', NULL, 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_BPCO', 'BPCO', 'Broncopneumopatia cronica ostruttiva', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_APNEE', 'Apnee notturne', 'OSAS, rilevante per sedazione/postura', 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE1', 'Diabete tipo 1', 'Insulino-dipendente', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE2', 'Diabete tipo 2', 'Non insulino-dipendente', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE_NS', 'Diabete non specificato', 'Per triage rapido quando il tipo non è noto', 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_IPOTIROIDISMO', 'Ipotiroidismo', NULL, 'normale', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_IPERTIROIDISMO', 'Ipertiroidismo', 'Morbo di Basedow o adenoma tossico', 'grave', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_CUSHING', 'Sindrome di Cushing', 'Ipercortisolismo endogeno o iatrogeno', 'grave', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_OSTEOPOROSI', 'Osteoporosi', 'Il rischio MRONJ è tracciato separatamente sui farmaci (FAR_BISFOSFONATI/FAR_DENOSUMAB)', 'normale', 70),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'REN_INSUFFICIENZA', 'Insufficienza renale cronica', 'IRC o dialisi', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'EPA_EPATITE', 'Epatite B/C', 'Epatite virale cronica', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'EPA_CIRROSI', 'Cirrosi epatica', 'Rischio coagulativo differente dall''epatite semplice', 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_REFLUSSO', 'Reflusso gastroesofageo', NULL, 'normale', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_ULCERA', 'Ulcera peptica', 'Controindicazione relativa ai FANS', 'normale', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_CROHN', 'Morbo di Crohn', NULL, 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_EPILESSIA', 'Epilessia', NULL, 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_PARKINSON', 'Malattia di Parkinson', 'Gestione poltrona, tempi di trattamento, tremore', 'normale', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_SCLEROSI', 'Sclerosi multipla', NULL, 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_HIV', 'HIV / immunodeficienza', 'Alert per gestione clinica (farmaci, lesioni orali) — NON usare per vincoli di scheduling: le precauzioni universali si applicano a ogni paziente indipendentemente dallo stato noto', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_ONCOLOGICA', 'Patologia oncologica in trattamento', 'Chemioterapia o radioterapia in corso', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_COAGULOPATIA', 'Disturbi della coagulazione', 'Voce generica — vedi anche emofilia/trombocitopenia per casi specifici', 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_EMOFILIA', 'Emofilia', NULL, 'grave', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_TROMBOCITOPENIA', 'Trombocitopenia', NULL, 'grave', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_RADIOTERAPIA_TESTA_COLLO', 'Radioterapia testa-collo pregressa', 'Rischio osteoradionecrosi, analogo a MRONJ', 'grave', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_PROTESI_ARTICOLARI', 'Protesi articolari', 'Anca, ginocchio — dal 2024 AAOS allineato ADA: profilassi routinaria NON raccomandata nella maggioranza dei casi, valutazione caso per caso', 'normale', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_TRAPIANTO', 'Trapianto d''organo', 'Immunosoppressione, rischio infettivo', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_SPLENECTOMIA', 'Splenectomia / asplenia', 'Rischio infettivo (sepsi post-splenectomia) in procedure invasive', 'grave', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_ALTRO', 'Altri interventi chirurgici', NULL, 'normale', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_FUMATORE_ATTIVO', 'Fumatore attivo', 'Impatto su guarigione post-chirurgica e osteointegrazione implantare', 'normale', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_EX_FUMATORE', 'Ex fumatore', 'Rischio parodontale/oncologico residuo', 'normale', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_VAPING', 'Sigaretta elettronica / vaping', 'Xerostomia, infiammazione gengivale — voce distinta dal fumo tradizionale (ADA)', 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_ALCOL', 'Consumo regolare di alcolici', 'Più di 2 unità/giorno', 'normale', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_DROGHE', 'Uso di sostanze', 'Interazione con vasocostrittori/anestesia', 'grave', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_BRUXISMO', 'Bruxismo / digrignamento', NULL, 'normale', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_ONICOFAGIA', 'Onicofagia / morsicatura labbra', NULL, 'normale', 70),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_PIERCING', 'Piercing orale', NULL, 'normale', 80),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'FATTORI_RISCHIO'), 'FTR_SPORT_AGONISTICO', 'Sportivo agonista', 'Rischio trauma dento-alveolare, indicazione a paradenti/bite — non è un''abitudine di vita', 'normale', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_SENSIBILITA', 'Sensibilità dentinale', NULL, 'normale', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_SANGUINAMENTO', 'Sanguinamento gengivale', NULL, 'normale', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_MOBILITA', 'Mobilità dentale', NULL, 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_ALITOSI', 'Alitosi cronica', NULL, 'normale', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_ATM', 'Problemi ATM / dolore masticatorio', NULL, 'normale', 50),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_XEROSTOMIA', 'Secchezza orale', 'Xerostomia', 'normale', 60),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_AFTE', 'Afte ricorrenti', NULL, 'normale', 70),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_GRAVIDANZA', 'Gravidanza in corso', 'Indicare il trimestre nelle note', 'grave', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_ALLATTAMENTO', 'Allattamento', NULL, 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_ORMONI', 'Terapia ormonale', 'Pillola, HRT', 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_ANSIA_STUDIO', 'Ansia da studio dentistico', NULL, 'normale', 10),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_FOBIA_AGHI', 'Fobia degli aghi', 'Belonefobia — impatta somministrazione anestesia', 'grave', 20),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_GAG_REFLEX', 'Riflesso del vomito accentuato', 'Difficoltà a tenere la bocca aperta a lungo', 'normale', 30),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_SEDAZIONE_PREGRESSA', 'Sedazione cosciente pregressa', NULL, 'normale', 40),
                    ((SELECT id FROM %1$I.anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_ESPERIENZE_TRAUMATICHE', 'Esperienze odontoiatriche traumatiche pregresse', NULL, 'normale', 50)
            $seed$, tenant_schema);
        END IF;

        -- 3. Storico append-only: colonna resolved_at. --------------------------------------
        EXECUTE format('ALTER TABLE %1$I.patient_anamnesis_item_selections ADD COLUMN IF NOT EXISTS resolved_at timestamptz', tenant_schema);

        -- 3b. Colonne legacy V23 (anamnesis_id/anamnesis_item_id NOT NULL): rilassa il vincolo. ---
        --     L app usa clinic_id/patient_id/item_id e non le popola: senza questo, INSERT di
        --     savePatientAnamnesis viola il NOT NULL su un tenant creato dal template V23.
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = tenant_schema
                   AND table_name = 'patient_anamnesis_item_selections' AND column_name = 'anamnesis_id') THEN
            EXECUTE format('ALTER TABLE %1$I.patient_anamnesis_item_selections ALTER COLUMN anamnesis_id DROP NOT NULL', tenant_schema);
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = tenant_schema
                   AND table_name = 'patient_anamnesis_item_selections' AND column_name = 'anamnesis_item_id') THEN
            EXECUTE format('ALTER TABLE %1$I.patient_anamnesis_item_selections ALTER COLUMN anamnesis_item_id DROP NOT NULL', tenant_schema);
        END IF;

        -- 4. Vincolo unico: rimuove il vecchio pieno (legacy) e crea l''indice unico parziale. -
        EXECUTE format('ALTER TABLE %1$I.patient_anamnesis_item_selections DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_unique', tenant_schema);
        EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_anamnesis_selections_active ON %1$I.patient_anamnesis_item_selections (clinic_id, patient_id, item_id) WHERE resolved_at IS NULL', tenant_schema);

        -- 5. FK item_id -> anamnesis_items per-tenant, SOLO se non orfana righe esistenti. ----
        -- REMAP MANUALE (runbook): questo seed genera nuovi id per-tenant (gen_random_uuid), diversi
        -- dagli id del vecchio catalogo GLOBALE dentalcare.anamnesis_items. Se un tenant REALE avesse
        -- selezioni pazienti (patient_anamnesis_item_selections.item_id) che puntano a quei vecchi id
        -- globali, aggiungere la FK qui le orfanerebbe / fallirebbe. In quel caso NON eseguire il blocco
        -- automatico sotto: rimappare prima gli item_id per codice, es.
        --   UPDATE <schema>.patient_anamnesis_item_selections s
        --      SET item_id = t.id
        --     FROM dentalcare.anamnesis_items g
        --     JOIN <schema>.anamnesis_items t ON t.code = g.code
        --    WHERE s.item_id = g.id;
        -- e SOLO dopo aver verificato 0 orfani, aggiungere la FK. Oggi non esistono tenant con pazienti
        -- reali (demo t_9d754153 gia' migrato), quindi il caso pratico e' "tenant nuovo/vuoto".
        EXECUTE format(
            'SELECT count(*) FROM %1$I.patient_anamnesis_item_selections s '
            'WHERE s.item_id IS NOT NULL AND NOT EXISTS '
            '(SELECT 1 FROM %1$I.anamnesis_items ai WHERE ai.id = s.item_id)', tenant_schema)
            INTO orphan_count;
        SELECT count(*) INTO fk_exists
          FROM information_schema.table_constraints
         WHERE table_schema = tenant_schema
           AND table_name = 'patient_anamnesis_item_selections'
           AND constraint_name = 'patient_anamnesis_item_selections_item_id_fkey'
           AND constraint_type = 'FOREIGN KEY';
        IF orphan_count = 0 AND fk_exists = 0 THEN
            EXECUTE format(
                'ALTER TABLE %1$I.patient_anamnesis_item_selections '
                'ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey '
                'FOREIGN KEY (item_id) REFERENCES %1$I.anamnesis_items (id) ON DELETE CASCADE', tenant_schema);
        ELSIF orphan_count > 0 THEN
            RAISE NOTICE 'Schema %: % selezioni orfane — FK NON aggiunta, remap manuale richiesto (vedi commento step 5)', tenant_schema, orphan_count;
        END IF;

        RAISE NOTICE 'Catalogo anamnesi convergente per schema %', tenant_schema;
    END LOOP;
END $$;

-- Verifica finale: tabelle presenti e FK ripuntata allo schema tenant.
SELECT t.schema_name AS tenant_schema,
       to_regclass(t.schema_name || '.anamnesis_categories') IS NOT NULL AS has_categories,
       to_regclass(t.schema_name || '.anamnesis_items')      IS NOT NULL AS has_items,
       to_regclass(t.schema_name || '.ux_patient_anamnesis_selections_active') IS NOT NULL AS has_active_ux,
       EXISTS (
           SELECT 1 FROM pg_constraint con
             JOIN pg_class rel  ON rel.oid  = con.conrelid
             JOIN pg_namespace n ON n.oid   = rel.relnamespace
             JOIN pg_class frel ON frel.oid = con.confrelid
             JOIN pg_namespace fn ON fn.oid = frel.relnamespace
            WHERE n.nspname = t.schema_name
              AND rel.relname = 'patient_anamnesis_item_selections'
              AND con.conname = 'patient_anamnesis_item_selections_item_id_fkey'
              AND frel.relname = 'anamnesis_items'
              AND fn.nspname = t.schema_name
       ) AS fk_points_to_tenant
FROM dentalcare.tenants t
WHERE t.active = true
ORDER BY t.schema_name;
