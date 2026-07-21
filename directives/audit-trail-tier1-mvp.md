# Audit trail clinico — taglio Tier 1 (MVP go-live) vs Tier 2 (differito)

Companion operativo di [`Modello_probatorio_audit_trail_clinico_DentalCare.md`](Modello_probatorio_audit_trail_clinico_DentalCare.md), che resta la **stella polare** (stato-obiettivo completo). Questo file isola il **minimo che il Gate 1 richiede davvero** dal resto, così l'intervento **#1 — Audit trail clinico** (vedi *Priorità sviluppo Fase 1* in [`proposte-modifiche.md`](proposte-modifiche.md)) parte con uno scope chiuso e **non tira dentro terze parti a pagamento** (QTSP eIDAS) fuori dai tempi della Fase 1.

> **Regola del taglio.** Tier 1 = condizione d'ingresso del go-live (nessun paziente reale senza). Tier 2 = si fa **dopo** il go-live, o quando un evento concreto lo richiede (contenzioso, ispezione, apertura Fase 2). Mettere Tier 2 nel gate significa non arrivare a gennaio.

---

## 0. Stato attuale (verificato sul codice — 21/07/2026)

- **`ai_audit_log`** (per-tenant) esiste ma traccia **solo il Copilot**: colonne piatte `clinic_id, provider_id, action_type, tool_name, args_summary, result, created_at`. **Non** append-only-enforced, **niente** hash chain. → è il §11 del modello completo (inferenza AI): da **assorbire e irrobustire** nello schema comune, non da buttare.
- **Zero** audit clinico su accessi/letture/scritture della cartella. È il buco che l'#1 chiude.
- **Zero** versionamento/finalizzazione su `clinical_history_entries` → è l'intervento **#3** (greenfield). Vedi §4, dipendenza.
- Architettura: **schema-per-tenant**, evoluzione via `patchSchema` idempotente (colonne/tabelle `IF NOT EXISTS` a ogni avvio).

---

## 1. Tier 1 — obbligatorio per il Gate 1

Ordinato per costo di implementazione, non per importanza (tutte obbligatorie).

| # | Requisito | Scope concreto DentalCare (MVP) | Fonte | Costo |
|---|---|---|---|---|
| T1.1 | **Retention** ≥ 24 mesi accessi al dossier · ≥ 6 mesi admin | Colonna/policy; nessuna cancellazione automatica sotto soglia | Garante Doc-Web 10262049 / 1577499 | banale |
| T1.2 | **Contenuto minimo evento** | operatore, `occurred_at` UTC ms, postazione/`ip`, paziente, tipo operazione, esito | Garante 10262049 · ISO 27789 | basso |
| T1.3 | **Append-only enforced a livello DB** | tabella `clinical_audit_log` per-tenant; grant applicativo **solo INSERT**, niente UPDATE/DELETE; nessuna vista che permetta modifica | §3–§4 modello | basso |
| T1.4 | **Hash chain interna** | ogni evento porta `previous_event_hash` + `event_hash` (SHA-256 su JSON canonico). Tamper-evidence **senza** QTSP | §4 modello | basso–medio (vedi §3 decisione A) |
| T1.5 | **Attribuzione reale** | non solo `user_id`: ruolo-al-momento, metodo auth/MFA, `session_id`, e **perché la policy ha concesso** (`rule`, `care_relationship`) | §5 modello | medio |
| T1.6 | **Logging delle CONSULTAZIONI** (letture), non solo scritture | apertura paziente / anamnesi / odontogramma / referto / documento → evento. **È il costo dominante**: trasversale a ~40 service clinici | Garante 10262049 (esplicito sulle letture) | **alto** |
| T1.7 | **Alert base anomalie** | versione batch/query, non realtime: "N pazienti in M minuti", accesso senza relazione di cura, ripetuti negati, uso break-glass | Garante 10262049 (cita gli alert) | medio |
| T1.8 | **Eventi break-glass + admin** | accesso straordinario con motivazione obbligatoria + evento; accessi admin nominativi tracciati | §5 modello · voce gate 17/07 | medio |

**Definizione di "fatto" (Tier 1)** — mappa sulle voci del gate in `piano-lungo-termine.md §5`:
- [ ] audit trail clinico attivo e **append-only** (T1.3)
- [ ] copre **consultazioni** oltre alle scritture (T1.6)
- [ ] ogni evento ha il contenuto minimo Garante e l'attribuzione (T1.2, T1.5)
- [ ] tentativo di accesso negato dal #2 è **registrato con la ragione** (T1.5 — accoppiato all'intervento #2)
- [ ] break-glass tracciato (T1.8)
- [ ] retention configurata (T1.1)
- [ ] alert base presenti (T1.7)

---

## 2. Tier 2 — differito (eccellente, ma non blocca il go-live)

| Requisito | Perché è Tier 2 | Trigger per farlo |
|---|---|---|
| **Audit Evidence Service** separato + transactional outbox + SIEM (§4) | Infrastruttura, settimane. L'MVP per-tenant append-only regge il requisito legale | Scala / SOC / più tenant reali |
| **Timestamp e sigilli qualificati eIDAS** + radici Merkle (§6 livello forte) | Richiede **contratto QTSP** (soldi + integrazione). Alza la data da "server" a "opponibile a terzi" | Primo contenzioso reale / richiesta legale |
| **Evidence Package generator** (§7) | Feature intera; serve quando c'è una prova da produrre | Reclamo / ispezione / causa |
| **Catena di custodia con tooling** (§8) | La parte procedurale minima (log dell'export) è in T1.6/T1.8; il tooling completo è dopo | Con l'Evidence Package |
| **Log inferenza AI clinica** (§11) | La radiologia è **spenta** in Fase 1 → è roba Fase 2. Il copilot (AI amministrativa) è già in `ai_audit_log` | Apertura Fase 2 (MDR) |
| **Alert realtime / ML anomalie** | L'MVP batch (T1.7) soddisfa il Garante | Volumi reali |

---

## 3. Decisioni di design da chiudere nel brainstorm dell'#1

Queste **non le scelgo da solo** — cambiano la forma del codice. Sono l'input del `/brainstorming`.

**Decisione A — concorrenza della hash chain.** "Ogni evento porta l'hash del precedente" presuppone un ordine totale. Due scritture cliniche in parallelo si contendono il "precedente" → catena rotta o lock globale per-tenant (collo di bottiglia).
Opzioni:
- **A1** — sequenza single-writer per tenant (append serializzato): chain per-riga vera, ma serializza le scritture di audit.
- **A2** — nessuna chain per-riga; **sigillo periodico** (radice Merkle a fine ora/giorno) su un batch di eventi ordinati. Meno stringente per-evento, nessun lock, e prepara naturalmente il Tier 2 (§6).
- *Raccomandazione di partenza:* **A2** per l'MVP (nessun lock, path verso il Tier 2), con `event_hash` per-riga ma **senza** `previous_event_hash` bloccante finché non serve.

**Decisione B — dove vive il log.** Il modello completo suggerisce un servizio separato (§4, Tier 2). Per l'MVP:
- **B1** — `clinical_audit_log` **dentro ogni schema tenant**, via `patchSchema`. Coerente con l'esistente, isolamento per-tenant gratis. *Raccomandato per Tier 1.*
- **B2** — schema `dentalcare` globale unico per l'audit. Più vicino al Tier 2 ma rompe il pattern schema-per-tenant e mescola i tenant.
- *Raccomandazione di partenza:* **B1**.

**Decisione C — come si instrumentano le letture (T1.6).** È il costo vero.
- **C1** — intercettore/aspect trasversale sui controller/service clinici (poco codice ripetuto, rischio di loggare troppo o troppo poco).
- **C2** — chiamata esplicita `auditService.logRead(...)` nei punti clinici (verboso ma preciso).
- *Da decidere in base a quanti e quali endpoint contano come "consultazione del dossier".*

**Decisione D — modulo interno vs servizio separato (riuso).** Domanda: l'audit come modulo dentro il backend, o come **servizio separato** che DentalCare usa applicativamente e che un altro applicativo medico potrebbe riusare?
- **D1 (raccomandato per Tier 1)** — **modulo interno dietro un'interfaccia stretta** `AuditService.record(event)`, contratto d'evento stabile. Scrive su `clinical_audit_log` per-tenant. *L'interfaccia È già la cucitura del riuso.*
- **D2 (Tier 2)** — servizio separato, dominio di sicurezza distinto (auditor ≠ audited, §4 modello). Si ottiene **cambiando l'implementazione dietro l'interfaccia D1**: i ~40 punti di chiamata non si toccano. Precedente identico già in codice: `MasterKeyProvider`/`ConfigMasterKeyProvider` (seam pronto per Vault).
- **Ponte tra i due — il transactional outbox.** Chiamare un microservizio audit in sincrono crea il *dual-write* (la scrittura clinica committa, l'audit fallisce → si perde la prova; oppure l'audit giù blocca lo studio). Soluzione: l'evento va in tabella **nella stessa transazione** della modifica clinica; un relay lo spedisce dopo, async e ritentabile. **La `clinical_audit_log` del Tier 1 è già quell'outbox:** Tier 2 aggiunge solo il relay, zero rilavoro.
- **NON generalizzare adesso.** Con un solo applicativo, progettare l'astrazione "servizio audit medico generico" è indovinare i requisiti del secondo (YAGNI / regola del tre). Estrai la generalità quando il secondo caso è reale; l'interfaccia D1 rende l'estrazione economica.
- **Caveat compliance del riuso:** un servizio audit che ospita dati sanitari di più applicativi diventa **lui stesso** responsabile del trattamento — sua DPIA, suo DPA, sua postura di sicurezza. Il riuso moltiplica il perimetro che il DPO deve coprire; è una decisione di prodotto, non solo tecnica.
- *Raccomandazione:* **D1 ora**, D2 quando (a) serve la forza probatoria del dominio separato, o (b) il secondo applicativo è reale. In nessun caso far ritardare il gate di gennaio all'ambizione del riuso.

---

## 4. Sequenza con l'intervento #3 (versionamento/finalizzazione)

L'evento di audit del modello (§2) contiene `version_before` / `version_after`. **Quei numeri esistono solo se** la cartella è versionata — cioè l'intervento **#3**.

Conseguenza pratica: **#1 e #3 non sono del tutto indipendenti**, ma **non** vanno fatti in blocco.
- L'MVP dell'#1 logga l'azione **senza** i numeri di versione all'inizio (campi `version_before/after` nullable).
- Quando il #3 atterra (finalizzazione + versioni su `clinical_history_entries`), l'evento si **arricchisce** puntando alla versione.

Quindi: **#1 prima (fondazione), #3 dopo, l'audit si completa retroattivamente sui nuovi eventi.** Non serve aspettare il #3 per chiudere il Tier 1.

---

## 5. Schema di partenza (input al brainstorm, NON definitivo)

Bozza per dare concretezza alla discussione. Da rivedere con le decisioni §3.

```sql
-- per-tenant, creata da patchSchema. Append-only: grant solo INSERT.
CREATE TABLE <schema>.clinical_audit_log (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id         uuid NOT NULL,
    event_type        text NOT NULL,              -- READ | UPDATE | CREATE | FINALIZE | EXPORT | BREAK_GLASS | ...
    occurred_at_utc   timestamptz NOT NULL DEFAULT now(),
    -- attore (T1.5)
    actor_provider_id uuid,
    actor_role        text NOT NULL,              -- ruolo AL MOMENTO, dal JWT
    auth_level        text,                       -- PASSWORD | MFA
    session_id        text,
    ip_address        inet,
    -- soggetto
    patient_id        uuid,
    encounter_id      uuid,
    resource_type     text,                       -- ODONTOGRAM | ANAMNESIS | HISTORY_ENTRY | DOCUMENT | ...
    resource_id       uuid,
    version_before    integer,                    -- nullable finché non c'è il #3
    version_after     integer,
    -- operazione + autorizzazione (T1.2, T1.5)
    action            text NOT NULL,
    purpose           text,                        -- PATIENT_CARE | ADMIN | ...
    result            text NOT NULL,               -- SUCCESS | DENIED | ...
    authz_rule        text,                        -- perché la policy ha concesso/negato
    reason            text,                        -- motivazione (obbligatoria per BREAK_GLASS)
    -- integrità (T1.4, decisione A)
    event_hash        text NOT NULL                -- SHA-256 su rappresentazione canonica
    -- previous_event_hash text  -- solo se si sceglie A1
);
```

I documenti formali del §12 del modello completo (politica, catalogo eventi, matrice ruoli, procedura estrazione, retention policy) sono **Tier 2 / governance con DPO** — non codice, non bloccano l'MVP tecnico.

---

## 6. Effort e prossimo passo

- **Item #1 (Tier 1) realistico: ~12–20h agente + il brainstorm di design.** Non 4–7h: il logging delle consultazioni (T1.6) è trasversale e alza il pavimento. Il resto del modello (Tier 2) è **fuori** dal gate.
- Non cambia la conclusione strategica: **settimane, non mesi**; il collo di bottiglia resta il **DPO**.

**Prossimo passo (a settembre):** `/brainstorming` sull'#1 partendo da questo Tier 1 → chiudere decisioni A/B/C → `/writing-plans` → agenti sui task deterministici. Le voci T1.1, T1.2, T1.3 hanno spec deterministica: buone da parallelizzare mentre si progetta T1.6.
