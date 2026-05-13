# SegretarIA — Architettura tecnica e gestione dei dati per ruolo e tenant

## 1. Obiettivo del documento

Questo documento descrive come realizzare il sistema SegretarIA come servizio AI multitenant per studi medici/dentistici, con particolare attenzione al problema più importante: **garantire che ogni utente riceva solo i dati consentiti dal proprio tenant, ruolo e contesto operativo**.

Il sistema deve integrare:

- Agente telefonico Retell.io.
- Workflow n8n.
- Database gestionale PostgreSQL.
- Motore AI chat.
- Eventuale vector database/RAG.
- Frontend web SegretarIA.
- Sistema di autenticazione, autorizzazione e audit.

## 2. Principio architetturale fondamentale

Il modello AI non deve mai accedere direttamente al database.

La regola è:

> L'AI interpreta la richiesta, ma i dati vengono restituiti solo da API/tool autorizzati, controllati dal backend, filtrati per tenant, ruolo e policy.

Quindi l'AI non esegue query libere. Può soltanto chiamare strumenti applicativi del tipo:

- `search_patient`
- `get_today_agenda`
- `find_available_slots`
- `get_patient_summary`
- `get_treatment_plan_summary`
- `get_estimates_summary`
- `get_retell_calls_summary`
- `create_appointment_request`
- `modify_appointment_request`

Ogni tool applica controlli prima di interrogare il database.

## 3. Architettura logica

```text
Utente web
   |
   v
Frontend SegretarIA
   |
   v
Backend API / BFF
   |
   +--> Auth & Session Service
   +--> Policy Engine RBAC/ABAC
   +--> AI Orchestrator
   +--> Tool Layer autorizzato
   +--> PostgreSQL gestionale
   +--> Vector DB / RAG autorizzato
   +--> Audit Log
   +--> n8n Webhook/API
   +--> Retell.io API/Webhook
```

## 4. Componenti principali

### 4.1 Frontend SegretarIA

Il frontend gestisce:

- Login utente.
- Visualizzazione tenant attivo.
- Visualizzazione ruolo corrente.
- Chat AI.
- Card dati.
- Azioni rapide.
- Avvisi di permesso.
- Conferme prima delle azioni modificative.

Il frontend non deve contenere logica di sicurezza critica. Deve mostrare solo quello che il backend autorizza.

### 4.2 Backend API / BFF

Il backend è il punto di controllo principale. Deve:

- Validare il token utente.
- Identificare tenant e ruolo.
- Ricevere la richiesta chat.
- Passare all'AI solo il contesto minimo necessario.
- Esporre tool controllati.
- Applicare policy prima e dopo la query.
- Restituire risposta al frontend.
- Scrivere audit log.

### 4.3 AI Orchestrator

L'AI Orchestrator coordina:

1. Comprensione della richiesta.
2. Classificazione intent.
3. Individuazione dati necessari.
4. Chiamata ai tool autorizzati.
5. Composizione della risposta finale.
6. Eventuale richiesta di conferma per azioni modificative.

Esempio:

```text
Richiesta: “Mostrami il piano di cura di Mario Rossi”
Intent: get_treatment_plan_summary
Dati richiesti: paziente, piano di cura, trattamenti, preventivi
Controlli: tenant, ruolo, permessi clinici
Tool chiamato: get_treatment_plan_summary(patient_ref="Mario Rossi")
Risposta: riepilogo filtrato in base al ruolo
```

### 4.4 Tool Layer autorizzato

Ogni tool deve ricevere sempre il contesto autorizzativo:

```json
{
  "tenant_id": "...",
  "user_id": "...",
  "role": "secretary",
  "scopes": ["agenda:read", "patients:read", "estimates:read"],
  "provider_id": null
}
```

Il tool deve:

1. Validare i permessi.
2. Costruire query con filtro obbligatorio `tenant_id` o `clinic_id`.
3. Usare viste o funzioni autorizzate.
4. Mascherare campi non ammessi.
5. Restituire solo dati necessari.
6. Loggare accesso e risultato.

## 5. Modello multitenant

### 5.1 Tenant

Nel tuo modello DentalCare il tenant può coincidere con la tabella `clinics`.

Ogni tabella operativa deve contenere `clinic_id` o `tenant_id`:

- patients
- providers
- service_catalog
- treatment_plans
- treatment_plan_items
- estimates
- estimate_lines
- appointments
- retell_calls
- ai_conversations
- audit_logs

### 5.2 Regola base

Ogni query deve contenere sempre:

```sql
WHERE clinic_id = current_user_clinic_id
```

Questa regola non deve essere affidata al prompt AI. Deve essere applicata dal backend e, idealmente, anche dal database con Row Level Security.

## 6. Autenticazione

L'utente accede con login personale.

Il token di sessione deve contenere o permettere di recuperare:

- user_id
- tenant_id / clinic_id
- ruolo
- provider_id, se l'utente è un medico/operatore sanitario
- scopes
- eventuali sedi abilitate

Esempio payload logico:

```json
{
  "sub": "user_123",
  "tenant_id": "clinic_roma_001",
  "role": "doctor",
  "provider_id": "provider_456",
  "scopes": [
    "agenda:read",
    "patients:read",
    "clinical:read",
    "estimates:read"
  ]
}
```

## 7. Autorizzazione: RBAC + ABAC

### 7.1 RBAC

RBAC significa Role-Based Access Control. I permessi dipendono dal ruolo.

Esempi di ruoli:

- owner
- tenant_admin
- doctor
- hygienist
- assistant
- secretary
- accounting
- ai_phone_agent
- super_admin_platform

### 7.2 ABAC

ABAC significa Attribute-Based Access Control. I permessi dipendono anche da attributi specifici.

Esempi:

- Il medico vede solo i propri pazienti o tutti i pazienti dello studio?
- L'igienista può vedere solo appuntamenti assegnati a lui/lei?
- La segretaria può vedere note cliniche? Di norma no.
- L'amministrazione può vedere importi e preventivi, ma non note cliniche.
- Il ruolo AI telefonico può accedere solo a dati minimi per prenotazione.

La combinazione consigliata è:

```text
RBAC = cosa può fare il ruolo
ABAC = su quali dati può farlo
```

## 8. Matrice permessi consigliata

| Area dati | Medico | Igienista | Segretaria | Amministrazione | Admin tenant | AI telefonica |
|---|---:|---:|---:|---:|---:|---:|
| Agenda lettura | Sì | Sì | Sì | Limitato | Sì | Limitato |
| Agenda scrittura | Limitato | Limitato | Sì | No | Sì | Solo tramite workflow |
| Anagrafica paziente | Sì | Sì | Sì | Limitato | Sì | Minima |
| Recapiti paziente | Sì | Sì | Sì | Sì | Sì | Solo necessari |
| Note cliniche | Sì | Limitato | No | No | Configurabile | No |
| Piani di cura | Sì | Limitato | Sintesi non clinica | No | Configurabile | No |
| Trattamenti | Sì | Limitato | Stato operativo | No | Configurabile | No |
| Preventivi | Sì | No/Limitato | Sì | Sì | Sì | No |
| Fatturazione | No/Limitato | No | Limitato | Sì | Sì | No |
| Trascrizioni chiamate | Sì, se pertinenti | No/Limitato | Sì | No/Limitato | Sì | N/A |
| Configurazioni | No | No | No | No | Sì | No |
| Audit log | No | No | No | No/Limitato | Sì | No |

## 9. Strategie per garantire isolamento dati

### 9.1 Filtro applicativo obbligatorio

Tutte le API devono ricevere il tenant dal token, non dal frontend.

Errato:

```json
{
  "clinic_id": "scelto_dal_frontend"
}
```

Corretto:

```text
clinic_id ricavato dal token autenticato lato backend
```

### 9.2 PostgreSQL Row Level Security

Si consiglia di attivare RLS sulle tabelle sensibili. Il backend imposta una variabile di sessione per il tenant corrente.

Esempio concettuale:

```sql
ALTER TABLE dentalcare.patients ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_patients
ON dentalcare.patients
USING (clinic_id = current_setting('app.current_clinic_id')::uuid);
```

Il backend, appena apre la connessione o transazione, imposta:

```sql
SELECT set_config('app.current_clinic_id', '<clinic_uuid>', true);
```

Così anche in caso di errore applicativo, il database blocca righe di altri tenant.

### 9.3 Viste autorizzate

Creare viste diverse per aree funzionali:

- `v_secretary_patient_summary`
- `v_doctor_patient_clinical_summary`
- `v_accounting_estimates_summary`
- `v_ai_phone_minimal_patient_lookup`
- `v_provider_agenda`

Il backend usa la vista coerente con il ruolo, invece di interrogare sempre le tabelle complete.

### 9.4 Field masking

Alcuni campi devono essere mascherati o esclusi.

Esempi:

- Note cliniche nascoste alla segretaria.
- Dati economici nascosti all'igienista.
- Trascrizioni chiamate visibili solo se necessarie.
- Dati identificativi ridotti per l'agente telefonico.

## 10. Gestione AI e prompt security

### 10.1 System prompt

Il system prompt dell'agente chat deve contenere una regola chiara:

> Non fornire mai dati se il tool non li restituisce. Non inventare informazioni. Se un dato è bloccato dai permessi, comunica il blocco in modo chiaro e proponi alternative autorizzate.

### 10.2 Tool calling controllato

L'AI può chiedere dati solo tramite tool. Ogni tool ha schema rigido.

Esempio tool:

```json
{
  "name": "get_patient_summary",
  "description": "Restituisce un riepilogo paziente filtrato per tenant e ruolo",
  "input_schema": {
    "patient_query": "string"
  }
}
```

Il tool non accetta `tenant_id` dall'AI. Il tenant viene iniettato dal backend.

### 10.3 Risposte non autorizzate

Se l'utente chiede dati non permessi, la risposta deve essere:

> Non posso mostrare questa informazione con il tuo ruolo attuale. Posso però aiutarti con: agenda, recapiti paziente e stato appuntamenti.

## 11. Vector database e RAG

Se SegretarIA usa un vector DB per documenti, trascrizioni o knowledge base, ogni chunk deve avere metadati di sicurezza.

Metadati minimi:

```json
{
  "tenant_id": "clinic_roma_001",
  "document_type": "clinical_note",
  "patient_id": "patient_123",
  "allowed_roles": ["doctor", "tenant_admin"],
  "data_class": "clinical",
  "created_at": "2026-04-28T10:00:00Z"
}
```

La ricerca RAG deve funzionare così:

1. Pre-filter su tenant.
2. Pre-filter su ruolo o data_class.
3. Ricerca semantica.
4. Post-filter sui risultati.
5. Redazione o esclusione dei campi non autorizzati.
6. Risposta AI con fonti interne autorizzate.

Regola fondamentale:

> Non fare mai retrieval globale e poi filtrare solo nel prompt. Il filtro deve essere prima della ricerca o dentro l'indice.

## 12. Flusso completo di una richiesta chat

```text
1. Utente scrive: “Mostrami il piano di cura di Mario Rossi”
2. Frontend invia richiesta al backend
3. Backend valida token
4. Backend ricava tenant, user_id, ruolo, scopes
5. AI Orchestrator classifica intent
6. Policy Engine verifica se il ruolo può accedere ai piani di cura
7. Tool cerca paziente solo nel tenant corrente
8. Tool recupera piano di cura da vista autorizzata
9. Tool maschera eventuali campi non permessi
10. AI genera risposta usando solo i dati ricevuti
11. Backend salva audit log
12. Frontend mostra risposta e azioni consentite
```

## 13. Gestione azioni modificative

Le azioni che modificano dati devono richiedere conferma esplicita.

Esempi:

- Creare appuntamento.
- Spostare appuntamento.
- Cancellare appuntamento.
- Inviare messaggio al paziente.
- Accettare preventivo.
- Modificare preventivo.

Flusso consigliato:

```text
Richiesta utente
   -> AI prepara proposta
   -> backend verifica permessi
   -> frontend mostra riepilogo
   -> utente conferma
   -> backend esegue azione
   -> audit log
   -> risposta finale
```

## 14. Integrazione con Retell.io

Retell.io deve inviare al backend o a n8n:

- call_id
- tenant_id o numero telefonico associato al tenant
- trascrizione
- intent
- dati raccolti
- esito chiamata
- eventuale azione richiesta

Il backend deve associare la chiamata al tenant non sulla base di un campo non verificato, ma tramite:

- numero telefonico chiamato,
- configurazione Retell agent,
- webhook secret,
- mapping agent_id -> tenant_id.

## 15. Integrazione con n8n

n8n può continuare a gestire i flussi operativi, ma le chiamate da e verso n8n devono essere controllate.

Ogni webhook n8n deve ricevere:

- tenant sicuro derivato dal backend o dal mapping agente,
- request_id,
- user_id o actor_id,
- azione richiesta,
- payload minimo.

Ogni risposta n8n deve essere salvata come evento:

- completata,
- fallita,
- da verificare,
- richiede intervento umano.

## 16. Tabelle aggiuntive consigliate

Oltre allo schema DentalCare già creato, aggiungerei queste tabelle.

### 16.1 users

```sql
users (
  id uuid primary key,
  email citext unique not null,
  full_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
)
```

### 16.2 tenant_users

```sql
tenant_users (
  id uuid primary key,
  clinic_id uuid not null references clinics(id),
  user_id uuid not null references users(id),
  provider_id uuid null references providers(id),
  role text not null,
  active boolean not null default true,
  unique (clinic_id, user_id)
)
```

### 16.3 role_permissions

```sql
role_permissions (
  role text not null,
  permission text not null,
  primary key (role, permission)
)
```

### 16.4 ai_conversations

```sql
ai_conversations (
  id uuid primary key,
  clinic_id uuid not null references clinics(id),
  user_id uuid not null,
  title text,
  created_at timestamptz not null default now()
)
```

### 16.5 ai_messages

```sql
ai_messages (
  id uuid primary key,
  conversation_id uuid not null references ai_conversations(id),
  clinic_id uuid not null references clinics(id),
  sender text not null,
  content text not null,
  intent text,
  created_at timestamptz not null default now()
)
```

### 16.6 ai_tool_calls

```sql
ai_tool_calls (
  id uuid primary key,
  clinic_id uuid not null references clinics(id),
  conversation_id uuid references ai_conversations(id),
  user_id uuid not null,
  tool_name text not null,
  input_redacted jsonb,
  output_redacted jsonb,
  status text not null,
  created_at timestamptz not null default now()
)
```

### 16.7 audit_logs

```sql
audit_logs (
  id uuid primary key,
  clinic_id uuid not null references clinics(id),
  actor_type text not null,
  actor_id uuid,
  action text not null,
  resource_type text,
  resource_id uuid,
  outcome text not null,
  metadata jsonb,
  created_at timestamptz not null default now()
)
```

### 16.8 retell_calls

```sql
retell_calls (
  id uuid primary key,
  clinic_id uuid not null references clinics(id),
  retell_call_id text not null,
  retell_agent_id text not null,
  patient_id uuid null references patients(id),
  phone_number text,
  intent text,
  transcript text,
  summary text,
  outcome text,
  requires_human_review boolean not null default false,
  created_at timestamptz not null default now(),
  unique (clinic_id, retell_call_id)
)
```

### 16.9 tasks

```sql
tasks (
  id uuid primary key,
  clinic_id uuid not null references clinics(id),
  patient_id uuid null references patients(id),
  assigned_to_user_id uuid,
  title text not null,
  description text,
  status text not null default 'open',
  priority text not null default 'normal',
  due_at timestamptz,
  source text,
  created_at timestamptz not null default now()
)
```

## 17. Esempi di tool applicativi

### 17.1 get_today_agenda

Input AI:

```json
{
  "provider_name": "Dottor Verdi",
  "date": "2026-04-28"
}
```

Controlli backend:

- `agenda:read`
- tenant corrente
- eventuale filtro provider

Output:

```json
{
  "appointments": [
    {
      "time": "09:00",
      "patient_name": "Mario Rossi",
      "service": "Igiene orale",
      "status": "confirmed"
    }
  ]
}
```

### 17.2 get_patient_summary

Controlli:

- `patients:read`
- filtro tenant
- mascheramento campi in base al ruolo

Output per segretaria:

```json
{
  "patient_name": "Mario Rossi",
  "phone": "+39...",
  "next_appointment": "2026-04-29 10:00",
  "open_estimates_count": 1
}
```

Output per medico:

```json
{
  "patient_name": "Mario Rossi",
  "next_appointment": "2026-04-29 10:00",
  "active_treatment_plan": "Piano implantologia",
  "pending_treatments": 3,
  "clinical_notes_summary": "..."
}
```

## 18. Audit e tracciabilità

Ogni richiesta AI deve essere tracciata.

Registrare:

- chi ha fatto la richiesta,
- tenant,
- ruolo,
- intent,
- tool chiamati,
- risorse accedute,
- esito,
- eventuale blocco per permessi,
- azioni modificative eseguite.

Questo serve per:

- sicurezza,
- compliance,
- controllo accessi,
- debugging,
- tutela dello studio.

## 19. Gestione errori

### 19.1 Dato non trovato

> Non ho trovato un paziente corrispondente nel tuo studio. Puoi indicarmi telefono o data di nascita?

### 19.2 Permesso insufficiente

> Non posso mostrarti questa informazione con il tuo ruolo attuale.

### 19.3 Ambiguità

> Ho trovato più pazienti con questo nome. Ti mostro solo i dati minimi necessari per scegliere quello corretto.

### 19.4 Integrazione non disponibile

> Il collegamento con n8n non è disponibile. Posso preparare la richiesta, ma non posso completare l'azione sull'agenda in questo momento.

## 20. Roadmap tecnica consigliata

### Fase 1 — MVP sicuro

- Login.
- Tenant e ruolo.
- Chat AI.
- Tool read-only.
- Query agenda/pazienti/preventivi/piani di cura.
- Audit log.
- Blocco richieste non autorizzate.

### Fase 2 — Integrazione operativa

- Collegamento Retell calls.
- Collegamento n8n.
- Lettura chiamate e attività.
- Creazione task.
- Suggerimenti azione.

### Fase 3 — Azioni modificative controllate

- Prenotazione appuntamento.
- Modifica appuntamento.
- Invio promemoria.
- Conferma appuntamento.
- Conferma esplicita utente.

### Fase 4 — RAG documentale

- Knowledge base studio.
- Procedure interne.
- Trascrizioni autorizzate.
- Documenti paziente, se previsti.
- Vector DB con metadata security.

### Fase 5 — Analytics

- Dashboard chiamate.
- Saturazione agenda.
- Appuntamenti persi.
- Tasso richieste completate AI.
- Carico segreteria.

## 21. Conclusione

Il problema della restituzione dei dati per ogni figura non deve essere risolto chiedendo all'AI di “comportarsi bene”. Deve essere risolto progettando il sistema in modo che l'AI possa vedere solo ciò che il backend e il database hanno già autorizzato.

La soluzione corretta è una combinazione di:

1. Tenant obbligatorio nel token.
2. RBAC per ruolo.
3. ABAC per contesto.
4. Tool applicativi controllati.
5. Query sempre filtrate per tenant.
6. Viste autorizzate.
7. PostgreSQL Row Level Security.
8. Vector DB con metadata security.
9. Field masking.
10. Audit log completo.

Con questa architettura SegretarIA può diventare una piattaforma SaaS sicura, vendibile a più studi, integrata con Retell.io e n8n, e capace di fornire risposte diverse e corrette a medico, segretaria, amministrazione e agente telefonico AI.
