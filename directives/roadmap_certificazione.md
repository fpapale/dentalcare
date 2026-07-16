# Roadmap di certificazione — Conformità EU AI Act (perimetro non-MDR)

**Documento di riferimento:** `DentalCare_Pro_EU_AI_Act_Compliance_2026.md` (v1.0, 16 luglio 2026)
**Data:** 16 luglio 2026
**Decisione di perimetro:** **NON si intraprende il percorso MDR / marcatura CE** per i moduli AI a titolo medico.
**Metodo:** stato verificato su codice e schema DB reale (`t_9d754153`), non su documentazione.

> **Avvertenza.** Questo è un piano tecnico-operativo, non un parere legale. La classificazione regolatoria e il gate clinico vanno sottoscritti da Regulatory Affairs e DPO prima del rilascio.

---

## 1. La conseguenza della decisione "no MDR"

Va detto senza ambiguità, perché determina tutto il resto del documento.

Il modulo radiologico di DentalCare (ONNX `dentex_fdi_v1` + `dentex_disease_v1`, rilevamento carie/lesioni periapicali/denti inclusi su ortopanoramica) è, secondo il documento di riferimento (§5), **verosimilmente un Medical Device Software di classe IIa o superiore** ai sensi della Rule 11 MDR.

Rinunciare al percorso MDR **non rende il modulo conforme: lo rende non commercializzabile per uso clinico.**

> **Regola operativa che ne discende:**
> Finché non esiste marcatura CE, il modulo radiologico **non può essere usato su pazienti reali per finalità diagnostiche o terapeutiche**, né essere presentato con finalità mediche.
> Le etichette "beta", "prototipo", "ricerca" o "solo supporto" **non neutralizzano il MDR** (§33.1, §33.2).

Quindi la conformità nel perimetro scelto **non si ottiene documentando il modulo radiologico**, ma **estraendolo dall'uso clinico** in modo tecnicamente verificabile. Questo è il lavoro #1 di questa roadmap.

### 1.1 Cosa resta possibile senza MDR

| Uso del modulo radiologico | Ammesso senza MDR? | Condizioni |
|---|---|---|
| Demo / tenant dimostrativo con dati fittizi | ✅ | nessun paziente reale, claim non medici |
| Sviluppo e validazione offline | ✅ | dati sintetici o pseudonimizzati, output non usato per la cura |
| Ricerca / studio autorizzato | 🟡 | base giuridica, DPIA, eventuale comitato etico, protocollo |
| **Shadow mode** (output calcolato ma non mostrato né usato) | 🟡 | previa valutazione legale e privacy; nessun accesso dell'odontoiatra all'output |
| **Supporto diagnostico su pazienti reali** | ❌ | **richiede MDR + CE. Vietato oggi.** |
| Marketing con claim medici | ❌ | vietato senza evidenza e certificazione (§33.3) |

### 1.2 Cosa resta pienamente perseguibile

Il **resto della piattaforma** è conformabile all'AI Act **adesso e senza organismo notificato**:

- gestionale, agenda, cartella, fatturazione: **non-AI**, fuori dall'AI Act (restano GDPR e qualità software);
- **Giulia** (voce/chat Retell) e il **Copilot AI**: sistemi AI **non high-risk**, soggetti a **trasparenza (art. 50)**, **AI literacy (art. 4)**, governance, sicurezza e GDPR;
- automazioni n8n / LLM amministrativi: non high-risk purché non producano valutazioni cliniche.

**Questo è il perimetro reale della roadmap.**

---

## 2. La scadenza che conta: 2 agosto 2026 — **fra 17 giorni**

| Data | Cosa scatta | Rilevanza per noi |
|---|---|---|
| 2 feb 2025 | divieti + **AI literacy** | **già applicabile — siamo in ritardo** |
| 2 ago 2025 | governance + GPAI | due diligence sui modelli generali (OpenAI) |
| **2 ago 2026** | **maggior parte delle norme + trasparenza art. 50** | **P0 di questa roadmap** |
| 2 dic 2026 | marcatura contenuti sintetici (Digital Omnibus) | verificare applicabilità ai testi generati |
| 2 dic 2027 | high-risk standalone (Annex III) | non centrale |
| 2 ago 2028 | high-risk embedded (Annex I) | **irrilevante finché non facciamo MDR** |

**Il differimento al 2028 non ci aiuta**: riguarda gli obblighi *high-risk AI Act* dei dispositivi. Non sospende il MDR, che è la norma che oggi ci blocca il modulo radiologico.

> Da conservare nel fascicolo: copia del **Digital Omnibus pubblicato in GUUE** (Consiglio: approvazione 29 giugno 2026). Verificare numero, data e testo definitivo prima di congelare la timeline.

---

## 3. Classificazione dei moduli DentalCare (da approvare formalmente)

| Modulo | Esiste? | AI Act | MDR | Decisione |
|---|---|---|---|---|
| Agenda, pazienti, cartella, fatturazione, magazzino | ✅ | Non-AI | Non-MD | GDPR + qualità software |
| **Giulia** — voce/chat prenotazioni (Retell + n8n) | ✅ | **AI — trasparenza art. 50** | Non-MD se solo amministrativa | **Disclosure + fallback umano entro il 2 ago** |
| **Copilot AI** (Spring AI + GPT-4.1, tool calling) | ✅ | AI non high-risk | Non-MD **se non suggerisce clinica** | Limitare i tool clinici; vietare diagnosi/priorità |
| Prompt Manager (`ai_prompts` + override) | ✅ | parte del ciclo AI | — | Change control sui prompt |
| **Modulo radiologico** (ONNX FDI + disease) | ✅ | *sarebbe* high-risk ex art. 6(1) | **Probabile MDSW IIa+** | **GATE: fuori dall'uso clinico** |
| Interfaccia revisione/annotazione (`patient_document_labels`) | ✅ | ciclo di vita AI | parte del QMS se MDSW | **Vietare auto-retraining** |
| Riaddestramento con dati di produzione | 🟡 label raccolte | rischio elevato | modifica sostanziale | **Vietato per policy** |
| KPI/analytics di studio | 🟡 | non high-risk | Non-MD | anonimizzazione |

**Regola di separazione (§3.2 del riferimento):** ogni modulo deve essere attivabile/disattivabile, versionabile, autorizzabile e loggabile **separatamente**. Oggi **non lo è**: non esiste un feature flag per-modulo/per-tenant. È un requisito tecnico della roadmap, non un dettaglio.

---

## 4. Stato attuale verificato — cosa già gioca a favore

Non partiamo da zero. Verificato nel codice/DB:

| Elemento | Stato | Evidenza |
|---|---|---|
| **Tracciabilità output AI** | ✅ buona | `patient_document_analyses`: `model_fdi`, `model_disease` (versioni), `job_id`, `review_status`, `reviewed_by_provider_id`, `reviewed_at`, `needs_review`, `requested_by_provider_id` |
| **Output AI distinto dalla decisione umana** | ✅ | `tooth_conditions.source` = `manual` \| `ai` + `analysis_id`; una modifica manuale su una cella AI ne prende possesso (`source→manual`). Soddisfa la regola fondamentale §17.1 |
| **Revisione umana esplicita** | ✅ | accetta / modifica / rifiuta già implementati in UI, con `review_status` persistito |
| **Audit delle tool call AI** | 🟡 | `ai_audit_log` (clinic_id, provider_id, action_type, tool_name, args_summary, result, created_at) |
| **Disclaimer AI** | 🟡 | introdotto con la Fase 0 governance copilot — **da verificare che copra Giulia all'inizio della chiamata** |
| **Gating per ruolo dei tool clinici** | 🟡 | il copilot distingue ruoli medici; da irrigidire |
| **Prompt versionabili** | 🟡 | `ai_prompts` + `ai_prompt_overrides` per tenant |
| **Segregazione tenant + cifratura** | ✅ | schema-per-tenant, chiavi per-tenant (HKDF/AES-GCM), master key fail-fast |
| **Nessun training automatico in produzione** | 🟡 di fatto | le label sono raccolte ma non retroagiscono sul modello — **va reso esplicito per policy, non lasciato al caso** |

Il pezzo più prezioso: **la catena `analysis → review → tooth_condition.source` esiste già.** È l'ossatura di §16.3 e del criterio §26.4. Va documentata, non riscritta.

---

## 5. Gap AI Act (perimetro non-MDR)

### 5.1 🔴 Bloccanti entro il 2 agosto 2026

| # | Gap | Stato | Azione |
|---|---|---|---|
| G1 | **Gate no-clinical sul modulo radiologico** | ❌ assente | Feature flag per tenant, **default OFF** in produzione clinica; rimozione dei claim medici dalla UI; log del cambio stato |
| G2 | **Registro AI** (`AI_System_Inventory.md`) | ❌ assente | Inventario di tutti i sistemi AI con i 20 campi §3.1 |
| G3 | **AI Use Policy** | ❌ assente | Divieti §8.2, incluso: no dati sanitari a LLM pubblici, no retraining su dati di produzione, no modifica prompt/soglie in produzione |
| G4 | **AI literacy** (art. 4 — **già in vigore dal 2 feb 2025**) | ❌ assente | Piano formativo differenziato §8.3 + evidenze (registro, materiali, test) |
| G5 | **Disclosure Giulia** (art. 50) | 🟡 da verificare | Annuncio AI **prima** di raccogliere informazioni + fallback umano sempre disponibile |
| G6 | **Limiti operativi di Giulia** | 🟡 | Regole deterministiche: no diagnosi, no triage, no urgenze, escalation a umano |
| G7 | **DPIA** | ❌ assente | Avviare (obbligatoria: multi-tenant + dati sanitari + AI) |
| G8 | **Due diligence fornitori** | ❌ assente | Retell, OpenAI, n8n, MinIO/cloud: DPA, SCC, TIA, no-training, sub-processor |
| G9 | **Informativa paziente sull'uso dell'AI** (L. 132/2025) | ❌ assente | Informativa breve in UI + estesa; decisione resta al professionista |
| G10 | **Incident intake** | ❌ assente | Canale e SOP di raccolta incidenti AI |
| G11 | **Registro claim** | ❌ assente | Claim autorizzati/vietati; allineare sito, demo, materiale commerciale |
| G12 | **Kill switch + separazione moduli** | ❌ assente | Disattivazione per modulo/tenant, log distinti, change control indipendente |

### 5.2 🟠 Da chiudere entro 30–90 giorni

- **AI Compliance Owner** nominato + comitato AI + RACI (§40);
- **classificazione formale** di ogni modulo (memo firmato) e memo provider/deployer (contratti con gli studi: chi è deployer, cosa non deve fare per non diventare provider — §6.3);
- **logging AI**: estendere `ai_audit_log` con `patient_id`, esito, sessione, correlation ID; e l'inferenza con hash input, soglie, runtime, latenza, qualità immagine, astensione (§17.1);
- **protezione LLM/agenti** (§19.3): prompt injection testing, allowlist tool, conferma umana per azioni sensibili, redazione dati, kill switch, test di esfiltrazione;
- **data flow map** + ROPA + inventario sub-processor;
- **SOP change/retraining**: le correzioni dell'odontoiatra sono **feedback, non ground truth** (§18.1);
- **contenuti sintetici** (2 dic 2026): valutare marcatura per i testi generati (e-mail/promemoria).

### 5.3 ⚪ Fuori perimetro per scelta (riaprire solo se si decide il MDR)

QMS ISO 13485, fascicolo tecnico, risk file ISO 14971, IEC 62304/62366, clinical evaluation (CEP/CER), PMCF, organismo notificato, marcatura CE, documentazione AI Act artt. 8-15.

**Questi non si fanno.** Il prezzo è la §1.1: niente uso clinico del modulo radiologico.

---

## 6. Roadmap

### Fase 0 — Entro il **2 agosto 2026** (17 giorni) — non rinviabile

Ordine di esecuzione consigliato (il primo è quello che spegne il rischio più grande):

1. **[G1] Gate no-clinical.**
   - `feature_flag` per tenant: `ai.radiology.enabled` (default `false` in prod);
   - in produzione clinica: modulo **disattivato**; attivo solo su tenant demo/dati fittizi;
   - rimuovere dalla UI ogni formulazione che suggerisca finalità diagnostica;
   - registrare chi attiva/disattiva e quando.
2. **[G5][G6] Giulia: disclosure + limiti.**
   - annuncio AI a inizio interazione (script §8.4), non nei T&C;
   - fallback umano sempre offerto;
   - regole deterministiche di escalation; frase di rifiuto per richieste cliniche;
   - informativa registrazione **distinta** da quella "sto parlando con un'AI".
3. **[G2] Registro AI** approvato (anche `.md` in `directives/`, purché versionato e approvato).
4. **[G3] AI Use Policy** approvata.
5. **[G4] AI literacy**: sessione + registro presenze + materiali (è già scaduto: chiudere il ritardo con evidenza datata).
6. **[G11] Registro claim** + bonifica del materiale commerciale e delle schermate.
7. **[G7] DPIA avviata** (non necessariamente chiusa) + **[G8] gap analysis fornitori**.
8. **[G9] Informativa paziente** sull'uso dell'AI in UI.
9. **[G10] Incident intake** attivo.
10. **[G12] Kill switch** per Giulia e Copilot.
11. **Prova delle modifiche**: commit datati, approvazioni, screenshot. L'evidenza vale quanto la misura.

### Fase 1 — 30 giorni (entro ~15 agosto 2026)

- AI Compliance Owner + comitato + RACI;
- classificazione formale di tutti i moduli (memo);
- data flow map, ROPA, inventario sub-processor;
- separazione ambienti (prod clinica / demo / sviluppo);
- policy di logging;
- inspection binder (repository con indice e owner);
- contratti studi: clausole deployer (§6.2, §6.3).

### Fase 2 — 60 giorni (entro ~15 settembre 2026)

- **DPIA completa** approvata dal DPO;
- **DPA + SCC + TIA** per Retell / OpenAI / cloud; verifica **no-training** e data location;
- remediation fornitori non conformi (o sostituzione);
- SOP change/retraining formalizzata;
- threat model cybersecurity + test prompt injection sul Copilot;
- estensione del logging AI (patient_id, esito, correlation ID).

### Fase 3 — 90 giorni (entro ~15 ottobre 2026)

- MFA per ruoli privilegiati (vedi anche `gap-analysis-cartella-clinica.md` §3.6);
- penetration test + remediation;
- audit interno del programma AI;
- monitoraggio override/uso del Copilot (KPI §25.1 applicabili al perimetro non medico);
- **verifica marcatura contenuti sintetici** in vista del 2 dic 2026;
- simulazione di controllo (domande §29).

### Fase 4 — 180 giorni

- riesame della decisione MDR (vedi §8);
- management review;
- aggiornamento DPIA e registro AI;
- formazione ricorrente + evidenze.

---

## 7. Checklist di readiness (semaforo)

| Area | Stato | Owner | Scadenza |
|---|---|---|---|
| Gate no-clinical modulo radiologico | 🔴 | CTO | 2 ago 2026 |
| Registro AI | 🔴 | AI Compliance Owner | 2 ago 2026 |
| AI Use Policy | 🔴 | CEO | 2 ago 2026 |
| AI literacy | 🔴 (**scaduto dal 2 feb 2025**) | HR/Quality | 2 ago 2026 |
| Disclosure Giulia | 🟡 verificare | Product | 2 ago 2026 |
| Limiti operativi Giulia | 🟡 | Product | 2 ago 2026 |
| Informativa paziente AI | 🔴 | DPO | 2 ago 2026 |
| Registro claim | 🔴 | Marketing | 2 ago 2026 |
| DPIA | 🔴 | DPO | avvio 2 ago / chiusura 60 gg |
| DPA fornitori | 🔴 | Legal | 60 gg |
| Kill switch / separazione moduli | 🔴 | CTO | 2 ago 2026 |
| Logging AI esteso | 🟡 | Engineering | 60 gg |
| Human oversight (accetta/modifica/rifiuta) | 🟢 | — | fatto |
| Output AI distinto (`source`/`analysis_id`) | 🟢 | — | fatto |
| Versione modello tracciata | 🟢 | — | fatto |
| Segregazione tenant + cifratura | 🟢 | — | fatto |
| Divieto auto-retraining | 🟡 de facto | CTO | formalizzare in policy |
| QMS / fascicolo / CE | ⚪ N/A | — | fuori perimetro (no MDR) |

---

## 8. Quando riaprire la decisione MDR

La scelta "no MDR" va riesaminata se si verifica uno di questi trigger:

- si vuole **vendere** il supporto diagnostico radiologico come funzione clinica;
- un cliente/gara richiede l'AI radiologica su pazienti reali;
- il Copilot inizia a **suggerire diagnosi, terapie o priorità cliniche** (§4: diventa probabile MDSW);
- un LLM viene usato per **riassumere dati clinici con implicazioni diagnostiche**;
- si introduce triage clinico in Giulia.

Fino ad allora il modulo resta un **asset tecnologico non commercializzabile clinicamente**: mantenerlo funzionante in demo/ricerca ha senso solo se il costo di manutenzione è giustificato dalla prospettiva di certificarlo in futuro.

**Stima indicativa del percorso MDR** (se riaperto): QMS + fascicolo + validazione clinica + organismo notificato ≈ **18-24 mesi** e un budget non marginale. È una decisione di business, non tecnica.

---

## 9. Le decisioni da prendere adesso

Adattate dalle "dieci decisioni" §44 al perimetro non-MDR:

1. **Separare formalmente la piattaforma amministrativa dal modulo radiologico** (feature flag + claim + contratti).
2. **Congelare l'uso clinico dei modelli ONNX** — senza MDR è un divieto, non una precauzione.
3. **Stabilire che Giulia non fa triage né consulenza clinica.**
4. **Introdurre la disclosure AI entro il 2 agosto 2026.**
5. **Stabilire che il Copilot non suggerisce diagnosi/terapie/priorità** (altrimenti diventa MDSW e ricadiamo nel problema).
6. **Bloccare per policy il riaddestramento con dati di produzione.**
7. **Completare DPIA e contratti dei fornitori AI.**
8. **Preparare evidenze verificabili**, non dichiarazioni: commit, approvazioni, registri datati.

---

## 10. Documenti da produrre (sottoinsieme non-MDR)

Dall'elenco §43, restano applicabili:

1. `AI_System_Inventory.md` — **P0**
2. `AI_Act_Classification_Memo.md` — 30 gg
3. `DentalCare_AI_Use_Policy.md` — **P0**
4. `AI_Literacy_Training_Plan.md` — **P0**
5. `Giulia_Transparency_Script.md` — **P0**
6. `Patient_AI_Information_Notice.md` — **P0**
7. `DPIA_DentalCare_AI` — avvio P0, chiusura 60 gg
8. `Supplier_AI_Due_Diligence_Questionnaire.md` — 60 gg
9. `Regulatory_Claims_Register` — **P0**
10. `Model_Change_and_Retraining_SOP.md` — 60 gg
11. `Logging_and_Traceability_Specification.md` — 60 gg
12. `AI_Incident_Response_SOP.md` — 90 gg
13. `Cybersecurity_Plan.md` + `SBOM.json` — 90 gg
14. `Release_Readiness_Checklist.md` — 90 gg
15. `Inspection_Readiness_Index.md` — 30 gg

**Non si producono** (fuori perimetro): Quality Manual, Risk Management Plan/Report ISO 14971, Clinical Evaluation Plan/Report, PMCF Plan, Intended Purpose imaging, MDR memo, model card ai fini regolatori, Usability Engineering File.

> Nota: `Model_Card_Dentex_FDI` / `Model_Card_Dentex_Disease` restano **consigliate** anche senza MDR — sono buona pratica di data governance e costano poco.

---

## 11. Rischio residuo dichiarato

Con questa roadmap completata:

- ✅ conformi agli obblighi AI Act applicabili al perimetro amministrativo (trasparenza, literacy, governance, GPAI);
- ✅ conformi GDPR (previa DPIA e contratti);
- ❌ **il modulo radiologico resta non utilizzabile clinicamente** — è un rischio *commerciale accettato*, non una non conformità, **purché il gate tecnico sia effettivo e verificabile**;
- ⚠️ il rischio si trasforma in **non conformità grave** se il modulo viene usato o presentato con finalità mediche senza CE (sanzioni MDR + AI Act fino a 15 M€ o 3% del fatturato, oltre a responsabilità civile e clinica).

**Il singolo controllo che regge tutta la posizione è il gate G1.** Se salta quello, la scelta "no MDR" smette di essere una strategia e diventa un'infrazione.
