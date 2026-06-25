# Proposte di modifica

Registro delle modifiche proposte da Claude e il loro stato. Aggiornato a ogni proposta/conferma.

Stati: **Proposta** (in attesa di tua conferma) · **Confermata** (da fare) · **Fatta** (implementata + commit) · **Scartata**.

---

## Indice

| # | Titolo | Impatto | Stato |
|---|--------|---------|-------|
| 1 | Aggiornamento agenda in tempo reale (SSE) | Medio-basso (~½ giornata) | Proposta |
| 2 | Retell multi-studio: agente per sede/poltrona | Medio (~1 giornata) | Proposta |

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
