# Piano a lungo termine — Fase 1 (senza AI medica) → Fase 2 (MDR)

**Data:** 16 luglio 2026
**Base:** stato dell'arte verificato su codice e DB reale (vedi `gap-analysis-cartella-clinica.md` e `roadmap_certificazione.md`)
**Assunzioni dichiarate** (confermate dal committente il 16/07/2026):
1. prod = **tenant demo, nessun paziente reale**;
2. risorse compliance = **nessun DPO, nessun Regulatory Affairs**;
3. obiettivo = **primo studio pagante entro ~6 mesi** (target gennaio 2027).

Se una di queste cambia, il piano va rifatto: sono le tre variabili che ne determinano le date.

---

## 1. La scadenza vera non è il 2 agosto 2026

Questo è il primo effetto delle assunzioni, ed è liberatorio.

L'AI Act si applica quando un sistema è **immesso sul mercato o messo in servizio**. Un tenant dimostrativo con dati fittizi, non usato da odontoiatri su pazienti veri, **non è in servizio**. Quindi il 2 agosto 2026 non è una scadenza che ti morde: è una data che passerà senza conseguenze.

> **La scadenza reale è un evento, non una data: il giorno in cui il primo paziente vero entra nel sistema.**
> Da quel momento — e non prima — scattano insieme: trasparenza art. 50, AI literacy, informativa paziente, DPIA, DPA fornitori, e il divieto d'uso clinico del modulo radiologico senza CE.

Con il target "primo studio pagante entro 6 mesi", quell'evento è previsto per **gennaio 2027**. Tutto il piano di Fase 1 è quindi ordinato verso **un gate di go-live**, non verso un calendario normativo.

**Il rischio da non sottovalutare:** il gate è binario. Non esiste "andiamo live e sistemiamo dopo": nel momento in cui entra il primo paziente reale, o il pacchetto è completo o sei non conforme dal giorno 1. Non è rimandabile perché non è una scadenza — è una condizione d'ingresso.

**Regola operativa da subito:** finché il pacchetto non è chiuso, il tenant demo resta **a dati fittizi**. Il momento più pericoloso di tutto il piano è il pilota "informale" con un amico dentista che carica due pazienti veri "tanto per provare". Quello è go-live, con tutti gli obblighi, senza nessuna delle protezioni.

---

## 2. Il collo di bottiglia non è il codice

Questo è il secondo effetto, ed è il più importante per pianificare.

Il progetto ha un rapporto di compressione misurato di **~50-100x** sulle ore umane (vedi metriche storiche: 68 commit / ~29k righe / ~7-8h umane nei primi 7 giorni). Alla velocità reale di questo progetto, il **debito tecnico preesistente della Fase 1 vale ~85-120 ore agente**. Dal 22/07/2026 si aggiunge #39 Chairside Agent, stimato separatamente in **43-69 giornate-agente** con tre agenti dedicati (~4-5 settimane calendario in parallelo).

> **Correzione 17/07/2026.** Qui c'era *"~65-100 ore agente"*: era sbagliato già alla stesura — gli sprint del §4 sommavano a 80-114h. Con l'intervento *admin tecnico + break glass* aggiunto allo Sprint 3 si arriva a **84-117h**, arrotondato a ~85-120h. Somma verificata: Sprint 0 (10-14) + Sprint 1 (20-25) + Sprint 2 (20-30) + Sprint 3 (24-33) + Sprint 4 (10-15).
>
> **Non cambia la conclusione, la rafforza:** anche a 120h il codice resta **settimane** contro i **mesi** di DPIA/DPA/contratti/pen test. Una stima tecnica sbagliata del 40% non sposta il percorso critico — e questo è esattamente il punto del paragrafo.

Il lavoro **non comprimibile** è l'altro:

| Attività | Chi la fa | Tempo di calendario | Comprimibile con AI? |
|---|---|---|---|
| Audit trail, finalizzazione, consensi, encounter | agente + tua review | settimane | ✅ sì (50-100x) |
| **Ingaggio DPO** | mercato | **2-6 settimane** | ❌ no |
| **DPIA** | DPO | **4-8 settimane** | ❌ no (serve firma di un terzo) |
| **DPA + SCC con Retell/OpenAI** | i fornitori | **4-8 settimane** | ❌ no (dipende da loro) |
| Contratti deployer con gli studi | legale | 4-6 settimane | ❌ no |
| Pen test | terza parte | 2-4 settimane | ❌ no |

> **Con "solo io, nessun DPO", il percorso critico della Fase 1 passa interamente per l'ingaggio di un DPO.** Non per il codice.

**Conseguenza secca:** se il DPO non è ingaggiato entro **fine agosto 2026**, il target di gennaio 2027 salta — non per colpa dello sviluppo, ma perché DPIA + informative + DPA non entrano in 4 mesi partendo da zero. Il codice, a quel punto, sarebbe pronto e fermo ad aspettare una firma.

**Questa è l'unica azione del piano che non puoi delegare a un agente e che devi fare per prima.**

---

## 3. Stato dell'arte (sintesi)

Cosa c'è già, verificato:

| Livello | Stato |
|---|---|
| **Nucleo dati** | ✅ solido — multi-tenancy schema-per-tenant, 34 tabelle, moduli agenda/pazienti/cartella/preventivi/fatture/magazzino/richiami/prestazioni |
| **Cifratura GDPR** | ✅ LIVE in prod — `birth_date` + `fiscal_code` cifrati per-tenant (HKDF+AES-GCM), blind index, master key fail-fast |
| **AI radiologica** | 🟡 funziona (ONNX FDI+disease), tracciabilità modello/revisione già presente — **ma non certificabile oggi** |
| **Copilot AI** | ✅ gate di conferma strutturale (zero scritture dirette, closure server-side, scope check + audit) |
| **Valore probatorio cartella** | ❌ **il buco** — no finalizzazione, no audit clinico, no consensi, no encounter |
| **Governance/privacy** | ❌ **assente** — no DPIA, no ROPA, no DPA, no policy, no registro AI |

Il progetto è **molto avanti sul prodotto e molto indietro sulla prova**. È il profilo tipico di chi ha costruito con un acceleratore: la parte comprimibile è corsa, la parte non comprimibile è ferma al via.

---

## 4. Fase 1 — Piattaforma vendibile senza AI medica

**Obiettivo:** un gestionale odontoiatrico completo e difendibile, con AI **solo amministrativa** (Giulia + Copilot), vendibile a studi reali. Il modulo radiologico resta spento in clinica.

**Definizione di "fatto":** il gate di go-live (§5) passa interamente.

### Sprint 0 — Sblocco (luglio–agosto 2026)

Le due cose che devono partire subito, in parallelo:

**A. [NON DELEGABILE] Ingaggio DPO** ← *inizia questa settimana*
- cercare e contrattualizzare un DPO con esperienza sanitaria/software;
- briefing: multi-tenant, dati sanitari, AI, sub-fornitori extra-SEE;
- output atteso: preventivo + calendario DPIA.

**B. [Codice, ~10-14h agente] Quick win compliance**
- **gate no-clinical**: feature flag `ai.radiology.enabled`, default OFF in prod → il rischio più grande si spegne con un flag;
- kill switch per Giulia e Copilot;
- disclosure Giulia + limiti operativi (no triage/diagnosi);
- **#20**: fix fallback `confirmAction` (1-2h);
- Registro AI + AI Use Policy (bozze tue, revisione DPO dopo).

> Il gate no-clinical vale da solo metà del rischio del progetto e costa un pomeriggio. Farlo subito, non a gennaio.

### Sprint 1 — Valore probatorio (agosto–settembre 2026) · ~20-25h agente

Il blocco che trasforma "database di dati clinici" in "cartella clinica". Da `gap-analysis-cartella-clinica.md` Fase A:

1. **Audit trail clinico** append-only (abilita tutto il resto: report accessi, diritti paziente, domande da controllo);
2. **Finalizzazione + addendum + hash** su `clinical_history_entries`;
3. **Segregazione segreteria server-side** + test automatico;
4. **Soft delete** al posto della cancellazione fisica.

### Sprint 2 — Modello clinico (settembre–ottobre 2026) · ~20-30h agente

1. **Encounter** + FK sulle entità cliniche;
2. **Consensi versionati** collegati al piano;
3. **Odontogramma temporale** (`certainty`, `encounter_id`, `supersedes_id`, storico);
4. **Anamnesi tri-stato** (presente/assente/non noto) + fonte.

### Sprint 3 — Identità e accessi (ottobre–novembre 2026) · ~24-33h agente

Riordinato: **prima le voci del gate** (§5), poi il resto.

1. **MFA** per professionisti e admin — *gate*;
2. **Export paziente completo** (art. 15 GDPR) + report accessi — *gate*;
3. **Admin tecnico senza accesso clinico ordinario** + **break glass** tracciato — *gate* (voce aggiunta il 17/07/2026: §11.1, §11.3, errore §28.18);
4. **Merge duplicati** + `patients.status`;
5. **`sha256` + MIME reale + malware scan** sugli upload + verifica paziente↔immagine;
6. **Relazione di cura** come filtro di autorizzazione (`primary_provider_id`).

> Dettaglio, dipendenze ed effort per intervento: *Piano di intervento — cartella clinica*, Blocco 3, in `proposte-modifiche.md`.

### Binario parallelo — #39 Chairside Agent (Fase 1) · ~43-69 gg-agente

Tre agenti dedicati — backend, frontend e test/QA — lavorano in parallelo per una durata stimata di **~4-5 settimane calendario**:

1. **dopo Sprint 1 / contratti stabili:** conversazione Copilot condivisa, policy per tenant e impostazioni di voce/lingua, dietro feature flag;
2. **in parallelo a Sprint 2-3:** push-to-talk, STT, TTS e hotword locale, solo su dati fittizi e funzioni di lettura/navigazione;
3. **dopo #20, audit, autorizzazioni e finalizzazione/addendum:** revisione dettatura, doppio gate di conferma e audit vocale;
4. **prima dell'attivazione:** test avversi, DPIA/valutazione del fornitore e pilota controllato su una postazione.

Allocazione: **backend 11-18 gg**, **frontend 17-26 gg**, **test/QA 15-25 gg**. Il frontend/hotword e il pilota costituiscono il percorso critico. Se il pilota non supera i criteri, la Fase 1 resta rilasciabile con la voce installata ma `enabled=false`.

Piano di dettaglio: `docs/superpowers/plans/2026-07-22-copilot-chairside-voice.md`.

### Binario parallelo — Governance (settembre–dicembre 2026) · dipende dal DPO

- **DPIA** completa e approvata;
- ROPA, informative (inclusa quella sull'uso dell'AI, L. 132/2025);
- **DPA + SCC + TIA** per Retell, OpenAI, cloud → verificare **no-training** e data location;
- contratti studi con clausole deployer;
- AI literacy (piano + evidenze datate);
- registro claim + bonifica materiale commerciale.

### Sprint 4 — Hardening (dicembre 2026) · ~10-15h agente + terze parti

- pen test + remediation;
- **restore test documentato** (oggi non c'è evidenza di un ripristino riuscito);
- test cross-tenant automatici;
- procedura di downtime;
- formazione del primo studio.

### Fine Fase 1: **gennaio 2027** — *condizionata all'ingaggio DPO entro fine agosto 2026*

**Cosa NON entra in Fase 1** (rimandato consapevolmente): conservazione a norma, DICOMweb, FHIR API, connettore FSE, portale paziente, terminology service, charting parodontale, esame obiettivo strutturato. Sono P1 della guida: servono per crescere, non per il primo studio.

---

## 5. Gate di go-live (la definizione di "finito" della Fase 1)

Nessun paziente reale prima che **tutte** siano verde:

- [ ] modulo radiologico **spento** in produzione clinica (flag + claim + contratto)
- [ ] audit trail clinico attivo e append-only
- [ ] note finalizzabili, non modificabili dopo la firma, addendum funzionante
- [ ] consensi versionati collegati ai piani
- [ ] segreteria **non** vede anamnesi/diagnosi/odontogramma/note (verificato server-side)
- [ ] **amministratore tecnico non accede ai contenuti clinici in chiaro**; ogni accesso straordinario passa da **break glass** tracciato (motivazione obbligatoria + audit + notifica)
- [ ] MFA attiva
- [ ] DPIA approvata dal DPO
- [ ] informative aggiornate (privacy + uso AI)
- [ ] DPA firmati con tutti i fornitori AI
- [ ] disclosure Giulia + fallback umano
- [ ] AI literacy erogata, con evidenze
- [ ] contratto studio con clausole deployer
- [ ] restore testato almeno una volta
- [ ] pen test eseguito e remediation chiusa
- [ ] export paziente (art. 15) funzionante

Se #39 viene **attivata** al go-live, devono inoltre essere verdi:

- [ ] audio non persistito per default e hotword elaborata localmente
- [ ] zero esecuzioni su paziente/tenant errato nei test avversi
- [ ] 100% delle dettature cliniche revisionate e 100% delle scritture confermate e auditate
- [ ] DPIA/DPA del provider STT/TTS coperti e pilota su postazione target superato

Queste quattro voci condizionano l'**attivazione della voce**, non il rilascio del gestionale: in caso contrario #39 resta disabilitata tramite policy server-side.

> **Voce aggiunta il 17/07/2026 — amministratore tecnico.** Il gate copriva la segregazione della **segreteria** ma non quella dell'**admin tecnico**, che §11.1 della guida vieta e che `gap-analysis-cartella-clinica.md` §8 marca già come errore **§28.18 ❌ presente**. Senza questa voce il gate sarebbe passato **con una non conformità nota e attiva** — l'unica cosa peggiore di un controllo mancante è un controllo che dichiara verde ciò che è rosso.
>
> Consegnata dallo **Sprint 3**; tracciata come intervento 11 del *Piano di intervento* in `proposte-modifiche.md`.

> **Regola del gate.** Ogni voce qui dev'essere consegnata da uno sprint del §4 e verificabile da un terzo. Una voce senza sprint è un'intenzione; uno sprint senza voce nel gate è lavoro che non blocca il go-live. Se aggiungi una voce, aggiungi anche chi la consegna.

---

## 6. Fase 2 — Percorso MDR per il modulo radiologico

### 6.1 La regola che governa la Fase 2

**Non si inizia finché la Fase 1 non vende.** Il percorso MDR costa più dell'intero prodotto costruito finora e non è comprimibile dall'AI: è fatto di code d'attesa, firme, studi clinici e organismi notificati. Spenderlo prima di sapere se il gestionale ha mercato è il modo più efficiente di bruciare il progetto.

**Trigger per aprire la Fase 2** (basta uno):
- N studi paganti chiedono l'AI radiologica come funzione clinica;
- una gara la richiede;
- un investitore la finanzia esplicitamente.

Fino ad allora il modulo resta un **asset dimostrativo**: utile in demo, spento in clinica.

### 6.2 Timeline realistica (se aperta a inizio 2027)

| Periodo | Attività | Note |
|---|---|---|
| **2027 H1** | decisione + budget; ingaggio **Regulatory Affairs**; intended purpose; MDR qualification + classification memo; **scelta organismo notificato** | Le code degli organismi notificati sono **6-12 mesi**: ci si mette in fila presto, non alla fine |
| **2027 H2 – 2028 H1** | QMS ISO 13485; risk file ISO 14971; lifecycle IEC 62304; usability 62366; cybersecurity 81001-5-1; data governance | Il QMS è organizzativo, non documentale: serve che l'azienda lo *usi* |
| **2028** | validazione interna + **validazione esterna multi-centro**; Clinical Evaluation Plan/Report | Il pezzo più lungo e più costoso |
| **2028 H2 – 2029** | conformity assessment, audit organismo notificato, remediation, **marcatura CE** | |
| **2 agosto 2028** | obblighi AI Act high-risk per prodotti Annex I | Si allinea naturalmente: se il CE arriva nel 2029, i due percorsi convergono |

**CE realistica: 2029.** Chiunque prometta il 2028 partendo da zero nel 2027 non ha considerato le code degli organismi notificati.

### 6.3 L'unica cosa della Fase 2 che deve iniziare in Fase 1

C'è una dipendenza che non si può recuperare a posteriori, ed è quella che fa fallire i progetti MDR:

> **Il dataset clinico con base giuridica documentata.**

La validazione clinica richiede dati annotati con **provenienza, licenza e base giuridica** tracciate. Le label già raccolte in `patient_document_labels` durante le demo **non sono utilizzabili**: non hanno base giuridica per il training, e la pseudonimizzazione non le rende anonime. Non si retro-adatta una base giuridica a dati già raccolti.

Quindi, **se pensi di fare la Fase 2**, in Fase 1 va predisposto (con il DPO, mentre è già ingaggiato):
- base giuridica per la raccolta a fini di sviluppo/ricerca, separata da quella assistenziale;
- informativa che la copra;
- SOP di annotazione (qualifiche annotatori, doppia lettura, adjudication, inter-rater);
- dataset card + provenance;
- separazione ambienti clinico / ricerca.

Costa poco farlo mentre il DPO è già al lavoro. Costa un anno recuperarlo nel 2028.

**Se invece decidi che la Fase 2 non si farà mai**, allora la scelta coerente è **smettere di raccogliere label** e togliere il modulo radiologico dal prodotto: mantenerlo funzionante ha un costo di manutenzione che non ripaga un asset che non potrà mai essere venduto.

---

## 7. Cosa fare questa settimana

In ordine. Le prime due sbloccano tutto il resto.

1. **Cercare un DPO.** È il percorso critico. Tutto il resto lo puoi fare o delegare; questo no.
2. **Spegnere il modulo radiologico in prod** (feature flag, default OFF). Un pomeriggio, e il rischio maggiore del progetto sparisce.
3. Decidere, anche solo per te: **Fase 2 sì o no?** Da questa risposta dipende se in Fase 1 costruisci la data governance del dataset o se smetti di raccogliere label.
4. Fix **#20** (fallback `confirmAction`): 1-2 ore.
5. Iniziare **#18 Fase A** (audit trail): è il blocco a più alto valore e più basso rischio di regressione.

---

## 8. Sintesi

| | Fase 1 | Fase 2 |
|---|---|---|
| **Cosa** | gestionale + AI amministrativa, senza AI medica | AI radiologica certificata CE |
| **Vincolo** | ingaggio DPO (non il codice) | budget + organismo notificato + evidenza clinica |
| **Durata** | ~6 mesi | ~24 mesi |
| **Fine** | **gennaio 2027** (se DPO ingaggiato entro agosto 2026) | **2029** (se aperta a inizio 2027) |
| **Costo dominante** | tempo di terzi (DPO, legale, pen test) | organismo notificato + validazione clinica |
| **Rischio principale** | go-live "informale" con pazienti veri prima del gate | aprirla prima di sapere se il prodotto vende |

**La frase da ricordare:** in questo progetto il codice non è più il collo di bottiglia. Lo sono le firme.
