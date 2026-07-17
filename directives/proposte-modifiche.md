# Proposte di modifica

Registro delle modifiche proposte da Claude e il loro stato. Aggiornato a ogni proposta/conferma.

Stati: **Proposta** (in attesa di tua conferma) · **Confermata** (da fare) · **Fatta** (implementata + commit) · **Scartata**.

---

## Indice

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
| 20 | **Conservazione a norma** | Conservazione ❌ | 16, 17 | dominato da fornitore/accreditamento | Oggi MinIO + `pg_dump` = **backup**, non conservazione (§9.3, errore §28.7). Distinzione non negoziabile. |
| 21 | **FHIR API** (adapter, **non** modello interno) | FHIR ❌ | 5, 6, 18 | M-L | La strategia duale §14.1 è **già corretta**: il modello interno non va rimodellato, si aggiunge un adapter. Serve encounter (5), consensi (6) e terminologia (18) o l'adapter mappa il vuoto. |
| 22 | **DICOMweb** → proposta **#8** | DICOMweb ❌ | — | S-M (#8) | Indipendente da tutto il resto: si può fare quando serve. |
| 23 | **Portale paziente** | Portale ❌ | 1, 6, 10 | L | Espone al paziente esattamente ciò che 1/6/10 rendono esponibile. Prima di quelli non ha contenuto da mostrare. |
| 24 | **Connettore FSE 2.0** | FSE ❌ | 17, 18, 20, 21 | dominato da accreditamento | **Ultimo per costruzione**: richiede CDA2 + PAdES + conservazione + accreditamento regionale. Ogni sua dipendenza è un altro P1. |

> **Report accessi** (§25.2) non compare qui: è **chiuso dall'intervento 10** in Fase 1, perché dipende dall'audit (1) e serve al diritto del paziente. È l'unico GAP P1 che entra in Fase 1 — e ci entra come effetto collaterale, non per scelta.

### Sintesi per rilascio

| Rilascio | Blocchi | Interventi | Effort agente | Vincolo reale |
|---|---|---|--:|---|
| **Fase 1 — go-live gennaio 2027** | 1 + 2 + 3 | 1-14 (+ report accessi) | **~66-90h** (solo #18) | **non il codice**: DPIA/DPA/contratti/pen test → ingaggio DPO entro **fine agosto 2026** |
| **Post-Fase 1** | 4 | 15-24 | mesi | mercato (19, 22) · terzi (16, 17, 20, 24) |
| **Fase 2 — CE 2029** | — | vedi #22 | ~24 mesi | apertura solo se la Fase 1 vende (`piano-lungo-termine.md` §6.1) |

> **✅ Allineato il 17/07/2026.** Il §2 di `piano-lungo-termine.md` dichiarava *"~65-100 ore agente"* per tutto il debito tecnico di Fase 1, ma i suoi stessi sprint sommavano a 80-114h. Corretto a **~85-120h agente** (= #18 ~66-90h + #19 Sprint 0 ~10-14h + hardening ~10-15h), e il gate §5 ha ora la voce sull'admin tecnico, consegnata dallo Sprint 3.
>
> La conclusione non cambia — si rafforza: anche a 120h **il codice resta settimane contro i mesi di DPIA/DPA/pen test**. Una stima tecnica sbagliata del 40% non sposta il percorso critico. **Il collo di bottiglia non è il codice: sono le firme.**

---

## 1. Aggiornamento agenda in tempo reale (SSE)

**Stato:** Proposta
**Data proposta:** 2026-06-25
**Impatto:** Medio-basso (~½ giornata)

### Obiettivo
Quando un appuntamento viene modificato dalla segreteria AI (chat in-app o n8n) mentre l'agenda è aperta, l'agenda si aggiorna senza refresh manuale.

### Approccio
SSE "ping" + refetch (riusa il pattern già in `ChatController`, funzionante attraverso il proxy prod :9443).
1. Backend: registry `ConcurrentMap<clinicId, Set<SseEmitter>>`; endpoint `GET /api/appointments/stream`; dopo ogni scrittura `publish(clinicId, "changed")`.
2. Frontend: `EventSource` in `agenda.component` → al ping richiama il load della vista corrente; chiusura in `ngOnDestroy`.
3. Il ping non contiene dati: il client rifetcha con la propria auth → isolamento tenant garantito.

Copre entrambi i path: n8n chiama gli stessi endpoint REST → stesso `AppointmentService` → stesso publish.

### File coinvolti
- Backend: nuova classe registry + `AppointmentController` (endpoint `/stream`) + hook `publish(...)` in `AppointmentService.reschedule/create/cancel/updateStatus`.
- Frontend: `agenda.component.ts` (EventSource + reload esistente), eventuale `appointment.service.ts`.

### Caveat
- EventSource non manda header `Authorization` → token via query param `?token=` (validare, non loggare).
- Registry in-memory: notifica solo i client sulla **stessa** istanza backend. Prod = container singolo → ok ora; multi-istanza richiede Redis pub/sub.
- Emettere dopo il commit (se i metodi diventano `@Transactional`; ora jdbc diretti → publish a fine metodo).
- Publish solo allo stesso `clinicId`.

### Alternativa
Polling ogni 20-30s sull'agenda (~1h, zero backend) ma laggoso e più carico.

---

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

**Stato:** Proposta
**Data proposta:** 2026-06-25
**Impatto:** Medio (~1 giornata)

### Problema
La tab "Documenti" nella scheda paziente esiste nel menu ma è completamente vuota — nessun component, nessuna tabella DB, nessun endpoint. Non è possibile allegare o visualizzare documenti (ortopanoramine, referti, consensi, RX, ecc.) ai pazienti.

### Soluzione

#### Tipi di documento supportati

| Codice | Etichetta |
|--------|-----------|
| `ortopanoramica` | Ortopanoramica ⭐ |
| `rx_endorale` | RX Endorale |
| `cefalometria` | Cefalometria |
| `tac_cbct` | TAC / CBCT |
| `foto_clinica` | Foto clinica |
| `consenso_informato` | Consenso informato |
| `referto` | Referto / Lettera |
| `altro` | Altro |

#### Fase 1 — DB: tabella `patient_documents`

```sql
CREATE TABLE patient_documents (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid        NOT NULL REFERENCES clinics(id),
    patient_id      uuid        NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    document_type   text        NOT NULL DEFAULT 'altro',
    title           text        NOT NULL,
    file_name       text        NOT NULL,
    mime_type       text        NOT NULL,         -- 'image/jpeg', 'image/png', 'application/pdf'
    file_base64     text        NOT NULL,         -- contenuto in base64
    file_size_bytes integer,
    notes           text,
    taken_at        date,                         -- data esame/documento
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON patient_documents (patient_id, clinic_id);
```

Aggiornare `install.sql` e la funzione `create_tenant`.

> **Nota dimensioni:** base64 aumenta il peso del file del ~33%. Un'ortopanoramica JPEG da 5MB diventa ~6.7MB in DB. Per studi con molti pazienti valutare in futuro object storage (MinIO/S3) con solo URL in DB — rimandato a iterazione futura. Limite upload suggerito: **15 MB per file**.

#### Fase 2 — Backend

**Endpoint:**
```
GET    /api/patients/{patientId}/documents          → lista metadati (NO base64)
POST   /api/patients/{patientId}/documents          → upload nuovo documento
GET    /api/patients/{patientId}/documents/{id}     → metadati + base64 (per preview/download)
PUT    /api/patients/{patientId}/documents/{id}     → aggiorna solo metadati (title, notes, takenAt, documentType)
DELETE /api/patients/{patientId}/documents/{id}     → elimina
```

**Separazione metadati / contenuto** obbligatoria: il GET lista non include `file_base64` per evitare payload enormi. Il base64 viene restituito solo sul GET singolo.

**DTO:**
```java
// Lista (senza base64)
public record PatientDocumentSummaryDto(
    UUID id, String documentType, String title,
    String fileName, String mimeType, Integer fileSizeBytes,
    String notes, LocalDate takenAt, LocalDateTime createdAt
) {}

// Dettaglio (con base64)
public record PatientDocumentDto(
    UUID id, String documentType, String title,
    String fileName, String mimeType, Integer fileSizeBytes,
    String fileBase64, String notes, LocalDate takenAt, LocalDateTime createdAt
) {}

// Upload
public record CreatePatientDocumentRequest(
    @NotBlank String documentType,
    @NotBlank String title,
    @NotBlank String fileName,
    @NotBlank String mimeType,
    @NotBlank String fileBase64,    // già convertito da frontend
    Integer fileSizeBytes,
    String notes,
    LocalDate takenAt
) {}

// Aggiorna metadati
public record UpdatePatientDocumentRequest(
    @NotBlank String title,
    String documentType,
    String notes,
    LocalDate takenAt
) {}
```

**Classi:** `PatientDocumentService`, `PatientDocumentController` (nuovo file ciascuno).

#### Fase 3 — Frontend

**Nuovo component:** `documenti-tab.component.ts/html` in `frontend/src/app/features/pazienti/documenti-tab/`

**Nuovo model:** `patient-document.model.ts` in `core/models/`

**Nuovo service:** `patient-document.service.ts` in `core/services/`

**UX tab Documenti:**
- Grid card dei documenti (icona tipo + titolo + data + dimensione)
- Thumbnail inline per immagini (JPEG/PNG) — `<img [src]="'data:'+doc.mimeType+';base64,'+doc.fileBase64">`
- Icona PDF per file PDF; icona generica per altri tipi
- Bottone "+ Aggiungi documento" → dialog/form upload
- Click su card → modal preview (immagine a schermo intero o PDF in `<iframe>`)
- Bottone download → `<a [href]="dataUrl" [download]="doc.fileName">`
- Bottone elimina con confirm dialog
- Bottone modifica metadati (titolo, tipo, note, data) senza re-upload

**Upload flow (FileReader API):**
```typescript
onFileSelected(event: Event): void {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;
  // Limit check
  if (file.size > 15 * 1024 * 1024) { this.uploadError.set('File troppo grande (max 15 MB)'); return; }
  const reader = new FileReader();
  reader.onload = () => {
    const base64 = (reader.result as string).split(',')[1]; // strip data:...;base64,
    this.pendingFile.set({ name: file.name, mimeType: file.type, base64, sizeBytes: file.size });
  };
  reader.readAsDataURL(file);
}
```

**Integrazione in `paziente-detail.component.html`:** aggiungere `@if (activeTab() === 'documenti') { <app-documenti-tab [patientId]="pazienteId"> }`.

### File coinvolti
| Layer | File |
|-------|------|
| DB | patch SQL + install.sql + create_tenant |
| Backend | `PatientDocumentSummaryDto`, `PatientDocumentDto`, `CreatePatientDocumentRequest`, `UpdatePatientDocumentRequest`, `PatientDocumentService`, `PatientDocumentController` |
| Frontend | `documenti-tab/` (component nuovo), `patient-document.model.ts`, `patient-document.service.ts`, modifica `paziente-detail.component.html` |

### Note
- La tab "Documenti" esiste già nel loop tab del template — basta aggiungere il branch `@if` per il contenuto
- Tipi MIME accettati: `image/jpeg`, `image/png`, `image/webp`, `application/pdf`; altri bloccati a livello di `<input accept="">`
- Il campo `taken_at` (data esame) è distinto da `created_at` (data upload) — importante per ordinare le ortopanoramine per data clinica
- Ordinamento default lista: `taken_at DESC NULLS LAST, created_at DESC`
- Limite 15MB per file è pratico per ortopanoramine JPEG; per CBCT in DICOM (>100MB) servirà object storage → vedi proposta #5

---

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

**Stato:** Fatta — validato E2E e **mergiato su `master`** (2026-06-30, FF). Microservizio `dentalcare-ai-service` (Python/FastAPI/ONNX) + integrazione DentalCare (bucket-per-tenant, tabelle analyses/labels, webhook HMAC, SSE, reconciler, sync odontogramma, overlay SVG). Spec: `docs/superpowers/specs/2026-06-26-ai-yolo-service-design.md`. Piani: `docs/superpowers/plans/2026-06-26-ai-service-python.md` + `2026-06-26-ai-integration-dentalcare.md`.
**Data proposta:** 2026-06-25
**Impatto:** Alto (~3-5 giorni)
**Prerequisiti:** Proposta #4 (tab documenti) + Proposta #5 (MinIO)

### Obiettivo
Quando il medico carica un'ortopanoramica, il sistema la analizza automaticamente con un modello YOLO e mostra i bounding box delle carie (e altre patologie) sovraimposti all'immagine. Il medico può correggere/approvare i rilevamenti, che alimentano il retraining del modello.

### Perché MinIO (#5) e non base64 (#4)

| | Base64 in DB | MinIO |
|---|---|---|
| Inference YOLO su 1 file | Decode da DB → pass a YOLO | Accesso diretto file da Python |
| Training su 5000 ortopanoramine | **Impossibile** — DB satura | Lettura diretta da bucket |
| Salvataggio dataset labelato | Blob nel DB | File `.txt` YOLO in bucket separato |

MinIO è prerequisito non negoziabile per questa feature.

### Classi rilevabili (YOLO dental)

```
carie            — dental caries
carie_profonda   — deep caries / periapical lesion
impianto         — implant
moncone          — abutment
corona           — crown
radice_residua   — retained root
dente_incluso    — impacted tooth
perdita_ossea    — bone loss
```

Dataset pubblici disponibili per pre-training: **DENTEX 2023** (MICCAI), **Tufts Dental Database**.

### Architettura

```
Frontend Angular
  └── upload ortopanoramica → MinIO (via backend)
  └── POST /api/patients/{id}/documents/{docId}/analyze
         → Spring Backend
              → HTTP call → Python AI Service (FastAPI)
                    → legge immagine da MinIO (boto3)
                    → YOLO inference (ultralytics)
                    → restituisce detections []
              → salva in patient_document_analyses (DB)
  └── overlay bounding box sull'immagine (Canvas API)
  └── medico corregge/approva → POST /api/documents/{docId}/labels
         → salva in patient_document_labels (DB)
         → trigger retraining (asincrono)
```

### Fase 1 — Nuove tabelle DB

```sql
-- Risultati inference
CREATE TABLE patient_document_analyses (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid        NOT NULL,
    document_id     uuid        NOT NULL REFERENCES patient_documents(id) ON DELETE CASCADE,
    model_version   text        NOT NULL,                    -- es. "dental-yolo-v1.2"
    status          text        NOT NULL DEFAULT 'pending',  -- pending|running|completed|failed
    detections      jsonb,      -- [{class, confidence, x1,y1,x2,y2, approved}]
    error_message   text,
    duration_ms     integer,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- Label corrette dal medico (per retraining)
CREATE TABLE patient_document_labels (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid        NOT NULL,
    document_id     uuid        NOT NULL REFERENCES patient_documents(id) ON DELETE CASCADE,
    labeled_by      uuid,                                    -- user_id del medico
    labels          jsonb       NOT NULL,                    -- formato YOLO: [{class_id, x_c, y_c, w, h}]
    exported_at     timestamptz,                             -- quando incluso in training run
    created_at      timestamptz NOT NULL DEFAULT now()
);
```

### Fase 2 — Python AI Service (microservizio Docker)

**Stack:** Python 3.11, FastAPI, Ultralytics YOLOv8/v11, boto3, torch.

```
ai-service/
├── Dockerfile
├── requirements.txt
├── main.py          — FastAPI app
├── inference.py     — YOLO inference logic
├── training.py      — fine-tuning / retraining pipeline
└── models/
    └── dental_yolo.pt   — modello base (volume Docker)
```

**Endpoints FastAPI:**
```
POST /infer          — { object_key } → { detections, model_version, duration_ms }
POST /train          — avvia job retraining asincrono (background task)
GET  /train/status   — stato job corrente
GET  /models         — lista versioni modello disponibili
```

**Deployment: tutto sulla stessa macchina (`192.168.0.72`), stesso `docker-compose.yml`.**

```
192.168.0.72 — Docker Engine
├── postgres          (già presente)
├── spring-backend    (già presente)
├── frontend          (già presente)
├── minio             (aggiunto con #5)
└── ai-service        (aggiunto con #6 — Python FastAPI + YOLO)
```

Tutti i container comunicano via **rete Docker interna** per nome container:
```
spring-backend → http://minio:9000       (salva/legge file)
spring-backend → http://ai-service:8001  (chiede inference)
ai-service     → http://minio:9000       (legge immagine per YOLO)
```

`ai-service` **non è esposto all'esterno** — solo `spring-backend` lo chiama internamente.

**`docker-compose.yml` — sezioni da aggiungere:**
```yaml
  minio:                                   # già definito in #5
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    restart: unless-stopped
    environment:
      MINIO_ROOT_USER: ${MINIO_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
    volumes:
      - minio_data:/data

  ai-service:
    build: ./ai-service/
    restart: unless-stopped
    environment:
      MINIO_ENDPOINT: http://minio:9000
      MINIO_ACCESS_KEY: ${MINIO_USER}
      MINIO_SECRET_KEY: ${MINIO_PASSWORD}
      MINIO_BUCKET: dentalcare-docs
      MODEL_PATH: /models/dental_yolo.pt
      TRAINING_DATASET_BUCKET: dentalcare-training
    volumes:
      - ai_models:/models
    depends_on:
      - minio
    # nessuna porta esposta: solo rete interna Docker

volumes:
  minio_data:
  ai_models:
```

**GPU:** se il server ha GPU NVIDIA aggiungere `runtime: nvidia` al container `ai-service`. Su CPU: inference ~8-15s/immagine (accettabile). Training su CPU: ore per run → GPU fortemente consigliata per il retraining.

### Fase 3 — Backend Spring Boot

**Nuovo endpoint:**
```
POST /api/patients/{patientId}/documents/{docId}/analyze
  → chiama AI service → salva analysis → restituisce analysisId

GET  /api/patients/{patientId}/documents/{docId}/analysis
  → restituisce ultima analysis (status + detections)

POST /api/patients/{patientId}/documents/{docId}/labels
  → salva label corrette dal medico
  → se totale label > soglia → trigger retraining asincrono via AI service
```

**`AiAnalysisService`:** gestisce chiamata HTTP a `http://ai-service:8001/infer`, polling status, salvataggio risultati.

### Fase 4 — Frontend Angular

**Al momento del caricamento ortopanoramica:** bottone "Analizza con AI" → spinner → mostra risultati.

**Overlay bounding box (Canvas API):**
```typescript
// Dopo ricezione detections, disegna su canvas sovrapposto all'immagine
drawDetections(ctx: CanvasRenderingContext2D, detections: Detection[], imgW: number, imgH: number): void {
  for (const d of detections) {
    ctx.strokeStyle = d.approved ? '#10b981' : '#f59e0b';  // verde=approvato, ambra=da verificare
    ctx.lineWidth = 2;
    ctx.strokeRect(d.x1 * imgW, d.y1 * imgH, (d.x2 - d.x1) * imgW, (d.y2 - d.y1) * imgH);
    ctx.fillText(`${d.class} ${Math.round(d.confidence * 100)}%`, d.x1 * imgW, d.y1 * imgH - 4);
  }
}
```

**UI correzione label:**
- Click su bounding box → dialog: "Conferma rilevamento / Rimuovi / Cambia classe"
- Bottone "Salva correzioni" → POST /labels → alimenta retraining

### Fase 5 — Retraining pipeline

**Trigger automatico:** quando `patient_document_labels` accumula N nuove label (es. 50) dall'ultimo training → Spring chiama `POST /train` su AI service.

**Training job (Python asincrono):**
1. Scarica tutte le label da DB
2. Scarica le immagini corrispondenti da MinIO
3. Prepara dataset in formato YOLO (`images/`, `labels/`)
4. Fine-tune del modello base con `model.train(data=..., epochs=50)`
5. Valuta su validation set → se mAP migliora, promuovi a `dental_yolo_v{n+1}.pt`
6. Aggiorna `MODEL_PATH` → le inference successive usano il modello aggiornato

### File coinvolti
| Layer | File |
|-------|------|
| Infrastruttura | `docker-compose.yml`, `.env`, nuovo folder `ai-service/` |
| DB | 2 nuove tabelle + aggiornamento install.sql |
| Backend | `AiAnalysisService`, `AiAnalysisController`, 2 nuovi DTO |
| Frontend | `documenti-tab` (aggiunta overlay Canvas + UI label), `patient-document.service.ts` (nuovi metodi) |
| Python | `ai-service/` completo |

### Ordine implementazione consigliato
1. #4 (tab documenti, base64) — upload e visualizzazione immediata
2. #5 (MinIO) — migrazione storage
3. #6 questa — AI inference + label loop + retraining

### Note
- Modello base: scaricare **DENTEX 2023** weights o fine-tune YOLOv8n dental da HuggingFace come punto di partenza
- Confidence threshold suggerito per UI: 0.35 (sopra → mostra box; sotto → ignora)
- Privacy: le ortopanoramine con label non escono mai dal server (MinIO locale + AI service locale) — GDPR compliant
- GPU non obbligatoria per MVP: YOLOv8n su CPU impiega ~8s su ortopanoramica standard — accettabile per uso clinico non real-time
- Se la GPU è disponibile (anche consumer RTX 3060): inference scende a ~0.3s

### Sessione validazione E2E (2026-06-30)

Test end-to-end reale (backend + ai-service + MinIO + frontend) con modelli ONNX reali su ortopanoramica. Bug di integrazione trovati e risolti (commit `5437f3e`):
- **ai-service** — i modelli ONNX bakano la normalizzazione `/255`: aggiunto `model_input_scale` configurabile (default 255) per non normalizzare due volte.
- **backend** — `RestClient` forzato a HTTP/1.1: JDK HttpClient usava HTTP/2 h2c upgrade in chiaro, rifiutato da uvicorn come richiesta invalida.
- **backend** — colonne `numeric` lette come `BigDecimal` poi convertite a `Double` (il cast `rs.getObject` a `Double` lanciava `ClassCastException`).
- **frontend** — `start()` legge `analysisId` (era `id` → undefined, rompeva l'URL SSE).

Feature aggiunte (commit `a33f48b`):
- **Mappa coerente AI→condizione DentalCare** (tutti i tenant): `Caries`/`Deep_Caries`→`cavity` (superficie B), `Periapical_Lesion`→`root_canal` (whole), `Impacted`→**nuova condizione** `impacted` (Incluso, whole).
- **Distinzione AI/manuale in odontogramma**: `source` esposto nel DTO + badge cyan "AI" sui denti con condizione AI + voce legenda.
- **Save manuale robusto**: upsert `ON CONFLICT` (una modifica manuale su una cella AI ne prende possesso, `source→manual`); il frontend omette le AI non toccate dal payload per preservarne il badge.
- **UI analisi**: legenda evidenze in chiaro, viewer a schermo intero, bottone "Ri-analizza" (re-inferenza esplicita) e re-sync odontogramma; alla riapertura ridisegna i box dai dati salvati **senza re-inferenza**.
- Sync odontogramma: DELETE allargato a tutte le righe AI del paziente (ultima analisi vince).

Suite backend verde (36 test). Merge su `master` in FF; branch `feat/ai-yolo-service` eliminato.

---

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

**Stato:** Fatta — `ChatHistoryService.assertOwned`/`resolveOwnedSession` + guard su `getSessionMessages`; `ChatController` POST e `/stream` usano `resolveOwnedSession`. Test `ChatHistoryServiceTest` (4). Suite 40 verde.
**Data proposta:** 2026-07-01
**Impatto:** Basso (~½ giornata)

### Contesto
La cronologia della Segreteria AI è **già suddivisa per utente** (`chat_sessions.provider_id`): creazione, elenco (`GET /chat/sessions`) e cancellazione sono filtrati sul `provider_id` derivato dal JWT. `ai_conversations` (vecchia tabella clinic-scoped) non è più usata. La cronologia appare condivisa solo quando si accede con lo **stesso account** (es. demo).

### Problema (IDOR)
Due endpoint non verificano la proprietà della sessione:
- `GET /chat/sessions/{id}/messages` → legge i messaggi di **qualsiasi** sessione conoscendone l'UUID
- `POST /chat` e `POST /chat/stream` con `sessionId` fornito dal client → **appendono** messaggi a una sessione altrui

Un utente che conosce/indovina un UUID di sessione può leggere o continuare la chat di un altro provider (Insecure Direct Object Reference).

### Soluzione
Enforcement della proprietà lato server, senza cambi di schema:
1. `ChatHistoryService.assertOwned(sessionId)` — verifica `chat_sessions.id = :id AND provider_id = :pid`; se assente → `ResourceNotFoundException` (404, non rivela l'esistenza).
2. `ChatHistoryService.resolveOwnedSession(sessionId, firstMessage)` — se `sessionId` null crea una nuova sessione (di proprietà del provider corrente); altrimenti `assertOwned` e la restituisce.
3. `getSessionMessages` → chiama `assertOwned` prima di leggere.
4. `ChatController` (`POST /chat` e `/chat/stream`) → usa `resolveOwnedSession` invece di accettare ciecamente `request.sessionId()`.
5. `deleteSession` già scoped (`WHERE id AND provider_id`) — nessuna modifica.

### File coinvolti
| Layer | File |
|-------|------|
| Backend | `ChatHistoryService` (assertOwned + resolveOwnedSession + guard in getSessionMessages), `ChatController` (POST + stream usano resolveOwnedSession) |
| Frontend | Nessuna modifica (già usa gli endpoint per-provider) |
| DB | Nessuna modifica (`provider_id` + indice già presenti, anche in `create_tenant`) |

### Note
- Per avere effettivamente cronologie separate serve che ogni operatore abbia un **account (provider) distinto** — il modello dati lo supporta già.
- Il contesto AI usa `request.history` (client) → nessun leak di contesto tra utenti; la fix riguarda solo la persistenza server-side.
- Nessun cambio al contratto API né al frontend.

---

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

**Stato:** Fatta (Livello A+B) — label menu + stringhe chat/impostazioni/badge appuntamento rinominate in "Copilot AI"; ruolo `secretary` e backend intatti. Livelli C (route/cartella) e D (marketing) restano fuori ambito.
**Data proposta:** 2026-07-01
**Impatto:** Basso (~½ giornata) — solo stringhe UI, nessuna logica

### Contesto
"Segreteria AI"/"SegretarIA" identifica **due concetti diversi**:
1. la **feature chat AI** (assistente) — da rinominare in "Copilot AI"
2. il **ruolo utente** `secretary` / "Segreteria" (segretaria vs medico vs admin) — **da NON toccare** (guard/permessi)

Il **Livello A** (label del menu `Segreteria AI` → `Copilot AI` in `app.ts`) è **già fatto**. Questa proposta copre il **Livello B**: rinominare la feature ovunque nella UI in-app, lasciando intatto il ruolo.

### Ambito (Livello B — stringhe da cambiare)
- `features/segretaria/segretaria.component.html`: "SegretarIA" (header, ~riga 12), "SegretarIA AI" (label messaggi, ~114), "Powered by SegretarIA Engine v2.4" (~304); opzionale persona "Giulia Segreteria" (~217)
- `features/impostazioni/impostazioni.component.html`: "Cronologia chat SegretarIA" (~1180-1181)
- `features/agenda/nuovo-appuntamento/nuovo-appuntamento.component.html`: badge "SegretarIA" (~259)

### Da NON toccare
- Ruolo `secretary` / label "Segreteria": `impostazioni.component.ts:121`, `app.html:86` e `:106`, `role.guard.ts`, `core/services/user-context.service.ts`
- Asset `ai-den-secretary.png` (rinomina opzionale, cosmetica)
- Backend: nessun naming "Segreteria" nel codice AI (`ChatService`, `DentalCareAiTools`)

### Fuori ambito (livelli superiori, decisioni a parte)
- **C — Route/cartella**: `/segretaria` → `/copilot`, `features/segretaria/` → `features/copilot/`, rinomina componente + import in `app.routes.ts` e link. Cosmetico, più file.
- **D — Marketing pubblico**: `landing.component.html` ("Segretaria Virtuale/AI"), `registrazione` ("AI-DEN Segretaria"). Branding di prodotto.

### File coinvolti (Livello B)
| Layer | File |
|-------|------|
| Frontend | `segretaria.component.html`, `impostazioni.component.html`, `nuovo-appuntamento.component.html` (solo stringhe) |
| Backend | Nessuno |

### Note
- Nessun cambio di logica/route → rischio minimo; serve solo rebuild frontend.
- Coerente con la roadmap #10 (il prodotto evolve da "segreteria" reattiva a "copilot").

---

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

**Stato:** Proposta
**Data proposta:** 2026-07-02
**Impatto:** Alto (~3-4 giorni)
**Prerequisito:** #10 Fase 0 (audit + disclaimer + gating ruolo)
**Scompone:** #10 Fasi 1-2

### Problema
Il Copilot oggi è **read-only fuori dall'agenda**. Tool attuali (`DentalCareAiTools`): lettura (appuntamenti, ricerca pazienti, dettaglio paziente, preventivi, richiami, fatture, dashboard, provider, slot liberi, briefing giornaliero) + scrittura **solo agenda** (crea/sposta/annulla appuntamento con `preview*`→`confirmAction`). Non può creare un preventivo, chiudere un richiamo, aggiungere una nota clinica, né leggere piani di cura/odontogramma/anamnesi/listino/scorte.

### Obiettivo
Da assistente di consultazione a **operativo su tutti i moduli**, riusando il pattern `preview → confirmAction` (già multi-codice) e i **service esistenti** (nessuna nuova logica di dominio).

### Blocco 1 — Tool di SCRITTURA (confirm-gated)
Ogni azione: `previewX` (nessun salvataggio) → codice → `confirmAction` (già gestisce più codici insieme).

| Modulo | Nuovi tool | Service esistente |
|--------|-----------|-------------------|
| Preventivi | `previewCreateEstimate`, `previewAddEstimateLine`, `previewUpdateEstimateStatus` | `EstimateService` |
| Richiami | `previewCreateRecall`, `previewMarkRecallContacted`, `previewCloseRecall` | `RecallService` |
| Pazienti | `previewCreatePatient`, `previewUpdatePatient` | `PatientService` |
| Piani di cura | `previewCreatePlan`, `previewAddPlanItem` | `TreatmentPlanService` |
| Clinico | `previewAddDiaryNote`, `previewAddDiagnosis`, `previewAddPrescription` | `ClinicalRecordService`, `DiagnosiService`, `PrescrizioneService` |

### Blocco 2 — Tool di LETTURA mancanti
| Tool | Fonte |
|------|-------|
| `getTreatmentPlans(patientId)` | `TreatmentPlanService.findByPatient` |
| `getOdontogram(patientId)` + patologie AI | `OdontogramService` + `patient_document_analyses` (#6) |
| `getAnamnesisAlerts(patientId)` (allergie, terapie, alert) | `AnamnesisService` |
| `getServiceCatalog(query)` (listino/prezzi) | `ServiceCatalogService` |
| `getInventory` / `getLowStock` | `ProductService` / `StockMovementService` |

### Gating per ruolo
Scrittura clinica (note/diagnosi/prescrizioni/piani) riservata a **medico**; segreteria limitata ad agenda/preventivi/richiami/anagrafica base. Ogni azione confermata → **audit** (Fase 0 #10).

### File coinvolti
| Layer | File |
|-------|------|
| Backend | `DentalCareAiTools` (nuovi `@Tool`), riuso service esistenti; system prompt (nuove capacità + disclaimer clinici) |
| Frontend | Nessuno (chat invariata) |
| DB | Nessuno (audit table arriva con #10 Fase 0) |

### Note
- Riusa `preview → confirmAction`: nessun nuovo pattern, nessun nuovo endpoint.
- Tutti i service esistono già → costo reale = wiring tool + prompt + test.
- Le letture del Blocco 2 sono a costo basso e alto uso (rispondono a domande cliniche quotidiane) → implementabili anche prima della scrittura.

---

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

**Stato:** Fatta (dev) — 2026-07-02. Validato E2E: seed IT/EN, GET admin 200, dentista 403, PUT/GET override/DELETE reset OK, chiave invalida 400, chat usa il prompt da DB.
**Data proposta:** 2026-07-02
**Impatto:** Medio

### Obiettivo
Esternalizzare i prompt AI (oggi hardcoded in `ChatService.SYSTEM_PROMPT`) in una struttura **chiave-valore multilingua**, editabile dall'admin di studio **senza redeploy**. Opzione A (DB + cache) con **override per-tenant** e UI **solo modifica valori** (chiavi definite dagli sviluppatori).

### Design
- **Default globali**: `dentalcare.ai_prompts(prompt_key, locale, value, description)`. Seed dall'app dalle risorse bundle `ai-prompts/<key>.<locale>.txt` (niente testo prompt nelle patch SQL).
- **Override per-studio**: `<schema>.ai_prompt_overrides(clinic_id, prompt_key, locale, value)`.
- **Risoluzione** (locale-first): override tenant+locale → globale+locale → override tenant+base → globale+base → risorsa bundle. Cache in-memory svuotata ad ogni scrittura.
- **Placeholder** `{{oggi}}`/`{{ora}}` risolti a runtime, formattati per locale.
- Lingue seed: **IT + EN**. Base locale `it`. `ChatRequest.locale` opzionale (default `app.ai.default-locale=it`).

### File coinvolti
| Layer | File |
|-------|------|
| DB | `patch_ai_prompts.sql`; `install.sql` (tabella globale + template `create_tenant` + demo). Self-provisioning via `EstimateSchemaInitializer` + `PromptService` bootstrap |
| Backend | `PromptService`, `AiPromptController` (`/api/admin/ai-prompts`), DTO `AiPromptDto`/`AiPromptLocaleDto`/`UpdateAiPromptRequest`, wiring `ChatService`, `SecurityConfig` (`/api/admin/**` → ADMIN/TENANT_ADMIN), risorse `ai-prompts/chat.system.{it,en}.txt` |
| Frontend | `ai-prompt.model.ts`, `ai-prompt.service.ts`, `AiPromptsComponent`, tab "AI" in `ImpostazioniComponent` |

### Estensioni future
- Nuove lingue: basta aggiungere `ai-prompts/chat.system.<locale>.txt` + il locale in `PromptService.LOCALES`.
- Nuove chiavi prompt (es. prompt tool-specifici, email templates): aggiungere a `PromptService.KEYS` + risorse.
- Derivare il `locale` reale dell'utente (oggi default `it`) da preferenza/Accept-Language.
- Blocco più oneroso e meno urgente: implementare dopo #13/#14 (valore operativo immediato).

---

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
