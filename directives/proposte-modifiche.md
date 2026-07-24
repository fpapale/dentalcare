# Proposte di modifica

Registro delle modifiche proposte da Claude e il loro stato. Aggiornato a ogni proposta/conferma.

Stati: **Proposta** (in attesa di tua conferma) · **Confermata** (da fare) · **Fatta** (implementata + commit) · **Scartata**.

---

## Indice

> Le voci **Fatte** storiche (#1, #4, #6, #9, #11, #13, #17) hanno il dettaglio in [proposte-archivio.md](proposte-archivio.md); qui resta uno stub con l'ancora stabile. Il debito **dev aperto** della Fase 1 è ordinato in *Priorità sviluppo Fase 1* più sotto.

| # | Titolo | Impatto | Stato |
|---|--------|---------|-------|
| 1 | Aggiornamento agenda in tempo reale (SSE) | Medio-basso (~½ giornata) | Fatta (dev) |
| 2 | Retell multi-studio: agente per sede/poltrona | Medio (~1 giornata) | Proposta |
| 3 | Validazione codice fiscale con bypass stranieri | Medio (~¾ giornata) | Proposta |
| 4 | Documenti paziente: tab CRUD con allegati (MinIO storage) | Medio (~1 giornata) | Fatta |
| 5 | Object storage MinIO per documenti grandi (CBCT/DICOM) | Medio (~1 giornata) | Proposta |
| 6 | AI YOLO: rilevamento carie su ortopanoramica + retraining | Alto (~3-5 giorni) | Fatta |
| 7 | GDPR: cifratura campo-per-campo con chiavi per tenant (HKDF + AES-256-GCM) | Alto (~2 giorni) | Slice 1+2a Fatta (prod) · Slice 2b Proposta |
| 8 | AI Service: supporto nativo DICOM (formato sorgente radiografico) | Medio (~1 giorno) | Proposta |
| 9 | Segreteria AI: isolamento chat per utente (hardening IDOR sessioni) | Basso (~½ giornata) | Fatta |
| 10 | Da Segreteria AI a DentalCare AI Copilot (roadmap a fasi) | Alto (~multi-settimana) | Proposta |
| 11 | Rinomina UI "Segreteria AI" → "Copilot AI" (feature, non ruolo) | Basso (~½ giornata) | Fatta |
| 12 | CRUD anagrafiche per-tenant (Prestazioni/prezzi, voci anamnesi per studio, categorie magazzino) | Alto (~3-4 giorni) | Proposta |
| 13 | Copilot operativo: scrittura sui moduli + letture mancanti | Alto (~3-4 giorni) | Fatta (dev) |
| 14 | Copilot contestuale e proattivo (contesto UI, push SSE, cross-modulo) | Medio-alto (~2-3 giorni) | Proposta |
| 15 | Copilot: RAG + multimodale + memoria | Alto (~1-2 settimane) | Proposta |
| 16 | Wiki LLM: OCR → GPT-4o → MinIO con versionamento per paziente | Alto (~3-5 giorni) | Proposta |
| 17 | Prompt Manager AI: prompt multilingua editabili (tabella chiave-valore) | Medio | Fatta (dev) |
| 18 | Cartella clinica — **GAP P0**: valore probatorio (audit clinico, finalizzazione/addendum, consensi, encounter) | Alto (~66-90h agente, 3 blocchi) | Proposta |
| 19 | Conformità EU AI Act (perimetro non-MDR): gate no-clinical radiologia + governance AI | Medio-alto (~2-3 settimane) | Proposta |
| 20 | Copilot: fallback `confirmAction` conferma tutte le anteprime invece dell'ultima | Basso (~1-2 ore) | Proposta |
| 21 | Cartella clinica — **GAP P1**: firma, conservazione, terminologia, FHIR, portale, FSE | Alto (~multi-mese, dopo Fase 1) | Proposta |
| 22 | Cartella clinica — **GAP P2**: AI certificata, secondary use, EHDS, federazione, mobile offline | Alto (~Fase 2 / non pianificato) | Proposta |
| 23 | Ruotare la password demo: è pubblica su GitHub e non è cancellabile dalla storia | Basso (~1 ora) | **Proposta — aperta** |
| 24 | `?providerId=` è un filtro deciso dal client, non un'autorizzazione | Medio (~1 giornata) | Proposta |
| 25 | Menu persona demo: cambia la UI ma non il JWT — non dimostra la segregazione | Basso (~½ giornata) | Proposta |
| 26 | CF obbligatorio all'emissione della fattura (seconda metà di 09dc68b) | Basso (~½ giornata) | Proposta |
| 27 | n8n opera come l'utente demo: manca un'utenza di servizio propria | Medio (~1 giornata) | Proposta |
| 28 | `getDemoConfig()` inghiotte l'errore: un 502 di un attimo disattiva il menu persona per tutta la sessione | Basso (~1 ora) | **Fatta (dev) — 18/07** |
| 29 | `install.sql` non rispecchia più la prod: utenze demo divergenti | Basso (~½ giornata) | Proposta |
| 30 | Menu persona demo auto-seleziona la segretaria-provider → lista pazienti a 0 | Basso (~1 ora) | **Fatta (dev) — 18/07** |
| 36 | Prestazioni filtrate per ruolo utente via categorie (`service_categories.allowed_roles`) | Medio (~1 giornata) | **Fatta (dev) — 20/07** |
| 37 | Combo impersonazione demo legata all'account demo, non allo schema del tenant | Basso (~2 ore) | **Fatta (dev) — 20/07** |
| — | Landing/area pubblica allineata al business plan (prezzi, roadmap Fase 1/2, Giulia, logo unico, self-service Essential) | Medio | **Fatta (dev) — 20-21/07** |
| 38 | Odontogramma AI: marcature editabili/eliminabili dal medico + rilascio su delete RX | Medio (~½ giornata) | **Fatta (dev) — 22/07** |
| 39 | Assistente Vocale “Hands-Free” da Poltrona (Chairside Agent) — hotword “Ehi Giulia” | Alto (~43-69 gg-agente; 4-5 settimane con 3 agenti) | **Inclusa in Fase 1 — pianificata** |
| 40 | MinIO — separazione root per ambiente (Dev / Coll / Prod) | Medio (~1 giornata + finestra migrazione prod) | Proposta |
| 41 | Script di installazione per ambiente COLLAUDO (nuovo container Docker) | Medio (~1 giornata) | Proposta |
| 42 | Visibilità dati clinici per ruolo: igienista/dentista/chirurgo/ortodontista vedono tutti i pazienti | Medio (~1 giornata) | Proposta |
| 43 | Anamnesi: severità a 3 livelli (Normale/Grave/Severa) + collegamento reale agli alert clinici + vincolo appuntamento fine giornata | Alto (~2-2.5 giornate) | **Fatta (dev) — 23-24/07 (merge PR #1)** |
| 44 | Tariffe: fatturazione Studio vs Medico, override prezzi per provider con versioning | Alto (~2-2.5 giornate) | Proposta |
| 45 | Odontogramma: pannello a tutta larghezza, legenda leggibile | Basso-Medio (~½-1 giornata) | **Fatta (dev) — 23/07 (core)** |
| 46 | Piano di cura: nome dente in grassetto nell'elenco prestazioni | Basso (~15 min) | **Fatta (dev) — 24/07** |
| 47 | Export selezionabile (una/più/tutte le cliniche del tenant) + **guardia obbligatoria pre-cancellazione** tenant/clinica, con snapshot del catalogo anamnesi condiviso, artefatto cifrato/auditato — **non** conservazione a norma | Medio (~1-1.5 giornate) | **Slice A+B Fatta (dev) — 24/07** |

> **Priorità richiesta dal committente (23/07/2026):** #42 → #43 → #44 → #45 vanno pianificate/eseguite **prima** di #40 e #41.

---

## Fix trovate e chiuse il 17/07/2026

Registrate qui perché nate fuori dal flusso delle proposte: emerse tutte mentre si preparava il manuale utente, e chiuse in giornata.

| Commit | Bug | Come si manifestava | Perché era sfuggito |
|---|---|---|---|
| `d7cefe5` | `initFromAuth()` assegnava `providerId` a ogni ruolo; i componenti lo passavano all'API come filtro | **La segretaria vedeva 0 pazienti e agenda vuota.** Non è il provider di nessun paziente → il filtro non trovava nulla | Il tenant demo lo mascherava: con login admin, `app.ts` forza la persona `__secretary__` → `providerId=null` → nessun filtro. Su un tenant reale il menu persona non esiste e la segretaria non aveva via d'uscita |
| `0864ae4` | `apptStatusFilter` partiva senza `'scheduled'`, e la vista "Prossimi" non aveva il chip per riattivarlo | **Un appuntamento appena prenotato spariva dall'agenda.** Vista di default vuota | La vista "Giorno" faceva già la cosa giusta: il difetto era solo in "Prossimi" |
| `09dc68b` | CF obbligatorio alla creazione del paziente + messaggio d'errore perso per i vincoli di classe | **Nessun paziente nuovo poteva prenotare per telefono** (400). L'agente ritentava identico perché riceveva solo "Dati non validi" | Conflitto fra due regole entrambe difendibili: il prompt di Giulia **vieta** di chiedere il CF (§19), l'API lo **pretendeva** |
| `23d091e` | `.example` prescriveva `demo=on` e una chiave JWT funzionante e pubblica | Ogni installazione nuova avrebbe riesposto la password e adottato in silenzio una chiave di firma pubblica | Il fix a mano sul server non sopravviveva: `install.sh` ricrea la config dal `.example`. **La causa era nel repo, non sul server** |

**Il filo comune:** tre difetti su quattro erano invisibili *proprio* perché li si guardava dall'ambiente demo, che si comporta diversamente dalla produzione reale (persona forzata, config divergente). L'ambiente costruito per dimostrare il prodotto è lo stesso che ne nascondeva i difetti.

## Fix chiuse il 18/07/2026

Proseguendo sui punti aperti del 17/07. Entrambe in `app.ts`, entrambe modi di rottura *dal vivo* del menu persona demo.

| Fix | Come si manifestava | Perché ora |
|---|---|---|
| **#30** — su tenant demo il menu persona parte da "Segreteria" per ogni login **non clinico** (admin / secretary / tenant_admin); `mapRole` ora mappa `secretary`→`secretary` invece di cadere sul default `doctor` | `segreteria@demo` (Maria Rossi) è anche un record `providers`: il menu la auto-selezionava come **provider** e, se ri-scelta, `mapRole('secretary')→'doctor'` la rendeva un medico filtrante → **lista pazienti a 0**. Solo i ruoli clinici (dentist/hygienist) restano agganciati al proprio provider | Rischio in presentazione: chi fa login come `segreteria@` vedeva 0 pazienti finché non sceglieva a mano "Segreteria" |
| **#28** — `getDemoConfig()` con `retry({count:5, delay:1500})` + `console.warn` invece di `catch` vuoto | Un 502 transitorio al riavvio (`docker compose up`: il frontend risponde prima che il backend sia pronto) lasciava `demoSchema=null` → menu persona demo sparito **per tutta la sessione**, in silenzio | Bastava un riavvio poco prima della presentazione per perdere il menu persona senza alcun segnale |

> Verifica: build FE verde (exit 0). Da deployare in prod insieme al resto.

---

## Incident prod: anamnesi non salva (FK item_id) — 24/07/2026

**Sintomo:** in prod il salvataggio anamnesi falliva con
`insert or update ... violates foreign key constraint "patient_anamnesis_item_selections_item_id_fkey" — Key (item_id)=(…) is not present in table "anamnesis_items"`, anche se l'item **esisteva** nel catalogo per-tenant `t_9d754153.anamnesis_items`.

**Causa:** il DB prod precede il rework anamnesi (#43). La FK `…_item_id_fkey` sullo schema del tenant puntava ancora al catalogo **globale** `dentalcare.anamnesis_items` (vecchia `create_tenant`), mentre gli item sono seedati per-tenant con `gen_random_uuid()` → id presente per-tenant ma **assente nel globale** → violazione. Il guard di convergenza (`patchAnamnesisCatalog` + `patch_anamnesis_tenant_migration.sql` step 5) aggiungeva la FK **solo se non esisteva**: con una FK già presente (verso il globale) la lasciava intatta → mai corretta.

**Fix codice** (commit `3e4dbce`): il guard ora conta la FK **solo se punta già al catalogo per-tenant**; altrimenti `DROP` + `ADD` verso lo schema del tenant, sempre gated su 0 orfani. Applicato sia in `EstimateSchemaInitializer.java` sia nel percorso DBA `patch_anamnesis_tenant_migration.sql`. Self-heal per restart/tenant nuovi.

**Fix dati prod (DBA, a mano):** le 27 selezioni demo esistenti referenziavano **due generazioni** di catalogo legacy (codici `ALLERG_*`/`FARMACI_*`/`SIS_*`/… — nessuno mappabile per codice al nuovo schema `ALL_*`/`FAR_*`/`COR_*`). Backup in `t_9d754153._bak_pais_legacy_orfane`, righe orfane cancellate, poi FK ripuntata al catalogo per-tenant. Verifica: `fk_points_to_tenant = true`, 0 orfani, salvataggio anamnesi OK.

**Nota residua:** `install.sql` (demo-dump) può ancora contenere quelle righe/catalogo legacy → rigenerare al prossimo `pg_dump` demo (vedi #29).

---

## Fix odontogramma AI — 22/07/2026

**#38 — Marcature AI dell'odontogramma editabili/eliminabili dal medico + rilascio su delete RX.** Stato: **Fatta (dev)**.

**Problema.** L'AI dell'ortopanoramica valorizza i denti (`tooth_conditions source='ai'`), ma il medico non poteva **eliminare** una marcatura AI errata: `OdontogramService.save()` cancellava solo le righe `manual`, quindi la riga AI sopravviveva e riappariva al reload (la *modifica* invece già la promuoveva a manuale). E cancellando l'ortopanoramica le marcature AI restavano orfane e ancora bloccate come AI.

**Fix.**
- `OdontogramService.save()` + `SaveOdontogramRequest.removedAi`: il frontend invia le marcature AI che il medico ha azzerato → il backend le elimina. Gira **prima** dei return anticipati, così un save che *solo* rimuove marcature AI funziona. La modifica di una marcatura AI continua a promuoverla a `manual` via upsert.
- `PatientDocumentService.delete()` su documento con analisi (RX): **promuove** le condizioni AI a `manual` (badge via, editabili/eliminabili), **conserva** analisi + labels come provenienza AI marcandole `document_deleted_at`, **purga** solo i binari MinIO (immagine annotata + JSON result). I metadati dei findings restano nelle labels.
- Schema: `patient_document_analyses.document_deleted_at` (patchSchema idempotente `ADD COLUMN IF NOT EXISTS` + install.sql, entrambe le occorrenze).
- Frontend: `odontogramma-tab.save()` calcola `removedAi` (chiavi AI ora assenti); model `ToothRef`.

**Decisioni prodotto.** Q1: *nuova RX = nuova evidenza* — la sync continua wipe+replace di `source='ai'`; le condizioni promosse a manuale non le tocca. Q2 (ottica audit): promuovi condizioni · **conserva** analisi+labels · purga binari · marker `document_deleted_at`; l'erasure GDPR art.17 resta un flusso separato. Motivazione in [DentalCare-Documentation → 13-Audit-Trail].

**Test.** `OdontogramServiceTest` (3, nuovo) + `PatientDocumentServiceTest` (7, incl. `delete_releasesAiArtifacts`). Backend `mvn test` verde (10/10), build FE verde. **Da deployare in prod.**

---

> ### ⚠️ Due significati di "P1" — non confonderli
>
> | Sigla | Dove | Significa |
> |---|---|---|
> | **P1 / P2 / P3** | *Roadmap prioritaria* qui sotto | bucket di priorità **delle proposte** → *quando* farle |
> | **GAP P0 / P1 / P2** | `gap-analysis-cartella-clinica.md` §3/§4/§5 → proposte #18 / #21 / #22 | livelli di requisito **della guida alla digitalizzazione** (§25.1/25.2/25.3) → *quanto è bloccante il requisito* |
>
> Non c'è corrispondenza tra le due scale. Scrivere sempre **`GAP P1`** (con prefisso) quando si intende il livello di requisito.

## Roadmap prioritaria (consigliata) — solo funzionalità di prodotto

> **Perimetro ridotto.** Questa roadmap ordina le proposte **di prodotto** (#1-#17). Il percorso **cartella clinica + compliance** (#18, #19, #20, #21, #22) è governato dal *Piano di intervento* qui sotto e da `piano-lungo-termine.md`, che ha la precedenza in caso di conflitto: quel percorso è vincolato dal **gate di go-live**, non dal valore utente.
>
> Conseguenza pratica: nessuna delle proposte in questa roadmap va in produzione **su pazienti reali** prima che il gate di go-live sia verde.

Ordine consigliato tra le proposte **aperte** (le #ID restano stabili per non rompere i riferimenti). Già **Fatte**: #4, #6, #9, #11. #7 parziale (Slice 1+2a LIVE prod, resta 2b). #5 (MinIO) di fatto consegnata con #6. Criteri: valore utente · effort · dipendenze · rischio/compliance.

**P1 — Subito (alto valore, basso rischio, sblocca uso reale)**
1. **#12.A** — CRUD Prestazioni/prezzi/default/bundle: quick-win, nessuna migrazione, sblocca listino e "Genera piano" per ogni studio.
2. **#1** — SSE agenda realtime: piccolo, migliora la UX agenda e abilita la proattività (#14).
3. **#10 Fase 0** — Governance Copilot (audit azioni + disclaimer + gating ruolo): enabler piccolo, prerequisito alla scrittura clinica.
4. **#13** — Copilot operativo (scrittura sui moduli + letture mancanti): salto di valore maggiore; dopo la Fase 0.

> ✅ **P1 completato in dev** (2026-07-02): #12.A (CRUD prestazioni, commit a7cce0d), #1 (SSE agenda, a7cce0d), #10 Fase 0 (audit+disclaimer, 9a01e3b), #13 (Copilot operativo, 4ec275c). Build FE+BE verdi, patch DB `ai_audit_log` applicata a dev. Da deployare in prod. Restano di #12: 12.B (anamnesi per-tenant, richiede decisione), 12.C (categorie prodotto), 12.D (poltrone).

**P2 — Poi (valore medio o dipendente)**
5. **#12.C** — CRUD categorie prodotto: piccolo, chiude il magazzino.
6. **#3** — Validazione codice fiscale + flag straniero: qualità dati anagrafici.
7. **#14** — Copilot contestuale/proattivo (contesto UI + push SSE + cross-modulo): dopo #13 e #1.

**P3 — Dopo / compliance / oneroso**
8. **#7** — GDPR cifratura per-tenant: **Slice 1 (birth_date) + 2a (fiscal_code) FATTE e LIVE in prod** (2026-07-15). Resta **Slice 2b** (phone/email/address, ~½ giornata) + valutazione TDE. Era P3 "compliance": di fatto anticipato per produzione clinica.
9. **#2** — Retell multi-studio (agente per sede/poltrona): se/quando servono più sedi.
10. **#16** — Wiki LLM: OCR + GPT-4o + MinIO multitenant: sblocca Knowledge Base clinica (RAG per #15); dipendente da #7 (GDPR) e #8 (DICOM) se esteso a radiografie.
11. **#12.B** — Anamnesi per-tenant: richiede decisione di design (Opt 1/2/3) + migrazione dati.
12. **#8** — DICOM nativo nell'AI service: nicchia, dopo #6.
13. **#15** — Copilot RAG/multimodale/memoria: blocco più oneroso, dopo #13/#14.

---

## Fix da fare — raccolta al 17/07/2026

Tutto ciò che è aperto, in un posto solo. Ordinato per **rischio**, non per costo.

### 🔴 Sicurezza — aperte

| # | Cosa | Perché adesso | Effort |
|---|---|---|--:|
| **23** | **Ruotare la password demo** | È in chiaro nel repo **pubblico** (7 file) e nella storia git da `fe58b78`. Toglierla dai file **non serve**: la storia è già clonata. Le utenze funzionano e prod è su Internet. Unica misura efficace: cambiarla. Script `database/rotate_demo_password.py` **validato + dry-run dev OK il 18/07**; resta l'esecuzione su prod (`--apply`, write bloccata al classifier per l'agente) + scelta password + allineamento config server (`app.demo.password`, `app.n8n.admin-password`) | ~1h |
| **24** | `?providerId=` non è autorizzazione | È `required=false` e arriva dal client: ometterlo = vedere tutto il tenant, con qualsiasi ruolo. È il gap 3.6 (§11.1 della guida) con il meccanismo esatto | ~1g |
| **27** | n8n opera come l'utente demo | Nell'audit è indistinguibile dall'utenza demo; con l'audit clinico di Fase 1 diventa un problema di attribuzione. E blocca il multi-studio di #2 | ~1g |

### 🟡 Correttezza — aperte

| # | Cosa | Perché | Effort |
|---|---|---|--:|
| **26** | CF obbligatorio in fattura | È la **seconda metà** della decisione presa con `09dc68b`: il CF è ora opzionale alla creazione, ma nessun controllo lo pretende dove serve davvero | ~½g |
| **25** | Menu persona: dichiarare che non è un confine | Cambia la UI, non il JWT. In demo promette una segregazione che non c'è | ~½g |
| ~~**28**~~ | ~~`getDemoConfig()`: niente `catch` vuoto~~ | **Fatta (dev) 18/07** — `retry`+`console.warn`, vedi §Fix chiuse il 18/07/2026 | — |
| **29** | Rigenerare il seed di `install.sql` | Diverge dalla prod: `medico@` non esiste, le utenze sono 7 non 4. Ogni runbook che le cita è già sbagliato. **Mappata il 18/07** (vedi §29) — resta il `pg_dump` prod (write/read prod bloccati al classifier: li lancia il committente) + decisione fonte-di-verità | ~½g |

### ⚪ Igiene — da valutare

- **Macchina prod chiamata `dev`** (l'host chiamato `dev` ospita `~/docker/dentalcarepro` e `dentalcare_prod`). Il nome dice l'opposto di ciò che la macchina fa. *Confermato voluto dal committente il 17/07 — annotato, non da correggere.*
- **`server.error.include-message=never`** in prod: giusto come hardening, ma con #28 e simili rende ogni diagnosi cieca. Valutare un canale di errore strutturato (codice stabile + `fields`, come prescrive CLAUDE.md §10.2) invece del messaggio libero.
- ~~**[#30] Segretaria che è anche provider → persona filtrante auto-selezionata.**~~ **Fatta (dev) 18/07** — `app.ts`: su tenant demo il menu persona parte da "Segreteria" per ogni login non clinico, e `mapRole('secretary')→'secretary'` (non più `doctor`). Meccanismo esatto e verifica: §Fix chiuse il 18/07/2026. Restava legata a [#25] (dichiarare che il menu persona non è un confine): quella resta aperta.
- **[demo-data] Due convenzioni poltrone insieme** (`Studio 1-4` + `Poltrona 1-4`): l'agenda creava **8 colonne** e sembrava vuota (gli appuntamenti erano nelle colonne scrollate fuori). Normalizzato a `Studio 1-4` il 17/07 sul tenant demo per gli screenshot. Origine della deriva: il seed usa "Studio", ma le prenotazioni via Giulia sceglievano la prima poltrona in ordine alfabetico ("Poltrona 1"). Dopo la normalizzazione `findChairLabels()` ritorna solo `Studio 1-4`, quindi Giulia sceglie "Studio 1" e la deriva si ferma. Va allineato anche nel seed di `install.sql` (vedi [#29]).

- **[leak-topologia] `rotate_demo_password.py` esponeva la rete interna sul repo pubblico** (IP del DB e del server app, utente SSH, path docker). **Scrubbato il 18/07** (`--host` obbligatorio, hint ssh/config generici). Come #23 la storia git resta — già fuori: da chiudere col push. Regola: nessuno script ops committato deve hardcodare topologia interna (host/IP/utenti/percorsi) — passarli da CLI o config locale. **Vale anche per questo file:** è versionato sullo stesso repo pubblico, quindi indirizzi, credenziali e hash vanno scritti come segnaposto.

### Rapporto con il resto

Queste fix sono **indipendenti** dal piano della cartella clinica (#18/#21/#22): sono difetti dell'esistente, non nuove funzioni. Ma tre confluiscono lì:
- **#24** → intervento 14 (relazione di cura come autorizzazione)
- **#25** → intervento 3 (segregazione server-side + test)
- **#27** → attribuzione nell'audit, intervento 1

**Nessuna di queste è nel gate di go-live.** La #23 dovrebbe esserci: una credenziale pubblica e funzionante su un sistema esposto è una condizione d'ingresso, non un miglioramento.

---

## Fix operativi dal collaudo — 20/07/2026 (#31-#35)

Emersi provando l'app come medico/segretaria. Verificati sul codice reale, non solo segnalati.

| # | Cosa | Analisi (dal codice) | Effort | Rischio |
|---|---|---|--:|---|
| 31 | **Appuntamento smart** (a1+a2): proporre data/ora + poltrona liberi in base alla **durata della prestazione**, auto-selezionare il medico (self per il medico; scelto o disponibile per la segretaria) e la poltrona | `nuovo-appuntamento.component.ts`: form **tutto manuale** (data/ora/durata/provider/chair a mano), nessun motore di disponibilità; la durata non deriva dalla prestazione. **Greenfield:** serve endpoint BE `availability` (primo slot libero per durata + provider opz. → slot+poltrona) + auto-fill FE | Alto (~1-1.5g: BE ~1g + FE ~½g) | Medio |
| 32 | **Odontogramma: distinguere AI vs manuale e curato vs da curare** (b) | AI-vs-manuale **già parziale** (`aiTeeth`/`isAi`/badge A, `source==='ai'`). Manca **curato vs non curato**: nessuna dimensione stato-trattamento visibile. Serve check schema `tooth_conditions` (colonna status/treated? lega a intervento 7 odontogramma temporale) + legenda/colori UI a due assi | Medio (~½-1g) | Basso |
| 33 | **PDF a tutta pagina** (c) | tab Documenti: PDF in viewer vincolato. Overlay fullscreen + chiusura X/Esc | Basso (~2h) | Basso |
| 34 | **Preventivo: subtotale/totale non si aggiornano** (d) | Il FE ricarica già via `loadEstimate()` dopo `addLine` → causa **backend**: totali non ricalcolati su add/delete riga (colonna memorizzata stantia o DetailDto che non somma le righe) | Basso (~2-4h) | Basso |
| 35 | **Fattura da medico: solo i propri preventivi** (e) | `EstimateController.findAll(status, providerId)` **già filtra** per provider. Serve: FE creazione fattura usa `filterProviderId` (medico→propri, segretaria→tutti), stesso pattern di #30. Lega a #24/#26 | Basso (~2-4h) | Basso |

**Gruppo di lavoro** (partizione per domini disgiunti → niente conflitti sul working tree; gli agenti implementano+build ma **non committano**, riconcilia il coordinatore). **Stato al 20/07 (tutto in dev):**
- ✅ **#33** PDF a tutta pagina + **#35** fattura → solo i propri preventivi — commit `272df82`.
- ✅ **#34** totali preventivo (ricalcolo app-side, indipendente dal trigger DB mancante su schema legacy; 7 test) — commit `dfbe871`.
- ✅ **#32** odontogramma a due assi (origine AI/manuale + stato clinico via `CONDITION_STATUS`) — commit `0bea0a4`.
- ✅ **#31** appuntamento smart, in tre pezzi:
  - **BE** `GET /api/appointments/availability` — primo slot libero medico+poltrona, calcolo in memoria su una sola query, regola overlap identica a `create` — commit `c768b80`.
  - **FE** `nuovo-appuntamento` si auto-compila: durata dalla prestazione, medico = sé stesso se clinico (a1) o scelto/proposto per la segreteria (a2), 3 proposte cliccabili, tutto sovrascrivibile — commit `86633ce`.
  - **Config** orari studio **per tenant** da Impostazioni → Agenda (`clinics.work_start_time/work_end_time/slot_minutes/working_days`), costanti come fallback — commit `7be2e3c`. La UI degli orari **esisteva già ma salvava solo in localStorage**: il backend non l'aveva mai vista.

> Follow-up da #31-config: le 4 colonne orari sono aggiunte via `patchSchema` (come le altre colonne di `clinics`), **non** in `install.sql` — coerente con il meccanismo esistente, ma resta la divergenza tracciata in [#29].

> Follow-up emerso da #34: `queryLines()` usa `INNER JOIN service_catalog` → una riga con `service_id` NULL (servizio cancellato) sparirebbe dal totale. Fuori scope del fix, da valutare.

---

## Priorità sviluppo Fase 1 — debito dev del gate go-live (21/07/2026)

> **La sequenza vincolante sta in `piano-lungo-termine.md` (Sprint 1→4 + §5 gate), che ha la precedenza.** Questa è la vista operativa del solo **debito di codice**, ordinata, con l'effort agente calibrato sulle metriche storiche del progetto. Il collo di bottiglia della Fase 1 **non è questo lavoro**: è l'ingaggio del DPO (DPIA/DPA/informative, mesi, non comprimibili). Vedi `piano-lungo-termine.md` §2.

Ordine di esecuzione (le voci mappano su interventi già dettagliati sotto e negli sprint):

| Pr | Cosa | Voce gate / intervento | Effort agente | Nota di sequenza |
|---:|---|---|--:|---|
| **1** | **Audit trail clinico** append-only | #18 Blocco 1 · Sprint 1.1 · **scope MVP in [`audit-trail-tier1-mvp.md`](audit-trail-tier1-mvp.md)** | **12-20h** + brainstorm | Fondazione. Abilita tutto il resto (il #2 deve *registrare* i tentativi negati). Il logging delle **letture** (obbligo Garante) è trasversale a ~40 service → alza il pavimento oltre la stima iniziale e **va progettato prima** |
| **2** | **Enforcement ruoli lato server** (segreteria non vede clinico) | #24 + intervento 3 · Sprint 1.3 | 2-4h | Dipende dal #1 per il log del negato. Oggi `SecurityConfig` protegge solo `/admin` e `/tenant-admin`: le rotte cliniche sono solo `authenticated` |
| **3** | **Finalizzazione note + addendum** e **consensi versionati** | #18 Blocco 1-2 · Sprint 1.2 / 2.2 | 8-14h | Cuore probatorio. **Non one-shot da agente**: decisioni medico-legali (hash, immutabilità, stati, versioning). Serve `/brainstorming` prima |
| **4** | **MFA** + **export paziente art. 15** | Sprint 3.1 / 3.2 | 5-8h | Isolate, parallelizzabili mentre si progetta il #3 |
| **5** | **Fondazioni Copilot vocale**: conversazione condivisa, policy e impostazioni | #39 Blocchi A-B | 11-18 gg BE + 17-26 gg FE + 15-25 gg QA per l'intero #39 | Può partire in parallelo al #3 dopo che contratti di audit e autorizzazione di #1-2 sono stabili; feature flag disabilitato |
| **6** | **Vertical slice voce**: push-to-talk, STT, TTS e hotword locale | #39 Blocchi C-E | incluso nella stima #39 | Prima su dati fittizi e funzioni di lettura/navigazione; nessuna scrittura clinica |
| **7** | **Dettatura clinica controllata e pilota Chairside** | #39 Blocchi F-G | incluso nella stima #39 | Solo dopo #1, #2, finalizzazione/addendum applicabile, chiusura #20, DPIA/fornitore e gate di go-live; revisione trascrizione e conferma dell'azione restano due gate distinti |

**Effort aggiuntivo #39 in Fase 1:** **~43-69 giornate-agente** complessive; con tre agenti dedicati e lavoro parallelo, **~4-5 settimane calendario** incluso il pilota controllato. Questa stima si aggiunge al debito preesistente della Fase 1 e non modifica i gate normativi.

**Totale debito dev preesistente Fase 1:** ~19-33h agente · ~5-9h di tua review · ~9-16 settimane equiv. team umano. Coerente con `piano-lungo-termine.md` §2 ("settimane, non mesi").

Fuori da questi 4 ma parte del gate (non-codice, terzi/tuoi): DPIA, DPA fornitori, informative, AI literacy, contratto deployer, restore test, pen test. Vedi il gate completo in `piano-lungo-termine.md` §5.

**Piano estivo consigliato:** gli agenti macinano #1→#2 e #4 (spec deterministica) mentre sei via; il #3 si apre insieme al rientro (serve la tua testa sul modello probatorio). E **la ricerca del DPO parte adesso in parallelo** — è quella che detta la data, non il codice.

---

## Piano di intervento — cartella clinica (GAP P0 → GAP P1)

**Fonti:** `gap-analysis-cartella-clinica.md` (gap verificati su codice + DB reale) · `piano-lungo-termine.md` (sequenza, sprint, date, gate) · `roadmap_certificazione.md` (perimetro AI).
**Copre:** GAP P0 (#18) e GAP P1 (#21). GAP P2 (#22) è fuori piano — vedi §Fase 2 in `piano-lungo-termine.md`.

Ordine per **priorità tecnica** (dipendenze prima) e **rilascio in produzione Fase 1** (voci del gate prima). La colonna **Gate** indica se l'intervento è nella lista *"nessun paziente reale prima che sia verde"* (`piano-lungo-termine.md` §5).

> **Perché quest'ordine.** L'audit è primo non perché sia il gap più grave — il più grave è la finalizzazione — ma perché è l'unico **abilitante**: report accessi, diritti del paziente, KPI di qualità e le domande da controllo (§24.2) dipendono tutti da lui, e la segregazione della segreteria richiede di *negare **e registrare***. L'encounter è il secondo perno: senza `encounter_id` l'odontogramma temporale e FHIR non hanno su cosa agganciarsi.

### Blocco 1 — Valore probatorio · GAP P0 · Fase 1 / Sprint 1 · ~20-26h agente

| # | Intervento | Gap | Dipende da | Gate | Effort |
|--:|---|---|---|:-:|--:|
| 1 | **Audit trail clinico** append-only: tabella `audit_event` separata dal log applicativo, no UPDATE/DELETE (revoca privilegi + trigger), eventi e campi §12, retention + esportabilità | 3.2 ❌ | — | ✅ | ~8-10h |
| 2 | **Finalizzazione + addendum + hash** su `clinical_history_entries`: stati §6.1, blocco UPDATE dopo `final` (service **e** trigger DB), SHA-256 alla finalizzazione, `version`, entità addendum | 3.1 ❌ | 1 (l'audit deve registrare finalize/addendum/annullamento) | ✅ | ~7-9h |
| 3 | **Segregazione segreteria server-side** + test automatico §26.2 | 3.6 🟡 | 1 (il criterio richiede *negata **e registrata***) | ✅ | ~3-4h |
| 4 | **Soft delete** (`deleted_at`/`status`) al posto della cancellazione fisica; purge come procedura eccezionale documentata | 3.11 🟡 | — | — | ~2-3h |

### Blocco 2 — Modello clinico · GAP P0 · Fase 1 / Sprint 2 · ~22-31h agente

| # | Intervento | Gap | Dipende da | Gate | Effort |
|--:|---|---|---|:-:|--:|
| 5 | **Encounter** (`planned`/`in-progress`/`finished`, sede, professionista, motivo) + FK `encounter_id` su clinical entries, diagnosi, documenti, `tooth_conditions` | 3.4 ❌ | 1 | — | ~8-12h |
| 6 | **Consensi versionati**: `consent_template` (testo/lingua/versione/efficacia) + `consent` (firmatario, revoca, allegati, rappresentanza), immutabile dopo firma, **collegato al piano** | 3.3 ❌ | 5 (il consenso si lega a procedura/piano dell'episodio) | ✅ | ~6-8h |
| 7 | **Odontogramma temporale**: `certainty`, `encounter_id`, `onset_date`, `recorded_by`, `supersedes_id`, `void_reason`, `status` → storico + confronto tra date | 3.7 🟡 | 5 | — | ~5-7h |
| 8 | **Anamnesi tri-stato** (presente / assente-negato / non noto) + fonte, data rilevazione, data risoluzione | 3.8 🟡 | — | — | ~3-4h |

> **Nota su 7.** `tooth_conditions.source` + `analysis_id` **è già la cosa giusta** (§17.1: output AI conservato come proposta distinta). Va **esteso, non rifatto**.

### Blocco 3 — Identità e accessi · GAP P0 · Fase 1 / Sprint 3 · ~24-33h agente

Riordinato rispetto a `piano-lungo-termine.md` §4 Sprint 3: **prima le voci del gate**.

| # | Intervento | Gap | Dipende da | Gate | Effort |
|--:|---|---|---|:-:|--:|
| 9 | **MFA** per professionisti e admin | 3.6 🟡 (§11.2) | — | ✅ | ~5-6h |
| 10 | **Export paziente completo** (art. 15) + copia integrale documentazione + **report accessi** + registrazione richieste/tempi | 3.10 🟡 | 1 | ✅ | ~4-6h |
| 11 | **Admin tecnico senza accesso clinico ordinario** + **break glass** tracciato (motivazione obbligatoria, audit, notifica) | 3.6 🟡 (§11.1, §11.3, §28.18) | 1 | ⚠️ **assente dal gate — vedi sotto** | ~3-4h |
| 12 | **Merge duplicati** + `patients.status` (attivo/deceduto/duplicato/archiviato), match esatto via blind index CF + fuzzy nome+data, approvazione + audit + reversibilità | 3.5 ❌ | 1 | — | ~5-7h |
| 13 | **`sha256`** (obbligatorio §30) + verifica **MIME reale** + malware scan/quarantena + coerenza paziente↔immagine | 3.9 🟡 | — | — | ~4-6h |
| 14 | **Relazione di cura** come filtro di autorizzazione (`primary_provider_id` esiste ma non è usato) | 3.6 🟡 (§11.1) | — | — | ~3-4h |

> **⚠️ Buco nel gate di go-live — da decidere.**
> Il gate (`piano-lungo-termine.md` §5) verifica che la **segreteria** non veda i contenuti clinici, ma **non dice nulla sull'`admin` tecnico**. La gap analysis §8 marca l'errore §28.18 *"amministratori tecnici che leggono tutto"* come **❌ presente**, e §11.1 lo vieta esplicitamente.
> Allo stato attuale il gate passerebbe **con una non conformità nota attiva**. Proposta: aggiungere al gate la voce *"l'amministratore tecnico non accede ai contenuti clinici in chiaro; ogni accesso straordinario passa da break glass tracciato"*, e promuovere l'intervento 11 a bloccante.
> Stessa logica del gate no-clinical (#19): il controllo che regge la posizione deve stare **nel gate**, non nelle buone intenzioni.
>
> Effetto sullo sprint: Sprint 3 passa da ~20-30h a **~24-33h** (l'intervento 11 non era nel piano originale).

### Blocco 4 — GAP P1 · **dopo** il go-live di Fase 1 · vedi #21

`piano-lungo-termine.md` §4 esclude i GAP P1 dalla Fase 1: *"servono per crescere, non per il primo studio"*. Ordine per dipendenza tecnica, non per valore.

Effort in taglie (S ≤ 1 settimana agente · M ≤ 1 mese · L > 1 mese) — **non derivato da analisi di dettaglio**, indicativo. Dove il costo è dominato da terzi (fornitore, accreditamento) l'effort agente è irrilevante e lo dico.

| # | Intervento | Gap P1 | Dipende da | Effort | Perché qui |
|--:|---|---|---|:-:|---|
| 15 | **Analytics qualità / KPI §23** | Analytics 🟡 | 1, 6, 12 | S | Il più economico dei P1: i KPI §23.1 (*piani con consenso collegato*, *duplicati per 1.000 pazienti*) diventano **misurabili da soli** appena esistono audit + consensi + merge. Raccolta di frutti già maturi. |
| 16 | **Politica di conservazione + massimario + politica di firma** (§9.2, §9.4) | Conservazione ❌ | — | **non-codice** (DPO/legale) | Prerequisito di 17 e 20. Va fatto **mentre il DPO è già ingaggiato** per la DPIA: costa poco in aggiunta, molto da soli. |
| 17 | **Firma avanzata/qualificata (PAdES)** | Firma ❌ | 2, 16 | M + fornitore | La finalizzazione (2) è il **livello 2** di §9.2; PAdES è il **livello 3**. Senza 2 non c'è nulla da firmare. |
| 18 | **Terminology service**: code system + versione su `service_code` / `condition` (oggi stringhe libere) | Terminology ❌ | — | M | **Gate tecnico di FHIR e FSE**: senza codifica governata non c'è scambio, solo export. Indipendente da tutto il resto → si può anticipare. |
| 19 | **Esame obiettivo strutturato** (extraorale, mucose, ATM, occlusione, endodonzia) + **charting parodontale** (sondaggio, recessioni, mobilità, placca/sanguinamento) | Parodontale ❌ + §5.4 | 5 | M | Profondità clinica, indipendente dall'interoperabilità. Oggi tutto in `clinical_notes` testo libero. **È l'unico P1 che un odontoiatra nota come funzione mancante** → candidato ad anticipazione se richiesto dal mercato. |
| 20 | **Conservazione a norma** | Conservazione ❌ | 16, 17 | dominato da fornitore/accreditamento | Oggi MinIO + `pg_dump` = **backup**, non conservazione (§9.3, errore §28.7). Distinzione non negoziabile. **L'app costruisce i *feeder*, non il *caveau*:** documentazione clinica → finalizzazione + hash (intervento 2) poi PDF/A + PAdES (intervento 17) come documenti *ingeribili* da un sistema di conservazione; **fatture** → delegate a un **conservatore accreditato AgID esterno** (via SdI), non conservate in casa. L'export #47 è copia di sicurezza/portabilità, **non** entra in questo perimetro. |
| 21 | **FHIR API** (adapter, **non** modello interno) | FHIR ❌ | 5, 6, 18 | M-L | La strategia duale §14.1 è **già corretta**: il modello interno non va rimodellato, si aggiunge un adapter. Serve encounter (5), consensi (6) e terminologia (18) o l'adapter mappa il vuoto. |
| 22 | **DICOMweb** → proposta **#8** | DICOMweb ❌ | — | S-M (#8) | Indipendente da tutto il resto: si può fare quando serve. |
| 23 | **Portale paziente** | Portale ❌ | 1, 6, 10 | L | Espone al paziente esattamente ciò che 1/6/10 rendono esponibile. Prima di quelli non ha contenuto da mostrare. |
| 24 | **Connettore FSE 2.0** | FSE ❌ | 17, 18, 20, 21 | dominato da accreditamento | **Ultimo per costruzione**: richiede CDA2 + PAdES + conservazione + accreditamento regionale. Ogni sua dipendenza è un altro P1. |

> **Report accessi** (§25.2) non compare qui: è **chiuso dall'intervento 10** in Fase 1, perché dipende dall'audit (1) e serve al diritto del paziente. È l'unico GAP P1 che entra in Fase 1 — e ci entra come effetto collaterale, non per scelta.

### Sintesi per rilascio

| Rilascio | Blocchi | Interventi | Effort agente | Vincolo reale |
|---|---|---|--:|---|
| **Fase 1 — go-live gennaio 2027** | 1 + 2 + 3 + #39 | 1-14 (+ report accessi) + Chairside Agent | **~66-90h** per #18 + **43-69 gg-agente** per #39 | **non il codice**: DPIA/DPA/contratti/pen test → ingaggio DPO entro **fine agosto 2026**; voce attivabile solo con pilota verde |
| **Post-Fase 1** | 4 | 15-24 | mesi | mercato (19, 22) · terzi (16, 17, 20, 24) |
| **Fase 2 — CE 2029** | — | vedi #22 | ~24 mesi | apertura solo se la Fase 1 vende (`piano-lungo-termine.md` §6.1) |

> **✅ Allineato il 17/07/2026.** Il §2 di `piano-lungo-termine.md` dichiarava *"~65-100 ore agente"* per tutto il debito tecnico di Fase 1, ma i suoi stessi sprint sommavano a 80-114h. Corretto a **~85-120h agente** (= #18 ~66-90h + #19 Sprint 0 ~10-14h + hardening ~10-15h), e il gate §5 ha ora la voce sull'admin tecnico, consegnata dallo Sprint 3.
>
> La conclusione non cambia — si rafforza: anche a 120h **il codice resta settimane contro i mesi di DPIA/DPA/pen test**. Una stima tecnica sbagliata del 40% non sposta il percorso critico. **Il collo di bottiglia non è il codice: sono le firme.**

---

## 1. Aggiornamento agenda in tempo reale (SSE)

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #1 resta stabile per i riferimenti.

## 2. Retell multi-studio: agente per sede/poltrona

**Stato:** Proposta
**Data proposta:** 2026-06-25
**Impatto:** Medio (~1 giornata)

### Problema
L'agente Retell (Giulia) è unico e non sa a quale studio/poltrona indirizzare gli appuntamenti. Se il tenant ha più sedi o più poltrone con numeri telefonici distinti, tutti gli appuntamenti creati da Retell finiscono con lo stesso `chairLabel` hardcodato in n8n.

### Scenario target
Un tenant con N sedi/studi, ciascuna con il proprio numero telefonico e il proprio agente Retell. Ogni chiamata deve produrre un appuntamento con il `chairLabel` (e opzionalmente il `providerId`) corretto per quella sede.

```
+3902111 → agent_A → Studio 1 / Poltrona 1
+3902222 → agent_B → Studio 2 / Poltrona 2
+3902333 → agent_C → Sede Roma / Poltrona 3
```

### Soluzione (4 fasi)

#### Fase 1 — DB: tabella `retell_agents` nel tenant schema

```sql
CREATE TABLE retell_agents (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    retell_agent_id     text        NOT NULL UNIQUE,   -- ID agente su Retell
    phone_number        text,                           -- numero pubblicato ai pazienti
    label               text        NOT NULL,           -- "Sede Roma", "Studio 1"
    default_chair_label text        NOT NULL DEFAULT 'Poltrona 1',
    default_provider_id uuid        REFERENCES providers(id) ON DELETE SET NULL,
    active              boolean     NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now()
);
```

Seed con l'agente corrente (Giulia). Aggiungere anche in `install.sql` e nella funzione `create_tenant`.

#### Fase 2 — Backend: endpoint `/api/retell/agents/{agentId}`

- `RetellAgentConfigDto` — record con `retellAgentId`, `label`, `defaultChairLabel`, `defaultProviderId`
- `RetellAgentService` — query su `retell_agents` filtrata per `active = true` e `retell_agent_id`
- `RetellController` — `GET /api/retell/agents/{agentId}`, autenticato con JWT (n8n già lo possiede dal service-token)

Risposta:
```json
{
  "retellAgentId": "agent_xxx",
  "label": "Sede Roma",
  "defaultChairLabel": "Poltrona 1",
  "defaultProviderId": null
}
```

#### Fase 3 — n8n: leggi config agente all'avvio del flusso

All'inizio del workflow (dopo il nodo service-token):

1. **HTTP Request** → `GET /api/retell/agents/{{ $('WebhookTrigger').item.json.body.agent_id }}`
2. **Set** → `chairLabel = {{ $json.defaultChairLabel }}`
3. Tutti i nodi `createAppointment` / `rescheduleAppointment` usano `chairLabel` dalla variabile invece del valore hardcodato.

#### Fase 4 — `create_tenant`: aggiungi `retell_agents` al provisioning

Nella funzione SQL che genera lo schema per ogni nuovo tenant, aggiungere `CREATE TABLE retell_agents (...)`.

### File coinvolti
- **DB:** nuovo script patch + aggiornamento `install.sql` + `create_tenant` function
- **Backend:** `RetellAgentConfigDto`, `RetellAgentService`, `RetellController`
- **n8n:** aggiunta HTTP node + Set node all'inizio del workflow principale

### Prerequisito operativo
Recuperare l'`agent_id` Retell di Giulia dalla dashboard Retell (Settings → Agent → ID) e usarlo per il seed in Fase 1.

### Note
- Nessuna modifica al contratto API degli appuntamenti (`createAppointment` accetta già `chairLabel`)
- Il flusso n8n rimane unico (parametrico): non servono workflow duplicati per agente
- Per aggiungere un nuovo studio: INSERT in `retell_agents` + nuovo agente Retell con numero dedicato → zero modifiche al codice

---

## 3. Validazione codice fiscale con bypass pazienti stranieri

**Stato:** Proposta
**Data proposta:** 2026-06-25
**Impatto:** Medio (~¾ giornata)

### Problema
Il CF italiano segue un formato preciso (16 caratteri, codifica nome/cognome/data/sesso/comune), ma attualmente:
- Il frontend richiede CF obbligatorio per tutti i pazienti (impossibile registrare stranieri senza CF)
- La validazione è solo `minLength(16)` — nessun controllo algoritmico del formato
- Il backend non valida il formato
- Non esiste un flag "paziente straniero" per distinguere i due casi
- La data di nascita, già raccolta, non viene usata per cross-validare il CF

### Soluzione

#### Regole di validazione

| Caso | CF obbligatorio | Validazione formato | Cross-check con data nascita |
|------|:-:|:-:|:-:|
| Paziente italiano | Sì | Sì | Sì (se coincide, warn; se diverge, errore) |
| Paziente straniero | No | No (accetta qualsiasi stringa ≤ 16 o vuoto) | No |

Il campo "paziente straniero" è una checkbox esplicita in fase di registrazione e modifica.

#### Formato CF valido (regex)
```
^[A-Z]{6}[0-9]{2}[ABCDEHLMPRST][0-9]{2}[A-Z][0-9]{3}[A-Z]$
```
(case-insensitive, applicato dopo `toUpperCase()`)

#### Cross-check CF vs data di nascita
Il CF italiano codifica l'anno (pos 6-7), il mese (pos 8 = lettera A-T), il giorno (pos 9-10; +40 per femmine).
Se entrambi CF e data di nascita sono presenti e il paziente non è straniero:
- anno CF ≠ anno nascita → **errore**
- mese CF ≠ mese nascita → **errore**
- giorno CF ≠ giorno nascita (tenendo conto del +40) → **errore**

#### Fase 1 — DB: colonna `foreign_patient`

```sql
ALTER TABLE patients ADD COLUMN IF NOT EXISTS foreign_patient boolean NOT NULL DEFAULT false;
```

Aggiornare `install.sql` e la funzione `create_tenant`.

#### Fase 2 — Backend

**`CreatePatientRequest` / `UpdatePatientRequest`:** aggiungere `Boolean foreignPatient`.

**Custom validator `@ValidFiscalCode`:**
```java
// Applicato a livello di classe su CreatePatientRequest e UpdatePatientRequest
// Logica:
// 1. Se foreignPatient == true → skip tutto → valid
// 2. Se fiscalCode blank → invalid (obbligatorio per italiani)
// 3. Regex sul formato → invalid se non corrisponde
// 4. Se birthDate non null → cross-check anno/mese/giorno → invalid se diverge
```

**`PatientService`:** salvare `foreign_patient` in INSERT e UPDATE.

**`PatientDetailDto` / `PatientListDto`:** esporre `foreignPatient`.

#### Fase 3 — Frontend

**Nuovo controllo form:** checkbox `pazienteStraniero` (default `false`).

**Comportamento dinamico:**
- Quando `pazienteStraniero = true`:
  - CF diventa opzionale, rimuove i validator `required` e `pattern`
  - Mostra etichetta "Documento identità (opzionale)" accanto al campo CF
- Quando `pazienteStraniero = false`:
  - CF richiesto, validator pattern `^[A-Za-z]{6}[0-9]{2}[A-EHLMPRSTaehlmprst][0-9]{2}[A-Za-z][0-9]{3}[A-Za-z]$`
  - Cross-validator che confronta CF con `dataNascita` → errore contestuale

**Validator Angular personalizzato:**
```typescript
// fiscalCodeValidator: ValidatorFn
// - skip se foreignPatient = true o CF vuoto
// - regex check
// - cross-check con dataNascita se entrambi compilati
```

**Messaggio errori:**
- Formato errato: `"Codice fiscale non valido — controlla il formato"`
- Data non coincide: `"La data nel codice fiscale non corrisponde alla data di nascita"`

**Modifica in:** `nuovo-paziente.component.ts/html` e `paziente-detail.component.ts/html` (modifica paziente esistente).

### File coinvolti
| Layer | File |
|-------|------|
| DB | patch SQL + install.sql + create_tenant |
| Backend | `CreatePatientRequest`, `UpdatePatientRequest`, `PatientDetailDto`, `PatientListDto`, `PatientService`, nuovo `FiscalCodeValidator` |
| Frontend | `nuovo-paziente.component.ts/html`, `paziente-detail.component.ts/html`, nuovo `fiscal-code.validator.ts` in `core/validators/` |

### Note
- Il cross-check usa la data di nascita già obbligatoria nel form → nessun campo aggiuntivo richiesto
- Pazienti stranieri con CF temporaneo italiano (11 cifre) sono trattati come stranieri → checkbox `pazienteStraniero = true`
- Il flag `foreign_patient` in DB è utile per report fiscali e fatturazione (le fatture a stranieri senza CF italiano hanno trattamento diverso)
- La validazione algoritmica del carattere di controllo (Luhn-like) è opzionale — regex + cross-check data coprono il 99% degli errori di battitura; aggiungibile in una seconda iterazione

---

## 4. Documenti paziente: tab CRUD con allegati base64

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #4 resta stabile per i riferimenti.

## 5. Object storage MinIO per documenti grandi (CBCT/DICOM)

**Stato:** Proposta
**Data proposta:** 2026-06-25
**Impatto:** Medio (~1 giornata)
**Prerequisito:** Proposta #4 implementata

### Problema
La proposta #4 salva i file in base64 nel DB PostgreSQL. Funziona per JPEG/PNG/PDF ≤15MB, ma non scala per:
- CBCT / DICOM: 50–500MB per scan
- Studi con molti pazienti: la tabella `patient_documents` diventa enorme e le query rallentano
- Backup DB: dimensioni esplose per colpa dei blob

### Soluzione: MinIO self-hosted (S3-compatibile)

MinIO è un object storage open source che gira come container Docker. API identica ad AWS S3 → il codice è portabile su cloud senza modifiche.

#### Fase 1 — Infrastruttura: aggiungi MinIO a docker-compose

```yaml
minio:
  image: minio/minio:latest
  command: server /data --console-address ":9001"
  restart: unless-stopped
  environment:
    MINIO_ROOT_USER: ${MINIO_USER}
    MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
  volumes:
    - minio_data:/data
  ports:
    - "127.0.0.1:9000:9000"   # API S3 (solo localhost, non esposta)
    - "127.0.0.1:9001:9001"   # Web console admin

volumes:
  minio_data:
```

Credenziali in `.env` (già gitignored). Web console raggiungibile via SSH tunnel.

#### Fase 2 — DB: migrazione `patient_documents`

La tabella acquisisce i campi MinIO; `file_base64` diventa nullable per retrocompatibilità con file già caricati.

```sql
ALTER TABLE patient_documents
    ADD COLUMN IF NOT EXISTS storage_backend text NOT NULL DEFAULT 'db',   -- 'db' | 'minio'
    ADD COLUMN IF NOT EXISTS bucket_name     text,
    ADD COLUMN IF NOT EXISTS object_key      text;                          -- 'patients/{patientId}/{docId}/{fileName}'

-- file_base64 rimane nullable: NULL per i nuovi file su MinIO, valorizzato per i vecchi in DB
```

Regola: `storage_backend = 'db'` → leggi `file_base64`; `storage_backend = 'minio'` → scarica da MinIO via `object_key`.

#### Fase 3 — Backend: dipendenza AWS SDK + MinioStorageService

**`pom.xml`:**
```xml
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>s3</artifactId>
    <version>2.25.x</version>
</dependency>
```

**`MinioStorageService`:**
```java
@Service
public class MinioStorageService {

    private final S3Client s3;

    @Value("${app.minio.bucket:dentalcare-docs}")
    private String bucket;

    // Upload: restituisce object key
    public String upload(String objectKey, byte[] data, String mimeType) { ... }

    // Download: restituisce byte[]
    public byte[] download(String objectKey) { ... }

    // Delete
    public void delete(String objectKey) { ... }
}
```

**`application.properties` (config/):**
```properties
app.minio.endpoint=http://minio:9000
app.minio.access-key=${MINIO_USER}
app.minio.secret-key=${MINIO_PASSWORD}
app.minio.bucket=dentalcare-docs
```

**`PatientDocumentService`:** logica biforcata in base a `storage_backend`:
- Upload nuovo → sempre MinIO → `storage_backend='minio'`, `file_base64=null`
- Download → se `'minio'` chiama `MinioStorageService.download()`; se `'db'` usa `file_base64` esistente
- Delete → se `'minio'` elimina anche l'oggetto da MinIO

**Endpoint invariato** — il frontend non sa dove è salvato il file.

#### Fase 4 — Migrazione file esistenti (opzionale)

Script one-shot che:
1. Legge tutte le righe con `storage_backend = 'db'` e `file_base64 NOT NULL`
2. Carica il file su MinIO
3. Aggiorna la riga: `storage_backend='minio'`, `object_key=...`, `file_base64=NULL`

Da eseguire in manutenzione fuori orario.

#### Fase 5 — Frontend

Nessuna modifica — il backend gestisce la trasparenza dello storage.

### File coinvolti
| Layer | File |
|-------|------|
| Infrastruttura | `docker-compose.yml`, `.env` |
| DB | patch SQL ALTER TABLE |
| Backend | `pom.xml`, `MinioStorageService`, `PatientDocumentService` (modifica logica), `application.properties` (config/) |
| Frontend | Nessuna modifica |

### Note
- MinIO esposto solo su `127.0.0.1` — non raggiungibile dall'esterno senza SSH tunnel o proxy
- Object key pattern: `patients/{clinicId}/{patientId}/{docId}/{fileName}` — isolamento per tenant nel bucket
- Il bucket va creato al primo avvio (o via `mc` CLI: `mc mb minio/dentalcare-docs`)
- Backup MinIO: `mc mirror minio/dentalcare-docs /backup/minio/` — separato dal backup DB
- CBCT/DICOM (`.dcm`): aggiungere `application/dicom` ai MIME accettati; viewer DICOM in-browser (es. Cornerstone.js) fuori scope per ora

---

## 6. AI YOLO: rilevamento carie su ortopanoramica + retraining

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #6 resta stabile per i riferimenti.

## 7. GDPR: cifratura campo-per-campo con chiavi per tenant (HKDF + AES-256-GCM)

**Stato:** Slice 1 + Slice 2a **Fatta** (LIVE in prod) · Slice 2b **Proposta**
**Data proposta:** 2026-06-25
**Impatto:** Alto (~2 giorni)

### Stato per slice

Realizzato per **slice** incrementali (dual-write → migrate → cutover per campo).

| Slice | Campi | Stato | Riferimenti |
|-------|-------|-------|-------------|
| **1** | `patients.birth_date` → `birth_date_enc` (età in Java, TZ Europe/Rome) | **Fatta — LIVE prod** (migrata 2026-07-15) | runbook `deploy-gdpr-slice1-prod.md` |
| **2a** | `patients.fiscal_code` → `fiscal_code_enc` + `fiscal_code_idx` (blind index) + snapshot `invoices.patient_fiscal_code_enc` | **Fatta — LIVE prod** (migrata 2026-07-15) | spec/plan `docs/superpowers/{specs,plans}/2026-07-08-gdpr-slice2a-fiscalcode*` |
| **2b** | `patients.phone` / `email` / `address` → `_enc` (+ `_idx` per phone/email, normalizzazione dedicata: phone solo cifre, email lowercase) | **Proposta** | vedi §Slice 2b sotto |

**Infrastruttura comune (Fatta):** `TenantEncryptionService` (HKDF-SHA256 → AES-256-GCM + blind index HMAC), `MasterKeyProvider` (seam Vault, `ConfigMasterKeyProvider` fail-fast), endpoint idempotente `POST /api/admin/encryption/migrate` (tenant-scoped), colonne plaintext mantenute (DROP rimandato).

**Fuori scope attuale / decisione aperta:** cifratura `first_name`/`last_name` (rompe ricerca parziale → resta in chiaro, misure compensative) e `TDE`/disk-encryption per il dato a riposo su disco/backup. Motivazioni complete in doc repo `DentalCare-Documentation` → `04-Architecture-Handbook/11-Data-Encryption.md`.

> Nota: la spec originale (#7 sotto) elencava anche `anamnesis`/`clinical_records`/`prescriptions`/`appointments.notes`. Non ancora affrontati — da valutare in uno slice successivo (2c) se richiesto.

### Slice 2b — contatti paziente (phone / email / address)

**Stato:** Proposta · **Impatto:** ~½-¾ giornata (infra già pronta, solo nuovi campi)

Applica il pattern consolidato di Slice 2a ai contatti:
- `patients.phone` → `phone_enc` + `phone_idx` (blind index su **sole cifre**: `replaceAll("\\D","")`).
- `patients.email` → `email_enc` + `email_idx` (blind index su **lowercase** `trim().toLowerCase`).
- `patients.address` (line1) → `address_enc` (no blind index: nessuna ricerca esatta su indirizzo).

Passi: patchSchema colonne PRIMA delle viste (regola ordering nota) → dual-write in `PatientService` create/update → `migrateContacts()` in `EncryptionMigrationService` (endpoint `/migrate` ritorna anche `contacts:N`) → cutover read decrypt in mapRow + ricerca via `_idx`. Viste `v_patient_*` espongono `_enc`/`_idx`. Aggiornare `install.sql` (2 copie) + `TenantExportService` (CSV) + test.

**Caveat:** verificare ogni punto UI/export/n8n che filtra o mostra phone/email (ricerca per telefono in rubrica, notifiche email) — passare da match plaintext a blind index esatto.

### Problema
I dati sanitari e anagrafici dei pazienti (codice fiscale, data di nascita, note cliniche, anamnesi, ecc.) sono salvati in chiaro nel DB. In caso di breach del database, tutti i dati sono leggibili. Il GDPR art. 32 richiede misure tecniche adeguate — la cifratura campo-per-campo con chiavi per-tenant è la soluzione più robusta.

### Principio architetturale: nessuna tabella di chiavi

Le chiavi tenant **non si salvano nel DB** — si derivano deterministicamente dalla master key + schema tenant tramite **HKDF** (HMAC-based Key Derivation Function, RFC 5869):

```
tenant_enc_key  = HKDF(master_key, salt=tenant_schema, info="dental-enc-v1",  length=32)
tenant_idx_key  = HKDF(master_key, salt=tenant_schema, info="dental-idx-v1",  length=32)
```

- `master_key`: 32 byte casuali, vive **solo** nell'env var `APP_MASTER_KEY` (mai in DB, mai nel codice)
- Schema diverso (`t_9d754153` vs `t_abc12345`) → chiave AES diversa → isolamento matematicamente garantito
- Nessuna tabella `tenant_keys` da proteggere
- Rotazione master key: re-encrypt batch → nuova chiave derivata per tutti i tenant
- Revoca tenant singolo: re-encrypt schema specifico con nuova salt → dati precedenti illeggibili

### Campi da cifrare

| Tabella | Campo | Cifrato | Blind index (ricercabile) |
|---------|-------|:-------:|:------------------------:|
| patients | fiscal_code | ✅ | ✅ (match esatto) |
| patients | birth_date | ✅ | ❌ |
| patients | phone | ✅ | ✅ (match esatto) |
| patients | email | ✅ | ✅ (match esatto) |
| patients | address_line1 | ✅ | ❌ |
| anamnesis | content/notes | ✅ | ❌ |
| clinical_records | notes | ✅ | ❌ |
| prescriptions | content | ✅ | ❌ |
| patients | first_name, last_name | ❌ | — (troppo costoso cifrare + ricerca full-text) |
| appointments | notes | ✅ | ❌ |

`first_name` e `last_name` non vengono cifrati: sono necessari per la ricerca full-text e la UX; la loro pseudonimizzazione richiederebbe un motore di ricerca separato (fuori scope).

### Blind Index per campi ricercabili

Problema: cifrando `fiscal_code` non si può più fare `WHERE fiscal_code = ?`.

Soluzione — doppia colonna:
```sql
-- Esempio su patients
ALTER TABLE patients
  ADD COLUMN fiscal_code_enc  text,   -- AES-256-GCM(plaintext, enc_key) → Base64
  ADD COLUMN fiscal_code_idx  text;   -- HMAC-SHA256(lower(plaintext), idx_key) → hex

-- La colonna fiscal_code originale diventa NULL dopo migrazione, poi si elimina
```

Ricerca:
```sql
-- Invece di: WHERE fiscal_code = :input
-- Si usa:    WHERE fiscal_code_idx = :idx
-- Dove :idx = HMAC-SHA256(lower(input), tenant_idx_key)
```

### Fase 1 — Backend: TenantEncryptionService

```java
@Service
public class TenantEncryptionService {

    private final byte[] masterKey; // @Value("${app.encryption.master-key}")

    private final Map<String, SecretKey> encKeyCache = new ConcurrentHashMap<>();
    private final Map<String, SecretKey> idxKeyCache = new ConcurrentHashMap<>();

    public String encrypt(String plaintext, String tenantSchema) {
        if (plaintext == null) return null;
        SecretKey key = encKey(tenantSchema);
        byte[] iv = randomIv();                             // 12 byte GCM
        byte[] cipher = aesGcmEncrypt(plaintext.getBytes(UTF_8), key, iv);
        return Base64.encode(concat(iv, cipher));           // iv(12) || ciphertext || tag(16)
    }

    public String decrypt(String ciphertext, String tenantSchema) {
        if (ciphertext == null) return null;
        byte[] raw = Base64.decode(ciphertext);
        byte[] iv = Arrays.copyOf(raw, 12);
        byte[] cipher = Arrays.copyOfRange(raw, 12, raw.length);
        return new String(aesGcmDecrypt(cipher, encKey(tenantSchema), iv), UTF_8);
    }

    public String blindIndex(String plaintext, String tenantSchema) {
        if (plaintext == null) return null;
        return hmacSha256Hex(plaintext.toLowerCase(Locale.ROOT), idxKey(tenantSchema));
    }

    private SecretKey encKey(String schema) {
        return encKeyCache.computeIfAbsent(schema,
            s -> hkdfDerive(masterKey, s, "dental-enc-v1"));
    }

    private SecretKey idxKey(String schema) {
        return idxKeyCache.computeIfAbsent(schema,
            s -> hkdfDerive(masterKey, s, "dental-idx-v1"));
    }
}
```

**Dipendenze `pom.xml`:** solo `javax.crypto` standard JDK (AES-GCM e HMAC-SHA256 sono già built-in) + `org.bouncycastle:bcprov-jdk18on` per HKDF.

### Fase 2 — DB: aggiunta colonne `_enc` e `_idx`

```sql
-- patients
ALTER TABLE patients
  ADD COLUMN fiscal_code_enc text,
  ADD COLUMN fiscal_code_idx text,
  ADD COLUMN birth_date_enc  text,
  ADD COLUMN phone_enc       text,
  ADD COLUMN phone_idx       text,
  ADD COLUMN email_enc       text,
  ADD COLUMN email_idx       text,
  ADD COLUMN address_enc     text;

-- anamnesis (content già esistente)
ALTER TABLE anamnesis ADD COLUMN content_enc text;

-- appointments
ALTER TABLE appointments ADD COLUMN notes_enc text;

-- (altre tabelle con note cliniche: stesso pattern)
```

Le colonne originali restano temporaneamente per retrocompatibilità durante la migrazione; vengono eliminate dopo.

### Fase 3 — Migrazione dati esistenti

Script Java (o SQL con pgcrypto come supporto) che:
1. Legge tutte le righe in chiaro
2. Cifra con `TenantEncryptionService`
3. Scrive nelle colonne `_enc` / `_idx`
4. Setta le colonne originali a `NULL`

Da eseguire in manutenzione (pochi minuti per studi con <10.000 pazienti).

Dopo migrazione: `DROP COLUMN fiscal_code`, rinomina `fiscal_code_enc → fiscal_code` (opzionale — o mantieni il suffisso per chiarezza).

### Fase 4 — Aggiornamento service layer

Ogni service che legge/scrive campi sensibili:

```java
// PatientService.create
params.addValue("fiscalCode", enc.encrypt(req.fiscalCode(), schema));
params.addValue("fiscalCodeIdx", enc.blindIndex(req.fiscalCode(), schema));

// PatientService.findAll (ricerca)
String idx = enc.blindIndex(searchQuery, schema);
"WHERE fiscal_code_idx = :idx OR ..."

// PatientService mapRow → decrypt
new PatientDto(..., enc.decrypt(rs.getString("fiscal_code"), schema), ...)
```

### Fase 5 — Configurazione

**`config/application.properties` (gitignored, mai in repo):**
```properties
app.encryption.master-key=<64-char-hex-random-generated-once>
```

Generazione master key (una tantum):
```bash
openssl rand -hex 32
```

**Rotazione master key (procedura):**
1. Genera nuova master key
2. Esegui script di re-encryption: leggi con vecchia chiave, riscrivi con nuova
3. Sostituisci master key in env
4. Riavvia container

### File coinvolti
| Layer | File |
|-------|------|
| DB | patch SQL (ALTER TABLE + indici su `_idx`) + aggiornamento install.sql + script migrazione |
| Backend | nuovo `TenantEncryptionService`, modifica `PatientService`, `AnamnesisService`, `AppointmentService`, `PrescrizioneService`, `ClinicalRecordService` |
| Config | `config/application.properties` (aggiunta `app.encryption.master-key`) |
| Frontend | Nessuna modifica — la cifratura è trasparente |

### Note
- AES-256-GCM con IV casuale per ogni encrypt → stessa stringa → ciphertext diverso ogni volta (non deterministico) — il blind index risolve la ricercabilità
- Le chiavi derivate sono cachate in memoria per performance — invalidare la cache a rotazione
- Il campo `first_name` / `last_name` non viene cifrato per non rompere la ricerca anagrafica: se richiesto in futuro, serve un motore di ricerca tokenizzato separato (es. pg_trgm cifrato o ElasticSearch)
- I file in MinIO (ortopanoramine, PDF) sono cifrati separatamente con **MinIO Server-Side Encryption** (SSE-S3 o SSE-C) — zero modifiche al codice applicativo
- Audit log: ogni accesso a dato cifrato loggato con `actor_id` + `resource` (senza loggare il plaintext)

---

## 18. Cartella clinica — GAP P0: valore probatorio (audit, finalizzazione, consensi, encounter)

**Stato:** Proposta
**Data proposta:** 2026-07-16
**Impatto:** Alto (~66-90h agente, 3 blocchi)
**Livello:** **GAP P0** = requisiti §25.1 della guida (bloccanti). GAP P1 → [#21](#21-cartella-clinica--gap-p1-firma-conservazione-terminologia-fhir-portale) · GAP P2 → [#22](#22-cartella-clinica--gap-p2-ai-certificata-secondary-use-ehds-federazione-mobile-offline)
**Piano ordinato:** [Piano di intervento — cartella clinica](#piano-di-intervento--cartella-clinica-gap-p0--gap-p1), Blocchi 1-3
**Rilascio:** **Fase 1** — tutti e 3 i blocchi prima del primo paziente reale (`piano-lungo-termine.md` §5)

Gap analysis completa in **`directives/gap-analysis-cartella-clinica.md`** (verificata su codice + DB reale, non su doc).

**Sintesi:** dei 15 requisiti GAP P0 della guida, 4 coperti, 6 parziali, **5 assenti**. Il nucleo dati è buono; manca il livello "prova".

**I 3 gap critici:**
1. **Nessuna finalizzazione/immutabilità** delle note (`clinical_history_entries` senza `status`/`version`/`hash`/addendum → UPDATE silenzioso per sempre).
2. **Nessun audit trail clinico** (solo `ai_audit_log` per le tool call; nessun log di lettura/download/stampa).
3. **Nessuna gestione consensi** (solo un `document_type`, niente template versionato/firma/revoca).

Più: encounter assente, merge duplicati assente, odontogramma senza storicità (`tooth_conditions` è snapshot), anamnesi senza tri-stato, documenti senza `sha256`/malware scan, cancellazione fisica invece di soft delete, MFA assente, admin tecnico che legge i contenuti clinici.

**Da verificare subito:** la segreteria non deve vedere anamnesi/diagnosi/odontogramma/note — il filtro va confermato **server-side** (criterio §26.2 della guida).

**Da decidere:** il gate di go-live non copre l'`admin` tecnico (§28.18, marcato ❌ presente) — vedi il riquadro nel Blocco 3 del piano.

### Rapporto con le altre proposte

| | |
|---|---|
| **#19** (AI Act) | Complementare, non sovrapposta: #19 mette in sicurezza il **perimetro AI**, #18 il **valore probatorio della cartella**. Entrambe alimentano lo stesso gate di go-live. L'audit di #18 è il logging AI esteso che #19 chiede a 60gg → **farlo una volta sola**. |
| **#20** (fallback `confirmAction`) | Le scritture cliniche del Copilot (`previewAddDiagnosis`, `previewAddPrescription`, `previewAddDiaryNote`) finiscono in cartella. Quando esiste la finalizzazione (2), una scrittura AI confermata alla cieca diventa una **nota firmata**. Fixare #20 **prima** dell'intervento 2. |
| **#7** (cifratura) | Indipendente. La cifratura protegge il dato **a riposo**; #18 ne protegge il **valore probatorio**. Nessuna delle due sostituisce l'altra. |

---

## 19. Conformità EU AI Act (perimetro non-MDR)

**Stato:** Proposta
**Data proposta:** 2026-07-16
**Impatto:** Medio-alto (~2-3 settimane per il P0)
**Scadenza esterna:** **2 agosto 2026** (trasparenza art. 50 + grosso dell'AI Act)

Roadmap completa in **`directives/roadmap_certificazione.md`**.

**Decisione di perimetro:** niente percorso MDR/CE. **Conseguenza:** il modulo radiologico (ONNX FDI+disease) è probabile MDSW classe IIa → senza CE **non può essere usato su pazienti reali**. La conformità si ottiene **estraendolo dall'uso clinico**, non documentandolo.

**Già a favore (verificato):** versione modello tracciata (`patient_document_analyses.model_fdi/model_disease`), revisione umana persistita (`review_status`, `reviewed_by`), output AI distinto dal manuale (`tooth_conditions.source` + `analysis_id`), segregazione tenant + cifratura. La catena `analysis → review → tooth_condition.source` è già l'ossatura giusta.

**P0 entro il 2 ago 2026:** gate no-clinical (feature flag radiologia, default OFF in prod) · disclosure Giulia + fallback umano · limiti operativi Giulia (no triage/diagnosi) · Registro AI · AI Use Policy · AI literacy (**già scaduta dal 2 feb 2025**) · informativa paziente AI (L. 132/2025) · registro claim · avvio DPIA · incident intake · kill switch.

**Poi:** 30gg governance/RACI/classificazione · 60gg DPIA chiusa + DPA/SCC/TIA fornitori (Retell, OpenAI) + SOP no-retraining + logging AI esteso · 90gg MFA, pen test, audit interno.

**Rischio residuo accettato:** il modulo radiologico resta non commercializzabile clinicamente. Diventa **non conformità grave** se usato/presentato con finalità mediche senza CE. **Il gate tecnico è il controllo che regge tutta la posizione.**

---

## 20. Copilot: il fallback di `confirmAction` conferma tutte le anteprime invece dell'ultima

**Stato:** Proposta
**Data proposta:** 2026-07-16
**Impatto:** Basso (~1-2 ore) — ma tocca la supervisione umana, quindi rilevante per [#19](#19-conformità-eu-ai-act-perimetro-non-mdr)
**Origine:** analisi del grafo graphify su `DentalCareAiTools` (nodo a betweenness più alta del progetto: 68 archi, 17 service iniettati)

### Contesto — cosa funziona già (non toccare)

Il gate di conferma delle scritture del Copilot è **solido e strutturale**, non prompt-based. Verificato sul codice:

- **Zero scritture dirette**: tutti i 19 punti di mutazione in `DentalCareAiTools` (1029 righe, 35 `@Tool`) stanno dentro una lambda passata a `pendingActions.register(...)`, seguita da `return "ANTEPRIMA — nessuna modifica salvata."` + codice a 4 cifre. I nomi ingannano: `createAppointment` **non crea**, registra soltanto. L'unico tool che scrive è `confirmAction`.
- **La closure blinda il payload**: la request è catturata server-side; il modello trasporta solo 4 cifre. L'azione confermata è **identica per costruzione** a quella mostrata in anteprima — l'LLM non può alterarla né allucinare parametri fra i turni.
- **Il controllo di scope regge**: `PendingActionService.consume(code)` non verifica lo scope, ma `DentalCareAiTools.execute()` (L404-412) sì — mismatch → azione rifiutata, `log.warn` + riga di audit. Vale anche cross-tenant (provider UUID diverso).
- TTL 600s, `purge()` a ogni accesso, `SecureRandom`, codici univoci globali.

Questo soddisfa §19.3 e §16.3 del piano AI Act ed è **evidenza difendibile**: non va rifatto.

### Problema

Divergenza fra javadoc e codice in `PendingActionService.consumeAllForScope()` (L61-76):

```java
/** Rimuove e ritorna tutte le azioni in sospeso per lo scope indicato, più recenti prima.
 *  Serve a confermare l'ULTIMA anteprima quando il modello non riporta il codice tra i turni. */
public List<Pending> consumeAllForScope(UUID scope)   // ← ritorna TUTTE, non l'ultima
```

Il commento dichiara *l'ultima*; il metodo ordina per recenza e poi le restituisce **tutte**. `DentalCareAiTools.confirmAction()` (L393-396) le esegue in ciclo quando il modello non riporta il codice — cosa che **succede regolarmente**, come ammette il commento stesso nel codice.

**Non è un problema di sicurezza** (lo scope regge: sono comunque solo le pending dell'utente). È un problema di **qualità del consenso**:

- entro la finestra TTL di 10 minuti un `confirmAction("ok")` generico esegue **tutte** le anteprime accumulate;
- l'audit registra il `summary` di ciascuna → *cosa* è stato fatto è tracciato, ma non c'è prova che l'utente abbia rivisto **ogni singola** proposta;
- lo scope è il **provider**, non la sessione di chat: due conversazioni parallele dello stesso medico condividono il pool di pending;
- coinvolge anche i tool clinici (`previewAddDiagnosis`, `previewAddPrescription`, `previewAddDiaryNote`) → scritture in cartella clinica.

Rispetto al piano AI Act tocca **§16.2** ("nessuna conferma pre-selezionata"), non §33.8 (non ci sono azioni autonome). Severità: **media**.

### Soluzione proposta

Allineare il codice al javadoc: quando manca il codice, confermare **solo la più recente**, lasciando le altre in attesa.

```java
// PendingActionService — nuovo metodo accanto a consumeAllForScope (o sostituirlo)
/** Rimuove e ritorna la SOLA anteprima più recente per lo scope indicato. */
public Optional<Pending> consumeLatestForScope(UUID scope) {
    purge();
    return store.entrySet().stream()
            .filter(e -> Objects.equals(e.getValue().providerScope(), scope))
            .max(Comparator.comparing(e -> e.getValue().expiresAt()))
            .filter(e -> store.remove(e.getKey()) != null)
            .map(Map.Entry::getValue);
}
```

In `confirmAction`, il ramo di fallback usa `consumeLatestForScope(...)` e, se restano altre pending, lo dice all'utente (es. *"Confermata l'ultima anteprima. Ne restano N in attesa: richiedile per codice."*).

**Alternativa scartata:** eliminare del tutto il fallback → l'UX si rompe (il modello perde il codice fra i turni, vedi memoria `chat_reschedule_confirm`), l'utente resta bloccato.

### File coinvolti
| Layer | File |
|---|---|
| Backend | `PendingActionService.java` (nuovo `consumeLatestForScope`), `DentalCareAiTools.java` (ramo fallback in `confirmAction`, L393-396) |
| Test | test su: fallback con 1 pending → esegue; con N pending → esegue solo la più recente e le altre restano; scope mismatch → rifiuto + audit |

### Note
- `store` è in-memory (`ConcurrentHashMap`): pending perse al restart e **non funziona multi-istanza**. Prod = container singolo → ok oggi; stesso limite del registry SSE (#1). Da rivedere se si scala.
- Il `summary` finisce in audit sia in caso di successo sia di scope mismatch: buona base per il logging AI esteso richiesto da #19.

---

## 21. Cartella clinica — GAP P1: firma, conservazione, terminologia, FHIR, portale, FSE

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Alto (~multi-mese) — **dopo** il go-live di Fase 1
**Livello:** **GAP P1** = requisiti §25.2 della guida (crescita, non blocco). GAP P0 → [#18](#18-cartella-clinica--gap-p0-valore-probatorio-audit-finalizzazione-consensi-encounter) · GAP P2 → [#22](#22-cartella-clinica--gap-p2-ai-certificata-secondary-use-ehds-federazione-mobile-offline)
**Piano ordinato:** [Piano di intervento — cartella clinica](#piano-di-intervento--cartella-clinica-gap-p0--gap-p1), Blocco 4 (interventi 15-24)

### Decisione di perimetro

`piano-lungo-termine.md` §4 esclude i GAP P1 dalla Fase 1: *"servono per crescere, non per il primo studio"*. Questa proposta li **registra e ordina** senza pianificarli: si aprono dopo il go-live, per pressione di mercato o di gara.

**Eccezione:** il **report accessi** è un GAP P1 che entra comunque in Fase 1, perché è chiuso dall'export art. 15 (intervento 10 di #18). Non è una scelta strategica: è un effetto collaterale della dipendenza dall'audit.

### Stato dei 10 requisiti §25.2

| Requisito | Stato | Dove sta oggi | Nota |
|---|:-:|---|---|
| **Report accessi** | ❌ | — | **→ chiuso in Fase 1** dall'intervento 10 di #18: dipende dall'audit e serve al diritto del paziente (§10.3) |
| **Analytics qualità** | 🟡 | nessun KPI §23 implementato | Il più economico: diventa misurabile **da solo** dopo audit + consensi + merge. Frutto già maturo |
| **Firma avanzata/qualificata (PAdES)** | ❌ | — | Oggi manca perfino la **finalizzazione clinica** = livello 2 di §9.2. PAdES è il livello 3: senza il 2 non c'è nulla da firmare |
| **Conservazione a norma** | ❌ | MinIO + `pg_dump` | **Backup ≠ conservazione** (§9.3, errore §28.7). Nessun massimario né politica di retention approvata. Distinzione non negoziabile |
| **Terminology service** | ❌ | `service_code` / `condition` = stringhe libere, senza code system né versione | §14.3, §22.2. **Gate tecnico di FHIR e FSE**: senza codifica governata c'è export, non scambio |
| **FHIR API** | ❌ | — | Il modello interno **è già compatibile come base**: §14.1 (strategia duale) è stata applicata correttamente per caso o per scelta. Serve un **adapter**, non un rimodellamento |
| **DICOMweb** | ❌ | solo PNG/JPEG | Già tracciato come **#8**. Indipendente da tutto il resto |
| **Portale paziente** | ❌ | — | Espone ciò che audit + consensi + export rendono esponibile. Prima di quelli non ha contenuto |
| **Connettore FSE 2.0** | ❌ | — | CDA2 + PAdES + conservazione + accreditamento regionale: **ogni sua dipendenza è un altro GAP P1**. Ultimo per costruzione |
| **Moduli parodontali avanzati** | ❌ | — | Nessun charting parodontale (sondaggio, recessioni, mobilità, placca/sanguinamento) — §5.4 |

Assente anche l'**esame obiettivo strutturato** (extraorale, mucose, ATM, occlusione, stato endodontico): oggi confluisce in `clinical_notes` testo libero. Non è nell'elenco §25.2 ma sta allo stesso livello.

### Le due catene di dipendenza

Tutto il GAP P1 si riduce a due catene. Fuori da queste, solo voci indipendenti (analytics, DICOMweb, parodontale).

```text
catena "prova → conservazione"
  finalizzazione (#18 int. 2)  →  politica firma+conservazione (16)  →  PAdES (17)  →  conservazione a norma (20)  ─┐
                                                                                                                     │
catena "semantica → scambio"                                                                                         ├─→  FSE 2.0 (24)
  terminology service (18)  →  FHIR API (21)  ────────────────────────────────────────────────────────────────────┘
        encounter (#18 int. 5) ┘        └ consensi (#18 int. 6)
```

**Lettura:** il FSE non è un progetto — è il **punto di arrivo di due catene** che partono entrambe dentro la Fase 1. Chi promette il FSE senza aver fatto finalizzazione, terminologia ed encounter sta promettendo la punta di un iceberg.

### Candidati ad anticipazione (se il mercato lo chiede)

Due voci si possono spostare in Fase 1 senza rompere il gate:

| Voce | Perché anticipabile | Costo dell'anticipo |
|---|---|---|
| **Esame obiettivo + charting parodontale** (19) | È **l'unico GAP P1 che un odontoiatra nota come funzione mancante**. Gli altri sono invisibili all'utente finale | M agente, dipende solo dall'encounter |
| **Politica conservazione + firma** (16) | È lavoro **DPO/legale, non codice** → gira in parallelo, non consuma sprint. E il DPO è già ingaggiato per la DPIA | ~zero marginale se fatto insieme alla DPIA |

La 16 è il vero affare: **costa poco farla mentre il DPO è già al lavoro, costa un progetto a sé farla dopo.** Stessa logica della data governance del dataset in #22.

### Note

- Le taglie di effort nel piano (S/M/L) **non sono derivate da un'analisi di dettaglio**: sono indicative. Per 16, 20 e 24 l'effort agente è irrilevante — il costo è tempo di terzi.
- Nessun intervento di questa proposta va aperto prima che il gate di go-live sia verde: sarebbe costruire il piano alto di una casa senza il livello della prova sotto (§34 della guida).

---

## 22. Cartella clinica — GAP P2: AI certificata, secondary use, EHDS, federazione, mobile offline

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Alto (Fase 2 / non pianificato)
**Livello:** **GAP P2** = requisiti §25.3 della guida (orizzonte lungo). GAP P0 → [#18](#18-cartella-clinica--gap-p0-valore-probatorio-audit-finalizzazione-consensi-encounter) · GAP P1 → [#21](#21-cartella-clinica--gap-p1-firma-conservazione-terminologia-fhir-portale)
**Fuori dal piano di intervento** (che si ferma a GAP P1). Riferimento: `piano-lungo-termine.md` §6.

### Stato dei 7 requisiti §25.3

| Requisito | Stato | Dove sta | Azione |
|---|:-:|---|---|
| **AI radiologica certificata** | ❌ | il modulo **esiste e funziona** (ONNX FDI+disease), ma non è certificato | **Fase 2** → `piano-lungo-termine.md` §6 · perimetro attuale → **#19**. CE realistica: **2029** |
| **Ricerca e secondary use** | ❌ | nessuna base giuridica né de-identificazione | ⚠️ **unica voce P2 con un'azione obbligatoria in Fase 1** — vedi sotto |
| **Dettatura e summarization controllata** | ❌ | parzialmente coperto da **#15** (Copilot multimodale) | ⚠️ **verificare il perimetro AI Act prima di costruirla** — vedi sotto |
| **EHDS readiness** | ❌ | — | Dopo FHIR (#21 int. 21). Non ha senso prima |
| **Federazione tra reti** | ❌ | — | Nessuna proposta. Presuppone FHIR + terminologia + identità federata |
| **Integrazione laboratori e dispositivi** | ❌ | — | Nessuna proposta |
| **Mobile offline** | ❌ | — | ⚠️ **conflitto architetturale** — vedi sotto |

### ⚠️ La trappola: il dataset non è retro-adattabile

`piano-lungo-termine.md` §6.3, ripetuto qui perché è **l'unico punto in cui un GAP P2 impone un'azione in Fase 1**:

> La validazione clinica di Fase 2 richiede dati annotati con **provenienza, licenza e base giuridica** tracciate. Le label già raccolte in `patient_document_labels` durante le demo **non sono utilizzabili**: non hanno base giuridica per il training, e la pseudonimizzazione non le rende anonime. **Non si retro-adatta una base giuridica a dati già raccolti.**

Quindi la decisione **"Fase 2 sì o no"** va presa **in Fase 1**, non nel 2028:

| Decisione | Conseguenza operativa in Fase 1 |
|---|---|
| **Fase 2 = sì** | Con il DPO già ingaggiato: base giuridica sviluppo/ricerca separata dall'assistenziale · informativa che la copra · SOP di annotazione (qualifiche, doppia lettura, adjudication, inter-rater) · dataset card + provenance · separazione ambienti clinico/ricerca. **Costa poco ora, costa un anno nel 2028.** |
| **Fase 2 = no** | **Smettere di raccogliere label** e togliere il modulo radiologico dal prodotto: mantenerlo funzionante ha un costo di manutenzione che non ripaga un asset invendibile. |

Non decidere **è** decidere: si continuano a raccogliere label inutilizzabili pagandone la manutenzione.

### ⚠️ Dettatura e summarization: sposta il perimetro AI Act

Questa voce **non è una feature come le altre**. #19 tiene DentalCare fuori dal perimetro high-risk sulla base che Copilot e Giulia siano AI **amministrative**. Una summarization che produce **contenuto clinico** (sintesi anamnestica, riassunto di visita che finisce in cartella) è candidata a spostare la classificazione — potenzialmente MDSW, come il modulo radiologico.

**Regola:** prima di costruirla, passare da #19 e `roadmap_certificazione.md` per riclassificare. Non è un problema di prompt: è un problema di **destinazione d'uso dichiarata**. Vale anche per la parte multimodale di **#15**.

### ⚠️ Mobile offline: conflitto con il valore probatorio

L'offline è in tensione diretta con ciò che #18 costruisce:

- **audit append-only** vs. eventi generati offline e sincronizzati dopo (l'ordine e il timestamp reali non sono più garantiti dal server);
- **finalizzazione + hash** vs. note finalizzate su un dispositivo e sincronizzate in ritardo (quale versione è clinicamente valida durante la finestra di divergenza?);
- **encounter** vs. episodi aperti da due dispositivi.

Non è irrisolvibile, ma **si progetta insieme a #18, non sopra #18 a cose fatte**. Se l'offline è nel futuro del prodotto, dirlo prima dell'intervento 1 — non dopo.

### Note

- Nessuna stima di effort: a questo livello sarebbero numeri inventati. Il costo dominante è **organismo notificato + validazione clinica** (AI certificata) o **accreditamento** (EHDS/federazione), non lo sviluppo.
- Trigger di apertura della Fase 2 (basta uno): N studi paganti chiedono l'AI radiologica come funzione clinica · una gara la richiede · un investitore la finanzia. Fino ad allora il modulo resta un **asset dimostrativo**: utile in demo, spento in clinica.

---

## 8. AI Service: supporto nativo DICOM (formato sorgente radiografico)

**Stato:** Proposta
**Data proposta:** 2026-07-01
**Impatto:** Medio (~1 giorno)
**Prerequisito:** Proposta #6 (AI service) — Fatta

### Obiettivo
Il servizio `dentalcare-ai-service` usa come formato sorgente **nativo il DICOM** (Digital Imaging and Communications in Medicine), mantenendo PNG/JPEG solo per debug, sviluppo e retrocompatibilità. L'intera pipeline AI lavora sul dato radiografico originale.

### Motivazioni
Le ortopanoramiche prodotte dai dispositivi radiografici sono archiviate come DICOM. Usare il file originale permette di:
- preservare la qualità radiografica originale (12/16 bit)
- evitare perdita di informazioni dovuta alla conversione JPEG
- mantenere i metadati clinici
- consentire futura integrazione con PACS
- essere conformi allo standard medicale internazionale (predisposizione MDR)

### Architettura aggiornata
```
DentalCare → Upload DICOM → MinIO → AI Service → Download DICOM
  → DICOM Parser → Anonymization (RAM) → Image Normalization → Preprocessing
  → YOLO FDI → YOLO Disease → Matching → JSON risultato → DentalCare
```

### Formati supportati
- **Input priorità:** `.dcm` (formato ufficiale)
- **Compatibilità (fallback):** `.png` `.jpg` `.jpeg` (solo debug/dev)

Il servizio determina automaticamente il tipo di file dall'estensione dell'`image_object_key`.

### Nuovo modulo — `app/inference/dicom.py`
Responsabilità: caricamento DICOM, anonimizzazione, estrazione pixel array, normalizzazione, windowing, conversione in `ndarray`.

```python
class DicomLoader:
    def load(self, path: str) -> np.ndarray: ...      # dcm -> ndarray uint8 RGB pronto per YOLO
    def anonymize(self, dataset) -> None: ...          # in RAM, non tocca il file originale
    def normalize(self, image: np.ndarray) -> np.ndarray: ...
    def to_uint8(self, image: np.ndarray) -> np.ndarray: ...
```

**Librerie da aggiungere** (`requirements.txt`): `pydicom`, `highdicom`, (già presenti `numpy`, `opencv-python-headless`).

### Pipeline aggiornata (`job_service.run_job`)
```
Download MinIO → verifica estensione
  ├─ .dcm  → DicomLoader.load() → pixel_array → normalize() → resize() → YOLO
  └─ png/jpg (se ENABLE_PNG_FALLBACK) → cv2.imread → YOLO
```

### Gestione pixel
`dataset.pixel_array` → conversione `float32` → normalizzazione → conversione RGB (canale grigio replicato).

### Windowing
Se presenti i tag `WindowCenter` / `WindowWidth` → applicare windowing. In assenza → normalizzazione automatica sul range min/max dei pixel.

### Anonimizzazione (obbligatoria, in RAM)
Prima di qualsiasi uso, rimuovere dal dataset in memoria: `PatientName`, `PatientID`, `PatientBirthDate`, `PatientSex`, `InstitutionName`, `AccessionNumber`, `StudyID`, `SeriesDescription`, `OperatorName` e ogni altro identificativo personale. **Il file DICOM originale su MinIO non viene mai modificato.**

### Gestione temporanei
Nessun PNG permanente. Solo `/tmp/dentalcare-ai/{job_id}/`, eliminato a fine job (già il pattern attuale di `job_service`). Il PNG viene creato solo se `save_preview=true` o `save_annotated_image=true`.

### Struttura MinIO consigliata
```
patients/{patientId}/studies/{studyId}/
    panoramic.dcm            ← dato originale
    ai/
        result.json
        annotated.png        ← solo artefatto di visualizzazione
```

### API
Endpoint invariato `POST /api/v1/inference/jobs`; il payload passa la key DICOM:
```json
{ "image_bucket": "dentalcare-docs", "image_object_key": "patients/P001/studies/S001/panoramic.dcm" }
```
**Output JSON invariato.** Le bounding box sono sempre riferite all'immagine originale estratta dal DICOM.

### Configurazione (`.env` / `config.py`)
```
ENABLE_DICOM=true
ENABLE_PNG_FALLBACK=true
SAVE_PREVIEW=false
SAVE_ANNOTATED_IMAGE=true
```

### File coinvolti
| Layer | File |
|-------|------|
| AI service | nuovo `app/inference/dicom.py`; modifica `app/services/job_service.py` (branch estensione); `app/config.py` (nuovi flag); `app/inference/preprocessing.py` (input già ndarray); `requirements.txt` (+`pydicom`, `highdicom`); `.env.example` |
| Backend/Frontend | nessuna modifica al contratto; il tipo `rx_panoramica` accetta anche upload `.dcm` (verificare MIME `application/dicom` in upload documenti) |

### Compatibilità futura
La progettazione consente integrazione futura con **PACS / Orthanc / DICOMweb (WADO-RS, QIDO-RS, STOW-RS)** senza modifiche sostanziali alla pipeline: `DicomLoader` diventa il punto di aggancio (sorgente file locale oggi, sorgente DICOMweb domani).

### Benefici
Dato originale → maggiore accuratezza; conformità standard medicali; eliminazione conversioni preventive; predisposizione integrazione ospedaliera; migliore gestione GDPR (anonimizzazione in RAM); predisposizione certificazione MDR.

### Note / caveat
- L'upload documenti (#4/#5) deve accettare `application/dicom` e key `.dcm`; verificare i MIME ammessi lato frontend/backend.
- L'anonimizzazione non deve loggare i tag rimossi (nessun PII nei log).
- Confidence/soglie e mappa classi restano invariate — cambia solo il **loader** a monte del preprocessing.
- Il matching FDI↔disease e il sync odontogramma non cambiano (lavorano su ndarray).

---

## 9. Segreteria AI: isolamento chat per utente (hardening IDOR sessioni)

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #9 resta stabile per i riferimenti.

## 10. Da Segreteria AI a DentalCare AI Copilot (roadmap a fasi)

**Stato:** Proposta
**Data proposta:** 2026-07-01
**Impatto:** Alto (~multi-settimana, incrementale a fasi)
**Prerequisiti:** #6 (Fatta), #1 (SSE realtime), #7 (cifratura GDPR), #8 (DICOM)

### Punto di partenza
La **Segreteria AI** è oggi un assistente **reattivo** per agenda + consultazione. Chat role-aware (segretaria/medico) con `DentalCareAiTools`:
- **Lettura**: appuntamenti, pazienti, dettaglio paziente, preventivi, richiami, fatture, dashboard, provider, slot liberi
- **Scrittura** (solo agenda, preview+conferma): crea/sposta/annulla appuntamento
- Storia per-provider (#9), contesto da `request.history`, canali in-app + n8n (Retell voce, gmail)

### Obiettivo
Trasformarla in un **Copilot clinico-operativo**: proattivo, consapevole del contesto, multimodale, con azioni su tutti i moduli, ragionamento sui dati clinici AI e recupero semantico della conoscenza — mantenendo confirm-gating, audit e gating per ruolo.

### Roadmap a fasi

**Fase 0 — Fondamenta sicurezza/audit**
Audit log di ogni azione AI (chi/cosa/quando), disclaimer clinici obbligatori sulle risposte diagnostiche, rinforzo del gating per ruolo sui tool. Prerequisito per uso clinico/MDR.

**Fase 1 — Copertura azioni (scrittura su tutti i moduli)**
Estendere `DentalCareAiTools` con tool di scrittura confirm-gated (stesso pattern preview→`confirmAction`): crea/modifica paziente, preventivi, richiami, fatture, piani di cura, note cliniche, documenti.

**Fase 2 — Intelligenza clinica (integra #6)**
Tool su `patient_document_labels` / odontogramma: "mostra le patologie AI del paziente X", "genera un preventivo dalle carie rilevate", cross-reference odontogramma ↔ preventivi ↔ anamnesi.

**Fase 3 — Contesto + proattività**
Iniezione del contesto corrente (paziente/schermata aperta) nel prompt; suggerimenti proattivi via SSE (#1): richiami scaduti, preventivi fermi, controlli consigliati.

**Fase 4 — RAG / conoscenza**
`pgvector`: embeddings su documenti, referti, anamnesi, note e protocolli clinici → ricerca semantica e risposte con citazioni della fonte.

**Fase 5 — Multimodale**
Lettura ortopanoramica e referti PDF (lega a #6/#8 DICOM): visione e parsing documenti nel contesto della conversazione.

**Fase 6 — Memoria + orchestrazione**
Memoria long-term per-provider (preferenze, pattern); planner multi-step che concatena azioni ("prepara richiamo → invia email → crea appuntamento").

### File coinvolti (indicativi, per fase)
| Fase | Layer principale |
|------|------------------|
| 0 | Backend: audit table + interceptor sui tool; system prompt (disclaimer) |
| 1 | Backend: `DentalCareAiTools` (+tool scrittura), pattern confirmAction esistente |
| 2 | Backend: tool su labels/odontogramma; ChatService prompt clinico |
| 3 | Backend: contesto corrente nel `ChatRequest`; SSE (#1); Frontend: passa contesto schermata |
| 4 | DB: `pgvector`; Backend: servizio embeddings + retrieval; ingest documenti |
| 5 | AI service / provider visione; parsing PDF/DICOM (#8) |
| 6 | Backend: memoria per-provider; planner multi-tool |

### Note
- Ogni fase è **rilasciabile in autonomia** e porta valore incrementale; ordine consigliato 0→6.
- Confirm-gating e audit restano trasversali a tutte le fasi.
- La scelta del modello (attuale `gpt-4o` via Spring AI) va rivalutata per visione/costi in Fase 5.
- GDPR/MDR: dati clinici nei prompt richiedono #7 (cifratura) e audit di Fase 0 prima di esporre reasoning clinico in produzione.
- **Governance (Fase 0) = prerequisito trasversale**: audit log di ogni azione AI (chi/cosa/quando), disclaimer clinici sulle risposte diagnostiche, gating per ruolo sui tool. Va fatta **prima** di abilitare scrittura clinica. Le fasi sono scomposte in proposte concrete: **#13** (copertura scrittura moduli + letture mancanti, ex-Fasi 1-2), **#14** (contesto+proattività+cross-modulo, ex-Fase 3 + parte 2), **#15** (RAG/multimodale/memoria, ex-Fasi 4-6).

---

## 11. Rinomina UI "Segreteria AI" → "Copilot AI" (feature, non ruolo)

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #11 resta stabile per i riferimenti.

## 12. CRUD anagrafiche per-tenant (Prestazioni/prezzi, voci anamnesi per studio, categorie magazzino)

**Stato:** Proposta
**Data proposta:** 2026-07-02
**Impatto:** Alto (~3-4 giorni, incrementale per anagrafica)

### Obiettivo
Dare a ogni studio (tenant) la gestione autonoma — via UI, senza toccare il DB — di tutte le anagrafiche/master data del programma: **prestazioni e prezzi**, **default prestazione per condizione** (guida "Genera piano"), **bundle prestazioni**, **voci di anamnesi**, **categorie di magazzino**. Colmare i buchi CRUD e portare tutto sotto uno stesso scope per-tenant.

### Censimento anagrafiche e stato attuale

| # | Anagrafica | Tabelle | CRUD backend | UI admin | Scope | Gap |
|---|-----------|---------|:---:|:---:|-------|-----|
| a | Voci anamnesi (categorie+voci) | `anamnesis_categories`, `anamnesis_items` | ✅ `/api/admin/anamnesis` | ✅ in `impostazioni` | **GLOBALE** (`dentalcare`) | Condiviso tra TUTTI gli studi: uno studio che modifica cambia a tutti |
| b | Prestazioni + prezzi | `service_catalog` | ❌ read-only | ❌ nessuna | per-tenant (`clinic_id`) | **CRUD assente** — prezzi/listino non modificabili da UI |
| c | Default prestazione per condizione | `condition_service_defaults` | ❌ read-only | ❌ nessuna | per-tenant | Admin assente — guida "Genera piano" dall'odontogramma |
| d | Bundle prestazioni | `service_bundle_items` | ❌ read-only | ❌ nessuna | per-tenant | Admin assente — prestazioni suggerite automatiche |
| e | Prodotti magazzino | `products` | ✅ | ✅ `magazzino` | per-tenant | ok |
| f | Fornitori | `suppliers` | ✅ | ✅ `magazzino` | per-tenant | ok |
| g | Movimenti magazzino | `stock_movements` | ✅ (GET+POST, append-only) | ✅ `magazzino` | per-tenant | ok |
| h | Categorie prodotto | `product_categories` | ❌ solo GET | parziale | per-tenant | **CRUD assente** (create/update/delete) |
| i | Operatori/Professionisti | `providers` | ✅ (impostazioni) | ✅ | per-tenant | ok |
| j | Impostazioni studio/fatturazione/richiami/slot | clinic/app settings | ✅ | ✅ | per-tenant | ok |
| k | Sedi/Centri | `clinics` | ✅ | ✅ (impostazioni) | per-tenant | ok |
| l | Poltrone/sedie | — (chairLabel free-text da `appointments`) | — | — | per-tenant | Nessuna anagrafica dedicata (valore libero) — opzionale |

**Gap da colmare (priorità):** b+c+d (Prestazioni/prezzi/default/bundle) → h (categorie prodotto) → a (anamnesi per-tenant) → l (poltrone, opzionale).

---

### 12.A — Prestazioni, prezzi, default-per-condizione, bundle (gap b/c/d) — PRIORITÀ ALTA

Le prestazioni sono già per-tenant (`service_catalog` nello schema tenant, `clinic_id`), ma esposte **solo in lettura**. Serve il CRUD completo + UI, incluse le due tabelle collegate che pilotano la generazione del piano di cura.

#### Backend — estendere `ServiceCatalogController` / `ServiceCatalogService`

Nuovi endpoint (autorizzati admin/medico):
```
POST   /api/services                          crea prestazione
PUT    /api/services/{id}                      modifica (nome, categoria, prezzo, durata, denti applicabili, attivo)
DELETE /api/services/{id}                      soft-delete (active=false) o hard se non referenziata
POST   /api/services/{id}/bundle               aggiungi figlio al bundle
DELETE /api/services/{id}/bundle/{childId}     rimuovi figlio dal bundle
GET    /api/services/condition-defaults/all    elenco completo mapping condizione→prestazioni
POST   /api/services/condition-defaults        crea mapping (condition_name, service_id, sort_order)
DELETE /api/services/condition-defaults/{id}   rimuovi mapping
```
DTO: `CreateServiceRequest`, `UpdateServiceRequest`, `ConditionDefaultDto`, `CreateConditionDefaultRequest`, `AddBundleItemRequest`. Campi `service_catalog`: `code, name, category, default_price, duration_minutes, min_tooth_digit, max_tooth_digit, applicable_to_deciduous, active`. Validazione: prezzo ≥ 0, nome obbligatorio, `condition_name` tra i valori odontogramma (`cavity, crown, missing, root_canal, to_extract, bridge_pillar, bridge_pontic, implant, impacted`).

Cancellazione sicura: prima di hard-delete verificare che la prestazione non sia usata in `treatment_plan_items` / `estimate_lines` → altrimenti soft-delete (`active=false`).

#### Frontend — nuova sezione "Prestazioni e Listino"
Nuova voce in `impostazioni` (o feature dedicata `features/prestazioni/`): tabella prestazioni per categoria con prezzo/durata/denti, form crea/modifica, toggle attivo, gestione bundle (figli suggeriti) e mapping default-per-condizione (quale prestazione proporre per carie, corona, ecc.). Estendere `service-catalog.service.ts` con i nuovi metodi.

**Beneficio:** ogni studio gestisce il proprio listino e la logica "Genera piano" senza intervento DB.

---

### 12.B — Voci di anamnesi per-tenant (gap a) — DECISIONE DI DESIGN

Oggi il catalogo anamnesi (`anamnesis_categories`/`anamnesis_items`) vive nello schema **globale** `dentalcare`: il CRUD in `impostazioni` funziona ma **modifica il catalogo di tutti gli studi**. Le selezioni del paziente (`patient_anamnesis_item_selections`) sono per-tenant e referenziano gli item globali.

Tre opzioni:

- **Opt 1 (consigliata) — Catalogo per-tenant, come `service_catalog`.** Spostare `anamnesis_categories`/`anamnesis_items` nello schema tenant; seedarle in `create_tenant` da un template base; migrare i tenant esistenti (copia righe globali → schema tenant) e ripuntare `patient_anamnesis_item_selections.item_id` agli item del tenant. Coerente col pattern già usato per le prestazioni. Costo: migrazione dati + FK.
- **Opt 2 (basso rischio) — Base globale + override per-tenant.** Mantenere il catalogo globale in sola lettura e aggiungere `tenant_anamnesis_overrides` (disabilita voce, rinomina, aggiungi voci custom). La lettura fonde base + override. Nessuna migrazione delle selezioni. Più complessa la query di merge.
- **Opt 3 — `clinic_id` nullable sulle tabelle globali.** `clinic_id IS NULL` = riga condivisa; righe con `clinic_id` = override/aggiunte del tenant. Ibrido tra 1 e 2.

Raccomando **Opt 1** per vera proprietà per-studio e coerenza col resto delle anagrafiche; **Opt 2** se si vuole evitare la migrazione delle selezioni esistenti. **Serve tua scelta prima di implementare.** Il CRUD UI in `impostazioni` resta quasi invariato — cambia solo lo scope (schema tenant invece di `dentalcare`) e `AnamnesisCatalogService`/`AnamnesisService` usano `s()` invece di `dentalcare`.

---

### 12.C — Categorie prodotto magazzino (gap h) — PRIORITÀ MEDIA

`product_categories` ha solo `GET`. Aggiungere in `ProductController`/relativo service:
```
POST   /api/product-categories
PUT    /api/product-categories/{id}
DELETE /api/product-categories/{id}   (blocca/soft-delete se referenziata da products)
```
UI: gestione categorie dentro la sezione Magazzino esistente (`magazzino.component`). Basso costo.

---

### 12.D — Poltrone/sedie (gap l) — OPZIONALE

Oggi `chairLabel` è testo libero negli appuntamenti (`findChairLabels` fa `DISTINCT`). Opzionale: tabella anagrafica `chairs` (label, sede, attivo) per selezione controllata in agenda e per la proposta #2 (Retell per poltrona). Rimandabile.

---

### Superficie UI: sezione unica "Anagrafiche"
Raggruppare la gestione master data sotto `impostazioni` (o nuova area `Anagrafiche`) con sottosezioni: **Prestazioni e Listino**, **Anamnesi**, **Magazzino** (prodotti/categorie/fornitori), **Operatori**, **Sedi**. Coerenza UX + un solo punto d'accesso admin.

### File coinvolti (per blocco)
| Blocco | Backend | Frontend | DB |
|--------|---------|----------|----|
| 12.A Prestazioni | `ServiceCatalogController`/`Service` (+CRUD), nuovi DTO | nuova sezione/feature Prestazioni, `service-catalog.service.ts` | nessuno (tabelle già esistono) |
| 12.B Anamnesi per-tenant | `AnamnesisCatalogService`/`AnamnesisService` (schema `s()`), `create_tenant` | invariato (impostazioni) | patch: sposta/duplica tabelle in schema tenant + `install.sql` + migrazione |
| 12.C Categorie prodotto | `ProductController`/service (+CRUD) | `magazzino.component` | nessuno |
| 12.D Poltrone | nuovo `ChairController`/service | agenda + impostazioni | nuova tabella `chairs` + `install.sql` + `create_tenant` |

### Ordine implementazione consigliato
1. **12.A** (Prestazioni/prezzi/default/bundle) — massimo valore, nessun cambio schema, sblocca gestione listino e "Genera piano".
2. **12.C** (categorie prodotto) — piccolo, chiude il magazzino.
3. **12.B** (anamnesi per-tenant) — dopo decisione Opt 1/2/3 (comporta migrazione).
4. **12.D** (poltrone) — opzionale.

### Note
- 12.A non richiede migrazioni: le tabelle sono già per-tenant, manca solo il CRUD. È il quick-win.
- La cancellazione delle anagrafiche referenziate (prestazioni in preventivi/piani, categorie con prodotti) deve essere **soft-delete** per non rompere lo storico.
- Gating per ruolo: gestione anagrafiche riservata ad admin (ed eventualmente medico per il listino).
- `create_tenant` semina già `service_catalog`/`condition_service_defaults` per i nuovi tenant → il CRUD 12.A opera su dati già presenti.
- 12.B è l'unico blocco con impatto sullo schema e sui dati esistenti: valutare la scelta di design prima di pianificare la migrazione.

---

## 13. Copilot operativo: scrittura sui moduli + letture mancanti

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #13 resta stabile per i riferimenti.

## 14. Copilot contestuale e proattivo

**Stato:** Proposta
**Data proposta:** 2026-07-02
**Impatto:** Medio-alto (~2-3 giorni)
**Prerequisiti:** #1 (SSE realtime), #13 (tool base)
**Scompone:** #10 Fase 3 (+ intelligenza clinica)

### 14.A Contesto corrente
Oggi il Copilot non sa quale paziente/schermata è aperta → deve sempre cercare per nome. Iniettare nel `ChatRequest` il **contesto UI** (es. `patientId`, vista corrente): il frontend lo passa, il backend lo aggiunge al system prompt. Effetto: "crea un preventivo a questo paziente" senza ricerca.

### 14.B Proattività push
`getDailyBriefing` è oggi **pull** (l'utente deve chiedere). Con SSE (#1): **push** di suggerimenti in chat/badge — richiami scaduti, preventivi fermi da N giorni, controlli consigliati. Backend: trigger/job → `publish(clinicId, suggestion)`; frontend: `EventSource` già usato per la chat.

### 14.C Intelligenza cross-modulo
Tool composti che attraversano i moduli:
- "genera un preventivo dalle carie rilevate dall'AI" → odontogramma/#6 → `EstimateService`
- "prepara i richiami del mese" → recall generation
- cross-reference odontogramma ↔ preventivi ↔ anamnesi in una risposta.

### File coinvolti
| Layer | File |
|-------|------|
| Backend | `ChatRequest` (+campo contesto), `ChatService` (prompt + contesto), tool cross-modulo in `DentalCareAiTools`, hook SSE (riuso registry #1) |
| Frontend | passaggio contesto schermata alla chat; `EventSource` per i suggerimenti proattivi |

### Note
- Dipende da **#13** (i tool di scrittura sono la base delle azioni proattive) e da **#1** (canale push).
- La proattività va confirm-gated come le altre scritture: il push **propone**, l'utente conferma.

---

## 15. Copilot: RAG, multimodale, memoria

**Stato:** Proposta
**Data proposta:** 2026-07-02
**Impatto:** Alto (~1-2 settimane)
**Prerequisiti:** #7 (cifratura, per dati clinici nei prompt), #6/#8 (immagini/DICOM)
**Scompone:** #10 Fasi 4-6

### 15.A RAG (pgvector)
Ricerca semantica sulla conoscenza dello studio: embeddings su documenti, referti, anamnesi, note cliniche, protocolli → risposte con **citazione della fonte**.
- DB: estensione `pgvector` + tabella `document_embeddings` (per-tenant).
- Backend: servizio embeddings (ingest + query), retrieval nel prompt.

### 15.B Multimodale
Lettura di ortopanoramica e referti PDF **nel contesto della chat** (lega #6 e #8 DICOM): modello con visione + parsing PDF.

### 15.C Memoria + planner
- Memoria long-term per-provider (preferenze, pattern ricorrenti).
- Planner multi-step che concatena azioni ("prepara richiamo → invia email → crea appuntamento").

### File coinvolti
| Layer | File |
|-------|------|
| DB | `pgvector` + tabelle embeddings/memoria (per-tenant, `install.sql` + `create_tenant`) |
| Backend | servizio embeddings/retrieval, ingest documenti, provider visione, planner |
| Frontend | rendering citazioni fonte; upload/anteprima in chat |

### Note
- La scelta del modello (attuale `gpt-4o` via Spring AI) va rivalutata per **visione e costi**.
- GDPR/MDR: dati clinici negli embeddings/prompt richiedono **#7** (cifratura) e l'**audit di #10 Fase 0**.

---

## 16. Wiki LLM: OCR → GPT-4o → MinIO con versionamento per paziente

**Stato:** Proposta
**Data proposta:** 2026-07-03
**Impatto:** Alto (~3-5 giorni)

### Problema
I documenti medici grezzi (PDF referti, radiografie scansionate, ricette, consensi) caricati in MinIO per il paziente rimangono "dati grezzi" — non vengono estratti, indicizzati, o correlati al database clinico. Non c'è una Knowledge Base strutturata per supportare successivamente RAG e Copilot contestuale.

### Soluzione
Implementare una **pipeline OCR → LLM → Wiki** che:
1. **Monitora** nuovi documenti in `patients/{patient_id}/documents/{doc_id}/source/` (MinIO)
2. **Estrae** testo via OCR (PyMuPDF nativo, Docling + Tesseract per scansioni)
3. **Elabora** con GPT-4o due task in parallelo:
   - **Task A:** JSON strutturato → sincronizza SQL (`PatientDocument`, `clinical_finding`)
   - **Task B:** Markdown formattato → salva come Wiki in MinIO (`patients/{patient_id}/wiki/{doc_id}.md`)
4. **Salva wiki** in MinIO con versionamento, metadata, audit trail
5. **Sincronizza SQL** con dati estratti (tipo esame, data, summary, findings)
6. **Supporta radiografie** — AI Service esegue inferenza (Dentex), genera ulteriore wiki-ai-summary

### Architettura
- **Python Worker** (service separato): MinIO listener + OCR + LLM calls + wiki upload
- **Backend Spring Boot**: WikiStorageService (extends MinioStorageService), WikiLlmService, callback sync SQL
- **MinIO Multitenant**: bucket `dc-<schema>` con sotto-cartelle wiki per ogni paziente
- **Database**: Estensione `PatientDocument` + nuove tabelle `clinical_finding_ai`, `wiki_metadata`

### Output Wiki (Markdown)
```markdown
# Dr Smith - 2025-03-15 (Visita)

## Summary
Paziente lamenta dolore acuto al dente 2.6...

## Clinical Findings
- Tooth 2.6: Carie profonda, interessamento camera pulpare
- Radiografia: conferma carie mesiale-distale

## Plan
1. Terapia endodontica entro 7 gg
2. Recall radiografico post-terapia
3. Prossimo controllo: 2025-04-15

## Raw Data
[Original PDF Link]
```

### File coinvolti
| Layer | File | Dettagli |
|-------|------|----------|
| **Architettura** | `directives/wiki_llm_minio_architecture.md` | Design completo: struttura MinIO, flusso, diagrammi Mermaid, SQL schema |
| **DB** | Patch SQL per `patient_document` + `clinical_finding_ai` + `wiki_metadata` + view summary | Versionamento wiki, audit, isolamento tenant |
| **Backend Java** | `WikiStorageService`, `WikiLlmService`, `WikiOcrService`, `PatientDocumentService` (extend) | OCR dispatch, LLM dual-task, MinIO save, DB sync |
| **Backend Config** | `application.properties` + secrets (OpenAI API key) | OCR engines, LLM model, MinIO endpoint, callback URL |
| **Python Worker** | New service: `wiki-worker` container (FastAPI) | Event listener, OCR/LLM pipeline, error handling, retry |
| **Python Config** | `.env.wiki` template + `wiki_worker.py` entry point | 80+ env vars per OCR, LLM, MinIO, security |
| **Docker Compose** | Extension: `wiki-worker` service (port 8001) | Webhook endpoint, health check, resource limits |

### Dipendenze e Prerequisiti
- **OpenAI API key** (GPT-4o accesso): da mettere in secrets/env
- **#7 GDPR** (se clinica seria): OCR + LLM elaborano PHI → richiede cifratura per-tenant
- **#8 DICOM** (facoltativo): se il worker deve gestire radiografie DICOM nativi, estendere OCR engine
- **#15 Copilot RAG** (dipendente): Wiki LLM fornisce Knowledge Base strutturata per successiva indicizzazione Elasticsearch

### Roadmap di implementazione
1. **Fase 1** (~1 giorno): Backend schema (DB + service skeleton)
2. **Fase 2** (~1.5 giorni): Python worker (OCR + LLM pipeline, error handling)
3. **Fase 3** (~0.5 giorni): Backend callback + SQL sync
4. **Fase 4** (~0.5 giorni): Testing, deployment (dev), dead-letter handling
5. **Fase 5** (facoltativo): Dashboard wiki (admin visualizza/revisiona doc processuati)

### Benefici
- **Strutturazione dati**: referti sparsi → database clinico organizzato
- **RAG-ready**: wiki markdown → embedding per Copilot #15
- **Audit trail**: versionamento wiki per compliance clinica
- **Multitenant safe**: isolamento per schema + crittografia (con #7)
- **Auto-sync SQL**: nessun manual data-entry dopo caricamento doc

### Caveat
- **Costi LLM**: ~$0.01-0.05 per documento (GPT-4o); tenere monitorato nei log
- **Tesseract OCR**: fallback per scansioni; accuratezza 85-95% (richiedere review se bassa)
- **PHI in LLM**: durante il call a GPT-4o i dati clinici passano su OpenAI API → compliance risk → bloccare da GDPR upgrade

---

## 17. Prompt Manager AI: prompt multilingua editabili (tabella chiave-valore)

> ✅ **Fatta.** Dettaglio storico archiviato in [proposte-archivio.md](proposte-archivio.md). #17 resta stabile per i riferimenti.

## 23. Ruotare la password demo: è pubblica su GitHub

**Stato:** Proposta — **aperta, azione richiesta**
**Data proposta:** 2026-07-17
**Impatto:** Basso (~1 ora) · **Rischio: la password di un'utenza admin funzionante è pubblica**

La password delle utenze demo è committata in chiaro in **7 file tracciati** del repo `fpapale/dentalcare`, che è **PUBLIC** (non la ripeto qui: `git grep` sui file sotto la trova, ed è il punto):

```
README.md
backend/src/main/resources/application.properties
config/application-prod.properties.example
directives/deploy-gdpr-slice1-prod.md
directives/deploy-procedures.md
directives/manuale-installazione-prod.md
install.sh
```

Ed è nella **storia git** almeno da `fe58b78`.

### Perché toglierla dai file non basta

La storia git è pubblica e già clonata. Una `git rm` di oggi non annulla ciò che è stato leggibile per mesi: chi l'ha presa, l'ha. Riscrivere la storia (`filter-repo`) su un repo pubblico già clonato è teatro, non bonifica.

**L'unica misura efficace è ruotare la password sulle 4 utenze demo** (`demo@`, `admin@`, `segreteria@`, `medico@` `.dentalcare.it`), che oggi condividono lo stesso hash bcrypt.

### Perché conta adesso

Il 17/07 abbiamo chiuso `GET /api/public/demo-config`, che regalava la password via API. Ma prod è raggiungibile da Internet (`papalef.duckdns.org`, vedi commit `41fc350`) e **quelle credenziali funzionano ancora**: chi le legge su GitHub entra come admin del tenant demo. Abbiamo chiuso una porta e lasciata aperta la finestra.

Mitigante: dopo la bonifica del 17/07 il tenant demo contiene **solo dati fittizi**. Il danno oggi è la fiducia, non i dati.

### Da fare
1. Ruotare la password delle 4 utenze demo (bcrypt, valore nuovo).
2. Aggiornare `config/application-prod.properties` sul server (`app.demo.password`, `app.n8n.admin-password`) e riavviare il backend.
3. Sostituire il valore nei 7 file con un placeholder — **non** per bonifica, ma perché il prossimo lettore non lo prenda per buono.
4. Valutare se il tenant demo debba stare su Internet.

> **Regola da adottare:** nessuna credenziale funzionante in un repo pubblico, nemmeno "di demo". Se serve un accesso dimostrativo, va rilasciato a richiesta, non pubblicato.

---

## 24. `?providerId=` è un filtro deciso dal client, non un'autorizzazione

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Medio (~1 giornata)
**Origine:** analisi durante il fix `d7cefe5`

```java
// PatientService.findAll / findById
String providerFilter = providerId != null
        ? "AND (pat.primary_provider_id = :providerId OR EXISTS (SELECT 1 FROM appointments a WHERE ...))"
        : "";   // ← parametro assente = NESSUN filtro
```

`providerId` è `@RequestParam(required = false)` e arriva **dal client**. Chi omette `?providerId=` vede l'intero tenant, qualunque sia il suo ruolo. Non è un controllo di autorizzazione: è una **vista** che il chiamante sceglie da sé.

Oggi non è una falla di riservatezza fra tenant — lo schema resta isolato dal JWT — ma è esattamente il gap **3.6** della gap analysis (§11.1 della guida: "pazienti assegnati o per i quali esiste una relazione di cura"). La colonna `primary_provider_id` esiste ed è usata **solo** come filtro cosmetico.

**Da fare:** derivare l'ambito dal JWT lato server (come già fa `DentalCareAiTools.isMedical()`), non dal parametro. Il parametro resta al massimo come *restringimento* di ciò che il ruolo già consente, mai come ampliamento. Tracciato anche come intervento 14 del [piano di intervento](#piano-di-intervento--cartella-clinica-gap-p0--gap-p1).

---

## 25. Menu persona demo: cambia la UI, non il JWT

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Basso (~½ giornata)

Il selettore in alto (visibile solo sul tenant demo, `@if (isDemoUser())`) cambia `userContext.role()`, che `role.guard.ts:29` usa per le rotte. Ma **il JWT resta quello del login**: `user-context.service.ts:11` lo dice esplicito — *"JWT role — set once on login, never changed by context switch"*.

Conseguenza: scegliere "Segreteria" nasconde i tab clinici e blocca le rotte, **ma l'API risponde ancora come admin**. È una tenda, non un muro.

**Non è una falla** (serve già un login valido e resta dentro il proprio tenant), ma è una **trappola in demo**: se al dentista si mostra il menu persona come prova che "la segretaria non vede la cartella", si promette un controllo che non c'è. La prova onesta è un **login reale** con `segreteria@demo.dentalcare.it`.

**Da fare:** rinominare l'affordance in modo che dichiari cosa è (es. "Anteprima ruolo (demo)") e documentare che non è un confine di sicurezza. Il confine vero è l'intervento 3 del piano (segregazione server-side + test).

---

## 26. CF obbligatorio all'emissione della fattura

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Basso (~½ giornata)
**Origine:** seconda metà della decisione presa con `09dc68b`

`09dc68b` ha reso il codice fiscale **opzionale alla creazione** del paziente, perché l'assistente vocale ha il divieto di chiederlo (§19 del prompt) e senza quella modifica nessun paziente nuovo poteva prenotare per telefono.

La decisione completa era *"CF opzionale, obbligatorio in fattura"*: **la seconda metà non è implementata.** Oggi `InvoiceService` non verifica affatto il CF, si limita allo snapshot — quindi `09dc68b` non ha introdotto regressioni, ma il controllo non esiste né prima né dopo.

**Da fare:** all'emissione, se il paziente non è `foreign_patient` e non ha CF → rifiutare con un errore che dica di completare la scheda. Attenzione: i pazienti stranieri senza CF italiano devono restare fatturabili.

---

## 27. n8n opera come l'utente demo

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Medio (~1 giornata)

```java
@Value("${app.n8n.admin-email:${app.demo.email:}}")     // ← ripiega sulle credenziali demo
@Value("${app.n8n.admin-password:${app.demo.password:}}")

public ServiceTokenResponse serviceToken(String providedKey) {
    if (n8nServiceKey.isBlank() || !n8nServiceKey.equals(providedKey)) throw new AccessDeniedException(...);
    LoginPreflightRequest req = new LoginPreflightRequest(n8nAdminEmail, n8nAdminPassword);
    ...
}
```

n8n presenta `X-N8N-Key` e il backend gli rilascia un JWT **facendo login come utente demo**. Tre conseguenze:

1. **Nell'audit n8n è indistinguibile dall'utente demo**: ogni prenotazione telefonica risulta fatta da quell'utenza. Con l'audit clinico della Fase 1 questo diventa un problema di attribuzione: *chi* ha creato la scheda?
2. **Il legame è invisibile**: la sola configurazione non lo mostra, è un default annidato nel codice. Reso esplicito nel `.example` il 17/07 (#23).
3. **Un tenant, uno solo**: `app.n8n.admin-email` è globale, quindi n8n può operare su un tenant solo. Blocca lo scenario multi-studio di [#2](#2-retell-multi-studio-agente-per-sedepoltrona).

**Da fare:** utenza di servizio dedicata, con ruolo proprio (non `admin`) e riconoscibile nell'audit; per il multi-studio, credenziali per tenant risolte dall'`agent_id` come già previsto in #2.

---

## 28. `getDemoConfig()` inghiotte l'errore e disattiva il menu persona

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Basso (~1 ora) — solo tenant demo, ma è il tipo di difetto che genera "a me non funziona"

```typescript
// app.ts
this.authService.getDemoConfig().subscribe({
  next: res => { this.demoEnabled.set(res.enabled); this.demoSchema.set(res.schema ?? null); },
  error: () => {}          // ← errore inghiottito, nessun retry
});
```

Osservato dal vivo il 17/07: subito dopo `docker compose up -d --build`, il frontend risponde prima che il backend sia pronto. `GET /api/public/demo-config` → **502** → `demoSchema` resta `null` → `isDemoUser()` è `false` → **il menu persona sparisce per tutta la sessione**. Un reload lo fa tornare, ma nulla lo suggerisce all'utente.

Stessa sorte per `GET /api/settings/clinic` e `GET /api/providers`, chiamati nello stesso momento.

**Perché conta più di quanto sembri:** è la finestra fra `frontend` up e `backend` healthy. Il compose ha `depends_on: backend healthy` per l'avvio del container, ma non impedisce a un browser già aperto di ricaricare durante il riavvio. In una demo dal vivo, un riavvio nel momento sbagliato mostra un'app monca senza spiegazione.

**Da fare:** retry con backoff sulle chiamate di bootstrap, o almeno un log e uno stato di errore visibile invece di `() => {}`. Vale la regola generale: nessun `catch` vuoto su una chiamata che decide cosa l'utente vede (CLAUDE.md §27 — *"nascondere errori con catch generici"*).

---

## 29. `install.sql` non rispecchia più la produzione

**Stato:** Proposta
**Data proposta:** 2026-07-17
**Impatto:** Basso (~½ giornata)

Emerso dal dry-run di `rotate_demo_password.py` (#23) sul tenant demo di prod:

| | `database/install.sql` (seed) | Prod reale |
|---|---|---|
| Utenze demo | 4 | **7** |
| Utenza medico | `medico@demo.dentalcare.it` | **non esiste** → è `ferretti@` |
| Altri | — | `amato@`, `gentili@`, `marchetti@` |

Chi installa da zero ottiene un tenant demo **diverso da quello che si dimostra**: credenziali che non esistono, medici che mancano. Ogni runbook, tutorial o manuale che cita `medico@demo.dentalcare.it` è già sbagliato.

Viola la regola già data: *"install.sql deve rispecchiare il DB — rigenerarlo a ogni modifica di schema"*. La regola parlava di schema; qui a divergere sono i **dati di seed**, che nessuno rigenera.

**Aggiornamento 18/07 (mappatura concreta).** Verificato sui file e sul dev DB:
- `install.sql` (blocco `COPY t_9d754153.providers`, righe ~5164-5169) seed **4** utenze: `admin@`, `segreteria@` (Maria Rossi), `medico@` (Laura Ferretti, email `medico@`), `demo@`. Tutte con lo stesso `password_hash`, corrispondente alla password demo pubblica dell'epoca (valore reale fuori da questo file: vedi il seed e le note di rotazione #23).
- Il **dev DB** (`dentalcarepro`) rispecchia *esattamente* il seed: stesse 4 utenze, stesso `medico@`. Il seed è quindi allineato al **dev**, non alla **prod** (7 utenze, `ferretti@`).
- **#29 e #23 sono lo stesso blocco:** la riga di seed che diverge dalla prod è anche quella che pubblica la password. Rigenerare il seed **dopo** aver ruotato (#23) e con l'hash sostituito da un placeholder chiude entrambi.

**Da fare (ordine):** 1) ruotare la password (#23) → 2) `pg_dump --data-only` dello schema demo di prod con l'hash → placeholder → 3) sostituire il blocco seed in `install.sql`. Passi 2-3 richiedono l'accesso al DB prod (read/write **bloccati al classifier per l'agente**: li lancia il committente). Resta la decisione: **seed o prod come fonte di verità?** Oggi non lo è nessuno dei due.

---

## 39. Assistente Vocale “Hands-Free” da Poltrona (Chairside Agent)

**Stato:** Confermata — inclusa nella Fase 1 del progetto; progettazione e piano approvati, sviluppo non avviato

**Data proposta:** 2026-07-22

**Impatto:** Alto (~43-69 giornate-agente; ~4-5 settimane calendario con tre agenti dedicati per l'MVP clinico; ~6-10 settimane per una versione estesa e irrobustita)
**Valore atteso:** Alto — riduce interruzioni, contatto con tastiera/mouse e tempi di documentazione durante la seduta

### Obiettivo

Consentire al medico di interagire con DentalCare Pro a mani libere tramite la hotword **“Ehi Giulia”**, senza rompere la sterilità clinica. Casi d'uso iniziali:

- dettare una nota clinica e rileggerla prima del salvataggio;
- interrogare anamnesi, allergie, farmaci, diagnosi e ultime visite del paziente già aperto;
- aprire o proiettare l'ultima radiografia o uno specifico documento;
- navigare fra le sezioni della cartella e controllare la visualizzazione;
- avviare un timer o creare un promemoria non clinico.

### Valutazione

**Raccomandazione: approvare come sperimentazione controllata, non come automazione clinica autonoma.** La feature è coerente con il Copilot esistente e può differenziare nettamente il prodotto, ma l'ambiente odontoiatrico è acusticamente difficile (aspiratore, turbina, mascherina, conversazioni) e un riconoscimento errato può produrre conseguenze cliniche o mostrare dati del paziente sbagliato.

| Dimensione | Valutazione | Nota |
|---|---|---|
| Valore per il medico | **Alto** | Evita cambi guanti e interrompe meno il flusso operativo |
| Fattibilità tecnica | **Medio-alta** | Riusa API, Copilot e tool applicativi; wake word e audio richiedono un client dedicato |
| Rischio clinico/privacy | **Alto** | Audio e trascrizioni contengono dati sanitari; il contesto paziente deve essere inequivocabile |
| Affidabilità in studio | **Media** | Va misurata sul campo con rumore reale e microfono direzionale |
| Complessità MVP | **Alta** | Voce realtime, autorizzazioni, conferme, audit, UI e fallback manuale |

Il beneficio maggiore non viene dal “parlare con un chatbot”, ma da pochi comandi affidabili e contestuali. Per questo l'MVP deve privilegiare un vocabolario operativo ristretto e azioni deterministiche; il linguaggio libero resta utile per dettatura e domande in sola lettura.

### Soluzione proposta

#### 1. Client Chairside locale

Un'app/PWA installata sul PC della poltrona gestisce microfono, indicatore visivo e stato della sessione. La wake word viene rilevata **localmente**: prima di “Ehi Giulia” nessun audio lascia il dispositivo. Dopo l'attivazione, il client acquisisce solo la singola richiesta, mostra chiaramente che il microfono è attivo e termina per silenzio, comando “annulla” o timeout breve.

Requisiti hardware consigliati: microfono direzionale o array USB vicino al monitor; evitare come configurazione certificata il microfono ambientale del portatile.

#### 2. Pipeline vocale separata dal ragionamento

```text
Wake word locale
  → Voice Gateway autenticato (sessione, tenant, utente, poltrona)
  → Speech-to-Text con vocabolario odontoiatrico
  → Intent Router / Copilot
  → Tool applicativo autorizzato lato server
  → risposta UI + sintesi vocale breve
```

Il modello non chiama direttamente database o frontend. Ogni comando viene tradotto in un **intent tipizzato** (`READ_ANAMNESIS`, `DRAFT_NOTE`, `OPEN_DOCUMENT`, ecc.) ed eseguito attraverso i tool/API di DentalCare Pro, con autorizzazione server-side derivata dal JWT e dal tenant. Il testo riconosciuto dal modello non può scegliere tenant, utente o paziente.

#### 3. Contesto paziente sicuro

Il Chairside Agent opera solo sul paziente già selezionato nell'interfaccia e annuncia un riferimento minimo prima di leggere o modificare dati, per esempio: “Paziente Mario R., confermi?”. Il cambio paziente via voce non è previsto nell'MVP.

Per evitare divulgazioni accidentali, le risposte vocali sono sintetiche (“rilevata un'allergia, dettagli a schermo”); i dati sensibili completi vengono mostrati sul monitor e non letti ad alta voce per impostazione predefinita.

#### 4. Regole di conferma

| Classe | Esempi | Comportamento |
|---|---|---|
| Navigazione | apri radiografia, vai all'anamnesi, zoom | Esecuzione immediata, annullabile |
| Lettura | allergie, ultima visita, farmaci | Risposta immediata con contesto paziente visibile |
| Bozza | detta nota, prepara prescrizione | Crea anteprima; nessun dato clinico definitivo |
| Scrittura clinica | salva nota, aggiorna anamnesi/odontogramma | **Conferma esplicita** e audit prima del commit |
| Azione ad alto rischio | firma/finalizza, prescrive, elimina, cambia paziente | Esclusa dall'MVP o conferma manuale a schermo |

La conferma deve riferirsi a una sola azione e includere un riepilogo; non va riutilizzato un generico `confirmAction` che possa confermare l'anteprima sbagliata (vedi #20).

#### 5. Privacy, sicurezza e audit

- opt-in per studio e per postazione, con informativa e procedura operativa per il paziente;
- audio non conservato per default; trascrizione temporanea con retention minima configurabile;
- cifratura in transito e a riposo, isolamento per tenant e divieto di PHI nei log tecnici;
- audit di attivazione, trascrizione normalizzata, intent, tool invocato, utente, paziente, esito e conferma, senza salvare più contenuto del necessario;
- pulsante/mute fisico e comando “Giulia, annulla”; indicatore visivo sempre percepibile;
- timeout, rate limit, protezione da replay e associazione della sessione alla postazione autorizzata;
- valutazione DPIA, fornitore STT/TTS, localizzazione dei dati e accordi di trattamento prima del pilota su pazienti reali.

### Collocazione nella Fase 1 e ordine di sviluppo

La funzionalità #39 è parte della **Fase 1 generale del progetto**, ma non precede le fondamenta cliniche e di sicurezza. L'ordine vincolante è:

1. audit clinico append-only (#18) e autorizzazioni server-side (#24);
2. chiusura del difetto di conferma #20 e stabilizzazione dei contratti Copilot;
3. conversazione Copilot condivisa, policy studio e impostazioni voce/lingua, dietro feature flag;
4. push-to-talk, STT e pannello globale in sola lettura su dati fittizi;
5. TTS configurabile e hotword locale “Ehi Giulia”;
6. revisione della dettatura clinica e doppio gate di conferma, integrati con finalizzazione/addendum;
7. test avversi, DPIA/valutazione fornitore e pilota controllato su una postazione;
8. abilitazione nel go-live Fase 1 solo al superamento dei criteri del pilota; in caso contrario il resto della Fase 1 resta rilasciabile con `enabled=false`.

Le attività 3-5 possono avanzare in parallelo al completamento del modello clinico, purché usino dati fittizi e non abilitino scritture. Le attività 6-8 dipendono invece dai gate clinici e normativi.

### Stima con tre agenti dedicati

| Flusso | Ambito prevalente | Effort | Carico indicativo |
|---|---|---:|---|
| **Agente backend** | policy per tenant, catalogo voci, metadati chat/SSE, classificazione autoritativa, audit, sicurezza | **11-18 gg-agente** | più intenso nei blocchi B, D e F |
| **Agente frontend** | conversazione condivisa, pannello globale, orchestratore audio, STT/TTS, hotword e review dettatura | **17-26 gg-agente** | percorso critico tecnico, soprattutto A, C ed E |
| **Agente test/QA** | test automatici, cross-tenant/ruoli, E2E voce-chat, casi avversi, hardware e rumore reale, pilota | **15-25 gg-agente** | parte dal Blocco A e guida il Blocco G |
| **Totale** | MVP clinico completo | **43-69 gg-agente** | **~4-5 settimane calendario** con parallelizzazione e una postazione disponibile |

La forchetta alta si applica se hotword o browser richiedono una companion app, se il provider STT/TTS necessita integrazione dedicata o se il rumore reale impone più cicli di calibrazione. Non include tempi esterni di DPO, accordi con fornitori, acquisto hardware o attese autorizzative.

### Piano di rilascio interno della feature

**Voice V0 — Prototipo tecnico (3-5 giorni).** Wake word locale, dettatura, tre comandi UI, misurazione con rumore registrato in ambiente reale. Nessuna scrittura su dati clinici.

**Voice V1 — MVP in sola lettura + bozze (2-3 settimane).** Anamnesi/allergie/ultime visite, apertura radiografie, dettatura di note in anteprima, conferma visuale, audit, metriche e fallback manuale.

**Voice V2 — Scritture cliniche controllate (1-2 settimane).** Salvataggio note e aggiornamenti a basso rischio con conferma vocale forte o manuale; test di autorizzazione e casi avversi.

**Voice V3 — Estensione (2-5 settimane).** Vocabolario configurabile, più lingue/voci, comandi odontogramma, integrazione monitor di sala e modalità degradata/offline. Solo dopo metriche positive del pilota.

### Criteri di accettazione del pilota

- nessuna attivazione silenziosa: wake word e ascolto sono sempre visibili;
- zero esecuzioni sul paziente o tenant errato nei test avversi;
- 100% delle scritture cliniche precedute da anteprima e conferma tracciata;
- successo ≥95% sui comandi chiusi in condizioni reali di poltrona;
- tasso di false attivazioni concordato e misurato per ora di utilizzo;
- latenza percepita ≤2 secondi per navigazione e ≤4 secondi per domande semplici;
- disattivazione immediata e uso completo dell'app anche senza voce.

### Decisioni aperte prima dello sviluppo

1. **Elaborazione audio:** STT/TTS cloud in regione UE, self-hosted oppure soluzione ibrida; la scelta cambia costi, latenza e DPIA.
2. **Dispositivo:** browser/PWA sul PC della poltrona oppure companion app desktop; per wake word affidabile e controllo del microfono è preferibile la companion app.
3. **Conferma clinica:** sola voce con challenge esplicita oppure click/pedale per le azioni più sensibili.
4. **Retention:** nessun audio e trascrizione effimera come default consigliato; eventuale conservazione solo con finalità e tempi formalizzati.

**Dipendenze:** #10 Fase 0 (governance Copilot), #13 (tool operativi), #18 (audit clinico) e chiusura di #20 prima di abilitare scritture. La feature può iniziare in sola lettura e navigazione senza attendere tutte le scritture cliniche, ma non deve andare su pazienti reali prima del gate di go-live applicabile.

### Decisione del 22/07/2026

Approvata l'integrazione come modalità del Copilot esistente: pannello globale, hotword più push-to-talk, messaggi vocali nella stessa chat, sintesi attivabile dal pannello e voce/lingue configurabili nelle Impostazioni. Le domande e la navigazione sono inviate subito; le dettature cliniche richiedono revisione della trascrizione e mantengono il successivo gate dell'azione.

Documenti esecutivi:

- [Spec di progettazione](../docs/superpowers/specs/2026-07-22-copilot-chairside-voice-design.md)
- [Piano di intervento](../docs/superpowers/plans/2026-07-22-copilot-chairside-voice.md)

---

## 40. MinIO — separazione root per ambiente (Dev / Coll / Prod)

**Stato:** Proposta
**Data proposta:** 2026-07-23
**Impatto:** Medio (~1 giornata codice+config) + finestra di migrazione su prod (dati reali, esecuzione bloccata all'agente)

### Problema
Un solo MinIO (`192.168.0.72:9000`) serve sia Dev (via tunnel SSH) sia Prod (via `host.docker.internal`) — vedi `application.properties` / `application-prod.properties`. Il bucket di ogni tenant è calcolato **solo** dallo schema: `bucketFor(schema) = bucketPrefix + schema.replace('_','-')` (`MinioStorageService.java:65-67`), e `app.minio.bucket-prefix` vale `dc-` **identico** in dev e prod. Non esiste alcuna radice che distingua l'ambiente: se un tenant con lo stesso schema esiste (o viene clonato) sia in `dentalcarepro` (dev) sia in `dentalcare_prod`, i due ambienti risolvono **lo stesso** bucket MinIO — dev può leggere/scrivere/cancellare documenti reali di prod (e viceversa). Il tenant demo `t_9d754153` è l'esempio concreto oggi presente in dev; se mai comparisse con lo stesso schema in prod, la collisione è garantita.

Con l'arrivo dell'ambiente COLLAUDO (proposta #41) lo stesso MinIO diventerebbe condiviso da **tre** ambienti sullo stesso bucket-namespace: il rischio si moltiplica.

### Soluzione: prefisso bucket per ambiente — nessuna modifica al codice Java

`MinioStorageService.bucketFor()` è già parametrico su `app.minio.bucket-prefix` (property esternalizzata, default `dc-`). Basta differenziare il prefisso per ambiente:

| Ambiente | `app.minio.bucket-prefix` | Bucket tenant `t_9d754153` |
|---|---|---|
| Dev | `dc-dev-` | `dc-dev-t-9d754153` |
| Coll | `dc-coll-` | `dc-coll-t-9d754153` |
| Prod | `dc-prod-` | `dc-prod-t-9d754153` |

Isolamento garantito indipendentemente da eventuali cloni/copie di schema tra ambienti: la radice ambiente fa parte del nome bucket, non solo dello schema tenant.

#### Fase 1 — File di configurazione

| File | Modifica |
|---|---|
| `backend/src/main/resources/application.properties` (profilo default = dev) | `app.minio.bucket-prefix=dc-dev-` |
| `backend/src/main/resources/application-prod.properties` | aggiungere `app.minio.bucket-prefix=dc-prod-` (oggi assente da questo file, presente solo nel default con valore `dc-`) |
| **nuovo** `backend/src/main/resources/application-coll.properties` | profilo `coll` — vedi proposta #41; include `app.minio.bucket-prefix=dc-coll-` |
| `config/application-prod.properties.example` (root, template deploy) | riga MinIO aggiornata a `dc-prod-` + commento sulla radice per ambiente |
| **nuovo** `config/application-coll.properties.example` | analogo a quello prod, con `dc-coll-` — vedi proposta #41 |
| `backend/config/application.properties` (locale, gitignored, dev reale) | allineare `app.minio.bucket-prefix=dc-dev-` |
| `backend/config/application-prod.properties` (locale, gitignored, sul server prod) | **non è nel repo** — va aggiornato a mano sul server `.72` in `~/docker/dentalcarepro/config/` come parte del deploy (vedi Fase 3) |

#### Fase 2 — Migrazione bucket prod esistenti (dati reali già live, #4/#5 Fatta)

I bucket prod attuali si chiamano `dc-<schema>` (nessun suffisso ambiente). Cambiare solo la property sposterebbe le letture su un bucket nuovo e vuoto `dc-prod-<schema>` — i documenti esistenti diventerebbero "invisibili" (i binari restano nei vecchi bucket, non più referenziati). Serve una migrazione esplicita **prima** del deploy della nuova property:

1. Elencare gli schema tenant reali in `dentalcare_prod`.
2. Per ciascuno: `mc mirror sourcealias/dc-<schema> targetalias/dc-prod-<schema>` (copia oggetti preservando le key — `object_key` in `patient_documents.file_path` non cambia formato, cambia solo il bucket che lo contiene).
3. Verifica: conteggio oggetti sorgente = destinazione prima di procedere.
4. Deploy della nuova config (`bucket-prefix=dc-prod-`) — da questo momento il backend legge/scrive solo sui bucket nuovi.
5. Solo dopo una finestra di osservazione (consigliata ≥1 settimana, upload/download funzionanti in prod): eliminare i vecchi bucket `dc-<schema>` con `mc rb --force`.

Script proposto: nuovo `database/scripts/migrate_minio_env_root.sh`, parametrico su alias `mc` sorgente/destinazione e prefisso. **Esecuzione su prod bloccata al classifier per l'agente**: comporta la migrazione di documenti clinici reali — la lancia il committente; un dry-run di sola verifica (conteggio oggetti, nessuna scrittura) resta eseguibile dall'agente.

#### Fase 3 — Coordinamento con `install.sh` / deploy

`install.sh` di prod crea `config/application-prod.properties` da `.example` **solo se assente** — chi ha già un file reale sul server non lo tocca. La riga `app.minio.bucket-prefix=dc-prod-` va quindi aggiunta **a mano** al file esistente sul server `.72` (`~/docker/dentalcarepro/config/application-prod.properties`), in coordinamento con la Fase 2 — non lasciata al solo `.example`.

### File coinvolti
| Layer | File |
|---|---|
| Backend (repo) | `application.properties`, `application-prod.properties`, nuovo `application-coll.properties` |
| Config template (repo) | `config/application-prod.properties.example`, nuovo `config/application-coll.properties.example` |
| Config locale (gitignored) | `backend/config/application.properties`, `backend/config/application-prod.properties` (server, fuori repo) |
| Migrazione | nuovo `database/scripts/migrate_minio_env_root.sh` |
| Nessuna modifica | `MinioStorageService.java` — già parametrico |

### Note
- Nessun impatto sul formato di `object_key` (`patients/{patientId}/{docId}/{fileName}`) — cambia solo il bucket che lo contiene.
- La stessa tecnica isola anche COLLAUDO (#41) senza ulteriori modifiche di codice: basta il terzo prefisso.
- Rischio se si fa il deploy della sola Fase 1 senza aver completato la Fase 2 su prod: 404 silenziosi sui download di documenti esistenti finché non si torna al bucket vecchio — **le due fasi vanno in produzione insieme**.
- Dev e Coll non hanno dati reali da migrare: possono adottare il nuovo prefisso direttamente; eventuali bucket vecchi `dc-<schema>` sono scartabili.

---

## 41. Script di installazione per ambiente COLLAUDO

**Stato:** Proposta
**Data proposta:** 2026-07-23
**Impatto:** Medio (~1 giornata)
**Dipendenza:** proposta #40 (radice MinIO `dc-coll-`) va introdotta insieme — altrimenti Coll condivide i bucket documenti con Dev e/o Prod.

### Host confermato
`192.168.0.72` — stesso Docker host di Prod (il `.71` nel messaggio originale era un refuso). Container Docker separato, porta pubblicata `8082`.

### Problema
Oggi esiste solo la coppia `install.sh` + `setup.sh` + `docker-compose.yml`, scritta e fissata per **Prod**: cartella fissa `~/docker/dentalcarepro`, DB `dentalcare_prod`, container `dentalcarepro-backend`/`dentalcarepro-frontend`/`dentalcare-ai-service`, porta `8181`. Non esiste un equivalente per COLLAUDO. Riusando `docker-compose.yml` così com'è in una seconda checkout sulla stessa macchina, i `container_name` **hardcoded** collidono con quelli di Prod già in esecuzione sullo stesso Docker host — impossibile avviare entrambi gli stack insieme (i nomi container sono unici per host Docker, indipendentemente dalla cartella).

### Soluzione: stack Docker Compose parallelo, isolato per nome e porta

`docker-compose.yml` / `install.sh` / `setup.sh` di Prod restano **invariati** (sono collaudati e in uso — CLAUDE.md §23 vieta refactoring non necessario su codice che funziona). Si aggiunge un set analogo, a fianco, per Coll.

#### Fase 1 — Nuovo profilo Spring `coll`

**Nuovo `backend/src/main/resources/application-coll.properties`**, ricalcato su `application-prod.properties`:
```properties
spring.datasource.url=jdbc:postgresql://192.168.0.173:5432/dentalcare_coll
spring.datasource.username=postgres
spring.flyway.enabled=false
app.flyway.schemas=dentalcare
app.flyway.baseline-version=4
app.flyway.locations=classpath:db/migration
server.port=8080
app.ai.base-url=http://dentalcare-ai-service:8000
app.minio.bucket-prefix=dc-coll-

# Demo mode: OFF — confermato 23/07/2026, come prod (Coll non deve esporre credenziali demo in chiaro sulla rete .72)
app.demo.enabled=false

# Log/errori: stile dev — confermato 23/07/2026, per diagnosi rapida durante il collaudo
server.error.include-message=always
server.error.include-binding-errors=always
logging.level.root=INFO
logging.level.com.dentalcare=DEBUG
```

**Nuovo `config/application-coll.properties.example`** (root repo, stesso pattern di `application-prod.properties.example`): placeholder per password DB, JWT secret, `app.encryption.master-key` **diversi** da quelli prod — se condivisi, un bug in Coll potrebbe leggere/scrivere dati cifrati con la stessa chiave di prod.

#### Fase 2 — `docker-compose.coll.yml` (nuovo file, root repo)

Copia di `docker-compose.yml` con differenze minime:
- `container_name`: `dentalcarepro-coll-backend`, `dentalcarepro-coll-frontend`, `dentalcare-coll-ai-service` (nessuna collisione con Prod sullo stesso host).
- `environment: SPRING_PROFILES_ACTIVE=coll`.
- porta frontend: `"${FRONTEND_PORT:-8082}:4200"` (default 8082, da `.env` proprio della cartella Coll).
- `image:` tag distinto (es. `dentalcarepro-backend:coll-${VERSION:-latest}`) per non confondersi con le immagini `:latest` di prod nella cache Docker locale dello stesso host.
- rete `minio`: **stessa rete esterna** `minio_default` di Prod — Coll usa lo stesso MinIO fisico, isolato via bucket-prefix `dc-coll-` (proposta #40), non via rete separata.
- rete bridge interna: nessuna modifica necessaria — Compose la prefissa col nome cartella (`dentalcarepro-coll_dentalcarepro`), già diverso da quello di Prod.

#### Fase 3 — `setup-coll.sh` + `install-coll.sh` (nuovi, root repo)

Copie parametrizzate 1:1 di `setup.sh`/`install.sh`, con le costanti cambiate:

| Costante | Prod (esistente) | Coll (nuovo) |
|---|---|---|
| `DEPLOY_DIR` | `~/docker/dentalcarepro` | `~/docker/dentalcarepro-coll` |
| `BACKEND_CONTAINER` (healthcheck) | `dentalcarepro-backend` | `dentalcarepro-coll-backend` |
| DB | `dentalcare_prod` | `dentalcare_coll` |
| Config file | `config/application-prod.properties` | `config/application-coll.properties` |
| Compose file | `docker-compose.yml` | `docker-compose.coll.yml` (`docker compose -f docker-compose.coll.yml ...`) |
| `.env` default | `FRONTEND_PORT=8181` | `FRONTEND_PORT=8082` |
| URL stampato a fine deploy | `http://<host>:8181/` | `http://<host>:8082/` |

`install-coll.sh` mantiene la stessa logica di `install.sh` (clone/pull, config da `.example`, prompt di conferma per (ri)creare il DB da `database/install.sql -v dbname=dentalcare_coll`, copia modelli AI ONNX, `docker compose -f docker-compose.coll.yml up -d --build`, healthcheck, stampa URL) — deliberatamente una **copia parametrizzata**, non una riscrittura, per non introdurre comportamenti diversi da Prod senza motivo.

#### Fase 4 — Deploy directory separata sulla stessa macchina .72

`~/docker/dentalcarepro-coll/` come clone **indipendente** del repo (stesso meccanismo di `setup.sh`: cartella vuota → clone; esistente → pull). Path diverso da `~/docker/dentalcarepro` → nessun rischio di sovrascrittura reciproca di `config/` o `.env` tra i due ambienti.

#### Fase 5 — Database

Nuovo DB `dentalcare_coll` su `192.168.0.173` (stesso host Postgres di dev/prod), creato con lo script parametrico esistente — nessuna modifica a `install.sql`, già parametrico su `dbname`:
```bash
psql -U postgres -h 192.168.0.173 -d postgres -v dbname=dentalcare_coll -f database/install.sql
```

### File coinvolti
| Layer | File |
|---|---|
| Backend | nuovo `application-coll.properties` |
| Config template | nuovo `config/application-coll.properties.example` |
| Docker | nuovo `docker-compose.coll.yml` |
| Script | nuovo `setup-coll.sh`, nuovo `install-coll.sh` |
| Doc | aggiornare `directives/deploy-procedures.md` con un terzo trigger ("deploy in collaudo") + nuovo `directives/manuale-installazione-coll.md` |
| Nessuna modifica | `docker-compose.yml`, `install.sh`, `setup.sh`, `database/install.sql` |

### Note
- **Dipende da #40**: senza radice MinIO separata, Coll condivide i bucket documenti con Dev e/o Prod (stesso MinIO fisico `.72:9000`).
- **Confermato 23/07/2026**: nessun flusso n8n/Retell dedicato a Coll — è solo stack web (BE+FE+AI+DB). Il collaudo telefonico resta su Dev/Prod. Se servirà in futuro, è un'estensione separata (nuovo numero + agente Retell + workflow n8n puntato a `:8082`), fuori da questa proposta.
- Immagini Docker `:coll-*` vanno pulite periodicamente (`docker image prune`) come già per `:latest` — nessuna differenza operativa da Prod.
- Il gate di go-live (`piano-lungo-termine.md` §5) resta invariato: Coll è un ambiente di test, non abilita l'uso su pazienti reali.

---

## 42. Visibilità dati clinici per ruolo: igienista/dentista/chirurgo/ortodontista vedono tutti i pazienti

**Stato:** Proposta
**Data proposta:** 2026-07-23
**Impatto:** Medio (~1 giornata)
**Priorità:** da fare **prima** di #40/#41 (richiesto dal committente 23/07/2026)

### Situazione attuale (verificata sul codice)
Oggi i ruoli clinici (dentist/hygienist/orthodontist/surgeon) sono **auto-filtrati sul proprio `providerId`** in più punti:
- Backend: `AppointmentService.java:57-70` definisce `callerIsMedical()`/`callerProviderId()`; tre volte (`:75,113,152`) applica `effectiveProviderId = callerIsMedical() ? callerProviderId() : providerId` — un ruolo clinico non può vedere gli appuntamenti/pazienti di un collega anche passando un `providerId` diverso.
- Frontend: `user-context.service.ts:21-33`, segnale `filterProviderId` — oggi restituisce l'id proprio se `role() === 'doctor' || role() === 'hygienist'` (il tipo `UserRole` collassa dentist/orthodontist/surgeon tutti su `'doctor'`), altrimenti `null`. Consumato da `dashboard.component.ts:39`, `agenda.component.ts:135,181`, `paziente-detail.component.ts:202,218`, `pazienti.component.ts:28,43,80,91,98`, `preventivi.component.ts:45`, `fatturazione.component.ts:107`.
- `PatientService.findAll/findById` (backend) **non** ha invece alcun lock-in server-side: il filtro è già opzionale lì. Il "self-only" è quindi imposto solo per gli appuntamenti (backend) e per la UI (frontend), non uniformemente.
- **Nessun `@PreAuthorize`/controllo di ruolo esiste in scrittura**: `OdontogramController.save` non ha alcun controllo di ruolo — un igienista può **già oggi** modificare l'odontogramma di qualunque paziente lato API. L'unico gate di ruolo trovato è nel layer AI chat (`DentalCareAiTools.java`, `isMedical()`), che blocca solo la segretaria dai tool clinici — l'igienista già passa quel controllo. **Quindi il punto (a) "l'igienista può modificare i dati" non richiede sblocco backend**, solo verifica che non ci sia un vincolo `disabled`/`readonly` lato frontend legato al ruolo (da grep mirato in fase di implementazione — non ancora verificato).

### Debito tecnico da sanare comunque
`isMedical`/`MEDICAL_ROLES` è definito **3 volte indipendenti**, con un commento nel codice che segnala la necessità di tenerle sincronizzate a mano: `DentalCareAiTools.java:97-98`, `AppointmentService.java:52-55`, `user-context.service.ts:7`. Prima di modificare la logica di filtro conviene unificarle in un'unica fonte, altrimenti il rischio è di sistemare un punto e lasciarne un altro incoerente.

### Soluzione

#### Fase 1 — Fonte unica dei ruoli clinici
Backend: nuova costante condivisa (es. `RoleConstants.MEDICAL_ROLES`) usata sia da `AppointmentService` sia da `DentalCareAiTools`, al posto dei due `Set.of(...)` duplicati.
Frontend: `MEDICAL_JWT_ROLES` in `user-context.service.ts:7` resta l'unica fonte lato FE (già corretta, il collasso dentist/orthodontist/surgeon→`'doctor'` è solo un raggruppamento per label UI e non cambia con questa proposta).

### Decisione del committente (23/07/2026): impostazione per-tenant, non rimozione secca
Non si elimina il comportamento attuale — si aggiunge una **modalità configurabile** in Impostazioni Studio, coerente con lo stesso pattern già usato/pianificato per `billing_mode` (#44):

| Valore | Etichetta UI | Comportamento |
|---|---|---|
| `per_provider` (default — **comportamento odierno**, zero impatto finché non si cambia) | **"Modalità di gestione pazienti per medico"** | Ogni ruolo clinico vede/gestisce solo i propri pazienti (comportamento attuale) |
| `shared` | **"Modalità di gestione pazienti condivisi"** | Tutti i ruoli clinici (dentist/hygienist/orthodontist/surgeon) vedono/gestiscono tutti i pazienti dello studio, cartella clinica inclusa |

Default `per_provider` = nessuna regressione per chi non tocca l'impostazione; lo switch a `shared` è una scelta esplicita e reversibile dello studio.

#### Fase 2 — DB + Backend: enforcement guidato dalla nuova impostazione
```sql
ALTER TABLE clinics
    ADD COLUMN IF NOT EXISTS patient_visibility_mode text NOT NULL DEFAULT 'per_provider'
        CHECK (patient_visibility_mode IN ('per_provider', 'shared'));
```
- `AppointmentService.java:75,113,152`: l'override esistente non si elimina, si **condiziona** alla nuova impostazione — `effectiveProviderId = (mode == 'per_provider' && callerIsMedical()) ? callerProviderId() : providerId`.
- `PatientService.findAll/findById`: **oggi non ha alcun lock-in server-side** (l'agente di ricerca l'ha confermato: il self-only per i pazienti è oggi solo una convenzione frontend, aggirabile da un client che non manda `providerId`). Per rendere l'impostazione una garanzia reale e non solo un default di UI, va aggiunto **qui per la prima volta** lo stesso enforcement condizionato — altrimenti "modalità per medico" non sarebbe davvero applicata lato server, riaprendo esattamente il rischio già segnalato in **#24** (`?providerId=` non è autorizzazione).

> Nota residua su **#14** (GAP P0, *"relazione di cura come filtro di autorizzazione"*): il conflitto con quella voce di roadmap ora si manifesta **solo per i tenant che scelgono esplicitamente `shared`** — il default resta compatibile con #14. Da riconciliare comunque quando/se un tenant in modalità `shared` rientra anche nel perimetro di conformità cartella-clinica (#18/#21): a quel punto la scelta "vedono tutti" e "serve relazione di cura per accedere" tornano incompatibili e va deciso quale vince.

#### Fase 3 — Frontend: `filterProviderId` legge l'impostazione di tenant
`user-context.service.ts:21-33`: il segnale smette di dipendere solo dal ruolo e legge anche `clinicSettings.patientVisibilityMode` (nuovo campo, da `GET /settings/clinic`) — se `per_provider`, comportamento identico a oggi (self per ruoli clinici); se `shared`, `null` (nessun filtro) per tutti i ruoli clinici.

Resta valida la distinzione già individuata con la fatturazione: **anche in modalità `shared`**, `preventivi.component.ts:45`/`fatturazione.component.ts:107` **non** seguono questo segnale — restano legati a `billingProviderId` (comportamento self, #30/#35 già Fatta), governato separatamente da `billing_mode` in #44. Visibilità pazienti/cartella clinica e attribuzione di preventivi/fatture sono due impostazioni indipendenti, anche se entrambe finiscono nella stessa schermata Impostazioni Studio.

#### Fase 4 — Agenda: segue la stessa impostazione, per coerenza
Essendo ora un'opzione esplicita e reversibile (non una rimozione definitiva), `agenda.component.ts:135,181` può seguire lo stesso `patientVisibilityMode` per coerenza con il resto della UI: `per_provider` → agenda self di default (comportamento attuale); `shared` → agenda mostra tutti i medici/poltrone senza filtro iniziale (restando comunque possibile filtrare manualmente). Da confermare in fase di implementazione se questo è il comportamento desiderato per l'agenda specificamente, ma non è più bloccante come nella versione precedente di questa proposta.

#### Fase 5 — Verifica scrittura igienista (punto a)
Grep mirato su `paziente-detail.component.html`/`odontogramma-tab.component.html`/`cartella-tab.component.html` per condizioni `role === ...` che disabilitano campi — se trovate e limitano l'igienista, rimuoverle. Se non trovate (come suggerisce l'assenza di `@PreAuthorize` lato backend), nessuna modifica necessaria: la scrittura è già aperta **indipendentemente dalla modalità di visibilità** (leggere non è scrivere: la modalità `per_provider` limita quali pazienti l'igienista vede, non se può modificarli una volta aperti).

#### Fase 6 — Impostazioni Studio: nuovo campo UI
`impostazioni.component.ts/html`, stessa area dove #44 aggiunge "Modalità di fatturazione": nuovo select "Modalità di gestione pazienti" con le due opzioni della tabella sopra, `PUT /settings/clinic` (`patientVisibilityMode`).

### File coinvolti
| Layer | File |
|---|---|
| DB | nuova migration (`clinics.patient_visibility_mode`) + `install.sql` |
| Backend | `AppointmentService.java` (override condizionato, 3 punti), `PatientService.java` (**nuovo** enforcement condizionato, oggi assente), nuova costante ruoli condivisa, `DentalCareAiTools.java` (usa la costante condivisa), `ClinicSettingsController` (campo `patientVisibilityMode`) |
| Frontend | `user-context.service.ts` (segnale legge l'impostazione), `dashboard.component.ts`, `pazienti.component.ts`, `paziente-detail.component.ts`, `agenda.component.ts` (Fase 4), `impostazioni.component.ts/html` (Fase 6) |
| Nessuna modifica | `preventivi.component.ts`, `fatturazione.component.ts` (restano su `billingProviderId`, gestiti da #44) |

### Note
- Default `per_provider` = nessun impatto per gli studi che non toccano l'impostazione — riduce il rischio del conflitto con #14 a un caso opt-in, non più strutturale.
- L'igienista che modifica dati clinici (punto a) è già tecnicamente permesso oggi lato API, in entrambe le modalità — il gap, se esiste, è solo nel frontend (da verificare, Fase 5).
- `PatientService` guadagna per la prima volta un enforcement server-side reale (Fase 2) — oggi non ce l'ha nemmeno in modalità "per medico": è un rafforzamento di sicurezza collaterale a questa proposta, non solo un nuovo comportamento per `shared`.

---

## 43. Anamnesi: severità a 3 livelli, storico con diff, alert clinici collegati al catalogo, vincolo appuntamento fine giornata

**Stato:** Confermata (23/07/2026)
**Data proposta:** 2026-07-23
**Impatto:** Alto (~3.5-4.5 giornate — rivisto al rialzo due volte il 23/07/2026: 1) migrazione schema globale→per-tenant, 2) ricognizione/ricostruzione contenuto catalogo [6 agenti di ricerca già eseguiti] + storico anamnesi con diff sintetico, entrambe confermate dal committente)
**Priorità:** da fare **prima** di #40/#41 (richiesto dal committente 23/07/2026)

### Correzione alla premessa: il CRUD esiste già
Il CRUD delle voci di anamnesi **non manca** — è già implementato e funzionante:
- DB: `dentalcare.anamnesis_categories` + `dentalcare.anamnesis_items` (`install.sql:2069,2086`), con colonna `is_alert boolean` (`:2092`). Tabelle oggi **globali** (schema condiviso `dentalcare`, non per-tenant) — **confermato dal committente il 23/07/2026: il catalogo deve essere per-tenant** (ogni studio le proprie voci). Vedi Fase 1 sotto per la migrazione.
- Backend: `AnamnesisCatalogController.java` — REST CRUD completo (`GET/POST/PUT/DELETE /api/admin/anamnesis/categories` e `/items`).
- Frontend: `impostazioni.component.ts` — sotto-tab "Anagrafiche → Anamnesi" (righe 68, 181-186, metodi CRUD 417-584), con toggle booleano `isAlert` per voce.

### Il gap reale: gli alert clinici sono disconnessi dal catalogo
`cartella-tab.component.ts:99-113` (`get alerts()`) e `dashboard.component.ts:150` (`hasAllergyAlert`/`hasMedicationAlert`) leggono **colonne booleane hardcoded** di `patient_anamnesis` (`allergie`, `takingAnticoagulants`, `takingBisphosphonates`, `heartDisease`, `hypertension`, `diabetes`) — **non** passano mai da `anamnesis_items.is_alert` né da `patient_anamnesis_item_selections` (la tabella che collega paziente↔voce di catalogo, `install.sql:666/2561`). Conseguenza pratica: se un admin aggiunge oggi una voce di anamnesi custom con `is_alert=true` dalle Impostazioni, **non comparirà mai** in "Alert clinici" da nessuna parte — il flag esiste solo nel catalogo, la UI degli alert non lo legge. Questo è il difetto da risolvere, non l'assenza di CRUD.

### Rischio trovato: cancellazione voce/categoria — verificato sul codice (risposta alla domanda posta)
**Sì, la cascade a DB esiste**, ma è più pericolosa di quanto sembri:
```sql
-- install.sql:6669-6670 (globale)
anamnesis_items.category_id  → anamnesis_categories(id)  ON DELETE CASCADE
-- install.sql:1667 / 7166 (per-tenant, sia dev sia ogni schema tenant)
patient_anamnesis_item_selections.item_id → dentalcare.anamnesis_items(id)  ON DELETE CASCADE
```
Quindi cancellare una **categoria** cancella a cascata tutte le sue **voci**, che a loro volta cancellano a cascata **tutte le selezioni paziente** che le usavano — nessun vincolo FK bloccante, nessun errore. Il problema non è l'integrità referenziale (quella è a posto), è che:
1. **`AnamnesisCatalogService.deleteCategory()`/`deleteItem()`** (righe 84-87, 150-154) fanno un `DELETE` diretto, **senza controllare prima quanti pazienti usano quella voce** e senza mostrare alcun avviso in UI — un admin può cancellare "Diabete" e azzerare silenziosamente lo storico anamnestico di ogni paziente che lo aveva, **senza possibilità di recupero** (hard delete, non soft delete).
2. **Il catalogo è globale, non per-tenant** (schema `dentalcare`, non `t_XXXX`) mentre l'endpoint è raggiungibile da un ruolo **`TENANT_ADMIN`** (`SecurityConfig`: `/api/admin/**` → `hasAnyRole("ADMIN","TENANT_ADMIN")`, nessuno scoping al tenant chiamante). **Un admin di UN singolo studio può quindi cancellare, con cascata fino ai pazienti, una voce usata anche da pazienti di ALTRI studi** — non è solo un problema di UX, è un problema di isolamento multi-tenant. **Risolto strutturalmente dalla Fase 1** (catalogo spostato per-tenant, 23/07/2026): una volta che ogni studio ha la propria copia delle tabelle nel proprio schema, un `TENANT_ADMIN` può fisicamente incidere solo sui dati del proprio tenant — il raggio d'azione cross-tenant sparisce da solo. Il rischio "delete silenzioso senza controllo" (punto 1) resta comunque, **entro** il proprio tenant, e va corretto lo stesso.

**Confermato dal committente (23/07/2026) — resta nella Soluzione (Fase 2, punto 0, precede la severità):**
- `deleteCategory`/`deleteItem`: **prima** del delete, contare le selezioni pazienti collegate (`SELECT count(*) FROM ... WHERE item_id = ...`); se `count > 0`, il DELETE va **rifiutato** (409) con messaggio che indica quanti pazienti sarebbero impattati — mai un delete silenzioso di dati clinici.
- Sostituire il DELETE fisico con **soft-delete** (`enabled = false`, colonna già presente) come via primaria per "rimuovere" una voce dall'uso futuro; il DELETE fisico resta disponibile solo per voci mai utilizzate (count=0), coerente con CLAUDE.md §7.4/§11 (niente cancellazioni distruttive senza rete di sicurezza).

### Ricognizione contenuto catalogo — esito verifica di 6 agenti di ricerca (23/07/2026)
Per rispondere alla domanda "le voci sono uniche, complete, categorizzate correttamente" ho fatto verificare il catalogo attuale — due batch di seed (06/05/2026 e 25/05/2026) mai riconciliati tra loro — da 6 agenti indipendenti con ricerca web, uno per dominio clinico. Risultato: **duplicazione sistemica confermata**. Quasi ogni categoria del batch B duplica concettualmente una del batch A, spesso con `is_alert` **discordante sullo stesso concetto** (es. "Anticoagulanti" è alert=true nel batch A e alert=false nel batch B) — non solo nomi diversi, un difetto di dato reale che avrebbe fatto sparire/comparire alert clinici a seconda di quale dei due duplicati un tenant avesse selezionato.

| Dominio | Duplicati trovati | Voci mancanti importanti (con fonte, vedi ricerca) | Mis-categorizzazioni |
|---|---|---|---|
| Allergie | 6 concetti duplicati, `alert` discordante su 4 | Clorexidina (anafilassi documentata, uso quotidiano), solfiti dell'anestetico (≠ sulfamidici, confusione lessicale comune), iodio, altri antibiotici oltre penicillina | "Metalli dentali"/Nickel da unificare; Acrilico/Metacrilato è duplicato puro (stesso allergene) |
| Farmaci | 7 duplicati su 15, `alert` discordante su 5 | **Denosumab** (stesso rischio ONJ dei bifosfonati, farmaco più recente — assente dal catalogo), antiangiogenetici, farmaci che causano iperplasia gengivale | Nessuna, solo duplicazione |
| Cardiovascolare | "Cardiopatia" triplicata con codici diversi; pacemaker/valvole duplicati | **Endocardite infettiva pregressa** — priorità #1 per profilassi secondo ESC 2023, oggi completamente assente; cardiopatia congenita; fibrillazione atriale | Cardiochirurgia va raggruppata col Cardiovascolare, non in "Chirurgia" generica; "Bypass" non giustifica profilassi endocardite (motivazione esistente errata) |
| Sistemiche (respiratorio/endocrino/renale/epatico/onco/neuro) | Categoria "Malattie Sistemiche" è quasi interamente un doppione ridondante delle categorie per apparato dello stesso batch | **Neurologico assente del tutto** (Parkinson, sclerosi multipla), coagulazione solo generica (manca emofilia/trombocitopenia), diabete/tiroide "non specificato" per triage rapido | "Malattie Sistemiche" da eliminare come contenitore ridondante — tenere solo le categorie per apparato |
| Abitudini/chirurgia pregressa | 3 duplicati | Vaping/sigaretta elettronica (raccomandato esplicitamente da ADA come voce distinta dal fumo), splenectomia/asplenia | **"Sportivo agonista" non è un'abitudine — è un fattore di rischio traumatico**, categoria sbagliata |
| Condizioni/gravidanza/psicologico | Gravidanza duplicata con `alert` discordante; "Apnea notturna" duplicata col dominio respiratorio | Trimestre di gravidanza come campo strutturato (non solo testo libero), scale di ansia validate (MDAS), sedazione cosciente pregressa | **"Sintomi Attuali" (dolore, gonfiore, urgenza) non è anamnesi — è motivo della visita/triage del giorno**, andrebbe tenuto fuori dal questionario anamnestico vero e proprio |

**Finding critico — già discusso e deciso col committente**: il criterio "Severa = fine giornata" non può basarsi su diagnosi croniche/stato sierologico (es. HIV) — le precauzioni universali CDC prescrivono di trattare **ogni** paziente allo stesso modo indipendentemente dallo stato noto, e un precedente legale USA (DOJ vs Woodlawn Family Dentistry, violazione ADA Title III) conferma che pianificare appuntamenti in base a una diagnosi nota è discriminatorio, non solo eticamente discutibile. **Confermato dal committente (23/07/2026): "Severa" si basa su stati clinici oggettivi e contingenti** (es. un'infezione attiva il giorno della visita), non su diagnosi permanenti — con l'implicazione diretta che serve uno **storico** delle anamnesi per sapere cosa è vero *ora* rispetto a prima (Fase 3 sotto, anch'essa confermata dal committente).

### Soluzione

#### Fase 1 — DB: migrazione catalogo da globale a per-tenant (nuova, 23/07/2026)
Meccanismo verificato: ogni tabella per-tenant (es. `service_catalog`/`service_categories`, già nel pattern giusto) è definita una volta nel template DDL dentro `dentalcare.create_tenant()` (`install.sql:291` — funzione che costruisce dinamicamente lo schema `t_XXXX` per un nuovo tenant) e materializzata come copia fisica in ogni schema tenant (es. `t_9d754153.service_catalog`, `install.sql:2949`). Il catalogo anamnesi va allineato allo stesso pattern:

1. Aggiungere `CREATE TABLE anamnesis_categories`/`anamnesis_items` (struttura identica alle attuali `dentalcare.anamnesis_categories`/`items`, incluso il nuovo campo `severity` della Fase 2) al template DDL dentro `create_tenant()`.

**Valorizzazione di default per i nuovi tenant — confermato dal committente 23/07/2026:**
**Hardcoded, non copia dal demo a runtime.** Verificato sul codice: `create_tenant()` (`install.sql:291-1823`) oggi **non** seeda affatto `service_catalog`/`service_categories` per un tenant nuovo — quelle tabelle nascono vuote, lo studio costruisce da zero il proprio listino via CRUD. Non c'è quindi un precedente di "copia automatica da un tenant di riferimento" nel codice — se lo introducessimo per l'anamnesi, sarebbe un pattern nuovo, e copiare **dal tenant demo specificamente** ha un problema concreto: il tenant demo (`t_9d754153`) è un ambiente vivo usato per presentazioni/screenshot, con dati che nel tempo derivano (vedi storico: poltrone duplicate, credenziali normalizzate ecc. — non è un fixture stabile). Se il provisioning di un cliente vero dipendesse dal contenuto attuale del demo, un'alterazione del demo per uno screenshot si propagherebbe silenziosamente a ogni nuovo studio reale creato dopo.

**Congelare il contenuto attuale** di `dentalcare.anamnesis_categories`/`items` (la lista oggi in uso, già ragionevole — allergie, cardiopatia, diabete, anticoagulanti, bifosfonati, ecc.) in una lista statica di `INSERT` letterali, incorporata **sia** nel DDL di `create_tenant()` (per i nuovi tenant) **sia** nello script di migrazione dei tenant esistenti (Fase 1 punto 2 sotto) — un'unica fonte di dati di partenza, scritta una volta, versionata su git, non ricalcolata a ogni provisioning. Da quel momento il demo è solo *uno dei* tenant con quella lista come punto di partenza, non la fonte da cui gli altri dipendono. Ogni studio (demo incluso) la personalizza poi in autonomia dalle Impostazioni, senza propagare nulla agli altri.
2. **Migrazione dei tenant esistenti** (script una tantum, non idempotente da rieseguire): per ogni schema `t_XXXX` già presente, creare le tabelle e inserire la stessa lista statica di cui sopra come seed iniziale (stessa lista per tutti, congelata dal contenuto oggi in `dentalcare.anamnesis_categories`/`items` — punto di partenza identico, poi ogni studio la personalizza in autonomia).
3. **Ripuntare la FK**: `patient_anamnesis_item_selections.item_id` referenzia oggi esplicitamente `dentalcare.anamnesis_items(id)` (`install.sql:1667/7166`) — va cambiata per puntare a `anamnesis_items(id)` nello **stesso schema tenant** (non più schema-qualificata verso `dentalcare`). Va fatta in ordine: creare le tabelle per-tenant (punto 1-2) **prima** di droppare/ricreare questa FK, altrimenti la constraint fallisce per righe orfane durante la transizione.
4. Le vecchie `dentalcare.anamnesis_categories`/`items` (globali) restano temporaneamente come riferimento storico/rollback, poi vanno droppate in una slice successiva a migrazione verificata (non nella stessa release, per avere un percorso di rollback se qualcosa va storto).
5. Backend: `AnamnesisCatalogService` oggi usa `dentalcare.anamnesis_categories`/`items` come prefisso **hardcoded** nelle query JDBC — va cambiato per usare `TenantContext.validatedSchema()` come prefisso schema, esattamente come già fa `ServiceCatalogService` (`s() { return TenantContext.validatedSchema(); }`, usato per ogni query). Stesso pattern, non un'invenzione nuova.
6. `install.sql`: le due occorrenze (template `create_tenant` + istanza `t_9d754153`) vanno aggiornate insieme, come da convenzione già in uso per le altre tabelle per-tenant.

#### Fase 2 — DB: ricostruzione contenuto catalogo + severità a 3 livelli
Non è più un semplice `ALTER TABLE`: la ricognizione (sopra) ha trovato duplicazione sistemica e voci mancanti, quindi questa fase deduplica, aggiunge le voci mancanti trovate, corregge le mis-categorizzazioni e **poi** applica la severità — tutto nel nuovo schema per-tenant (dopo la Fase 1).

```sql
ALTER TABLE anamnesis_items    -- schema per-tenant, dopo la Fase 1
    ADD COLUMN IF NOT EXISTS severity text NOT NULL DEFAULT 'normale'
        CHECK (severity IN ('normale', 'grave', 'severa'));
```
Deduplicazione: per ogni coppia di duplicati trovati nella ricognizione, **soft-disable** (`enabled=false`) di uno dei due (mai delete fisico se già in uso da qualche tenant esistente, coerente col rischio-cancellazione trovato sopra) tenendo quello con la descrizione/struttura migliore secondo l'agente di dominio. Le voci mancanti trovate vanno aggiunte come nuovi item. Il seed statico finale (Fase 1) incorpora già la versione ricostruita, non quella originale con i duplicati.

`is_alert` **non** va droppato subito ma diventa ridondante rispetto a `severity`; da marcare deprecato e rimuovere in una slice successiva quando confermato inutilizzato.

Semantica di `severity` (aggiornata 23/07/2026 dopo la decisione sul criterio):
| Severità | Effetto |
|---|---|
| Normale | Nessuna visualizzazione tra gli alert |
| Grave | Visualizzata in "Alert clinici" (dashboard + cartella paziente), nessun vincolo di scheduling — assegnata nel seed a tutte le voci con giudizio "sì" dagli agenti di ricerca (allergie critiche, anticoagulanti/bifosfonati/denosumab, cardiopatie a rischio endocardite, immunosoppressione, oncologia attiva, coagulopatie, gravidanza/allattamento, ecc.) |
| Severa | Visualizzata in "Alert clinici" **e** vincola gli appuntamenti del paziente a **solo fine giornata** — **nessuna voce del catalogo di base viene precompilata Severa** nel seed statico (coerente con la decisione: nessuna diagnosi cronica la giustifica di per sé). Resta un valore selezionabile per stati contingenti che ogni studio marca a runtime (richiede lo storico — Fase 3) |

#### Fase 3 — Storico anamnesi e diff sintetico (nuova, confermata dal committente 23/07/2026)
Un criterio "Severa" a stato contingente è inutile senza sapere cosa è vero *ora* rispetto all'ultima visita. Oggi `patient_anamnesis_item_selections` **non è uno storico**: un solo record per `(clinic_id, patient_id, item_id)` (`install.sql:1223`, vincolo UNIQUE) — ogni aggiornamento sovrascrive, nessuna traccia di "da quando" o "fino a quando" una condizione è stata vera.

```sql
-- schema per-tenant, dopo la Fase 1
ALTER TABLE patient_anamnesis_item_selections
    ADD COLUMN IF NOT EXISTS resolved_at timestamptz;  -- NULL = condizione tuttora attiva

-- il vincolo UNIQUE esistente va sostituito da un indice unico PARZIALE:
-- al più una riga ATTIVA per item/paziente, righe storiche risolte multiple ammesse
ALTER TABLE patient_anamnesis_item_selections DROP CONSTRAINT patient_anamnesis_item_selections_unique;
CREATE UNIQUE INDEX ux_pais_active ON patient_anamnesis_item_selections (clinic_id, patient_id, item_id)
    WHERE resolved_at IS NULL;
```
Regole operative:
- **Nuova selezione** = sempre `INSERT` (mai `UPDATE` che sovrascrive) — se la voce era già stata registrata e risolta in passato, la nuova occorrenza è una riga nuova: sappiamo che è ricomparsa, non solo che "è vera adesso".
- **Rimozione/risoluzione** = mai `DELETE` — `UPDATE ... SET resolved_at = now()` sulla riga attiva.
- **Stato corrente** (quello che la UI mostra oggi implicitamente) = `WHERE resolved_at IS NULL`.
- **Storico completo** = tutte le righe ordinate per `recorded_at`.

**Diff sintetico**: nuovo endpoint (es. `GET /api/patients/{id}/anamnesis/diff`) che confronta le voci attive **ora** con quelle attive **alla data dell'ultimo aggiornamento anamnesi precedente**, restituendo *Nuove* / *Risolte* / *Invariate*. UI: badge sintetico in cartella paziente (es. "3 nuove · 1 risolta dall'ultima visita"), espandibile allo storico completo.

**Convergenza con la roadmap esistente**: questo lavoro anticipa/assorbe in larga parte l'intervento 8 del Blocco 2 GAP P0 (*"Anamnesi tri-stato + fonte, data rilevazione, data risoluzione"*, già nel piano cartella-clinica) — stesso concetto di data-rilevazione/data-risoluzione qui implementato come `recorded_at`/`resolved_at`. Da riconciliare con `piano-lungo-termine.md` in fase di esecuzione per non duplicare lavoro: probabile che questa Fase 3 chiuda anche quella voce di roadmap.

#### Fase 4 — Backend: collegare davvero gli alert al catalogo
1. Vista `v_patient_max_anamnesis_severity(patient_id, max_severity)`: `MAX` di `severity` (ordinata normale < grave < severa) tra le voci **attive** (`resolved_at IS NULL`, Fase 3) in `patient_anamnesis_item_selections`, join `anamnesis_items`.
2. `AnamnesisCatalogController`/DTO: sostituire `isAlert` boolean con `severity` (Create/UpdateCatalogItemRequest, CatalogItemDto).
3. Endpoint paziente (dashboard/cartella) che oggi calcola gli alert lato SQL/service dalle colonne hardcoded: **riscrivere** per includere anche il risultato di `v_patient_max_anamnesis_severity` — non sostituire le colonne di sistema esistenti (allergie/anticoagulanti/ecc. restano, sono voci "di sistema" preesistenti), ma **unire** le voci custom del catalogo. Le colonne di sistema legacy vanno trattate come severità 'grave' implicita finché non si decide di migrarle anch'esse a righe `patient_anamnesis_item_selections` vere e proprie (fuori scope minimo di questa proposta, da valutare).
4. `AppointmentService.findAvailability` (`:580` circa) — oggi non riceve `patientId`. Aggiungere il parametro; se `v_patient_max_anamnesis_severity(patientId) = 'severa'`, filtrare gli slot proposti a quelli entro l'ultima fascia della giornata (configurabile, es. ultimi N slot prima di `clinics.work_end_time`).
5. Creazione manuale appuntamento (non solo via `/availability`): validazione server-side equivalente — se paziente 'severa' e lo slot richiesto non è a fine giornata → **422** con messaggio esplicito (altrimenti la segreteria può bypassare la constraint scegliendo uno slot a mano, vanificando la Fase 4 punto 4).

#### Fase 5 — Frontend
- Impostazioni → Anamnesi: sostituire il toggle `isAlert` con un select a 3 valori, con testo esplicativo per "Severa" (vincolo fine giornata, richiede motivazione contingente non diagnosi permanente).
- `cartella-tab.component.ts`/`dashboard.component.ts`: estendere `get alerts()` per includere le voci custom da catalogo (via nuovo endpoint/vista), non solo le colonne hardcoded.
- **Nuovo**: badge/riepilogo diff sintetico in cartella paziente (Fase 3) — "N nuove · M risolte dall'ultima visita".
- Form nuovo appuntamento/agenda: se il backend rifiuta uno slot per vincolo di severità, messaggio chiaro ("Paziente con condizione a rischio infettivo attiva — disponibili solo slot di fine giornata"), non un generico errore di validazione.

### File coinvolti
| Layer | File |
|---|---|
| DB | migrazione schema globale→per-tenant (Fase 1) + deduplicazione/nuove voci/severity (Fase 2) + storico `resolved_at`/indice parziale (Fase 3) + `install.sql` (template + istanza `t_9d754153`) + nuova vista + nuova query diff |
| Backend | `AnamnesisCatalogController/Service` (**+ passaggio a `TenantContext.validatedSchema()`**, oggi hardcoded su `dentalcare.`), `CatalogItemDto`/`Create-`/`UpdateCatalogItemRequest`, nuovo endpoint diff anamnesi, endpoint alert dashboard/cartella (individuare il service esatto in fase di implementazione), `AppointmentService.findAvailability` + creazione manuale appuntamento |
| Frontend | `impostazioni.component.ts/html` (select severità), `cartella-tab.component.ts`, `dashboard.component.ts` (+ badge diff), componente nuovo appuntamento/agenda (gestione errore 422) |

### Note
- **Confermato dal committente (23/07/2026)**: catalogo per-tenant (non più globale, Fase 1); seed statico congelato dal contenuto **ricostruito** (deduplicato + voci mancanti aggiunte, non dal contenuto originale con i duplicati); criterio "Severa" basato su stato contingente, non diagnosi permanente (implica storico, Fase 3).
- Le colonne booleane legacy di `patient_anamnesis` (allergie, cardiopatia, ecc.) restano fonte di alert "di sistema" — questa proposta le affianca al nuovo meccanismo, non le sostituisce, per non perdere dati clinici già raccolti.
- **Confermato dal committente (23/07/2026)**: le "voci contingenti" (es. "infezione respiratoria attiva oggi") restano nel catalogo anamnesi — severity=severa impostabile a runtime dal clinico, resa temporanea dal campo `resolved_at` della Fase 3. Non serve un meccanismo/tabella separata per il "motivo della visita"; il catalogo anamnesi copre entrambi i casi (permanente e contingente) grazie allo storico.
- Effort alto perché il lavoro reale è cinque cose insieme: migrare il catalogo da globale a per-tenant, ricostruire il contenuto (deduplicare + integrare i risultati della ricerca su 6 domini clinici), introdurre lo storico/versioning di `patient_anamnesis_item_selections` con diff, ricollegare due sistemi oggi indipendenti (catalogo dinamico e alert hardcoded), e introdurre per la prima volta un vincolo clinico dentro il motore di scheduling (#31).

---

## 44. Tariffe: fatturazione Studio vs Medico, override prezzi con versioning

**Stato:** Proposta
**Data proposta:** 2026-07-23
**Impatto:** Alto (~2-2.5 giornate)
**Priorità:** da fare **prima** di #40/#41 (richiesto dal committente 23/07/2026)
**Collegata a:** #42 (il filtro `billingProviderId` per preventivi/fatture resta legato a questa proposta, vedi #42 Fase 3)

### Situazione attuale (più pronta del previsto)
- `ServiceCatalogController`/`Service` (proposta #12.A, Fatta): CRUD prestazioni **unico per tenant**, nessuna dimensione per-medico.
- `estimate_lines` (`install.sql:486-511`): **già** salva `unit_price`/`discount_amount`/`vat_rate` propri per riga (snapshot al momento della creazione) — il prezzo di un preventivo esistente non cambia se il listino cambia dopo. `invoice_lines` (`:542-560`) è ancora più isolato: nessun FK a `service_catalog`, tutto denormalizzato.
- **`invoices` ha già tutto l'occorrente per l'intestazione al medico**: `issuer_type enum('clinic','provider')`, `provider_id`, e colonne di snapshot (`issuer_name`, `issuer_vat_number`, `issuer_fiscal_code`, `issuer_address`, `issuer_email`, `issuer_pec`, `issuer_sdi_code`, `issuer_iban`) — `InvoiceService.createFromEstimate` (righe 177-284) le valorizza già leggendo da `providers` quando `issuerType='provider'`. **Oggi è una scelta manuale per-fattura**, non una modalità di tenant — questo è ciò che manca.
- `providers` ha già tutti i campi di identità fiscale (`vat_number`, `fiscal_code`, `professional_register`, `billing_address_*`, `billing_pec`, `billing_iban`, `billing_sdi_code`, `invoice_prefix`) — **nessuna colonna nuova necessaria lì**.
- `clinics` ha già lo schema giusto per ospitare impostazioni di tenant (orari, `install.sql:471-474`) — posto naturale per `billing_mode`.
- Bug collaterale noto (**#34 follow-up**): `EstimateService.queryLines()` fa `INNER JOIN service_catalog` solo per il nome visualizzato — una riga con `service_id` NULL/cancellato sparisce dal totale. Da sistemare qui perché gli override per-medico aumentano i casi limite.

### Mancano solo: override prezzi per medico, versioning, flag di modalità tenant

#### Fase 1 — DB
```sql
ALTER TABLE clinics
    ADD COLUMN IF NOT EXISTS billing_mode text NOT NULL DEFAULT 'studio'
        CHECK (billing_mode IN ('studio', 'provider'));

CREATE TABLE provider_price_overrides (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id  uuid NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    service_id   uuid NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    price        numeric(10,2) NOT NULL,
    valid_from   timestamptz NOT NULL DEFAULT now(),
    valid_to     timestamptz,              -- NULL = versione corrente
    created_by   uuid REFERENCES providers(id),
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (provider_id, service_id, valid_from)
);
```
Versioning per **intervallo temporale** (`valid_from`/`valid_to`), non contatore: aggiornare un prezzo = chiudere la riga corrente (`valid_to = now()`) + inserirne una nuova, **mai** `UPDATE` in-place del prezzo (altrimenti lo storico si perde e i preventivi vecchi "cambierebbero" prezzo retroattivamente). Preventivi/fatture non hanno bisogno di un FK vivo alla versione: il prezzo è già copiato in `unit_price` al momento della riga (Fase attuale del sistema, invariata) — la versione serve solo per audit/tracciabilità, non per il calcolo.

Vista `v_provider_effective_prices(provider_id, service_id, price, source)`: override attivo (`valid_to IS NULL`) se esiste, altrimenti prezzo di `service_catalog` (eredita dallo studio).

#### Fase 2 — Backend
- Nuovo `ProviderPriceOverrideController`/`Service` (`/api/providers/{id}/prices`): CRUD limitato a "crea nuova versione" (no update in-place, coerente col modello valid_from/valid_to). Sola lettura di `v_provider_effective_prices` per popolare il default-prezzo lato preventivo.
- `EstimateService`: quando si aggiunge una riga preventivo, il prezzo di default proposto viene da `v_provider_effective_prices(providerId, serviceId)` se `clinics.billing_mode='provider'`, altrimenti da `service_catalog.price` diretto (comportamento attuale). Il prezzo resta comunque esplicito e modificabile riga per riga come oggi.
- `EstimateService.queryLines()`: `INNER JOIN` → `LEFT JOIN` su `service_catalog` (fix #34 follow-up, ora necessario anche per gli override).
- `InvoiceService.createFromEstimate`: oggi `issuerType`/`providerId` sono **campi client** nella request. Cambiare: il service legge `clinics.billing_mode` e **decide lui** l'intestazione — `billing_mode='provider'` → forza `issuerType='provider'` + `providerId` del medico del preventivo; `billing_mode='studio'` → forza sempre `issuerType='clinic'`, ignorando eventuale scelta client. Coerente con CLAUDE.md §11 ("non fidarsi mai solo della validazione client-side") e con lo spirito di #24 (un parametro client non deve decidere un esito di business/fiscale).

#### Fase 3 — Frontend
- Impostazioni → Studio: nuovo select "Modalità di fatturazione" (Studio / Medico) → `PUT /settings/clinic` (`billingMode`).
- Nuova vista "Le mie tariffe" (nella stessa area Impostazioni → Prestazioni, visibile al medico loggato): elenco prestazioni con prezzo studio + campo override (vuoto = eredita); salvataggio = nuova versione, mai modifica della riga esistente.
- Preventivo/fattura: nessuna modifica visibile — i default-prezzo derivano già dal backend aggiornato; l'intestazione fattura ora è automatica in base a `billing_mode`, non più una scelta manuale nel form.
- **Non toccare** il filtro `preventivi.component.ts`/`fatturazione.component.ts` in questa proposta — resta `billingProviderId` (self) come oggi (#35), coerente con #42 Fase 3; quando `billing_mode='studio'` valutare se aprirlo, ma è una decisione successiva, non automatica.

### File coinvolti
| Layer | File |
|---|---|
| DB | nuova migration (`billing_mode` + `provider_price_overrides` + vista) + `install.sql` |
| Backend | nuovo `ProviderPriceOverrideController/Service/DTO`, `EstimateService` (fix join + default prezzo), `InvoiceService.createFromEstimate` (enforcement lato server), `ClinicSettingsController` (campo `billingMode`) |
| Frontend | `impostazioni.component.ts/html` (select modalità + vista "le mie tariffe"), `clinic-billing.model.ts` |

### Note
- Nessuna colonna nuova su `providers` — l'identità fiscale per fatturare al medico è già completa.
- Il fix di `queryLines()` (`INNER`→`LEFT JOIN`) è un side-effect utile indipendente, non il cuore della proposta, ma va incluso nello stesso lavoro perché gli override aumentano la probabilità di righe con `service_id` non risolvibile.
- Dipendenza incrociata con #42: non implementare le due proposte in ordine che rompa il filtro preventivi/fatture già consegnato con #35.

---

## 45. Odontogramma: pannello a tutta larghezza, legenda leggibile

**Stato:** **Fatta (dev) — 23/07 (core)** — Fase 1 (`max-w-5xl mx-auto`→`w-full`) + Fase 2a (SVG `width` fisso → `w-full h-auto`, viewBox già presente) su `odontogramma-tab.component.html`. Verificato live in browser (:4200, medico@demo) e approvato. **Non fatte** (opzionali, da rifinire con verifica browser se servono): Fase 3b legenda-a-fianco su `xl`, Fase 2b `STEP` responsive via ResizeObserver.
**Data proposta:** 2026-07-23
**Impatto:** Basso-Medio (~½-1 giornata)
**Priorità:** da fare **prima** di #40/#41 (richiesto dal committente 23/07/2026)

### Situazione attuale (verificata sul codice)
- `odontogramma-tab.component.html:1` — contenitore radice con `max-w-5xl mx-auto` (cap fisso a 1024px, centrato), **nessun breakpoint responsive** (`grep lg:|xl:|md:|sm:` → zero risultati in tutto il componente).
- Il componente **non** usa il pattern a tre colonne di `LayoutService` (CLAUDE.md §5.8): nessun `#rightPanel` registrato — la colonna destra non è occupata da nient'altro, quindi allargare il centro non sposta nulla.
- La legenda è già sopra la chart (non a fianco): `html:64-100`, riga flex-wrap a piena larghezza dentro la stessa card `max-w-5xl`.
- La chart è un unico `<svg>` con dimensioni **pixel-fisse** calcolate da costanti (`odontogramma-tab.component.ts:12-24`: `STEP=34` → adulto 566px, bambino 362px), `style="max-width:100%"` ma non `width:100%` — quindi anche rimuovendo il cap del contenitore, il disegno **non si allarga da solo**, resta piccolo al centro dello spazio libero.
- 32 denti adulto (2 archi × 16, quadranti Q1/Q2 sopra, Q4/Q3 sotto) o 20 da latte, denti posizionati come `<g transform>` assoluti dentro l'SVG (non CSS grid).

### Soluzione proposta (di partenza — da validare con verifica visiva reale)

#### Fase 1 — Rimuovere il cap di larghezza
`max-w-5xl` → `w-full` (o rimuovere del tutto la classe) sul contenitore radice: la colonna centrale del layout a tre colonne si allarga già automaticamente quando, come qui, nessun pannello destro è registrato.

#### Fase 2 — Rendere l'SVG davvero responsive
Non basta il container più largo: serve che il disegno lo riempia. Due opzioni, effort crescente:
- **(a) Minima**: `viewBox` sulle dimensioni attuali + `width="100%"` sull'`<svg>` (oggi solo `max-width:100%`) → il disegno scala proporzionalmente fino a riempire lo spazio, stesso rapporto dimensioni.
- **(b) Più completa**: calcolo responsive di `STEP`/`TOOTH`/`PAD` in base alla larghezza reale disponibile (`ResizeObserver` o equivalente Angular) → i denti diventano proporzionalmente più grandi/cliccabili, non solo "più zoomati".
Punto di partenza: (a), a basso rischio; passare a (b) solo se il medico segnala che i denti restano difficili da selezionare col mouse/touch anche a piena larghezza.

#### Fase 3 — Legenda leggibile senza rubare spazio verticale
Due opzioni:
- **(a)** Restare sopra la chart ma renderla collassabile (accordion, default aperta) — minimo rischio.
- **(b)** Spostarla a fianco su schermi larghi (`xl:flex xl:flex-row`, chart `flex-1`, legenda `xl:w-56 xl:shrink-0 xl:sticky`), sopra su schermi stretti — coerente con la richiesta "allargare a tutto il pannello" (la legenda sopra consuma altezza utile che potrebbe andare al disegno).
Punto di partenza: (b), da confermare visivamente.

#### Fase 4 — Responsive breakpoints
Introdurre almeno `lg:`/`xl:` (oggi assenti) per distinguere schermo clinico allargato da schermo stretto/mobile.

### Implementazione: delega a UX
Come richiesto, la validazione finale della soluzione visiva va fatta con l'agente **frontend-dev** (specialista Angular/Tailwind di questo progetto) supportato dalla skill **frontend-design** (linee guida per scelte visive intenzionali, non default template), **con verifica reale in browser** (screenshot prima/dopo, non solo compilazione) prima di dichiarare la modifica completa — coerente con CLAUDE.md §"per modifiche UI, testare nel browser prima di riportare il task come completo". Le opzioni (a)/(b) sopra sono un punto di partenza per quella verifica, non una decisione finale.

### File coinvolti
| Layer | File |
|---|---|
| Frontend | `odontogramma-tab.component.html` (layout, SVG width/viewBox), `odontogramma-tab.component.ts` (se si sceglie l'opzione 2b, calcolo responsive `STEP`/`TOOTH`) |
| Nessuna modifica | Backend, DB |

### Note
- Nessun conflitto con altri componenti: la colonna destra del layout è libera per questo tab.
- Effort basso perché è puro lavoro di layout Angular/Tailwind, ma la stima assume che l'opzione (a) sull'SVG basti — se serve la (b) l'effort sale verso la fascia alta del range indicato.

---

## 47. Export selezionabile per clinica + guardia obbligatoria pre-cancellazione

**Stato:** Proposta
**Data proposta:** 2026-07-24
**Impatto:** Medio (~1-1.5 giornate)
**Origine:** discussione committente 24/07/2026 sulla segregazione dati tenant/clinica e sull'irreversibilità di `deleteTenant`.

### Situazione attuale (verificata sul codice)
`TenantExportService` **esiste già** con due percorsi:
- `exportClinicToStream(clinicId, out)` — ZIP di CSV filtrati per `clinic_id` (pazienti, appuntamenti, fatture, piani, storico clinico). Export di **una** clinica.
- `exportToStream(out)` — export dell'**intero tenant** (tutte le cliniche).

Quindi "una clinica" e "tutte" ci sono già; **manca la selezione di un sottoinsieme** (una o più cliniche) e soprattutto **l'aggancio alla cancellazione**.

**Il buco vero — le cancellazioni non impongono l'export** (`TenantAdminService`):
- `deleteTenant()` → `DROP SCHEMA ... CASCADE` + `purgeBucket` MinIO = **irreversibile totale**. Il commento nel codice dice *"L'export va effettuato prima (lato client)"* — è **solo una convenzione**, niente lo garantisce.
- `deleteClinic()` → rifiuta se la clinica ha pazienti (`"Clinic has patients"`) o se è l'ultima; il flusso reale per svuotare una sede passa comunque da lì.

### Distinzione da tenere netta — questo export NON è conservazione a norma
Tre livelli, tre scopi diversi (vedi anche intervento 20 e `DentalCare_Guida_Digitalizzazione_Cartella_Clinica_Dentale.md` §"Un archivio di file o un bucket MinIO non equivale a un sistema di conservazione a norma"):

| | Cos'è | Scopo |
|---|---|---|
| Backup | MinIO + `pg_dump` | ripristino dopo guasto |
| **Export (#47)** | ZIP CSV/JSON leggibile | portabilità (art. 15/20) + **copia di sicurezza pre-cancellazione** |
| Conservazione a norma | sistema conforme AgID (PDF/A, PAdES + marca temporale, pacchetti, responsabile + manuale, conservatore accreditato) | valore probatorio nel tempo — intervento 20/17, **fuori scope #47** |

Questa proposta è il **secondo** livello. Va **dichiarata esplicitamente "non conservazione a norma"** nell'UI e nel README dell'export, per non ingenerare falso affidamento.

### Soluzione

#### Fase 1 — Export multi-clinica
Generalizzare `exportClinicToStream` per accettare un **insieme** di `clinicId` (`WHERE clinic_id IN (:ids)`); il caso "tutte" resta `exportToStream`. UI tenant-admin con selezione multipla delle cliniche del tenant.

#### Fase 2 — Snapshot del catalogo anamnesi condiviso (confermato dal committente 24/07/2026)
Il catalogo anamnesi (`anamnesis_categories`/`anamnesis_items`) è **per-tenant, senza `clinic_id`** (#43) → non sezionabile per clinica. Le selezioni del paziente (`patient_anamnesis_item_selections`) referenziano `item_id`: **senza il catalogo com'era, le selezioni esportate diventano illeggibili** dopo la cancellazione (perdita di valore probatorio, proprio ciò che lo storico-con-diff di #43 vuole evitare).
→ Ogni export (per-clinica o intero tenant) **include uno snapshot puntuale e datato del catalogo anamnesi di riferimento** come contesto, incluso intero. Analogo trattamento per eventuale altra anagrafica per-tenant condivisa necessaria a interpretare i dati esportati.

#### Fase 3 — Guardia obbligatoria pre-cancellazione (il vero guadagno) — decisione C RISOLTA (committente 24/07/2026)

**Principio.** La guardia si basa su **fatti verificabili dal server**, non sull'autodichiarazione dell'utente. Una checkbox "hai salvato il file?" è teatro: non verificabile, inutile su un'operazione irreversibile → **scartata**. Il server può accertare che l'export sia stato *generato* e *scaricato*; **non** può accertare che i byte siano atterrati sani sul disco dell'utente (ultimo miglio, client-side) → per quello non ci si affida a una spunta, **si conserva una copia server-side**.

**Livello scelto — grace period che rende reversibile l'irreversibile.** Trasforma `deleteTenant()` da distruzione immediata a cancellazione differita annullabile (standard dei provider cloud, finestra ~30 gg):

1. **Export imposto + token.** All'avvio della cancellazione il server genera l'export fresco e completo, lo streamma in download e rilascia un **token monouso a scadenza breve** legato all'export (hash export + tenant + operatore + timestamp). La conferma accetta **solo** un token valido/non scaduto corrispondente all'export appena prodotto → senza export niente cancellazione (409).
2. **Conferma digitata** (nome tenant o `ELIMINA`), non checkbox → difesa dal click accidentale.
3. **Copia server-side in retention.** L'export resta in uno storage di retention separato per N giorni → recuperabile anche se la copia locale è persa/corrotta.
4. **Soft-delete del tenant.** Invece del `DROP SCHEMA` immediato: `dentalcare.tenants.active = false` + nuova colonna `scheduled_drop_at = now() + N giorni`, accesso revocato; il `DROP SCHEMA ... CASCADE` reale + `purgeBucket` avviene **solo allo scadere**, via job schedulato. Fino a lì è annullabile.

`deleteClinic()`: stessa logica di export+token+conferma digitata; il grace period sul singolo schema non si applica (non c'è drop di schema), ma va coordinato con la regola esistente che rifiuta la cancellazione di una clinica con pazienti (vedi Note) — export prima dello svuotamento.

Coerente con CLAUDE.md §7.4/§11 (niente cancellazioni distruttive senza rete di sicurezza) e con la soft-delete di #43.

> **Trade-off GDPR art. 17:** se la cancellazione nasce da una richiesta di erasure dell'interessato, la finestra di grace va giustificata/documentata come tempo tecnico. Per l'offboarding **volontario del tenant** non c'è vincolo. La finestra non trattiene i dati oltre il necessario: è revoca d'accesso immediata + drop differito.

#### Fase 4 — Protezione + audit dell'artefatto
- **L'export decifra**: `writeCustomersCsv` + `TenantEncryptionService` scrivono `fiscal_code`/`birth_date` **in chiaro** → il file annulla la cifratura di #7 e diventa l'anello debole. Protezione scelta (decisione B, vedi sotto): **signed URL a scadenza breve + archivio cifrato con password monouso mostrata una volta**.
- **Audit**: un'estrazione massiva di dati di categoria particolare (art. 9) va registrata come **evento di audit** (chi/quando/scope/conteggi), non solo `log.info` — lega all'intervento 1 (audit trail) e all'art. 30.

### File coinvolti
| Layer | File |
|---|---|
| Backend | `TenantExportService` (multi-clinica + snapshot catalogo anamnesi), `TenantAdminService` (`deleteTenant`/`deleteClinic` con guardia export), nuova voce audit |
| Frontend | UI tenant-admin: selezione multipla cliniche + step export obbligatorio nel flusso di cancellazione |
| DB | nessuna nuova tabella (usa `clinic_id` esistente); eventuale evento in audit log |

### Decisioni aperte
- **A** — dati condivisi per-tenant nell'export per-clinica: **risolta** → inclusi interi come snapshot datato (catalogo anamnesi confermato dal committente 24/07).
- **B** — meccanismo di protezione dell'artefatto: **risolta** (committente 24/07/2026) → **signed URL a scadenza breve** (nessuna copia persistente non protetta sul server, audit del download gratis) **+ archivio cifrato con password monouso mostrata una volta** (copre l'ultimo miglio: il file resta cifrato una volta sul disco dell'utente). Coerente col pattern token/monouso della guardia (decisione C). **Scartata come default** la cifratura con chiave del tenant (opzione 3): ostacola la portabilità art. 20, che richiede dati leggibili all'interessato — resterebbe valida solo se l'export fosse concepito come backup interno anziché consegna.
- **C** — forma della guardia: **risolta** (committente 24/07/2026) → **export imposto + token monouso · conferma digitata · copia server-side in retention · soft-delete del tenant con drop differito di N giorni**. Scartata la checkbox "hai salvato?" (autodichiarazione non verificabile). Dettaglio in Fase 3.

### Note
- Distinto dall'**intervento 10** (Blocco 3, gate: *export paziente completo art. 15 + report accessi*), che è **per-paziente** e diritto dell'interessato. Il #47 è **tenant-admin, bulk, clinica-selezionabile + guardia di cancellazione**: asse diverso.
- **Non** copre la conservazione a norma (intervento 20): per fatture → conservatore accreditato esterno; per documentazione clinica → finalizzazione+hash (intervento 2) poi PDF/A+PAdES (intervento 17).

### Implementazione — Slice A (Fatta in dev, 24/07/2026)

Partizione per domini disgiunti (backend / frontend, come da pattern #31-#35). Backend + test scritti a mano, frontend delegato a un agente su contratto fisso; backend `mvn test` verde (TenantDeletionServiceTest 7/7, compile OK), build FE verde.

**DB**
- `dentalcare.tenants.scheduled_drop_at timestamptz` — patch globale idempotente in `EstimateSchemaInitializer` + `install.sql` (CREATE TABLE).

**Backend**
- `TenantExportService`: `exportClinicToStream` ora delega a **`exportClinicsToStream(List<UUID>)`** (`clinic_id IN (...)`, export multi-clinica); **`writeAnamnesisCatalog`** aggiunge `data/anamnesis_catalog.json` (snapshot datato del catalogo condiviso) a **ogni** export.
- Nuovo **`TenantDeletionService`** (guardia con grace period): `prepare()` genera l'export → lo salva **cifrato a riposo su MinIO** (retention, `_deletion/...`) → rilascia token monouso TTL 15′; `streamPreparedExport()`; `confirmDeleteTenant(token, nome)` valida token + **nome digitato esatto** → soft-delete (`active=false` + `scheduled_drop_at=now()+N gg`, default N=30); `cancelDeleteTenant()` annulla in finestra; `dropExpiredTenants()` fa il DROP reale + purge bucket allo scadere.
- Nuovo **`TenantDeletionScheduler`** (`@Scheduled` 03:00 Europe/Rome → `dropExpiredTenants`).
- `TenantAdminController`: nuovi endpoint `POST /tenant/deletion/prepare`, `GET /tenant/deletion/export`, `POST /tenant/deletion/cancel`, `DELETE /tenant` (ora body `{deletionToken, confirmationName}` → soft-delete, non più drop immediato), `GET /export/clinics?ids=`.
- Rimosso il vecchio `TenantAdminService.deleteTenant()` (drop immediato). Login già filtra `active=true` → il soft-delete blocca subito gli accessi. Config: `app.tenant.deletion-grace-days:30`, `app.tenant.deletion-token-ttl-minutes:15`.
- Audit: `log.info("AUDIT tenant-deletion ...")` su prepare/confirm/cancel/hard-drop (evento durevole persistente → intervento 1, follow-up).

**Frontend** (`features/admin-tenant`): flusso tenant a 3 stati (prepara → scarica copia obbligatoria + conferma nome digitato → programmato con "Annulla eliminazione"); export multi-clinica con checkbox di selezione; conferma digitata anche sulla delete di clinica.

### Implementazione — Slice B (Fatta in dev, 24/07/2026)

Chiude la **decisione B** (protezione dell'artefatto).

**Backend**
- Nuova `PasswordZipUtil` (Zip4j, dipendenza aggiunta): avvolge l'export in un **archivio ZIP AES-256 protetto da password monouso** (20 caratteri, alfabeto senza caratteri ambigui), apribile con qualsiasi client ZIP standard.
- `TenantDeletionService.prepare()`: genera l'export → lo avvolge nell'archivio protetto → lo salva su MinIO (doppio strato: archivio con password **+** cifratura a riposo di `upload()`); la password è restituita **una sola volta** in `DeletionPrepareResponse.archivePassword`.
- **"Signed URL a scadenza breve"**: realizzato a livello applicativo come endpoint `GET /tenant/deletion/export` gated dal **token monouso a TTL breve** (15′) — link firmato di fatto. Un presigned URL S3 nativo è **deliberatamente evitato**: la copia in MinIO è cifrata a riposo dall'app, quindi un presigned diretto servirebbe ciphertext non apribile. La protezione "una volta sul disco" è data dall'archivio con password.
- Test: `PasswordZipUtilTest` (apre solo con password corretta; password robusta) + `TenantDeletionServiceTest` (prepare ritorna la password monouso). `mvn test` verde (10/10).

**Frontend**: la password monouso è mostrata **una sola volta** nello step "scarica copia", con avviso di salvarla (serve ad aprire l'archivio cifrato).

**Follow-up residui** (non decisione B): evento di audit **persistente** (oggi `log.info`), check `active` nel `JwtAuthenticationFilter` per invalidare i JWT già emessi entro la finestra di grazia, token di cancellazione persistente (oggi in memoria, perso al riavvio), eventuale presigned URL nativo se in futuro si separa lo storage non cifrato.
