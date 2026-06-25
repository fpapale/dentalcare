# Proposte di modifica

Registro delle modifiche proposte da Claude e il loro stato. Aggiornato a ogni proposta/conferma.

Stati: **Proposta** (in attesa di tua conferma) · **Confermata** (da fare) · **Fatta** (implementata + commit) · **Scartata**.

---

## Indice

| # | Titolo | Impatto | Stato |
|---|--------|---------|-------|
| 1 | Aggiornamento agenda in tempo reale (SSE) | Medio-basso (~½ giornata) | Proposta |
| 2 | Retell multi-studio: agente per sede/poltrona | Medio (~1 giornata) | Proposta |
| 3 | Validazione codice fiscale con bypass stranieri | Medio (~¾ giornata) | Proposta |
| 4 | Documenti paziente: tab CRUD con allegati base64 | Medio (~1 giornata) | Proposta |

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
- Limite 15MB per file è pratico per ortopanoramine JPEG; per CBCT in DICOM (>100MB) servirà object storage — fuori scope ora
