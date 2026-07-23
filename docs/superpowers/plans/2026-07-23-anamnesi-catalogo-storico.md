# Anamnesi: catalogo per-tenant, severità, storico e vincolo scheduling — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendere il catalogo anamnesi per-tenant (oggi globale), ricostruirne il contenuto (deduplicato + voci mancanti trovate da ricerca clinica), introdurre severità a 3 livelli collegata davvero agli alert clinici, versionare le selezioni paziente con diff sintetico, e vincolare lo scheduling per pazienti in stato "severa".

**Architecture:** Le tabelle catalogo (`anamnesis_categories`/`anamnesis_items`) si spostano dallo schema globale `dentalcare` allo schema per-tenant (`t_XXXX`), seguendo lo stesso pattern già usato da `service_catalog`/`service_categories`: definite una volta nel template DDL di `dentalcare.create_tenant()`, materializzate come copia fisica per ogni tenant. `patient_anamnesis_item_selections` passa da stato-corrente-sovrascritto ad append-only (`resolved_at`), con un indice unico parziale che garantisce una sola riga attiva per item/paziente. Gli alert clinici (dashboard, agenda, cartella paziente) vengono estesi — non sostituiti — con una nuova sorgente derivata dal catalogo via vista SQL. Lo scheduling (`AppointmentService.findAvailability`) guadagna un vincolo opzionale "solo fine giornata" quando il paziente ha una condizione attiva di severità `severa`.

**Tech Stack:** Spring Boot (`NamedParameterJdbcTemplate`, no JPA per questi service), PostgreSQL (schema-per-tenant), Angular standalone components + signals, JUnit 5.

## Global Constraints

- Mai `DELETE` fisico su righe di `patient_anamnesis_item_selections` o su voci di catalogo già in uso — solo soft-delete/risoluzione (`resolved_at`/`enabled=false`).
- Ogni tabella per-tenant è schema-qualificata a runtime via `TenantContext.validatedSchema()` (helper `private String s() { return TenantContext.validatedSchema(); }`), mai uno schema hardcoded nel testo SQL.
- `install.sql` va aggiornato in **entrambe** le occorrenze per ogni modifica DDL: il template dentro `dentalcare.create_tenant()` (righe 291-1823) e l'istanza materializzata per il tenant demo `t_9d754153`.
- Nessuna voce del catalogo di base ha `severity='severa'` nel seed — è un valore selezionabile a runtime, mai precompilato per una diagnosi cronica (decisione del committente, 23/07/2026 — vedi `directives/proposte-modifiche.md` §43).
- Build verde richiesta prima di ogni commit: `cd backend && ./mvnw test` (o `mvn test` se manca il wrapper) e `cd frontend && npm run build`.

---

## File Structure

| File | Responsabilità |
|---|---|
| `database/install.sql` | Template `create_tenant()` (nuove tabelle + seed) + istanza `t_9d754153` (stesse modifiche duplicate) |
| `database/patches/2026-07-23_anamnesis_tenant_migration.sql` (nuovo) | Migrazione one-shot per i tenant già esistenti diversi da quello creato da zero — crea le tabelle per-tenant e copia il seed statico |
| `backend/.../service/AnamnesisCatalogService.java` | CRUD catalogo — passa da `dentalcare.` hardcoded a `TenantContext.validatedSchema()`; `isAlert` → `severity`; delete con count-check + soft-delete |
| `backend/.../controller/AnamnesisCatalogController.java` | Nessuna modifica di routing, solo DTO aggiornati |
| `backend/.../dto/CatalogItemDto.java`, `CreateCatalogItemRequest.java`, `UpdateCatalogItemRequest.java` | `isAlert boolean` → `severity String` |
| `backend/.../service/AnamnesisService.java` | `savePatientAnamnesis()` riscritto da wipe+replace a diff (insert/risoluzione); nuovo metodo `diffSinceLastVisit()` |
| `backend/.../controller/AnamnesisController.java` | Nuovo endpoint `GET .../anamnesis/diff` |
| `backend/.../dto/AnamnesisDiffDto.java` (nuovo) | Risposta del diff |
| `backend/.../service/AppointmentService.java` | `findAvailability` accetta `patientId`; `computeAvailability` filtra a fine giornata se severità `severa`; `create()` valida lo stesso vincolo |
| `frontend/.../impostazioni.component.ts/html` | Toggle `isAlert` → select severità 3 valori |
| `frontend/.../cartella-tab.component.ts` | `get alerts()` include il nuovo alert da catalogo |
| `frontend/.../dashboard.component.ts/html` | Stesso alert aggiuntivo, coerente col resto |
| `frontend/.../paziente-detail/...` (tab cartella clinica) | Badge diff sintetico |

---

## Task 1: Schema — catalogo anamnesi per-tenant (DDL)

**Files:**
- Modify: `database/install.sql:291-1823` (template `create_tenant()`, inserire dopo la definizione di `patient_anamnesis_item_selections`, riga ~675, prima di `patient_diagnoses`)
- Modify: `database/install.sql` (istanza `t_9d754153`, stesso punto relativo — dopo `t_9d754153.patient_anamnesis_item_selections`, prima di `t_9d754153.patient_diagnoses`, riga ~2568 circa)
- Modify: `database/install.sql` (sezione `ALTER TABLE ... ADD CONSTRAINT` — righe 5440-5468 per i vincoli categorie/voci, sia template sia istanza)
- Modify: `database/install.sql` (sezione `CREATE INDEX` — righe 6055-6072, sia template sia istanza)
- Modify: `database/install.sql` (sezione FK — riga 6666-6670 per `anamnesis_items_category_id_fkey`, sia template sia istanza)
- Modify: `database/install.sql:1667` e `:7166` — FK di `patient_anamnesis_item_selections.item_id`, da `dentalcare.anamnesis_items(id)` a `anamnesis_items(id)` (stesso schema tenant)

**Interfaces:**
- Consumes: nessuna dipendenza da altri task
- Produces: tabelle per-tenant `anamnesis_categories(id, code, name, description, icon, sort_order, enabled, created_at)` e `anamnesis_items(id, category_id, code, label, description, severity, sort_order, enabled, created_at, has_detail)` — usate da Task 2 (seed), Task 3 (service), Task 6 (viste)

- [ ] **Step 1: Aggiungere le CREATE TABLE nel template `create_tenant()`**

In `database/install.sql`, subito dopo la definizione di `patient_anamnesis_item_selections` nel template (circa riga 675, prima di `CREATE TABLE patient_diagnoses`):

```sql
CREATE TABLE anamnesis_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text,
    name text NOT NULL,
    description text,
    icon text DEFAULT 'medical_information'::text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT anamnesis_categories_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);

CREATE TABLE anamnesis_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
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
);
```

Nota: `severity` sostituisce `is_alert` fin dall'origine in questa nuova tabella per-tenant — non serve una colonna legacy da migrare qui, la migrazione dato riguarda solo il seed (Task 2), non lo schema.

- [ ] **Step 2: Aggiungere gli stessi CREATE TABLE nell'istanza `t_9d754153`**

Stesso blocco di Step 1, ma con prefisso schema esplicito, inserito subito dopo `CREATE TABLE t_9d754153.patient_anamnesis_item_selections` (circa riga 2568):

```sql
CREATE TABLE t_9d754153.anamnesis_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text,
    name text NOT NULL,
    description text,
    icon text DEFAULT 'medical_information'::text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT t_9d754153_anamnesis_categories_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);

CREATE TABLE t_9d754153.anamnesis_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    description text,
    severity text DEFAULT 'normale'::text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    has_detail boolean DEFAULT false NOT NULL,
    CONSTRAINT t_9d754153_anamnesis_items_label_not_empty CHECK ((length(TRIM(BOTH FROM label)) > 0)),
    CONSTRAINT t_9d754153_anamnesis_items_severity_check CHECK ((severity = ANY (ARRAY['normale'::text, 'grave'::text, 'severa'::text])))
);
```

- [ ] **Step 3: Vincoli, indici e FK — template**

Nella sezione `ALTER TABLE ... ADD CONSTRAINT` del template (vicino a dove oggi vive `patient_anamnesis_item_selections_pkey`, circa riga 1219 nel template — stesso punto strutturale):

```sql
ALTER TABLE ONLY anamnesis_categories
    ADD CONSTRAINT anamnesis_categories_pkey PRIMARY KEY (id);
ALTER TABLE ONLY anamnesis_categories
    ADD CONSTRAINT anamnesis_categories_code_unique UNIQUE (code);
ALTER TABLE ONLY anamnesis_categories
    ADD CONSTRAINT ux_anamnesis_categories_name UNIQUE (name);

ALTER TABLE ONLY anamnesis_items
    ADD CONSTRAINT anamnesis_items_pkey PRIMARY KEY (id);
ALTER TABLE ONLY anamnesis_items
    ADD CONSTRAINT anamnesis_items_code_unique UNIQUE (code);
ALTER TABLE ONLY anamnesis_items
    ADD CONSTRAINT anamnesis_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES anamnesis_categories(id) ON DELETE CASCADE;

CREATE INDEX ix_anamnesis_categories_sort ON anamnesis_categories USING btree (sort_order, code) WHERE (enabled = true);
CREATE INDEX ix_anamnesis_items_category ON anamnesis_items USING btree (category_id, sort_order);
CREATE INDEX ix_anamnesis_items_category_sort ON anamnesis_items USING btree (category_id, sort_order) WHERE (enabled = true);
```

- [ ] **Step 4: Stessi vincoli/indici/FK — istanza `t_9d754153`**

Stesso blocco di Step 3 con `t_9d754153.` come prefisso su ogni nome tabella e nomi vincolo prefissati `t_9d754153_` per evitare collisione coi nomi globali già usati altrove nel dump:

```sql
ALTER TABLE ONLY t_9d754153.anamnesis_categories
    ADD CONSTRAINT t_9d754153_anamnesis_categories_pkey PRIMARY KEY (id);
ALTER TABLE ONLY t_9d754153.anamnesis_categories
    ADD CONSTRAINT t_9d754153_anamnesis_categories_code_unique UNIQUE (code);
ALTER TABLE ONLY t_9d754153.anamnesis_categories
    ADD CONSTRAINT t_9d754153_ux_anamnesis_categories_name UNIQUE (name);

ALTER TABLE ONLY t_9d754153.anamnesis_items
    ADD CONSTRAINT t_9d754153_anamnesis_items_pkey PRIMARY KEY (id);
ALTER TABLE ONLY t_9d754153.anamnesis_items
    ADD CONSTRAINT t_9d754153_anamnesis_items_code_unique UNIQUE (code);
ALTER TABLE ONLY t_9d754153.anamnesis_items
    ADD CONSTRAINT t_9d754153_anamnesis_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES t_9d754153.anamnesis_categories(id) ON DELETE CASCADE;

CREATE INDEX t_9d754153_ix_anamnesis_categories_sort ON t_9d754153.anamnesis_categories USING btree (sort_order, code) WHERE (enabled = true);
CREATE INDEX t_9d754153_ix_anamnesis_items_category ON t_9d754153.anamnesis_items USING btree (category_id, sort_order);
CREATE INDEX t_9d754153_ix_anamnesis_items_category_sort ON t_9d754153.anamnesis_items USING btree (category_id, sort_order) WHERE (enabled = true);
```

- [ ] **Step 5: Ripuntare la FK di `patient_anamnesis_item_selections.item_id`**

Nel template, `database/install.sql:1667` (circa — cercare `patient_anamnesis_item_selections_item_id_fkey`):

```sql
-- PRIMA
ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey FOREIGN KEY (item_id) REFERENCES dentalcare.anamnesis_items(id) ON DELETE CASCADE;

-- DOPO
ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey FOREIGN KEY (item_id) REFERENCES anamnesis_items(id) ON DELETE CASCADE;
```

Stessa modifica nell'istanza `t_9d754153` (`database/install.sql:7166` circa):

```sql
-- PRIMA
ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey FOREIGN KEY (item_id) REFERENCES dentalcare.anamnesis_items(id) ON DELETE CASCADE;

-- DOPO
ALTER TABLE ONLY t_9d754153.patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey FOREIGN KEY (item_id) REFERENCES t_9d754153.anamnesis_items(id) ON DELETE CASCADE;
```

**Importante — ordine di esecuzione**: questo Step 5 deve girare **dopo** che Task 2 ha popolato `anamnesis_items` per-tenant con lo stesso set di `id` già referenziati dalle righe esistenti di `patient_anamnesis_item_selections` (altrimenti la FK fallisce per righe orfane). Su un tenant creato da zero via `create_tenant()` non c'è questo problema (nessuna riga preesistente). Sul tenant demo `t_9d754153`, che ha già selezioni pazienti seedate in `install.sql` (righe ~4987+), la migrazione dato di Task 2 deve **riusare gli stessi `id` di riga** già presenti in `dentalcare.anamnesis_items` quando crea `t_9d754153.anamnesis_items`, non generarne di nuovi — altrimenti le selezioni esistenti del demo perdono il riferimento.

- [ ] **Step 6: Verifica manuale — nessun test automatico per DDL puro**

Non esiste un framework di test per `install.sql` in questo repo (è uno script eseguito con `psql`, non testato da Maven/JUnit). Verifica: dopo aver completato Task 2 (seed), eseguire l'intero `install.sql` su un DB Postgres locale/di test pulito e confermare che non lancia errori:

```bash
psql -U postgres -h localhost -d postgres -v dbname=dentalcare_test -f database/install.sql
```

Expected: nessun errore, uscita pulita. Se fallisce, l'errore indica la riga esatta — tipicamente ordine di creazione (FK verso tabella non ancora esistente) o nome vincolo duplicato.

- [ ] **Step 7: Commit**

```bash
git add database/install.sql
git commit -m "feat(anamnesi): sposta catalogo categorie/voci da schema globale a per-tenant"
```

---

## Task 2: Dati — catalogo ricostruito (deduplicato + voci mancanti) come seed statico

**Files:**
- Modify: `database/install.sql` (template `create_tenant()` — nuovo blocco `INSERT INTO anamnesis_categories/anamnesis_items` subito dopo le `CREATE TABLE` di Task 1 Step 1)
- Modify: `database/install.sql` (istanza `t_9d754153` — sostituire i due blocchi `COPY dentalcare.anamnesis_categories`/`COPY dentalcare.anamnesis_items` esistenti, righe 3237-3374 circa, con lo stesso seed ricostruito, **riusando gli `id` già presenti** per le voci referenziate da `patient_anamnesis_item_selections` esistenti — vedi Step 3)
- Create: `database/patches/2026-07-23_anamnesis_tenant_migration.sql` — script per i tenant reali già esistenti diversi dal demo

**Interfaces:**
- Consumes: tabelle `anamnesis_categories`/`anamnesis_items` da Task 1
- Produces: 15 categorie, ~68 voci con `severity` assegnata, usate da Task 3 (service legge da qui) e Task 6 (viste alert)

- [ ] **Step 1: Seed categorie — inserire nel template `create_tenant()`**

Subito dopo le `CREATE TABLE` di Task 1 Step 1:

```sql
INSERT INTO anamnesis_categories (code, name, sort_order) VALUES
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
    ('PSICOLOGICO', 'Stato Psicologico e Comportamentale', 150);
```

- [ ] **Step 2: Seed voci — inserire subito dopo, nello stesso blocco template**

```sql
INSERT INTO anamnesis_items (category_id, code, label, description, severity, sort_order) VALUES
    -- ALLERGIE
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_PENICILLINA', 'Penicillina / Amoxicillina', 'Include tutte le betalattamine', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ANESTETICI', 'Anestetici locali', 'Articaina, mepivacaina, lidocaina', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_LATEX', 'Lattice', NULL, 'grave', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_FANS', 'Aspirina / FANS', NULL, 'grave', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_SULFAMIDICI', 'Sulfamidici', NULL, 'grave', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_SOLFITI', 'Solfiti', 'Metabisolfito, stabilizzante dell''anestetico con vasocostrittore — distinto dai sulfamidici', 'grave', 60),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_CLOREXIDINA', 'Clorexidina', 'Uso quotidiano in collutori/gel — reazioni anafilattiche documentate', 'grave', 70),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ALTRI_ANTIBIOTICI', 'Altri antibiotici', 'Cefalosporine, clindamicina, macrolidi', 'grave', 80),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_BARBITURICI', 'Barbiturici / sedativi', 'Rilevante per sedazione cosciente', 'grave', 90),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_METALLI', 'Metalli', 'Nickel, oro, palladio, cromo-cobalto', 'normale', 100),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_ACRILICI', 'Acrilici / resine', 'Metacrilato, protesi rimovibili', 'normale', 110),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_IODIO', 'Iodio / mezzi di contrasto', NULL, 'normale', 120),

    -- FARMACI
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTICOAGULANTI', 'Anticoagulanti orali', 'TAO, NAO (warfarin, dabigatran, rivaroxaban, apixaban)', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIAGGREGANTI', 'Antiaggreganti piastrinici', 'Aspirina, clopidogrel, ticagrelor', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_BISFOSFONATI', 'Bifosfonati', 'Alendronato, zoledronato — rischio MRONJ', 'grave', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_DENOSUMAB', 'Denosumab', 'Antiriassorbitivo anti-RANKL, stesso rischio MRONJ dei bifosfonati', 'grave', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIANGIOGENETICI', 'Antiangiogenetici', 'Bevacizumab e simili — rientrano nella definizione MRONJ', 'grave', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_CORTISONICI', 'Cortisonici sistemici', NULL, 'grave', 60),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_IMMUNOSOPPRESSORI', 'Immunosoppressori', 'Ciclosporina, azatioprina, metotrexato', 'grave', 70),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIDIABETICI', 'Antidiabetici orali / insulina', NULL, 'grave', 80),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ANTIIPERTENSIVI', 'Antiipertensivi', 'Interazione con vasocostrittore in anestesia locale', 'grave', 90),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_GENGIVOIPERPLASTICI', 'Farmaci con rischio iperplasia gengivale', 'Fenitoina, ciclosporina, nifedipina', 'normale', 100),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_XEROSTOMIZZANTI', 'Farmaci xerostomizzanti', 'Antidepressivi, antistaminici, diuretici', 'normale', 110),
    ((SELECT id FROM anamnesis_categories WHERE code = 'FARMACI'), 'FAR_ALTRI', 'Altra terapia farmacologica in corso', NULL, 'normale', 120),

    -- CARDIOVASCOLARE
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_ENDOCARDITE', 'Endocardite infettiva pregressa', 'Massimo rischio, profilassi antibiotica obbligatoria (ESC 2023)', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_VALVOLARE', 'Protesi valvolare cardiaca', 'Profilassi antibiotica obbligatoria (ESC 2023 Classe I)', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_CONGENITA', 'Cardiopatia congenita', 'Non corretta o corretta con residui — profilassi obbligatoria', 'grave', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_PACEMAKER', 'Pacemaker / defibrillatore (ICD)', 'Non richiede profilassi endocardite, ma interferenza con elettrobisturi', 'grave', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_FIBRILLAZIONE', 'Fibrillazione atriale', 'Gestione anticoagulanti/rischio emostatico', 'grave', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_INFARTO', 'Infarto pregresso', NULL, 'grave', 60),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_ANGINA', 'Angina pectoris', NULL, 'grave', 70),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_SCOMPENSO', 'Scompenso cardiaco', 'Insufficienza cardiaca congestizia', 'grave', 80),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_BYPASS', 'Bypass / angioplastica coronarica', 'Gestione antiaggreganti/sanguinamento — non indicazione a profilassi endocardite', 'grave', 90),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CARDIOVASCOLARE'), 'CAR_IPERTENSIONE', 'Ipertensione arteriosa', NULL, 'normale', 100),

    -- RESPIRATORIO
    ((SELECT id FROM anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_ASMA', 'Asma bronchiale', NULL, 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_BPCO', 'BPCO', 'Broncopneumopatia cronica ostruttiva', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'RESPIRATORIO'), 'RES_APNEE', 'Apnee notturne', 'OSAS, rilevante per sedazione/postura', 'normale', 30),

    -- ENDOCRINO
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE1', 'Diabete tipo 1', 'Insulino-dipendente', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE2', 'Diabete tipo 2', 'Non insulino-dipendente', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_DIABETE_NS', 'Diabete non specificato', 'Per triage rapido quando il tipo non è noto', 'grave', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_IPOTIROIDISMO', 'Ipotiroidismo', NULL, 'normale', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_IPERTIROIDISMO', 'Ipertiroidismo', 'Morbo di Basedow o adenoma tossico', 'grave', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_CUSHING', 'Sindrome di Cushing', 'Ipercortisolismo endogeno o iatrogeno', 'grave', 60),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ENDOCRINO'), 'END_OSTEOPOROSI', 'Osteoporosi', 'Il rischio MRONJ è tracciato separatamente sui farmaci (FAR_BISFOSFONATI/FAR_DENOSUMAB)', 'normale', 70),

    -- RENALE_EPATICO
    ((SELECT id FROM anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'REN_INSUFFICIENZA', 'Insufficienza renale cronica', 'IRC o dialisi', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'EPA_EPATITE', 'Epatite B/C', 'Epatite virale cronica', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'RENALE_EPATICO'), 'EPA_CIRROSI', 'Cirrosi epatica', 'Rischio coagulativo differente dall''epatite semplice', 'grave', 30),

    -- GASTROINTESTINALE
    ((SELECT id FROM anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_REFLUSSO', 'Reflusso gastroesofageo', NULL, 'normale', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_ULCERA', 'Ulcera peptica', 'Controindicazione relativa ai FANS', 'normale', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'GASTROINTESTINALE'), 'GAS_CROHN', 'Morbo di Crohn', NULL, 'normale', 30),

    -- NEUROLOGICO
    ((SELECT id FROM anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_EPILESSIA', 'Epilessia', NULL, 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_PARKINSON', 'Malattia di Parkinson', 'Gestione poltrona, tempi di trattamento, tremore', 'normale', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'NEUROLOGICO'), 'NEU_SCLEROSI', 'Sclerosi multipla', NULL, 'normale', 30),

    -- IMMUNO_ONCO_COAG
    ((SELECT id FROM anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_HIV', 'HIV / immunodeficienza', 'Alert per gestione clinica (farmaci, lesioni orali) — NON usare per vincoli di scheduling: le precauzioni universali si applicano a ogni paziente indipendentemente dallo stato noto', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_ONCOLOGICA', 'Patologia oncologica in trattamento', 'Chemioterapia o radioterapia in corso', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_COAGULOPATIA', 'Disturbi della coagulazione', 'Voce generica — vedi anche emofilia/trombocitopenia per casi specifici', 'grave', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_EMOFILIA', 'Emofilia', NULL, 'grave', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_TROMBOCITOPENIA', 'Trombocitopenia', NULL, 'grave', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'IMMUNO_ONCO_COAG'), 'IMM_RADIOTERAPIA_TESTA_COLLO', 'Radioterapia testa-collo pregressa', 'Rischio osteoradionecrosi, analogo a MRONJ', 'grave', 60),

    -- CHIRURGIA
    ((SELECT id FROM anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_PROTESI_ARTICOLARI', 'Protesi articolari', 'Anca, ginocchio — dal 2024 AAOS allineato ADA: profilassi routinaria NON raccomandata nella maggioranza dei casi, valutazione caso per caso', 'normale', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_TRAPIANTO', 'Trapianto d''organo', 'Immunosoppressione, rischio infettivo', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_SPLENECTOMIA', 'Splenectomia / asplenia', 'Rischio infettivo (sepsi post-splenectomia) in procedure invasive', 'grave', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'CHIRURGIA'), 'CHI_ALTRO', 'Altri interventi chirurgici', NULL, 'normale', 40),

    -- ABITUDINI
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_FUMATORE_ATTIVO', 'Fumatore attivo', 'Impatto su guarigione post-chirurgica e osteointegrazione implantare', 'normale', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_EX_FUMATORE', 'Ex fumatore', 'Rischio parodontale/oncologico residuo', 'normale', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_VAPING', 'Sigaretta elettronica / vaping', 'Xerostomia, infiammazione gengivale — voce distinta dal fumo tradizionale (ADA)', 'normale', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_ALCOL', 'Consumo regolare di alcolici', 'Più di 2 unità/giorno', 'normale', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_DROGHE', 'Uso di sostanze', 'Interazione con vasocostrittori/anestesia', 'grave', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_BRUXISMO', 'Bruxismo / digrignamento', NULL, 'normale', 60),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_ONICOFAGIA', 'Onicofagia / morsicatura labbra', NULL, 'normale', 70),
    ((SELECT id FROM anamnesis_categories WHERE code = 'ABITUDINI'), 'ABT_PIERCING', 'Piercing orale', NULL, 'normale', 80),

    -- FATTORI_RISCHIO
    ((SELECT id FROM anamnesis_categories WHERE code = 'FATTORI_RISCHIO'), 'FTR_SPORT_AGONISTICO', 'Sportivo agonista', 'Rischio trauma dento-alveolare, indicazione a paradenti/bite — non è un''abitudine di vita', 'normale', 10),

    -- COND_ORALI
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_SENSIBILITA', 'Sensibilità dentinale', NULL, 'normale', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_SANGUINAMENTO', 'Sanguinamento gengivale', NULL, 'normale', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_MOBILITA', 'Mobilità dentale', NULL, 'normale', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_ALITOSI', 'Alitosi cronica', NULL, 'normale', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_ATM', 'Problemi ATM / dolore masticatorio', NULL, 'normale', 50),
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_XEROSTOMIA', 'Secchezza orale', 'Xerostomia', 'normale', 60),
    ((SELECT id FROM anamnesis_categories WHERE code = 'COND_ORALI'), 'COR_AFTE', 'Afte ricorrenti', NULL, 'normale', 70),

    -- GRAVIDANZA
    ((SELECT id FROM anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_GRAVIDANZA', 'Gravidanza in corso', 'Indicare il trimestre nelle note', 'grave', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_ALLATTAMENTO', 'Allattamento', NULL, 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'GRAVIDANZA'), 'GRA_ORMONI', 'Terapia ormonale', 'Pillola, HRT', 'normale', 30),

    -- PSICOLOGICO
    ((SELECT id FROM anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_ANSIA_STUDIO', 'Ansia da studio dentistico', NULL, 'normale', 10),
    ((SELECT id FROM anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_FOBIA_AGHI', 'Fobia degli aghi', 'Belonefobia — impatta somministrazione anestesia', 'grave', 20),
    ((SELECT id FROM anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_GAG_REFLEX', 'Riflesso del vomito accentuato', 'Difficoltà a tenere la bocca aperta a lungo', 'normale', 30),
    ((SELECT id FROM anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_SEDAZIONE_PREGRESSA', 'Sedazione cosciente pregressa', NULL, 'normale', 40),
    ((SELECT id FROM anamnesis_categories WHERE code = 'PSICOLOGICO'), 'PSI_ESPERIENZE_TRAUMATICHE', 'Esperienze odontoiatriche traumatiche pregresse', NULL, 'normale', 50);
```

Nota deliberata: **nessuna riga con `severity = 'severa'`** — coerente col vincolo globale del piano. `IMM_HIV` è `'grave'` (alert visibile) non `'severa'` (nessun vincolo di scheduling), con motivazione esplicita nella `description`.

- [ ] **Step 2: Verificare il conteggio**

```bash
grep -c "^    ((SELECT id FROM anamnesis_categories" database/install.sql
```

Expected: il numero di righe INSERT nel blocco appena aggiunto corrisponde a 68 (conta le righe VALUES sopra — se il conteggio diverge, un `,` di troppo/mancante ha spezzato una riga).

- [ ] **Step 3: Istanza `t_9d754153` — sostituire il seed esistente riusando gli `id`**

I due blocchi `COPY dentalcare.anamnesis_categories`/`COPY dentalcare.anamnesis_items` esistenti (`database/install.sql:3240-3374` circa) vanno **rimossi** (erano nello schema globale, non esistono più lì). Al loro posto, nel punto dove Task 1 Step 2 ha creato `t_9d754153.anamnesis_categories`/`items`, inserire lo stesso seed di Step 1-2 sopra ma qualificato `t_9d754153.` — con una differenza cruciale: le voci già referenziate da `t_9d754153.patient_anamnesis_item_selections` esistenti (`install.sql:4987+`) devono mantenere lo **stesso `id`** di oggi, altrimenti quelle selezioni pazienti già salvate nel dump demo perdono il riferimento quando la FK viene ripuntata (Task 1 Step 5).

Procedura concreta:
1. Estrarre dal dump attuale la mappa `item_id -> code` per le sole righe **oggi referenziate** da `t_9d754153.patient_anamnesis_item_selections`:
   ```bash
   grep -oP "b1000000-0000-0000-000\d-\d{12}" database/install.sql | sort -u
   ```
   (questi sono gli `id` del batch A, quello con `is_alert` coerente — verificare a mano quali compaiono nelle righe `COPY t_9d754153.patient_anamnesis_item_selections` a riga 4987+).
2. Nel blocco `INSERT INTO t_9d754153.anamnesis_items (...)` (copia di Step 2 con prefisso schema), per le sole voci che risultano referenziate, sostituire `((SELECT id FROM ...), 'CODICE', ...)` con un `INSERT` a `id` esplicito che riusa l'UUID originale, es.:
   ```sql
   ('b1000000-0000-0000-0001-000000000001', (SELECT id FROM t_9d754153.anamnesis_categories WHERE code = 'ALLERGIE'), 'ALL_PENICILLINA', 'Penicillina / Amoxicillina', 'Include tutte le betalattamine', 'grave', 10),
   ```
   Tutte le altre righe (non referenziate da nessuna selezione paziente esistente) usano `gen_random_uuid()` implicito (nessun `id` esplicito), come nel blocco standard.
3. Le voci del batch B che **non hanno corrispondenza** nel nuovo catalogo ricostruito (i duplicati eliminati) — se referenziate da qualche riga demo — vanno gestite: verificare se `t_9d754153.patient_anamnesis_item_selections` referenzia anche `id` del batch B (`00000011-...`); se sì, quelle righe demo vanno aggiornate per puntare all'`id` unificato del batch A prima di eliminare il duplicato, con un `UPDATE` esplicito prima del seed finale.

Questo step richiede lettura attenta dei dati demo esistenti al momento dell'esecuzione (non deducibile in astratto) — il worker che esegue questo task deve:
```bash
grep -A2 "COPY t_9d754153.patient_anamnesis_item_selections" database/install.sql
```
e mappare a mano ogni `item_id` trovato prima di scrivere l'`UPDATE`/i nuovi `INSERT` con `id` fisso.

- [ ] **Step 4: Migrazione tenant esistenti reali (diversi dal demo)**

Create `database/patches/2026-07-23_anamnesis_tenant_migration.sql`:

```sql
-- Migrazione one-shot: sposta il catalogo anamnesi da dentalcare (globale) a ogni schema tenant.
-- Esecuzione: una volta per DB (dev o prod), NON per singolo tenant — itera su tutti gli schema t_XXXX esistenti.
-- Prerequisito: Task 1 (CREATE TABLE) già applicato via patchSchema o manualmente su ogni schema tenant.

DO $$
DECLARE
    tenant_schema text;
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM dentalcare.tenants
    LOOP
        -- Crea le tabelle nello schema tenant se non esistono già (idempotente)
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.anamnesis_categories (
                id uuid DEFAULT gen_random_uuid() NOT NULL,
                code text,
                name text NOT NULL,
                description text,
                icon text DEFAULT ''medical_information''::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                CONSTRAINT %I CHECK ((length(TRIM(BOTH FROM name)) > 0))
            )', tenant_schema, tenant_schema || '_anamnesis_categories_name_not_empty');

        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.anamnesis_items (
                id uuid DEFAULT gen_random_uuid() NOT NULL,
                category_id uuid NOT NULL,
                code text NOT NULL,
                label text NOT NULL,
                description text,
                severity text DEFAULT ''normale''::text NOT NULL,
                sort_order integer DEFAULT 100 NOT NULL,
                enabled boolean DEFAULT true NOT NULL,
                created_at timestamp with time zone DEFAULT now() NOT NULL,
                has_detail boolean DEFAULT false NOT NULL,
                CONSTRAINT %I CHECK ((length(TRIM(BOTH FROM label)) > 0)),
                CONSTRAINT %I CHECK ((severity = ANY (ARRAY[''normale''::text, ''grave''::text, ''severa''::text])))
            )', tenant_schema, tenant_schema || '_anamnesis_items_label_not_empty', tenant_schema || '_anamnesis_items_severity_check');

        -- Copia il catalogo globale esistente COSÌ COM'È (non ancora deduplicato) — la
        -- ricostruzione avviene via applicazione dello stesso seed statico di Task 2 Step 1,
        -- eseguito a parte dal committente dopo verifica manuale dei dati già presenti nel tenant
        -- (ogni tenant reale ha selezioni pazienti che referenziano id oggi in dentalcare.anamnesis_items:
        -- questa copia preserva quegli id, la deduplicazione va fatta con un passaggio successivo
        -- di UPDATE + soft-disable, non con un DELETE, per non rompere le selezioni esistenti).
        EXECUTE format('
            INSERT INTO %I.anamnesis_categories (id, code, name, description, icon, sort_order, enabled, created_at)
            SELECT id, code, name, description, icon, sort_order, enabled, created_at
            FROM dentalcare.anamnesis_categories
            ON CONFLICT DO NOTHING', tenant_schema);

        EXECUTE format('
            INSERT INTO %I.anamnesis_items (id, category_id, code, label, description, severity, sort_order, enabled, created_at, has_detail)
            SELECT id, category_id, code, label, description,
                   CASE WHEN is_alert THEN ''grave'' ELSE ''normale'' END,
                   sort_order, enabled, created_at, has_detail
            FROM dentalcare.anamnesis_items
            ON CONFLICT DO NOTHING', tenant_schema);

        -- Ripunta la FK di patient_anamnesis_item_selections allo schema tenant
        EXECUTE format('
            ALTER TABLE %I.patient_anamnesis_item_selections
            DROP CONSTRAINT IF EXISTS patient_anamnesis_item_selections_item_id_fkey', tenant_schema);
        EXECUTE format('
            ALTER TABLE %I.patient_anamnesis_item_selections
            ADD CONSTRAINT patient_anamnesis_item_selections_item_id_fkey
                FOREIGN KEY (item_id) REFERENCES %I.anamnesis_items(id) ON DELETE CASCADE', tenant_schema, tenant_schema);

        RAISE NOTICE 'Migrato catalogo anamnesi per schema %', tenant_schema;
    END LOOP;
END $$;
```

Nota: questo script copia il catalogo **as-is** (non deduplicato) per ogni tenant reale esistente, preservando gli `id` — la deduplicazione/arricchimento (Step 1-2, il seed ricostruito) va applicata **dopo**, tenant per tenant, con `UPDATE`/`INSERT ... ON CONFLICT` mirati che aggiungono le voci mancanti e disabilitano (`enabled=false`, mai `DELETE`) i duplicati, verificando prima via `SELECT count(*)` che non siano in uso da nessun paziente di quel tenant (stesso principio del count-check-prima-del-delete già stabilito). Questo secondo passaggio **non è incluso in questo script** — è deliberatamente un'operazione supervisionata, non automatica, perché tocca dati clinici reali di studi con pazienti veri: la esegue il committente con il dry-run di verifica preparato dall'agente, non un job automatico.

- [ ] **Step 5: Commit**

```bash
git add database/install.sql database/patches/2026-07-23_anamnesis_tenant_migration.sql
git commit -m "feat(anamnesi): seed catalogo ricostruito (dedup + voci mancanti da ricerca clinica) per nuovi tenant e migrazione per tenant esistenti"
```

---

## Task 3: Backend — `AnamnesisCatalogService`/`Controller` per-tenant + severità + cascade-delete sicuro

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/AnamnesisCatalogService.java`
- Modify: `backend/src/main/java/com/dentalcare/dto/CatalogItemDto.java`
- Modify: `backend/src/main/java/com/dentalcare/dto/CreateCatalogItemRequest.java`
- Modify: `backend/src/main/java/com/dentalcare/dto/UpdateCatalogItemRequest.java`
- Create: `backend/src/test/java/com/dentalcare/service/AnamnesisCatalogServiceTest.java`

**Interfaces:**
- Consumes: `TenantContext.validatedSchema()` (esistente, `com.dentalcare.security.TenantContext`)
- Produces: `CatalogItemDto(UUID id, UUID categoryId, String code, String label, String description, String severity, int sortOrder, boolean enabled)` — consumato da Task 9 (frontend)

- [ ] **Step 1: Aggiornare i DTO — `isAlert` → `severity`**

`backend/src/main/java/com/dentalcare/dto/CatalogItemDto.java`:
```java
package com.dentalcare.dto;

import java.util.UUID;

public record CatalogItemDto(
        UUID id, UUID categoryId, String code, String label,
        String description, String severity, int sortOrder, boolean enabled
) {}
```

`backend/src/main/java/com/dentalcare/dto/CreateCatalogItemRequest.java`:
```java
package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.UUID;

public record CreateCatalogItemRequest(
        UUID categoryId,
        @NotBlank String code,
        @NotBlank String label,
        String description,
        @Pattern(regexp = "normale|grave|severa") String severity,
        int sortOrder
) {}
```

`backend/src/main/java/com/dentalcare/dto/UpdateCatalogItemRequest.java`:
```java
package com.dentalcare.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateCatalogItemRequest(
        @NotBlank String label,
        String description,
        @Pattern(regexp = "normale|grave|severa") String severity,
        int sortOrder,
        boolean enabled
) {}
```

- [ ] **Step 2: Riscrivere `AnamnesisCatalogService` — schema per-tenant + severità + count-check-prima-del-delete**

`backend/src/main/java/com/dentalcare/service/AnamnesisCatalogService.java` (sostituzione completa):

```java
package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.exception.CatalogItemInUseException;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class AnamnesisCatalogService {

    private final NamedParameterJdbcTemplate jdbc;

    public AnamnesisCatalogService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    // ── Categories ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<CatalogCategoryDto> findAllCategories() {
        return jdbc.query("""
            SELECT c.id, c.code, c.name, c.description, c.icon, c.sort_order, c.enabled,
                   COUNT(i.id) AS items_count
            FROM %s.anamnesis_categories c
            LEFT JOIN %s.anamnesis_items i ON i.category_id = c.id
            GROUP BY c.id, c.code, c.name, c.description, c.icon, c.sort_order, c.enabled
            ORDER BY c.sort_order, c.name
            """.formatted(s(), s()),
            new MapSqlParameterSource(),
            (rs, n) -> new CatalogCategoryDto(
                    rs.getObject("id", UUID.class),
                    rs.getString("code"),
                    rs.getString("name"),
                    rs.getString("description"),
                    rs.getString("icon"),
                    rs.getInt("sort_order"),
                    rs.getBoolean("enabled"),
                    rs.getLong("items_count")
            ));
    }

    @Transactional
    public CatalogCategoryDto createCategory(CreateCatalogCategoryRequest req) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO %s.anamnesis_categories
                (id, code, name, description, icon, sort_order, enabled)
            VALUES (:id, :code, :name, :description, :icon, :sortOrder, true)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("code", req.code().toUpperCase().trim())
                .addValue("name", req.name())
                .addValue("description", req.description())
                .addValue("icon", req.icon())
                .addValue("sortOrder", req.sortOrder()));
        return findAllCategories().stream()
                .filter(c -> c.id().equals(id))
                .findFirst().orElseThrow();
    }

    @Transactional
    public void updateCategory(UUID id, UpdateCatalogCategoryRequest req) {
        jdbc.update("""
            UPDATE %s.anamnesis_categories
            SET name = :name, description = :description, icon = :icon,
                sort_order = :sortOrder, enabled = :enabled
            WHERE id = :id
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("name", req.name())
                .addValue("description", req.description())
                .addValue("icon", req.icon())
                .addValue("sortOrder", req.sortOrder())
                .addValue("enabled", req.enabled()));
    }

    @Transactional
    public void deleteCategory(UUID id) {
        long inUse = countPatientsUsingCategory(id);
        if (inUse > 0) {
            throw new CatalogItemInUseException(
                    "Impossibile eliminare: %d pazienti hanno una voce di questa categoria selezionata nell'anamnesi. Disabilita la categoria invece di eliminarla.".formatted(inUse));
        }
        jdbc.update("DELETE FROM %s.anamnesis_categories WHERE id = :id".formatted(s()),
            new MapSqlParameterSource("id", id));
    }

    private long countPatientsUsingCategory(UUID categoryId) {
        Long count = jdbc.queryForObject("""
            SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections s
            JOIN %s.anamnesis_items i ON i.id = s.item_id
            WHERE i.category_id = :categoryId AND s.resolved_at IS NULL
            """.formatted(s(), s()),
            new MapSqlParameterSource("categoryId", categoryId), Long.class);
        return count != null ? count : 0L;
    }

    // ── Items ─────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<CatalogItemDto> findItemsByCategory(UUID categoryId) {
        return jdbc.query("""
            SELECT id, category_id, code, label, description, severity, sort_order, enabled
            FROM %s.anamnesis_items
            WHERE category_id = :categoryId
            ORDER BY sort_order, label
            """.formatted(s()),
            new MapSqlParameterSource("categoryId", categoryId),
            (rs, n) -> new CatalogItemDto(
                    rs.getObject("id", UUID.class),
                    rs.getObject("category_id", UUID.class),
                    rs.getString("code"),
                    rs.getString("label"),
                    rs.getString("description"),
                    rs.getString("severity"),
                    rs.getInt("sort_order"),
                    rs.getBoolean("enabled")
            ));
    }

    @Transactional
    public CatalogItemDto createItem(CreateCatalogItemRequest req) {
        UUID id = UUID.randomUUID();
        String severity = req.severity() != null ? req.severity() : "normale";
        jdbc.update("""
            INSERT INTO %s.anamnesis_items
                (id, category_id, code, label, description, severity, sort_order, enabled)
            VALUES (:id, :categoryId, :code, :label, :description, :severity, :sortOrder, true)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("categoryId", req.categoryId())
                .addValue("code", req.code().toUpperCase().trim())
                .addValue("label", req.label())
                .addValue("description", req.description())
                .addValue("severity", severity)
                .addValue("sortOrder", req.sortOrder()));
        return findItemsByCategory(req.categoryId()).stream()
                .filter(i -> i.id().equals(id))
                .findFirst().orElseThrow();
    }

    @Transactional
    public void updateItem(UUID id, UpdateCatalogItemRequest req) {
        String severity = req.severity() != null ? req.severity() : "normale";
        jdbc.update("""
            UPDATE %s.anamnesis_items
            SET label = :label, description = :description, severity = :severity,
                sort_order = :sortOrder, enabled = :enabled
            WHERE id = :id
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("label", req.label())
                .addValue("description", req.description())
                .addValue("severity", severity)
                .addValue("sortOrder", req.sortOrder())
                .addValue("enabled", req.enabled()));
    }

    @Transactional
    public void deleteItem(UUID id) {
        long inUse = countPatientsUsingItem(id);
        if (inUse > 0) {
            throw new CatalogItemInUseException(
                    "Impossibile eliminare: %d pazienti hanno questa voce selezionata nell'anamnesi. Disabilita la voce invece di eliminarla.".formatted(inUse));
        }
        jdbc.update("DELETE FROM %s.anamnesis_items WHERE id = :id".formatted(s()),
            new MapSqlParameterSource("id", id));
    }

    private long countPatientsUsingItem(UUID itemId) {
        Long count = jdbc.queryForObject("""
            SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections
            WHERE item_id = :itemId AND resolved_at IS NULL
            """.formatted(s()),
            new MapSqlParameterSource("itemId", itemId), Long.class);
        return count != null ? count : 0L;
    }
}
```

Nota: `countPatientsUsingItem`/`countPatientsUsingCategory` filtrano su `resolved_at IS NULL` — dipendono dalla colonna `resolved_at` introdotta da **Task 4**. Se questo Task 3 viene eseguito prima di Task 4, la query fallisce (colonna inesistente): **eseguire Task 4 prima di Task 3**, oppure — se si preferisce l'ordine di questo piano — applicare Task 4 Step 1 (solo l'`ALTER TABLE`, non il resto) come prerequisito immediato di questo step. Il worker che esegue: verificare `\d anamnesis_items` / `\d patient_anamnesis_item_selections` su un tenant di test prima di lanciare i test di questo task.

- [ ] **Step 3: Nuova eccezione `CatalogItemInUseException`**

Create `backend/src/main/java/com/dentalcare/exception/CatalogItemInUseException.java`:

```java
package com.dentalcare.exception;

public class CatalogItemInUseException extends RuntimeException {
    public CatalogItemInUseException(String message) {
        super(message);
    }
}
```

Registrare in `GlobalExceptionHandler` (`backend/src/main/java/com/dentalcare/exception/GlobalExceptionHandler.java` — verificare nome esatto della classe esistente con `grep -rn "@RestControllerAdvice" backend/src/main/java`) un handler che mappa questa eccezione a **409 Conflict**:

```java
@ExceptionHandler(CatalogItemInUseException.class)
@ResponseStatus(HttpStatus.CONFLICT)
public ErrorResponse handleCatalogItemInUse(CatalogItemInUseException ex) {
    return ErrorResponse.of("CATALOG_ITEM_IN_USE", ex.getMessage());
}
```

(Adattare al formato `ErrorResponse`/pattern già usato dagli altri handler nella stessa classe — leggere `GlobalExceptionHandler.java` prima di scrivere questo step per matchare esattamente firma e stile.)

- [ ] **Step 4: Test — creazione, aggiornamento, delete bloccato, delete permesso**

Create `backend/src/test/java/com/dentalcare/service/AnamnesisCatalogServiceTest.java`:

```java
package com.dentalcare.service;

import com.dentalcare.dto.CreateCatalogCategoryRequest;
import com.dentalcare.dto.CreateCatalogItemRequest;
import com.dentalcare.dto.CatalogCategoryDto;
import com.dentalcare.dto.CatalogItemDto;
import com.dentalcare.exception.CatalogItemInUseException;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class AnamnesisCatalogServiceTest {

    @Autowired AnamnesisCatalogService service;
    @Autowired NamedParameterJdbcTemplate jdbc;

    private static final String TEST_SCHEMA = "t_9d754153"; // schema demo, presente in ogni ambiente di test

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void createItem_persistsSeverity() {
        CatalogCategoryDto cat = service.createCategory(
                new CreateCatalogCategoryRequest("TEST_CAT_" + UUID.randomUUID(), "Categoria di test", null, null, 999));

        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM", "Voce di test", null, "grave", 10));

        assertThat(item.severity()).isEqualTo("grave");
        assertThat(item.categoryId()).isEqualTo(cat.id());
    }

    @Test
    void deleteItem_blockedWhenUsedByActivePatientSelection() {
        CatalogCategoryDto cat = service.createCategory(
                new CreateCatalogCategoryRequest("TEST_CAT_" + UUID.randomUUID(), "Categoria di test", null, null, 999));
        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM_INUSE", "Voce in uso", null, "grave", 10));

        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        UUID patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        jdbc.update("""
            INSERT INTO %s.patient_anamnesis_item_selections (clinic_id, patient_id, item_id)
            VALUES (:clinicId, :patientId, :itemId)
            """.formatted(TEST_SCHEMA),
            new MapSqlParameterSource()
                .addValue("clinicId", clinicId)
                .addValue("patientId", patientId)
                .addValue("itemId", item.id()));

        assertThatThrownBy(() -> service.deleteItem(item.id()))
                .isInstanceOf(CatalogItemInUseException.class)
                .hasMessageContaining("1 pazienti");
    }

    @Test
    void deleteItem_allowedWhenUnused() {
        CatalogCategoryDto cat = service.createCategory(
                new CreateCatalogCategoryRequest("TEST_CAT_" + UUID.randomUUID(), "Categoria di test", null, null, 999));
        CatalogItemDto item = service.createItem(
                new CreateCatalogItemRequest(cat.id(), "TEST_ITEM_UNUSED", "Voce non usata", null, "normale", 10));

        service.deleteItem(item.id());

        assertThat(service.findItemsByCategory(cat.id())).noneMatch(i -> i.id().equals(item.id()));
    }
}
```

- [ ] **Step 5: Run test to verify**

```bash
cd backend && ./mvnw test -Dtest=AnamnesisCatalogServiceTest
```

Expected: `deleteItem_blockedWhenUsedByActivePatientSelection` PASS solo dopo che Task 4 ha aggiunto `resolved_at` — se fallisce con "column resolved_at does not exist", eseguire prima Task 4 Step 1.

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/AnamnesisCatalogService.java \
        backend/src/main/java/com/dentalcare/dto/CatalogItemDto.java \
        backend/src/main/java/com/dentalcare/dto/CreateCatalogItemRequest.java \
        backend/src/main/java/com/dentalcare/dto/UpdateCatalogItemRequest.java \
        backend/src/main/java/com/dentalcare/exception/CatalogItemInUseException.java \
        backend/src/test/java/com/dentalcare/service/AnamnesisCatalogServiceTest.java
git commit -m "feat(anamnesi): catalogo per-tenant, severity a 3 livelli, delete bloccato se in uso"
```

---

## Task 4: DB + Backend — storico `patient_anamnesis_item_selections` e riscrittura `savePatientAnamnesis`

**Files:**
- Modify: `database/install.sql` (template + istanza — colonna `resolved_at` + indice unico parziale su `patient_anamnesis_item_selections`)
- Modify: `backend/src/main/java/com/dentalcare/service/AnamnesisService.java`
- Modify: `backend/src/main/java/com/dentalcare/dto/AnamnesisItemDto.java` (aggiungere `severity`)
- Create: `backend/src/test/java/com/dentalcare/service/AnamnesisServiceTest.java`

**Interfaces:**
- Consumes: tabella `patient_anamnesis_item_selections` esistente (Task 1/2 non la toccano, solo la FK)
- Produces: colonna `resolved_at`, usata da Task 3 (count-check), Task 5 (diff), Task 6 (vista severità)

- [ ] **Step 1: DDL — colonna `resolved_at` + indice unico parziale**

Template `create_tenant()` (`database/install.sql`, subito dopo `CREATE TABLE patient_anamnesis_item_selections` di Task 1 riferimento, ma **questa colonna va aggiunta alla tabella esistente**, non a una nuova — il `CREATE TABLE` di `patient_anamnesis_item_selections` è **immutato** salvo l'aggiunta di questa colonna nella sua definizione):

```sql
-- Nel CREATE TABLE patient_anamnesis_item_selections esistente (riga ~666), aggiungere la colonna:
--     resolved_at timestamp with time zone,  -- NULL = condizione tuttora attiva
-- subito dopo recorded_by_provider_id.
```

Concretamente, modificare il blocco esistente:

```sql
-- PRIMA
CREATE TABLE patient_anamnesis_item_selections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    item_id uuid NOT NULL,
    notes text,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by_provider_id uuid
);

-- DOPO
CREATE TABLE patient_anamnesis_item_selections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    item_id uuid NOT NULL,
    notes text,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by_provider_id uuid,
    resolved_at timestamp with time zone
);
```

Stessa modifica nell'istanza `t_9d754153` (blocco gemello).

Poi, nella sezione constraint del template (dove oggi vive `patient_anamnesis_item_selections_unique`, `install.sql:1223`):

```sql
-- PRIMA
ALTER TABLE ONLY patient_anamnesis_item_selections
    ADD CONSTRAINT patient_anamnesis_item_selections_unique UNIQUE (clinic_id, patient_id, item_id);

-- DOPO — rimuovere la riga sopra, sostituire con un indice unico parziale (fuori dal blocco ALTER TABLE CONSTRAINT, va nella sezione CREATE INDEX)
```

Rimuovere interamente la riga `ADD CONSTRAINT patient_anamnesis_item_selections_unique UNIQUE (...)`. Nella sezione `CREATE INDEX` (vicino a `ix_patient_anamnesis_selections_patient`, `install.sql:1397`), aggiungere:

```sql
CREATE UNIQUE INDEX ux_patient_anamnesis_selections_active
    ON patient_anamnesis_item_selections USING btree (clinic_id, patient_id, item_id)
    WHERE (resolved_at IS NULL);
```

Ripetere entrambe le modifiche (colonna + indice, rimozione del vecchio UNIQUE) nell'istanza `t_9d754153` con prefisso schema e nome indice `t_9d754153_ux_patient_anamnesis_selections_active`.

- [ ] **Step 2: `AnamnesisItemDto` — aggiungere `severity`**

`backend/src/main/java/com/dentalcare/dto/AnamnesisItemDto.java`:

```java
package com.dentalcare.dto;

import java.util.UUID;

public record AnamnesisItemDto(
        UUID id,
        String code,
        String label,
        String description,
        String severity,
        int sortOrder,
        boolean selected,
        String selectionNotes
) {
}
```

- [ ] **Step 3: Riscrivere `getPatientAnamnesis` — filtrare su `resolved_at IS NULL` e leggere `severity`**

In `backend/src/main/java/com/dentalcare/service/AnamnesisService.java`, sostituire il metodo `getPatientAnamnesis`:

```java
@Transactional(readOnly = true)
public List<AnamnesisCategoryDto> getPatientAnamnesis(UUID patientId) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

    String sql = """
        SELECT
            ac.id AS category_id,
            ac.code AS category_code,
            ac.name AS category_name,
            ac.description AS category_description,
            ac.icon AS category_icon,
            ac.sort_order AS category_sort_order,
            ai.id AS item_id,
            ai.code AS item_code,
            ai.label AS item_label,
            ai.description AS item_description,
            ai.severity,
            ai.sort_order AS item_sort_order,
            s.id AS selection_id,
            s.notes AS selection_notes
        FROM %s.anamnesis_categories ac
        JOIN %s.anamnesis_items ai
            ON ai.category_id = ac.id
           AND ai.enabled = true
        LEFT JOIN %s.patient_anamnesis_item_selections s
            ON s.item_id = ai.id
           AND s.patient_id = :patientId
           AND s.clinic_id = :clinicId
           AND s.resolved_at IS NULL
        WHERE ac.enabled = true
        ORDER BY ac.sort_order, ac.code, ai.sort_order, ai.code
        """.formatted(s(), s(), s());

    MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("patientId", patientId)
            .addValue("clinicId", clinicId);

    List<Map<String, Object>> rows = jdbc.queryForList(sql, params);

    return buildCategoryList(rows);
}
```

- [ ] **Step 4: Riscrivere `savePatientAnamnesis` — diff invece di wipe+replace**

Sostituire completamente il metodo `savePatientAnamnesis` e aggiungere gli helper privati:

```java
@Transactional
public void savePatientAnamnesis(UUID patientId, SaveAnamnesisRequest request) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

    Set<UUID> currentlyActive = new HashSet<>(jdbc.queryForList("""
            SELECT item_id FROM %s.patient_anamnesis_item_selections
            WHERE clinic_id = :clinicId AND patient_id = :patientId AND resolved_at IS NULL
            """.formatted(s()),
            new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
            UUID.class));

    List<SaveAnamnesisRequest.ItemSelection> selections =
            request.selections() != null ? request.selections() : List.of();
    Map<UUID, String> newNotesByItem = new HashMap<>();
    for (SaveAnamnesisRequest.ItemSelection sel : selections) {
        newNotesByItem.put(sel.itemId(), sel.notes());
    }
    Set<UUID> newActive = newNotesByItem.keySet();

    // Voci nuove o ricomparse: INSERT (mai riattivazione della vecchia riga — fedeltà storica)
    for (UUID itemId : newActive) {
        if (!currentlyActive.contains(itemId)) {
            jdbc.update("""
                INSERT INTO %s.patient_anamnesis_item_selections
                    (clinic_id, patient_id, item_id, notes)
                VALUES (:clinicId, :patientId, :itemId, :notes)
                """.formatted(s()),
                new MapSqlParameterSource()
                    .addValue("clinicId", clinicId)
                    .addValue("patientId", patientId)
                    .addValue("itemId", itemId)
                    .addValue("notes", newNotesByItem.get(itemId)));
        } else {
            // Voce già attiva: solo aggiornamento note, nessuna nuova versione
            jdbc.update("""
                UPDATE %s.patient_anamnesis_item_selections
                SET notes = :notes, updated_at = now()
                WHERE clinic_id = :clinicId AND patient_id = :patientId
                  AND item_id = :itemId AND resolved_at IS NULL
                """.formatted(s()),
                new MapSqlParameterSource()
                    .addValue("clinicId", clinicId)
                    .addValue("patientId", patientId)
                    .addValue("itemId", itemId)
                    .addValue("notes", newNotesByItem.get(itemId)));
        }
    }

    // Voci non più selezionate: risoluzione, mai DELETE
    for (UUID itemId : currentlyActive) {
        if (!newActive.contains(itemId)) {
            jdbc.update("""
                UPDATE %s.patient_anamnesis_item_selections
                SET resolved_at = now()
                WHERE clinic_id = :clinicId AND patient_id = :patientId
                  AND item_id = :itemId AND resolved_at IS NULL
                """.formatted(s()),
                new MapSqlParameterSource()
                    .addValue("clinicId", clinicId)
                    .addValue("patientId", patientId)
                    .addValue("itemId", itemId));
        }
    }

    syncLegacyAnamnesis(patientId, clinicId, request);
}
```

Aggiungere gli import necessari in cima al file: `java.util.HashMap`, `java.util.HashSet`, `java.util.Set` (probabilmente già coperti da `import java.util.*;` esistente — verificare, il file attuale ha già quel wildcard import).

- [ ] **Step 5: Aggiornare `syncLegacyAnamnesis` e le query interne — schema per-tenant per il catalogo**

Il metodo `syncLegacyAnamnesis` fa riferimento a `dentalcare.anamnesis_items` in ogni subquery `EXISTS` (24 occorrenze, tutte con `JOIN dentalcare.anamnesis_items ai`). Sostituire ogni `dentalcare.anamnesis_items` con `%s.anamnesis_items` (schema tenant) — dato che sono già dentro una stringa `.formatted(...)` con placeholder posizionali multipli, il modo più sicuro è una sostituzione testuale del blocco:

```bash
# Nel file AnamnesisService.java, dentro syncLegacyAnamnesis:
# ogni "JOIN dentalcare.anamnesis_items ai" diventa "JOIN %s.anamnesis_items ai"
```

E aggiungere altrettanti `s()` in più nella chiamata `.formatted(...)` finale del metodo (oggi passa `s()` 25 volte per le altre tabelle — con questa modifica servono 25 `s()` aggiuntivi in più, uno per ogni `JOIN dentalcare.anamnesis_items` convertito). Dato il rischio di errore nel contare manualmente i placeholder posizionali `%s` in una stringa con 25+ occorrenze, il worker che esegue questo step deve:
1. Sostituire ogni `dentalcare.anamnesis_items` con `%s.anamnesis_items` nel testo SQL.
2. Contare il numero totale di `%s` nella stringa risultante con `grep -o '%s' <file> | wc -l` limitato al blocco della query.
3. Passare esattamente quel numero di `s()` a `.formatted(...)`, nello stesso ordine in cui compaiono i placeholder nella stringa (il primo `%s` è la tabella di INSERT, poi uno per ogni JOIN).
4. Compilare (`./mvnw compile`) — un numero sbagliato di argomenti a `.formatted()` fallisce a runtime con `MissingFormatArgumentException`, non a compile-time (stringa costruita in un blocco text, non literal semplice) — **verificare con un test che esegue `savePatientAnamnesis` end-to-end**, non solo la compilazione.

- [ ] **Step 6: Test — diff-based save preserva lo storico**

Create `backend/src/test/java/com/dentalcare/service/AnamnesisServiceTest.java`:

```java
package com.dentalcare.service;

import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class AnamnesisServiceTest {

    @Autowired AnamnesisService service;
    @Autowired NamedParameterJdbcTemplate jdbc;

    private static final String TEST_SCHEMA = "t_9d754153";
    private UUID patientId;
    private UUID itemId;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        TenantContext.setCurrentClinicId(clinicId.toString());
        patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemId = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_LATEX'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        // stato pulito
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void resolvingAnItem_setsResolvedAt_doesNotDelete() {
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemId, null)), null, null));

        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(List.of(), null, null));

        Integer totalRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid AND item_id = :iid"
                        .formatted(TEST_SCHEMA),
                new MapSqlParameterSource().addValue("pid", patientId).addValue("iid", itemId), Integer.class);
        Integer activeRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid AND item_id = :iid AND resolved_at IS NULL"
                        .formatted(TEST_SCHEMA),
                new MapSqlParameterSource().addValue("pid", patientId).addValue("iid", itemId), Integer.class);

        assertThat(totalRows).isEqualTo(1); // la riga esiste ancora (mai DELETE)
        assertThat(activeRows).isEqualTo(0); // ma non è più attiva
    }

    @Test
    void reselectingAResolvedItem_createsNewRow_notReactivation() {
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemId, "prima volta")), null, null));
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(List.of(), null, null));
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemId, "seconda volta")), null, null));

        Integer totalRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid AND item_id = :iid"
                        .formatted(TEST_SCHEMA),
                new MapSqlParameterSource().addValue("pid", patientId).addValue("iid", itemId), Integer.class);

        assertThat(totalRows).isEqualTo(2); // due righe storiche distinte, non una riattivata
    }
}
```

- [ ] **Step 7: Run test to verify**

```bash
cd backend && ./mvnw test -Dtest=AnamnesisServiceTest
```

Expected: entrambi PASS.

- [ ] **Step 8: Commit**

```bash
git add database/install.sql \
        backend/src/main/java/com/dentalcare/service/AnamnesisService.java \
        backend/src/main/java/com/dentalcare/dto/AnamnesisItemDto.java \
        backend/src/test/java/com/dentalcare/service/AnamnesisServiceTest.java
git commit -m "feat(anamnesi): storico append-only delle selezioni paziente (resolved_at), mai piu' wipe+replace"
```

---

## Task 5: Backend — endpoint diff anamnesi

**Files:**
- Create: `backend/src/main/java/com/dentalcare/dto/AnamnesisDiffDto.java`
- Modify: `backend/src/main/java/com/dentalcare/service/AnamnesisService.java` (nuovo metodo `getDiffSinceLastVisit`)
- Modify: `backend/src/main/java/com/dentalcare/controller/AnamnesisController.java` (nuovo endpoint)
- Create: `backend/src/test/java/com/dentalcare/service/AnamnesisDiffTest.java`

**Interfaces:**
- Consumes: `patient_anamnesis_item_selections` con `resolved_at` (Task 4)
- Produces: `GET /api/patients/{patientId}/anamnesis/diff` → `AnamnesisDiffDto`, consumato da Task 10 (frontend badge)

- [ ] **Step 1: DTO diff**

Create `backend/src/main/java/com/dentalcare/dto/AnamnesisDiffDto.java`:

```java
package com.dentalcare.dto;

import java.util.List;

public record AnamnesisDiffDto(
        List<AnamnesisDiffItem> newItems,
        List<AnamnesisDiffItem> resolvedItems,
        List<AnamnesisDiffItem> unchangedItems
) {
    public record AnamnesisDiffItem(String code, String label, String severity) {}
}
```

- [ ] **Step 2: Metodo `getDiffSinceLastVisit` in `AnamnesisService`**

Aggiungere a `AnamnesisService.java`:

```java
@Transactional(readOnly = true)
public AnamnesisDiffDto getDiffSinceLastVisit(UUID patientId) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

    // Ultima data di modifica anamnesi PRIMA della sessione corrente: la riga più recente
    // tra recorded_at (nuove selezioni) e resolved_at (risoluzioni) esclusa la più recente
    // in assoluto, per confrontare "oggi" con "l'ultima visita precedente a oggi".
    List<java.time.OffsetDateTime> changePoints = jdbc.queryForList("""
        SELECT DISTINCT change_at FROM (
            SELECT recorded_at AS change_at FROM %s.patient_anamnesis_item_selections
            WHERE clinic_id = :clinicId AND patient_id = :patientId
            UNION
            SELECT resolved_at AS change_at FROM %s.patient_anamnesis_item_selections
            WHERE clinic_id = :clinicId AND patient_id = :patientId AND resolved_at IS NOT NULL
        ) t
        ORDER BY change_at DESC
        """.formatted(s(), s()),
        new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
        java.time.OffsetDateTime.class);

    if (changePoints.size() < 2) {
        // Nessuna visita precedente da confrontare: tutto quello che è attivo oggi è "nuovo"
        // rispetto a un'anamnesi mai registrata prima.
        List<AnamnesisDiffDto.AnamnesisDiffItem> allActive = activeItemsAt(patientId, clinicId, null);
        return new AnamnesisDiffDto(allActive, List.of(), List.of());
    }

    java.time.OffsetDateTime previousVisitAt = changePoints.get(1);
    List<AnamnesisDiffDto.AnamnesisDiffItem> activeNow = activeItemsAt(patientId, clinicId, null);
    List<AnamnesisDiffDto.AnamnesisDiffItem> activeBefore = activeItemsAt(patientId, clinicId, previousVisitAt);

    Set<String> codesNow = activeNow.stream().map(AnamnesisDiffDto.AnamnesisDiffItem::code).collect(java.util.stream.Collectors.toSet());
    Set<String> codesBefore = activeBefore.stream().map(AnamnesisDiffDto.AnamnesisDiffItem::code).collect(java.util.stream.Collectors.toSet());

    List<AnamnesisDiffDto.AnamnesisDiffItem> newItems = activeNow.stream()
            .filter(i -> !codesBefore.contains(i.code())).toList();
    List<AnamnesisDiffDto.AnamnesisDiffItem> resolvedItems = activeBefore.stream()
            .filter(i -> !codesNow.contains(i.code())).toList();
    List<AnamnesisDiffDto.AnamnesisDiffItem> unchangedItems = activeNow.stream()
            .filter(i -> codesBefore.contains(i.code())).toList();

    return new AnamnesisDiffDto(newItems, resolvedItems, unchangedItems);
}

/** Voci attive al momento `asOf` (o ora, se null): recorded_at <= asOf AND (resolved_at IS NULL OR resolved_at > asOf). */
private List<AnamnesisDiffDto.AnamnesisDiffItem> activeItemsAt(UUID patientId, UUID clinicId, java.time.OffsetDateTime asOf) {
    String timeFilter = asOf != null
            ? "AND s.recorded_at <= :asOf AND (s.resolved_at IS NULL OR s.resolved_at > :asOf)"
            : "AND s.resolved_at IS NULL";
    MapSqlParameterSource params = new MapSqlParameterSource()
            .addValue("clinicId", clinicId).addValue("patientId", patientId);
    if (asOf != null) params.addValue("asOf", asOf);
    return jdbc.query("""
        SELECT ai.code, ai.label, ai.severity
        FROM %s.patient_anamnesis_item_selections s
        JOIN %s.anamnesis_items ai ON ai.id = s.item_id
        WHERE s.clinic_id = :clinicId AND s.patient_id = :patientId
        %s
        """.formatted(s(), s(), timeFilter),
        params,
        (rs, n) -> new AnamnesisDiffDto.AnamnesisDiffItem(
                rs.getString("code"), rs.getString("label"), rs.getString("severity")));
}
```

Aggiungere import `com.dentalcare.dto.AnamnesisDiffDto` e `java.util.Set` in cima al file.

- [ ] **Step 3: Endpoint controller**

In `backend/src/main/java/com/dentalcare/controller/AnamnesisController.java`, aggiungere:

```java
@GetMapping("/diff")
public AnamnesisDiffDto getDiff(@PathVariable UUID patientId) {
    return anamnesisService.getDiffSinceLastVisit(patientId);
}
```

E l'import `com.dentalcare.dto.AnamnesisDiffDto` in cima al file.

- [ ] **Step 4: Test**

Create `backend/src/test/java/com/dentalcare/service/AnamnesisDiffTest.java`:

```java
package com.dentalcare.service;

import com.dentalcare.dto.AnamnesisDiffDto;
import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles("test")
class AnamnesisDiffTest {

    @Autowired AnamnesisService service;
    @Autowired NamedParameterJdbcTemplate jdbc;

    private static final String TEST_SCHEMA = "t_9d754153";
    private UUID patientId;
    private UUID itemLatex;
    private UUID itemPenicillina;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
        UUID clinicId = jdbc.queryForObject(
                "SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        TenantContext.setCurrentClinicId(clinicId.toString());
        patientId = jdbc.queryForObject(
                "SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemLatex = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_LATEX'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        itemPenicillina = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'ALL_PENICILLINA'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void diff_detectsNewAndResolvedItems() throws InterruptedException {
        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemLatex, null)), null, null));
        Thread.sleep(10); // garantisce timestamp distinti tra le due visite

        service.savePatientAnamnesis(patientId, new SaveAnamnesisRequest(
                List.of(new SaveAnamnesisRequest.ItemSelection(itemPenicillina, null)), null, null));

        AnamnesisDiffDto diff = service.getDiffSinceLastVisit(patientId);

        assertThat(diff.newItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code).containsExactly("ALL_PENICILLINA");
        assertThat(diff.resolvedItems()).extracting(AnamnesisDiffDto.AnamnesisDiffItem::code).containsExactly("ALL_LATEX");
    }
}
```

- [ ] **Step 5: Run test to verify**

```bash
cd backend && ./mvnw test -Dtest=AnamnesisDiffTest
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/dentalcare/dto/AnamnesisDiffDto.java \
        backend/src/main/java/com/dentalcare/service/AnamnesisService.java \
        backend/src/main/java/com/dentalcare/controller/AnamnesisController.java \
        backend/src/test/java/com/dentalcare/service/AnamnesisDiffTest.java
git commit -m "feat(anamnesi): endpoint diff anamnesi (nuove/risolte/invariate) tra visita corrente e precedente"
```

---

## Task 6: DB — vista severità aggregata + alert catalogo in dashboard/agenda/cartella

**Files:**
- Modify: `database/install.sql` (nuova vista `v_patient_max_anamnesis_severity`, template + istanza)
- Modify: `database/install.sql` (estendere `v_agenda_daily` con `has_catalog_alert`, template + istanza)
- Modify: `database/install.sql` (estendere `v_patient_clinical_card` con `catalog_alert_severity`, template + istanza)
- Modify: `backend/src/main/java/com/dentalcare/dto/PatientDetailDto.java` (nuovo campo)
- Modify: `backend/src/main/java/com/dentalcare/dto/AppointmentDto.java` (nuovo campo — verificare nome esatto del file con `grep -rn "hasAllergyAlert" backend/src/main/java/com/dentalcare/dto`)
- Modify: `backend/src/main/java/com/dentalcare/service/PatientService.java` (mappare il nuovo campo — verificare metodo esatto che mappa `v_patient_clinical_card` con `grep -rn "v_patient_clinical_card" backend/src/main/java`)

**Interfaces:**
- Consumes: `anamnesis_items.severity` (Task 1/2), `patient_anamnesis_item_selections.resolved_at` (Task 4)
- Produces: colonna `has_catalog_alert` (agenda), `catalog_alert_severity` (cartella), consumate da Task 9

- [ ] **Step 1: Vista `v_patient_max_anamnesis_severity` — template**

In `database/install.sql`, subito dopo la definizione di `v_agenda_daily` esistente (circa riga 1050, prima di `CREATE VIEW v_clinic_dashboard`):

```sql
CREATE VIEW v_patient_max_anamnesis_severity AS
 SELECT s.clinic_id, s.patient_id,
    MAX(CASE ai.severity
        WHEN 'severa' THEN 3
        WHEN 'grave' THEN 2
        ELSE 1
    END) AS severity_rank,
    (ARRAY['normale', 'grave', 'severa'])[MAX(CASE ai.severity
        WHEN 'severa' THEN 3
        WHEN 'grave' THEN 2
        ELSE 1
    END)] AS max_severity
   FROM patient_anamnesis_item_selections s
   JOIN anamnesis_items ai ON ai.id = s.item_id
   WHERE s.resolved_at IS NULL
   GROUP BY s.clinic_id, s.patient_id;
```

Stessa vista nell'istanza `t_9d754153`, con nome `t_9d754153.v_patient_max_anamnesis_severity` e tabelle qualificate `t_9d754153.patient_anamnesis_item_selections`/`t_9d754153.anamnesis_items`.

- [ ] **Step 2: Estendere `v_agenda_daily` — `has_catalog_alert`**

Modificare il `CREATE VIEW v_agenda_daily` esistente (`install.sql:1022-1050`), aggiungendo una terza colonna alert accanto alle due esistenti:

```sql
-- PRIMA (righe 1043-1045)
    (EXISTS ( SELECT 1
           FROM patient_anamnesis pa2
          WHERE ((pa2.patient_id = p.id) AND (pa2.clinic_id = a.clinic_id) AND (pa2.is_current = true) AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates OR pa2.heart_disease)))) AS has_medication_alert
   FROM ((((appointments a

-- DOPO
    (EXISTS ( SELECT 1
           FROM patient_anamnesis pa2
          WHERE ((pa2.patient_id = p.id) AND (pa2.clinic_id = a.clinic_id) AND (pa2.is_current = true) AND (pa2.taking_anticoagulants OR pa2.taking_bisphosphonates OR pa2.heart_disease)))) AS has_medication_alert,
    (EXISTS ( SELECT 1
           FROM patient_anamnesis_item_selections pais
           JOIN anamnesis_items ai ON ai.id = pais.item_id
          WHERE (pais.patient_id = p.id) AND (pais.clinic_id = a.clinic_id)
            AND pais.resolved_at IS NULL AND ai.severity IN ('grave', 'severa'))) AS has_catalog_alert
   FROM ((((appointments a
```

Stessa modifica nell'istanza `t_9d754153` (righe 3095-3098 circa, stesso pattern con prefisso schema su `patient_anamnesis_item_selections`/`anamnesis_items`).

- [ ] **Step 3: Estendere `v_patient_clinical_card` — `catalog_alert_severity`**

Modificare `CREATE VIEW v_patient_clinical_card` (`install.sql:1080-1111`):

```sql
-- PRIMA (righe 1105-1111)
    pa.general_notes AS anamnesis_notes,
    pa.recorded_at AS anamnesis_date,
    ( SELECT count(*) AS count
           FROM appointments a
          WHERE ((a.patient_id = p.id) AND (a.clinic_id = p.clinic_id))) AS total_appointments
   FROM (patients p
     LEFT JOIN patient_anamnesis pa ON (((pa.patient_id = p.id) AND (pa.clinic_id = p.clinic_id) AND (pa.is_current = true))));

-- DOPO
    pa.general_notes AS anamnesis_notes,
    pa.recorded_at AS anamnesis_date,
    ( SELECT count(*) AS count
           FROM appointments a
          WHERE ((a.patient_id = p.id) AND (a.clinic_id = p.clinic_id))) AS total_appointments,
    mas.max_severity AS catalog_alert_severity
   FROM ((patients p
     LEFT JOIN patient_anamnesis pa ON (((pa.patient_id = p.id) AND (pa.clinic_id = p.clinic_id) AND (pa.is_current = true))))
     LEFT JOIN v_patient_max_anamnesis_severity mas ON ((mas.patient_id = p.id) AND (mas.clinic_id = p.clinic_id)));
```

Stessa modifica nell'istanza `t_9d754153` (righe 3143+ circa).

- [ ] **Step 4: `PatientDetailDto` — nuovo campo**

`backend/src/main/java/com/dentalcare/dto/PatientDetailDto.java`, aggiungere `catalogAlertSeverity` al record (dopo `anamnesisDate`):

```java
public record PatientDetailDto(
        // ... campi esistenti invariati fino a ...
        OffsetDateTime anamnesisDate,
        String catalogAlertSeverity,
        // Stats
        Long totalAppointments,
        // ... resto invariato
) {}
```

- [ ] **Step 5: Mappare il campo in `PatientService`**

Individuare il metodo che mappa `v_patient_clinical_card` a `PatientDetailDto`:

```bash
grep -rn "v_patient_clinical_card\|PatientDetailDto(" backend/src/main/java/com/dentalcare/service/PatientService.java
```

Aggiungere `rs.getString("catalog_alert_severity")` nella posizione corrispondente del costruttore `PatientDetailDto`, nello stesso punto dove oggi legge `anamnesis_date`. (Il worker che esegue questo step deve leggere il metodo esatto — nome variabile `rs`/`row` dipende dal driver usato in quel punto, `RowMapper` lambda o `Map<String,Object>` — verificare lo stile del file prima di scrivere la riga esatta.)

- [ ] **Step 6: `AppointmentDto` — nuovo campo `hasCatalogAlert`**

```bash
grep -rln "hasAllergyAlert" backend/src/main/java/com/dentalcare/dto
```

Aggiungere `Boolean hasCatalogAlert` al record trovato, stessa posizione di `hasMedicationAlert`. Poi in `AppointmentService.mapRow(ResultSet rs)` (o nome equivalente — verificare con `grep -n "hasAllergyAlert\|has_allergy_alert" backend/src/main/java/com/dentalcare/service/AppointmentService.java`), aggiungere `rs.getBoolean("has_catalog_alert")` nella stessa posizione.

- [ ] **Step 7: Verifica manuale (nessun test JPA/Hibernate su viste — verificare via query diretta)**

```bash
psql -U postgres -h localhost -d dentalcare_test -c "
INSERT INTO t_9d754153.patient_anamnesis_item_selections (clinic_id, patient_id, item_id)
SELECT c.id, p.id, i.id
FROM t_9d754153.clinics c, t_9d754153.patients p, t_9d754153.anamnesis_items i
WHERE i.code = 'CAR_ENDOCARDITE' LIMIT 1;
SELECT max_severity FROM t_9d754153.v_patient_max_anamnesis_severity LIMIT 1;
"
```

Expected: `max_severity = 'grave'`.

- [ ] **Step 8: Commit**

```bash
git add database/install.sql \
        backend/src/main/java/com/dentalcare/dto/PatientDetailDto.java \
        backend/src/main/java/com/dentalcare/service/PatientService.java \
        backend/src/main/java/com/dentalcare/service/AppointmentService.java
git commit -m "feat(anamnesi): vista severita' aggregata + alert catalogo in agenda e cartella clinica"
```

---

## Task 7: Backend — vincolo scheduling fine-giornata per severità `severa`

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/AppointmentService.java`
- Modify: `backend/src/main/java/com/dentalcare/controller/AppointmentController.java`
- Create: `backend/src/test/java/com/dentalcare/service/AppointmentAvailabilitySeverityTest.java`

**Interfaces:**
- Consumes: `v_patient_max_anamnesis_severity` (Task 6)
- Produces: `findAvailability(int, UUID, UUID, LocalDate, int)` (nuovo parametro `patientId`), usato da `AppointmentController`

- [ ] **Step 1: Scrivere il test per `computeAvailability` con vincolo fine-giornata (fallisce)**

`computeAvailability` è già `static` e testato senza JDBC (pattern esistente, commento a riga 676-680). Aggiungere il parametro `endOfDayOnly` alla firma e testare che, quando `true`, solo l'ultimo slot della giornata (quello immediatamente prima di `workEnd`) viene proposto.

Create `backend/src/test/java/com/dentalcare/service/AppointmentAvailabilitySeverityTest.java`:

```java
package com.dentalcare.service;

import com.dentalcare.dto.AvailabilitySlotDto;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AppointmentAvailabilitySeverityTest {

    @Test
    void computeAvailability_endOfDayOnly_proposesOnlyLastSlotsOfTheDay() {
        UUID providerId = UUID.randomUUID();
        var providers = List.of(new AppointmentService.AvailabilityProvider(providerId, "Dr. Test"));
        var chairs = List.of("Studio 1");
        var busy = List.<AppointmentService.BusyAppointment>of();

        AppointmentService.ScheduleConfig cfg = new AppointmentService.ScheduleConfig(
                LocalTime.of(8, 0), LocalTime.of(19, 0), 15,
                java.util.EnumSet.of(java.time.DayOfWeek.MONDAY, java.time.DayOfWeek.TUESDAY,
                        java.time.DayOfWeek.WEDNESDAY, java.time.DayOfWeek.THURSDAY, java.time.DayOfWeek.FRIDAY));

        LocalDate monday = LocalDate.of(2026, 7, 27); // lunedì
        List<AvailabilitySlotDto> proposals = AppointmentService.computeAvailability(
                30, monday, 3, providers, chairs, busy, cfg, true);

        assertThat(proposals).isNotEmpty();
        assertThat(proposals).allSatisfy(slot ->
                assertThat(slot.startTime()).isEqualTo("18:30")); // ultimo slot che chiude entro le 19:00 con durata 30min
    }

    @Test
    void computeAvailability_notEndOfDayOnly_proposesFirstAvailableSlot() {
        UUID providerId = UUID.randomUUID();
        var providers = List.of(new AppointmentService.AvailabilityProvider(providerId, "Dr. Test"));
        var chairs = List.of("Studio 1");
        var busy = List.<AppointmentService.BusyAppointment>of();

        AppointmentService.ScheduleConfig cfg = new AppointmentService.ScheduleConfig(
                LocalTime.of(8, 0), LocalTime.of(19, 0), 15,
                java.util.EnumSet.of(java.time.DayOfWeek.MONDAY));

        LocalDate monday = LocalDate.of(2026, 7, 27);
        List<AvailabilitySlotDto> proposals = AppointmentService.computeAvailability(
                30, monday, 1, providers, chairs, busy, cfg, false);

        assertThat(proposals).hasSize(1);
        assertThat(proposals.get(0).startTime()).isEqualTo("08:00");
    }
}
```

Nota: il test referenzia `AppointmentService.AvailabilityProvider`/`BusyAppointment` — sono `record` package-private oggi (righe 733, 736) — restano tali, il test vive nello stesso package `com.dentalcare.service` quindi li vede.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && ./mvnw test -Dtest=AppointmentAvailabilitySeverityTest
```

Expected: FAIL — `computeAvailability` non ha ancora un overload a 8 argomenti con `endOfDayOnly`.

- [ ] **Step 3: Implementare il vincolo in `computeAvailability`**

In `AppointmentService.java`, modificare la firma esistente e aggiungerne una nuova che la richiama con `endOfDayOnly=false` per compatibilità:

```java
// Firma esistente (righe 748-751) diventa un overload di compatibilità:
static List<AvailabilitySlotDto> computeAvailability(
        int durationMin, LocalDate fromDate, int limit,
        List<AvailabilityProvider> providers, List<String> chairLabels, List<BusyAppointment> busy,
        ScheduleConfig cfg) {
    return computeAvailability(durationMin, fromDate, limit, providers, chairLabels, busy, cfg, false);
}

static List<AvailabilitySlotDto> computeAvailability(
        int durationMin, LocalDate fromDate, int limit,
        List<AvailabilityProvider> providers, List<String> chairLabels, List<BusyAppointment> busy,
        ScheduleConfig cfg, boolean endOfDayOnly) {

    List<AvailabilitySlotDto> proposals = new ArrayList<>();
    if (durationMin <= 0 || limit <= 0 || providers.isEmpty() || chairLabels.isEmpty()) return proposals;

    int workStartMin = cfg.workStart().toSecondOfDay() / 60;
    int workEndMin = cfg.workEnd().toSecondOfDay() / 60;

    // Se il paziente e' 'severa': un solo slot candidato per giornata, quello che finisce
    // esattamente a fine orario (l'ultimo possibile), non l'intera griglia di slot.
    int iterationStart = endOfDayOnly ? (workEndMin - durationMin) : workStartMin;
    int iterationStep = endOfDayOnly ? Integer.MAX_VALUE : cfg.slotMinutes(); // un solo giro se endOfDayOnly

    for (int day = 0; day < SEARCH_DAYS && proposals.size() < limit; day++) {
        LocalDate date = fromDate.plusDays(day);
        if (!cfg.workingDays().contains(date.getDayOfWeek())) continue;

        for (int m = iterationStart; m + durationMin <= workEndMin && proposals.size() < limit; ) {
            LocalTime slotStart = LocalTime.ofSecondOfDay(m * 60L);
            LocalTime slotEnd = LocalTime.ofSecondOfDay((m + durationMin) * 60L);
            OffsetDateTime candidateStart = date.atTime(slotStart).atZone(ROME).toOffsetDateTime();
            OffsetDateTime candidateEnd = date.atTime(slotEnd).atZone(ROME).toOffsetDateTime();

            for (AvailabilityProvider provider : providers) {
                if (providerBusy(busy, provider.providerId(), candidateStart, candidateEnd)) continue;
                String freeChair = firstFreeChair(busy, chairLabels, candidateStart, candidateEnd);
                if (freeChair == null) continue;
                proposals.add(new AvailabilitySlotDto(
                        date, slotStart.format(AVAILABILITY_TIME), slotEnd.format(AVAILABILITY_TIME),
                        freeChair, provider.providerId(), provider.providerName()));
                break;
            }

            if (endOfDayOnly) break; // un solo candidato per giornata: l'ultimo slot possibile
            m += iterationStep;
        }
    }
    return proposals;
}
```

Rimuovere la variabile `iterationStep` inutilizzata nel ramo `endOfDayOnly` (semplificare: se `endOfDayOnly`, il loop interno fa un solo giro e poi `break` — la riga `iterationStep` con `Integer.MAX_VALUE` serve solo a documentare l'intento, ma va tolta se il compilatore segnala variabile inutilizzata dopo il `break` immediato; verificare in fase di compilazione e, se inutilizzata, rimuoverla e incrementare `m` con `cfg.slotMinutes()` comunque, dato che il `break` esterno rende irrilevante il valore).

- [ ] **Step 4: Run test to verify it passes**

```bash
cd backend && ./mvnw test -Dtest=AppointmentAvailabilitySeverityTest
```

Expected: entrambi PASS.

- [ ] **Step 5: `findAvailability` — aggiungere `patientId`, leggere la severità**

Modificare la firma pubblica (riga 580) e l'implementazione:

```java
public List<AvailabilitySlotDto> findAvailability(int durationMin, UUID providerId, UUID patientId, LocalDate fromDate, int limit) {
    if (durationMin <= 0) {
        throw new IllegalArgumentException("durationMin deve essere maggiore di zero: " + durationMin);
    }
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
    LocalDate searchFrom = fromDate != null ? fromDate : LocalDate.now(ROME);
    int effectiveLimit = limit > 0 ? limit : 3;
    LocalDate searchTo = searchFrom.plusDays(SEARCH_DAYS - 1L);

    List<AvailabilityProvider> providers = loadAvailabilityProviders(clinicId, providerId);
    List<String> chairLabels = findChairLabels();
    List<BusyAppointment> busy = loadBusyAppointments(clinicId, searchFrom, searchTo);
    boolean endOfDayOnly = patientId != null && isSevera(clinicId, patientId);

    return computeAvailability(durationMin, searchFrom, effectiveLimit, providers, chairLabels, busy,
            loadSchedule(clinicId), endOfDayOnly);
}

/** true se il paziente ha una condizione anamnestica attiva di severita' 'severa' (vincolo fine giornata). */
private boolean isSevera(UUID clinicId, UUID patientId) {
    List<String> rows = jdbc.queryForList("""
        SELECT max_severity FROM %s.v_patient_max_anamnesis_severity
        WHERE clinic_id = :clinicId AND patient_id = :patientId
        """.formatted(s()),
        new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId),
        String.class);
    return !rows.isEmpty() && "severa".equals(rows.get(0));
}
```

- [ ] **Step 6: Aggiornare il controller — nuovo parametro `patientId`**

```bash
grep -n "findAvailability" backend/src/main/java/com/dentalcare/controller/AppointmentController.java
```

Aggiungere `@RequestParam(required = false) UUID patientId` alla firma del metodo controller che chiama `findAvailability`, e passarlo alla chiamata del service (`patientId` opzionale: se il chiamante non lo passa, nessun vincolo — comportamento identico a oggi).

- [ ] **Step 7: Validazione server-side sulla creazione manuale — 422 se violato**

In `AppointmentService.create()` (riga 225), aggiungere una chiamata di validazione prima dell'`INSERT`:

```java
public UUID create(CreateAppointmentRequest request) {
    UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

    checkWorkingDay(clinicId, request);
    checkChairConflict(clinicId, request);
    checkProviderConflict(clinicId, request);
    checkSeveritySchedulingConstraint(clinicId, request);

    // ... resto invariato
}

/** Se il paziente e' 'severa', lo slot richiesto deve finire entro l'ultimo intervallo di lavoro della giornata. */
private void checkSeveritySchedulingConstraint(UUID clinicId, CreateAppointmentRequest request) {
    if (!isSevera(clinicId, request.patientId())) return;

    LocalDate date = request.startsAt().atZoneSameInstant(ZoneId.of("Europe/Rome")).toLocalDate();
    ScheduleConfig cfg = loadSchedule(clinicId);
    LocalTime requestedStart = request.startsAt().atZoneSameInstant(ZoneId.of("Europe/Rome")).toLocalTime();
    long durationMin = java.time.Duration.between(request.startsAt(), request.endsAt()).toMinutes();
    LocalTime lastPossibleStart = cfg.workEnd().minusMinutes(durationMin);

    if (requestedStart.isBefore(lastPossibleStart)) {
        throw new AppointmentConflictException("SEVERITY_END_OF_DAY_ONLY",
                "Paziente con condizione a rischio infettivo attiva: disponibili solo slot di fine giornata (dalle " +
                        lastPossibleStart.format(AVAILABILITY_TIME) + ").");
    }
}
```

`CreateAppointmentRequest.patientId()` — verificare che il metodo esista già sul record (usato altrove nello stesso `create()`, riga 242 lo usa già come `request.patientId()`, quindi è presente).

- [ ] **Step 8: Test — creazione appuntamento bloccata per paziente severa fuori fascia oraria**

Aggiungere a `AppointmentAvailabilitySeverityTest.java` (o nuovo file se il primo era solo per la funzione pura — dato che questo test tocca il DB, va in un file `@SpringBootTest` separato):

Create `backend/src/test/java/com/dentalcare/service/AppointmentSeverityConstraintIntegrationTest.java`:

```java
package com.dentalcare.service;

import com.dentalcare.dto.CreateAppointmentRequest;
import com.dentalcare.exception.AppointmentConflictException;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class AppointmentSeverityConstraintIntegrationTest {

    @Autowired AppointmentService service;
    @Autowired NamedParameterJdbcTemplate jdbc;

    private static final String TEST_SCHEMA = "t_9d754153";
    private UUID clinicId, patientId, providerId;

    @BeforeEach
    void setUp() {
        TenantContext.setCurrentSchema(TEST_SCHEMA);
        clinicId = jdbc.queryForObject("SELECT id FROM %s.clinics LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        TenantContext.setCurrentClinicId(clinicId.toString());
        patientId = jdbc.queryForObject("SELECT id FROM %s.patients LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        providerId = jdbc.queryForObject("SELECT id FROM %s.providers WHERE active = true LIMIT 1".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);

        UUID severaItemId = jdbc.queryForObject(
                "SELECT id FROM %s.anamnesis_items WHERE code = 'CAR_ENDOCARDITE'".formatted(TEST_SCHEMA), new MapSqlParameterSource(), UUID.class);
        jdbc.update("UPDATE %s.anamnesis_items SET severity = 'severa' WHERE id = :id".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("id", severaItemId)); // forzato solo per questo test, non e' il default del seed
        jdbc.update("""
            INSERT INTO %s.patient_anamnesis_item_selections (clinic_id, patient_id, item_id)
            VALUES (:clinicId, :patientId, :itemId)
            """.formatted(TEST_SCHEMA),
            new MapSqlParameterSource().addValue("clinicId", clinicId).addValue("patientId", patientId).addValue("itemId", severaItemId));
    }

    @AfterEach
    void tearDown() {
        jdbc.update("DELETE FROM %s.patient_anamnesis_item_selections WHERE patient_id = :pid".formatted(TEST_SCHEMA),
                new MapSqlParameterSource("pid", patientId));
        TenantContext.clear();
    }

    @Test
    void create_rejectsNonEndOfDaySlot_forSeveraPatient() {
        OffsetDateTime morningStart = OffsetDateTime.now(ZoneOffset.UTC)
                .plusDays(7).withHour(9).withMinute(0).withSecond(0).withNano(0);
        CreateAppointmentRequest req = new CreateAppointmentRequest(
                patientId, providerId, "Studio 1", morningStart, morningStart.plusMinutes(30), null, null);

        assertThatThrownBy(() -> service.create(req))
                .isInstanceOf(AppointmentConflictException.class)
                .hasMessageContaining("fine giornata");
    }
}
```

Nota: `CreateAppointmentRequest` — verificare l'ordine/nome esatto dei campi del record con `grep -n "record CreateAppointmentRequest" backend/src/main/java/com/dentalcare/dto/CreateAppointmentRequest.java` prima di scrivere questo test — il costruttore usato sopra è indicativo dell'ordine visto in `create()` (`patientId, providerId, chairLabel, startsAt, endsAt, notes`) ma il record potrebbe avere campi aggiuntivi (es. `treatmentPlanItemId`) da includere come `null`.

- [ ] **Step 9: Run all AppointmentService tests**

```bash
cd backend && ./mvnw test -Dtest=AppointmentAvailabilitySeverityTest,AppointmentSeverityConstraintIntegrationTest
```

Expected: tutti PASS.

- [ ] **Step 10: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/AppointmentService.java \
        backend/src/main/java/com/dentalcare/controller/AppointmentController.java \
        backend/src/test/java/com/dentalcare/service/AppointmentAvailabilitySeverityTest.java \
        backend/src/test/java/com/dentalcare/service/AppointmentSeverityConstraintIntegrationTest.java
git commit -m "feat(anamnesi): vincolo scheduling fine-giornata per pazienti con condizione severa attiva"
```

---

## Task 8: Frontend — select severità in Impostazioni (sostituisce toggle `isAlert`)

**Files:**
- Modify: `frontend/src/app/core/models/anamnesis-catalog.model.ts`
- Modify: `frontend/src/app/features/impostazioni/impostazioni.component.ts`
- Modify: `frontend/src/app/features/impostazioni/impostazioni.component.html`

**Interfaces:**
- Consumes: `CatalogItemDto` con `severity: string` (Task 3)
- Produces: form Impostazioni aggiornato

- [ ] **Step 1: Aggiornare il model TypeScript**

```bash
grep -n "isAlert" frontend/src/app/core/models/anamnesis-catalog.model.ts
```

Sostituire ogni `isAlert: boolean` con `severity: 'normale' | 'grave' | 'severa'` nelle interfacce `CatalogItem`, `CreateCatalogItemRequest`, `UpdateCatalogItemRequest` (nomi esatti da verificare nel file — il pattern del backend usa gli stessi nomi lato TS per convenzione già stabilita nel progetto).

- [ ] **Step 2: Aggiornare `impostazioni.component.ts` — form state**

In `frontend/src/app/features/impostazioni/impostazioni.component.ts`, sostituire (righe 102-107 circa):

```typescript
// PRIMA
newItemForm: { code: string; label: string; description: string; isAlert: boolean; sortOrder: number } = {
  code: '', label: '', description: '', isAlert: false, sortOrder: 99
};
editItemForm: { label: string; description: string; isAlert: boolean; sortOrder: number; enabled: boolean } = {
  label: '', description: '', isAlert: false, sortOrder: 99, enabled: true
};

// DOPO
newItemForm: { code: string; label: string; description: string; severity: 'normale' | 'grave' | 'severa'; sortOrder: number } = {
  code: '', label: '', description: '', severity: 'normale', sortOrder: 99
};
editItemForm: { label: string; description: string; severity: 'normale' | 'grave' | 'severa'; sortOrder: number; enabled: boolean } = {
  label: '', description: '', severity: 'normale', sortOrder: 99, enabled: true
};
```

E ogni riferimento a `isAlert` nei metodi `createAnamnesisItem`, `saveAnamnesisItem`, `startEditAnamnesisItem` (righe 508-583 circa) diventa `severity`, es.:

```typescript
// createAnamnesisItem(), riga ~517
severity: this.newItemForm.severity ?? 'normale',

// saveAnamnesisItem(item), riga ~538
severity: this.editItemForm.severity,

// dopo il salvataggio, riga ~550
severity: req.severity,

// startEditAnamnesisItem(item), riga ~579
severity: item.severity,
```

- [ ] **Step 3: Template — select a 3 valori invece del toggle**

```bash
grep -n "isAlert" frontend/src/app/features/impostazioni/impostazioni.component.html
```

Sostituire ogni checkbox/toggle `isAlert` con un `<select>`:

```html
<label class="block text-sm font-medium text-slate-700 mb-1">Severità</label>
<select
  [(ngModel)]="newItemForm.severity"
  name="newItemSeverity"
  class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm">
  <option value="normale">Normale — nessun alert</option>
  <option value="grave">Grave — mostra alert clinico</option>
  <option value="severa">Severa — alert clinico + appuntamenti solo a fine giornata</option>
</select>
```

(Duplicare per il form di modifica con `[(ngModel)]="editItemForm.severity"` e `name="editItemSeverity"`. Verificare nel file esistente se il form usa Reactive Forms o `[(ngModel)]` semplice — il codice component visto sopra usa oggetti plain (`newItemForm`/`editItemForm`), coerente con `[(ngModel)]` template-driven, non `FormGroup`.)

- [ ] **Step 4: Build frontend per verificare che compili**

```bash
cd frontend && npm run build
```

Expected: nessun errore TypeScript (nessun riferimento residuo a `isAlert`).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/core/models/anamnesis-catalog.model.ts \
        frontend/src/app/features/impostazioni/impostazioni.component.ts \
        frontend/src/app/features/impostazioni/impostazioni.component.html
git commit -m "feat(anamnesi): select severita' a 3 valori in Impostazioni, sostituisce il toggle isAlert"
```

---

## Task 9: Frontend — alert da catalogo in cartella paziente e dashboard

**Files:**
- Modify: `frontend/src/app/core/models/patient.model.ts` (o dove vive l'interfaccia `PatientDetail` — verificare)
- Modify: `frontend/src/app/core/models/appointment.model.ts` (interfaccia `Appointment`)
- Modify: `frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.ts`
- Modify: `frontend/src/app/features/dashboard/dashboard.component.html`

**Interfaces:**
- Consumes: `catalogAlertSeverity: string | null` su `PatientDetailDto` (Task 6), `hasCatalogAlert: boolean` su `AppointmentDto` (Task 6)
- Produces: UI alert coerente col resto

- [ ] **Step 1: Model TypeScript — nuovi campi**

```bash
grep -rn "anamnesisDate\b" frontend/src/app/core/models
```

Nel file trovato (interfaccia `PatientDetail` o simile), aggiungere:

```typescript
catalogAlertSeverity: 'normale' | 'grave' | 'severa' | null;
```

```bash
grep -rn "hasMedicationAlert" frontend/src/app/core/models
```

Nel file trovato (interfaccia `Appointment`), aggiungere:

```typescript
hasCatalogAlert: boolean;
```

- [ ] **Step 2: `cartella-tab.component.ts` — includere l'alert da catalogo**

Modificare `get alerts()` (righe 99-113):

```typescript
get alerts(): { type: 'critical' | 'warning' | 'info'; label: string }[] {
  const list: { type: 'critical' | 'warning' | 'info'; label: string }[] = [];
  const p = this.paziente;
  if (!p) return list;
  if (p.allergie?.length) {
    list.push({ type: 'critical', label: 'Allergie registrate' });
  }
  if (p.takingAnticoagulants) list.push({ type: 'critical', label: 'Terapia anticoagulante' });
  if (p.takingBisphosphonates) list.push({ type: 'critical', label: 'Terapia con bisfosfonati' });
  if (p.heartDisease) list.push({ type: 'warning', label: 'Cardiopatia' });
  if (p.hypertension) list.push({ type: 'warning', label: 'Ipertensione' });
  if (p.diabetes) list.push({ type: 'warning', label: 'Diabete' });
  if (p.catalogAlertSeverity === 'severa') {
    list.push({ type: 'critical', label: 'Condizione a rischio infettivo attiva — solo appuntamenti fine giornata' });
  } else if (p.catalogAlertSeverity === 'grave') {
    list.push({ type: 'warning', label: 'Condizioni cliniche da anamnesi — vedi scheda anamnesi' });
  }
  if (!p.anamnesisDate) list.push({ type: 'info', label: 'Anamnesi da completare' });
  return list;
}
```

- [ ] **Step 3: `dashboard.component.html` — badge aggiuntivo**

Nei tre punti dove oggi compaiono `a.hasAllergyAlert`/`a.hasMedicationAlert` (righe 186-194, 307-320, 426-441), aggiungere un `@if` gemello per `hasCatalogAlert`, stesso stile visivo delle altre righe alert esistenti (icona `warning`, colore rosso/arancio coerente col resto — replicare esattamente la struttura HTML delle righe adiacenti, cambiando solo la property testata e il testo a "Condizione clinica da anamnesi").

- [ ] **Step 4: Build frontend**

```bash
cd frontend && npm run build
```

Expected: nessun errore.

- [ ] **Step 5: Verifica manuale nel browser**

```bash
cd frontend && npm start
```

Aprire un paziente con una voce anamnesi a severità `grave` selezionata (es. tramite l'endpoint PUT anamnesi o via UI cartella) e verificare che l'alert compaia in dashboard e in cartella clinica. Screenshot prima/dopo se possibile.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/app/core/models/*.ts \
        frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.ts \
        frontend/src/app/features/dashboard/dashboard.component.html
git commit -m "feat(anamnesi): alert da catalogo dinamico visibili in dashboard e cartella paziente"
```

---

## Task 10: Frontend — badge diff sintetico in cartella paziente

**Files:**
- Modify: `frontend/src/app/core/services/anamnesis.service.ts` (o nome esatto — verificare con `grep -rln "getPatientAnamnesis\|savePatientAnamnesis" frontend/src/app/core/services`)
- Modify: `frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.ts`
- Modify: `frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.html`

**Interfaces:**
- Consumes: `GET /api/patients/{id}/anamnesis/diff` (Task 5)
- Produces: badge UI

- [ ] **Step 1: Model TypeScript per il diff**

Create/modify (stesso file dei model anamnesi):

```typescript
export interface AnamnesisDiffItem {
  code: string;
  label: string;
  severity: 'normale' | 'grave' | 'severa';
}

export interface AnamnesisDiff {
  newItems: AnamnesisDiffItem[];
  resolvedItems: AnamnesisDiffItem[];
  unchangedItems: AnamnesisDiffItem[];
}
```

- [ ] **Step 2: Service — metodo `getDiff`**

Nel service anamnesi esistente, aggiungere:

```typescript
getDiff(patientId: string): Observable<AnamnesisDiff> {
  return this.http.get<AnamnesisDiff>(`${this.baseUrl}/${patientId}/anamnesis/diff`);
}
```

(Adattare a `baseUrl`/pattern esatto del service esistente — verificare come `getAnamnesis(patientId)` costruisce l'URL oggi, replicare la stessa convenzione.)

- [ ] **Step 3: Component — caricare il diff**

In `cartella-tab.component.ts`, aggiungere un signal e caricarlo in `ngOnInit` (o hook equivalente già presente nel file):

```typescript
anamnesisDiff = signal<AnamnesisDiff | null>(null);

private loadAnamnesisDiff(): void {
  const p = this.paziente;
  if (!p) return;
  this.anamnesisService.getDiff(p.patientId).subscribe({
    next: diff => this.anamnesisDiff.set(diff),
    error: () => this.anamnesisDiff.set(null)
  });
}
```

Chiamare `this.loadAnamnesisDiff()` nello stesso punto dove il componente già carica i dati paziente (verificare hook `ngOnChanges`/`ngOnInit` esistente nel file).

- [ ] **Step 4: Template — badge sintetico**

In `cartella-tab.component.html`, vicino a dove renderizzano gli alert esistenti:

```html
@if (anamnesisDiff(); as diff) {
  @if (diff.newItems.length > 0 || diff.resolvedItems.length > 0) {
    <div class="text-xs text-slate-500 flex items-center gap-2 mb-2">
      <span class="material-symbols-outlined text-[14px]">history</span>
      @if (diff.newItems.length > 0) {
        <span class="text-amber-700 font-medium">{{ diff.newItems.length }} nuov{{ diff.newItems.length > 1 ? 'e' : 'a' }}</span>
      }
      @if (diff.resolvedItems.length > 0) {
        <span class="text-emerald-700 font-medium">{{ diff.resolvedItems.length }} risolt{{ diff.resolvedItems.length > 1 ? 'e' : 'a' }}</span>
      }
      <span>dall'ultima visita</span>
    </div>
  }
}
```

- [ ] **Step 5: Build e verifica manuale**

```bash
cd frontend && npm run build && npm start
```

Aprire un paziente, salvare l'anamnesi due volte con selezioni diverse (via UI), verificare che il badge mostri il conteggio corretto.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/app/core/services/*.ts \
        frontend/src/app/core/models/*.ts \
        frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.ts \
        frontend/src/app/features/pazienti/cartella-tab/cartella-tab.component.html
git commit -m "feat(anamnesi): badge diff sintetico (nuove/risolte) in cartella paziente"
```

---

## Task 11: Frontend — gestione errore 422 vincolo scheduling in nuovo appuntamento

**Files:**
- Modify: `frontend/src/app/features/agenda/nuovo-appuntamento/nuovo-appuntamento.component.ts` (verificare nome file esatto)

**Interfaces:**
- Consumes: risposta 409 `SEVERITY_END_OF_DAY_ONLY` da `POST /api/appointments` (Task 7)

- [ ] **Step 1: Individuare il gestore errori esistente per la creazione appuntamento**

```bash
grep -rn "CHAIR_CONFLICT\|HOLIDAY\|AppointmentConflictException\|error.code" frontend/src/app/features/agenda
```

- [ ] **Step 2: Aggiungere il caso `SEVERITY_END_OF_DAY_ONLY`**

Nello stesso blocco `switch`/`if` che oggi gestisce `CHAIR_CONFLICT`/`HOLIDAY` (formato esatto da leggere nel file trovato allo Step 1), aggiungere un ramo che mostra `error.message` così com'è (il backend già include l'orario nel messaggio, Task 7 Step 7) invece di un messaggio generico — replicare lo stile di gestione già usato per gli altri codici errore in quello stesso file.

- [ ] **Step 3: Build e verifica manuale**

```bash
cd frontend && npm run build
```

Test manuale: creare un paziente con voce `severity='severa'` (via SQL diretto o dopo che il catalogo lo permette a runtime), tentare un appuntamento al mattino, verificare che il messaggio d'errore sia quello del backend (non un generico "errore di validazione").

- [ ] **Step 4: Commit**

```bash
git add frontend/src/app/features/agenda/nuovo-appuntamento/*.ts
git commit -m "feat(anamnesi): messaggio chiaro quando lo scheduling rifiuta uno slot per vincolo severita'"
```

---

## Self-Review (eseguita dall'autore del piano)

1. **Copertura spec** — confronto con `directives/proposte-modifiche.md` §43:
   - Fase 1 (migrazione per-tenant) → Task 1, 2 ✅
   - Fase 2 (ricostruzione contenuto + severità) → Task 2 (dati), Task 3 (service) ✅
   - Fase 3 (storico + diff) → Task 4, 5 ✅
   - Fase 4 (backend alert + scheduling) → Task 6, 7 ✅
   - Fase 5 (frontend) → Task 8, 9, 10, 11 ✅
   - Cascade-delete count-check + soft-delete (accordo separato) → Task 3 Step 2-3 ✅
   - "Nessuna voce severa nel seed" → Task 2 Step 1, verificato esplicitamente ✅
   - Seed statico ricostruito, non copiato dal demo a runtime → Task 2 Step 1 (letterale, non query dinamica) ✅

2. **Placeholder scan**: nessun "TBD"/"implement later" nei blocchi di codice. Alcuni step (Task 4 Step 5, Task 6 Step 5, Task 9 Step 1, Task 10 Step 2, Task 11 Step 1-2) richiedono al worker di leggere un file esistente per un dettaglio non deducibile in astratto (nome esatto di un metodo/variabile) prima di scrivere la riga finale — non sono omissioni di logica, sono verifiche di corrispondenza con codice che il piano non può citare byte-per-byte senza averlo letto in quel momento; ogni caso include il comando `grep`/`bash` esatto da eseguire prima di procedere.

3. **Coerenza dei tipi**: `severity: String` (backend) ↔ `severity: 'normale' | 'grave' | 'severa'` (frontend) coerenti in Task 3/8. `AnamnesisDiffDto.AnamnesisDiffItem(code, label, severity)` (Task 5) ↔ `AnamnesisDiffItem { code, label, severity }` (Task 10) coerenti. `computeAvailability(..., ScheduleConfig, boolean)` (Task 7 Step 3) è l'unica firma con 8 argomenti usata sia dal test (Step 1) sia dalla produzione (Step 5 la chiama con `endOfDayOnly` calcolato) — coerente.

**Rischio principale del piano**: Task 2 Step 3 (riconciliazione `id` per il tenant demo `t_9d754153`) e Task 4 Step 5 (conteggio dei placeholder `%s` in `syncLegacyAnamnesis`) sono gli unici due step che richiedono giudizio umano/agente in tempo reale sui dati esistenti, non pura esecuzione meccanica — vanno eseguiti con particolare attenzione, idealmente con revisione prima del commit.
