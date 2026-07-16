# Gap analysis — Cartella clinica digitale

**Documento di riferimento:** `DentalCare_Guida_Digitalizzazione_Cartella_Clinica_Dentale.md` (v1.0, 16 luglio 2026)
**Data analisi:** 16 luglio 2026
**Metodo:** verifica diretta su codice (`backend/`, `frontend/`) e schema DB reale (`t_9d754153`), non su documentazione.
**Esito sintetico:** DentalCare copre **bene il livello "dati"**, ma **non copre il livello "prova"**: manca ciò che rende una cartella clinica *difendibile* (finalizzazione, storicità, audit, consensi).

---

## 1. Conclusione esecutiva

La guida definisce 15 requisiti **P0** (§25.1). Stato attuale:

| Esito | Conteggio | Requisiti |
|---|---:|---|
| ✅ Coperto | 4 | tenant isolation, documenti e immagini, backup/restore (parziale-manuale), privacy workflow (parziale) |
| 🟡 Parziale | 6 | RBAC e assegnazione, anamnesi versionata, odontogramma, diagnosi/lista problemi, piano e procedure, export |
| ❌ Assente | 5 | **identità paziente e merge duplicati**, **encounter**, **consensi versionati**, **finalizzazione e addendum**, **audit** |

**I tre gap che pesano di più**, in ordine:

1. **Nessuna finalizzazione né immutabilità delle note cliniche.** `clinical_history_entries` non ha `status`, `version`, `hash`, `finalized_at`, né addendum: una nota si modifica con UPDATE, in silenzio, per sempre. Viola il principio di immutabilità logica (§2.3), gli stati nota (§6.1), la regola di correzione (§6.2) e il criterio di accettazione §26.1. È il gap più grave: senza di esso la cartella non ha valore probatorio.
2. **Nessun audit trail clinico.** Esiste solo `ai_audit_log` (clinic_id, provider_id, action_type, tool_name, args_summary, result, created_at) che traccia **le tool call del copilot**, non chi ha aperto/letto/scaricato/stampato una cartella. Tutta la §12 è scoperta, incluse le domande da controllo §24.2 ("Chi ha scaricato il documento?").
3. **Nessuna gestione dei consensi.** Non esiste entità consenso: solo un `document_type = 'consenso_informato'` tra i documenti. Nessun template versionato, nessuna firma, nessuna revoca, nessun collegamento al piano/procedura (§5.9). Il criterio "piani con consenso collegato" (§23.1) non è misurabile.

**Rischio di segregazione da verificare subito:** la scheda paziente (`pazienti/:id`) è accessibile al ruolo `secretary` via route guard. Il criterio §26.2 richiede che la segreteria **non** veda anamnesi, diagnosi, odontogramma e note, e che ogni chiamata diretta alle API cliniche sia **negata e registrata**. Va verificato che il filtro sia **server-side** e non solo un tab nascosto nel frontend.

---

## 2. Cosa è già coperto (non va rifatto)

Onestà prima di tutto: il nucleo dati esiste ed è di buona qualità.

| Area | Stato | Evidenza |
|---|---|---|
| **Multi-tenancy** | ✅ | schema-per-tenant (`t_<hex>`), `clinic_id` su tutte le entità cliniche, tenant derivato dal JWT (mai dal client) |
| **Isolamento chiavi** | ✅ | chiavi di cifratura derivate per-tenant (HKDF), un tenant compromesso non espone gli altri |
| **Cifratura dati sensibili** | ✅ | `birth_date_enc`, `fiscal_code_enc` + blind index (AES-256-GCM), master key fuori dal repo con fail-fast — copre §7.4 "cifratura selettiva" |
| **CF non è chiave primaria** | ✅ | `patients.id` è UUID interno; il CF è opzionale e validato (`@ValidFiscalCode`) con flag `foreign_patient` — conforme a §5.1 e all'errore §28.6 |
| **Anamnesi strutturata** | 🟡→✅ | `patient_anamnesis` + `patient_anamnesis_item_selections` con catalogo globale (`anamnesis_categories`, `anamnesis_items`), `is_current`, `recorded_at`, `recorded_by_provider_id`, `signed_at` |
| **Odontogramma con provenienza** | 🟡→✅ | `tooth_conditions` ha `source` (`manual`/`ai`) e `analysis_id`: la distinzione osservazione umana / output algoritmico esiste già (§5.5 "indicazione della fonte") |
| **Tracciabilità output AI** | ✅ | `patient_document_analyses`: `model_fdi`, `model_disease` (versioni modello), `review_status`, `reviewed_by_provider_id`, `reviewed_at`, `needs_review` — copre gran parte di §17.2 e del criterio §26.4 |
| **Immagini su object storage** | ✅ | MinIO, bucket per tenant, path senza nomi/CF (§8.2) |
| **Piano → preventivo → fattura** | ✅ | `treatment_plans` + items, `estimates` + lines, `invoices` + lines |
| **Storage vs fatture** | ✅ | le fatture non si cancellano col paziente (FK `RESTRICT`) — conservazione fiscale rispettata |

Il modello `tooth_conditions.source` + `analysis_id` merita una nota: **è già la cosa giusta** e soddisfa la regola fondamentale §17.1 (l'output AI è conservato come proposta distinta). Va esteso, non rifatto.

---

## 3. Gap P0 — bloccanti

### 3.1 ❌ Finalizzazione, immutabilità e addendum

**Stato:** assente. `clinical_history_entries` = `id, clinic_id, patient_id, appointment_id, provider_id, entry_date, tooth_number, service_code, service_name, clinical_notes, materials_used, next_visit_notes, created_at, updated_at`.

**Manca:** `status` (draft/final/amended/void), `version`, `hash`, `finalized_at`, `finalized_by`, `supersedes_id`/`amends_id`, `void_reason`.

**Da implementare:**
- macchina a stati §6.1: `Bozza → Da revisionare → Finalizzata → (Rettificata | Annullata)`;
- blocco `UPDATE` sul contenuto dopo `final` (a livello service **e** trigger DB);
- entità **addendum** con riferimento all'originale, motivo, autore, timestamp (§6.2);
- `hash` SHA-256 del contenuto alla finalizzazione (data dictionary §30: `clinical_entry.hash` obbligatorio se final);
- `version` per optimistic locking (§7.4);
- UI: stato visibile, "quale versione è clinicamente valida", storico non distruttivo.

**Criterio di accettazione:** §26.1 (gherkin) deve passare.

### 3.2 ❌ Audit trail clinico

**Stato:** solo `ai_audit_log`, limitato alle tool call AI. Nessun log di accesso/lettura/download/stampa/export.

**Da implementare** (§12):
- tabella `audit_event` **separata** dal log applicativo, **append-only** (nessun UPDATE/DELETE: revoca dei privilegi + trigger);
- eventi minimi: login/logout, fallimenti auth, **apertura cartella**, visualizzazione categorie sensibili, create/update/finalize, addendum, annullamento, download/stampa/export, condivisione, variazione ruoli, accesso AI, break glass;
- campi: event ID, tenant, utente+ruolo, **paziente**, risorsa, azione, esito, timestamp, IP/device, sessione, motivazione, correlation ID, versione applicativa;
- retention + esportabilità per audit;
- report accessi per paziente (serve anche per §10.3, diritto del paziente).

> `ai_audit_log` va **mantenuto** ma è un sottoinsieme: gli manca `patient_id`, l'esito e il contesto di sessione.

### 3.3 ❌ Consensi versionati

**Stato:** assente come entità. Solo un tipo di documento.

**Da implementare** (§5.9):
- `consent_template` versionato (testo, lingua, versione, data efficacia);
- `consent` per paziente: template+versione, procedura/piano collegato, rischi e alternative presentati, firmatario e titolo, data/ora, professionista informante, firme, **revoca/limitazione**, allegati, interprete, rappresentanza per minori/fragili;
- immutabilità dopo la firma (nuova versione ⇒ nuovo consenso);
- collegamento obbligatorio piano ↔ consenso (KPI §23.1).

### 3.4 ❌ Encounter (episodio di cura)

**Stato:** assente. Esistono `appointments` (pianificazione) e `clinical_history_entries` (registrazione), ma non l'episodio clinico che li lega.

**Perché serve:** è il perno del modello §7.1 e della mappatura FHIR §14.2. Senza `encounter_id`, osservazioni/diagnosi/procedure/immagini non sono raggruppabili per visita, e la ricostruzione "cartella a una data storica" (§24.2) è impossibile.

**Da implementare:** `encounter` con `status` (planned/in-progress/finished), sede, professionista, motivo; FK `encounter_id` su clinical entries, diagnosi, documenti, tooth_conditions.

### 3.5 ❌ Identità paziente e merge duplicati

**Stato:** assente. Nessuna procedura di deduplicazione né stato del record.

**Da implementare** (§5.1):
- `patients.status`: attivo / deceduto / duplicato / archiviato;
- rilevazione duplicati (il blind index CF aiuta per il match esatto; serve anche match fuzzy nome+data nascita);
- **procedura di merge con approvazione e audit**, link al record unificato, reversibilità;
- KPI "duplicati per 1.000 pazienti" (§23.1).

### 3.6 🟡 RBAC e relazione di cura

**Stato:** parziale. Ruoli esistono (`tenant_admin, admin, dentist, hygienist, orthodontist, surgeon, assistant, secretary, other`), guard front-end + matcher back-end.

**Gap:**
- **segregazione clinica per la segreteria** da verificare/imporre **server-side** (§26.2);
- **assegnazione / relazione di cura**: oggi un medico del tenant vede tutti i pazienti; §11.1 richiede "pazienti assegnati o per i quali esiste una relazione di cura" (`primary_provider_id` esiste su `patients` ma non risulta usato come filtro di autorizzazione);
- **amministratore tecnico**: §11.1 e §28.18 vietano l'accesso ordinario ai contenuti clinici in chiaro — oggi `admin` accede alla cartella;
- **break glass** (§11.3): assente;
- **MFA** (§11.2): assente — `providers` ha solo `password_hash`, `password_temporary`. Nessun SSO OIDC/SAML.

### 3.7 🟡 Odontogramma temporale

**Stato:** `tooth_conditions` è **snapshot dello stato corrente** (upsert `ON CONFLICT`, solo `updated_at`). La provenienza AI/manuale c'è; la **storia** no.

**Gap vs il modello `DentalFinding` (§5.5):** mancano `encounter_id`, `certainty` (sospetta/confermata/trattata), `onset_date`, `recorded_by`, `supersedes_id`, `void_reason`, `status`. Manca il **confronto tra date** e la distinzione **osservazione vs procedura**.

**Impatto:** oggi non è possibile ricostruire l'evoluzione clinica di un dente — che è esattamente il gap "solo immagine statica → impossibilità di ricostruire evoluzione" della tabella §4.3.

### 3.8 🟡 Anamnesi: tri-stato mancante

**Stato:** `patient_anamnesis_item_selections` registra la **presenza** di una voce. L'assenza di una riga è ambigua.

**Gap:** §5.2 vieta esplicitamente questo: serve distinguere **presente / assente (negato) / non noto (non indagato)**, più `fonte` (paziente/caregiver/documento/professionista), `data risoluzione`, `livello di verifica`.

### 3.9 🟡 Documenti: integrità e sicurezza upload

**Stato:** `patient_documents` = `..., file_name, file_path, file_size_bytes, mime_type, taken_at, ...`.

**Gap (§8.2, §8.3):** manca `sha256` (**obbligatorio** nel data dictionary §30), controllo MIME reale, **antivirus/malware scan**, quarantena, verifica coerenza paziente↔immagine, retention class, versione, stato firma/conservazione, deduplicazione controllata.

### 3.10 🟡 Export cartella e diritti dell'interessato

**Stato:** esiste `TenantExportService` (CSV a livello tenant).

**Gap (§10.3):** manca l'**export completo per singolo paziente** in formato leggibile (art. 15 GDPR) + copia integrale della documentazione, la registrazione delle richieste e dei tempi, il report accessi (dipende da 3.2), la gestione di deleghe/rappresentanza.

### 3.11 🟡 Cancellazione: soft delete

**Stato:** la cancellazione paziente è **fisica** con CASCADE (lo conferma lo script `database/purge_patients_before.sql`).

**Gap (§7.4):** "soft delete o stato di annullamento, **non cancellazione fisica ordinaria**". Serve `deleted_at`/`status` + purge come procedura eccezionale documentata (retention policy §9.4).

---

## 4. Gap P1

| Requisito (§25.2) | Stato | Nota |
|---|---|---|
| Portale paziente | ❌ | assente |
| Firma avanzata/qualificata (PAdES) | ❌ | assente; oggi nemmeno la "finalizzazione clinica" (livello 2 di §9.2) |
| Conservazione a norma | ❌ | MinIO + `pg_dump` = storage e backup, **non** conservazione (§9.3). Nessun massimario/politica di retention approvata |
| DICOMweb | ❌ | non implementato (tracciato come proposta #8). Oggi solo PNG/JPEG |
| FHIR API | ❌ | assente. Il modello interno è però compatibile come base (§14.1: strategia duale corretta) |
| Terminology service | ❌ | `service_code`/`condition` senza code system né versione (§14.3, §22.2) |
| Connettore FSE | ❌ | assente (CDA2 + PAdES + accreditamento) |
| Report accessi | ❌ | dipende dall'audit (3.2) |
| Analytics qualità | 🟡 | KPI §23 non implementati |
| Moduli parodontali avanzati | ❌ | nessun charting parodontale (sondaggio, recessioni, mobilità, placca/sanguinamento) — §5.4 |

Assente anche l'**esame obiettivo strutturato** (extraorale, mucose, ATM, occlusione, stato endodontico): oggi confluisce in `clinical_notes` testo libero.

---

## 5. Gap P2

| Requisito (§25.3) | Stato |
|---|---|
| AI radiologica **certificata** | ❌ — il modulo esiste e funziona, ma **non è certificato**: vedi `roadmap_certificazione.md` |
| Dettatura e summarization controllata | ❌ |
| Federazione tra reti | ❌ |
| Ricerca e secondary use | ❌ (nessuna base giuridica né de-identificazione) |
| EHDS readiness | ❌ |
| Integrazione laboratori e dispositivi | ❌ |
| Mobile offline | ❌ |

---

## 6. Governance e processo (non software, ma bloccante)

La guida chiede prima del codice (§3.2, §10.4, §21.1):

- [ ] **DPIA** — assente, obbligatoria di fatto per multi-tenant + dati sanitari + AI (§10.4);
- [ ] registro dei trattamenti (ROPA);
- [ ] informative aggiornate (incluso uso AI e FSE);
- [ ] DPA con i fornitori (MinIO/cloud, Retell, LLM);
- [ ] **politica di conservazione** per categoria documentale (§9.4);
- [ ] politica di finalizzazione e firma (§9.2);
- [ ] **ADR** — registro decisioni architetturali (§3.3): oggi esiste `directives/proposte-modifiche.md` che è già un buon embrione, ma non nel formato ADR;
- [ ] RPO/RTO dichiarati e **restore testato** (§13.4: "non dichiarare backup effettuato senza prova di restore");
- [ ] procedura di downtime (§21.2);
- [ ] test cross-tenant automatici (§13.3, §26.3).

---

## 7. Piano consigliato

Ordine guidato dal rischio, non dalla difficoltà.

### Fase A — Valore probatorio (il minimo per essere una cartella clinica)
1. **Audit trail clinico** append-only (3.2) — abilita tutto il resto, incluso il report accessi.
2. **Finalizzazione + addendum + hash** su `clinical_history_entries` (3.1).
3. **Segregazione segreteria server-side** + test automatico §26.2 (3.6, parziale).
4. **Soft delete** al posto della cancellazione fisica (3.11).

### Fase B — Modello clinico
5. **Encounter** + FK su entità cliniche (3.4).
6. **Odontogramma temporale** (`certainty`, `encounter_id`, `supersedes_id`, storico + confronto date) (3.7).
7. **Anamnesi tri-stato** + fonte (3.8).
8. **Consensi versionati** collegati al piano (3.3).

### Fase C — Identità e integrità
9. **Merge duplicati** + `patients.status` (3.5).
10. **`sha256` + malware scan + verifica paziente↔immagine** sugli upload (3.9).
11. **Export paziente completo** (art. 15) (3.10).

### Fase D — Accessi
12. **MFA** per professionisti e admin, **break glass**, access review, timeout (3.6).
13. **Relazione di cura** come filtro di autorizzazione (`primary_provider_id`) (3.6).

### Fase E — P1
14. Politica di conservazione + firma; poi conservazione a norma, DICOMweb, FHIR API, terminology service, portale, FSE.

> **Nota di sequenza (§34 della guida):** "La priorità iniziale deve essere un nucleo clinico affidabile, semplice da usare e dimostrabile. FSE, portale, AI e automazioni devono essere costruiti sopra questo nucleo, non al suo posto." DentalCare ha costruito molto sopra (AI, copilot, voce) prima di aver completato il nucleo probatorio (audit, finalizzazione, consensi). Le fasi A-B recuperano quel debito.

---

## 8. Rapporto con gli "errori da evitare" (§28)

Autovalutazione onesta sui 20 errori elencati dalla guida:

| # | Errore | DentalCare |
|---:|---|---|
| 2 | account condivisi | ✅ evitato (account individuali) |
| 3 | segreteria con accesso indiscriminato | ⚠️ **da verificare server-side** |
| 4 | sovrascrivere note finalizzate | ❌ **presente** (non esiste finalizzazione) |
| 5 | immagini con nome paziente nel filesystem | ✅ evitato (path per UUID) |
| 6 | CF come chiave primaria | ✅ evitato |
| 7 | confondere backup e conservazione | ⚠️ oggi c'è solo backup |
| 8 | dati sanitari a LLM pubblici | ⚠️ da verificare (copilot/n8n) → `roadmap_certificazione.md` |
| 14 | addestrare l'AI con correzioni non validate | ⚠️ le label esistono (`patient_document_labels`); serve la regola "no auto-retraining" |
| 16 | non testare il ripristino | ⚠️ nessuna evidenza di restore test |
| 17 | non registrare download e stampe | ❌ **presente** |
| 18 | amministratori tecnici che leggono tutto | ❌ **presente** |

---

**Prossimo passo suggerito:** aprire una proposta in `proposte-modifiche.md` per la **Fase A** (audit + finalizzazione), che è il blocco a valore probatorio più alto e a rischio più basso di regressione.
