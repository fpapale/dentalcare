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
| 4 | Documenti paziente: tab CRUD con allegati (MinIO storage) | Medio (~1 giornata) | Fatta |
| 5 | Object storage MinIO per documenti grandi (CBCT/DICOM) | Medio (~1 giornata) | Proposta |
| 6 | AI YOLO: rilevamento carie su ortopanoramica + retraining | Alto (~3-5 giorni) | Fatta |
| 7 | GDPR: cifratura campo-per-campo con chiavi per tenant (HKDF + AES-256-GCM) | Alto (~2 giorni) | Proposta |

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

**Stato:** Fatta — microservizio `dentalcare-ai-service` (Python/FastAPI/ONNX) + integrazione DentalCare (bucket-per-tenant, tabelle analyses/labels, webhook HMAC, SSE, reconciler, sync odontogramma, overlay SVG). Spec: `docs/superpowers/specs/2026-06-26-ai-yolo-service-design.md`. Piani: `docs/superpowers/plans/2026-06-26-ai-service-python.md` + `2026-06-26-ai-integration-dentalcare.md`. Branch `feat/ai-yolo-service`.
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

---

## 7. GDPR: cifratura campo-per-campo con chiavi per tenant (HKDF + AES-256-GCM)

**Stato:** Proposta
**Data proposta:** 2026-06-25
**Impatto:** Alto (~2 giorni)

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
