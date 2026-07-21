# Proposte di modifica — archivio

Sezioni **Fatte** (implementate + commit) spostate qui da [proposte-modifiche.md](proposte-modifiche.md) per tenere snello il tracker attivo. Nulla è perso: questo file conserva il dettaglio storico. Gli #ID restano stabili.

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

**Deployment: tutto sulla stessa macchina (`<server-app>`), stesso `docker-compose.yml`.**

```
<server-app> — Docker Engine
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
