# Spec: Servizio AI YOLO — Inferenza ortopanoramiche + integrazione DentalCare (#6)

**Data:** 2026-06-26
**Proposta originale:** directives/proposte-modifiche.md §6 (questa spec SOSTITUISCE il piano §6 precedente)
**Direttiva tecnica base:** directives/dentalcare_ai_service_spec.md
**Stato:** In design

---

## 1. Obiettivo

Servizio AI per rilevazione automatica di denti (FDI) e patologie su ortopanoramiche, con revisione clinica e predisposizione retraining. Composto da:

1. **`dentalcare-ai-service`** — microservizio Python/FastAPI standalone (sottocartella `dentalcare-ai-service/`), inferenza ONNX a due modelli in cascata, storage MinIO, protetto JWT.
2. **Integrazione DentalCare** — tabelle DB tenant, proxy/orchestrazione Spring, overlay bounding box Angular nel tab Documenti del paziente.

Supporto decisionale: ogni risultato è marcato `AI-generated, requires clinician review`. Nessuna diagnosi auto-confermata.

---

## 2. Decisioni chiave

| Decisione | Scelta | Motivo |
|-----------|--------|--------|
| Architettura servizio AI | Microservizio Python separato | Stack ML (ONNX/OpenCV) fuori dal backend Java; scalabile in container dedicato |
| Modelli | Due ONNX in cascata: `dentex_fdi_v1` (32 denti FDI) + `dentex_disease_v1` (4 patologie) | Come da direttiva; FDI localizza denti, disease localizza lesioni, matching unisce |
| Esecuzione job | **Asincrona** in-process (FastAPI BackgroundTasks) ora; queue (Redis/RQ) quando il volume lo richiede | Non-bloccante; evita infra pesante finché single-machine basta |
| Notifica ai-service → backend | **Webhook HMAC** + idempotency key + retry | Push, niente polling Spring→ai-service; ai-service resta one-directional |
| Notifica backend → UI | **SSE** (Server-Sent Events) su aggiornamento DB | Push reattivo al browser, niente polling browser; SSE basta (server→client) |
| Affidabilità | **Reconciliation cron** Spring (poll fallback per webhook persi / browser chiuso) | Belt-and-suspenders SaaS |
| Storage | MinIO **bucket-per-tenant** `dc-{schema}` | A 500+ tenant: billing storage, GDPR drop-bucket, isolamento, blast radius contenuto |
| Ciclo vita bucket | Applicativo: create a provisioning tenant, purge a delete tenant | Bucket segue ciclo vita schema tenant |
| Persistenza risultati | Tabelle DB DentalCare (`patient_document_analyses` + `patient_document_labels`) | UI lista/storico/stato revisione, audit, isolamento tenant; JSON dettaglio su MinIO |
| Connettività MinIO | `host.docker.internal:9000` (come backend #4) | MinIO standalone host, non esposto; coerente con setup esistente |
| Overlay UI | SVG bounding box su immagine | Box scalabili/cliccabili; base per editing futuro (move/resize) più semplice di Canvas |
| Sync odontogramma | Solo **dopo revisione dentista**, merge non distruttivo, solo carie | AI = supporto decisionale; non sporcare cartella clinica con falsi positivi; mapping pulito solo per Caries/Deep_Caries |

---

## 3. Architettura e flusso

### Topologia (stessa macchina, container distinti, rete `dentalcarepro`)

```
Browser (Angular SPA)
  │ "Analizza con AI" su ortopanoramica (patient_document rx_panoramica)
  ▼
Spring backend (container)
  │  crea riga patient_document_analyses (PROCESSING)
  │  POST http://dentalcare-ai-service:8000/api/v1/inference/jobs
  │  (inoltra JWT utente; image_bucket=dc-{schema}, image_object_key=file_path doc)
  │  ← job_id (status=queued)  [SUBITO]
  │  apre/registra SSE per il client
  ▼
dentalcare-ai-service (container)
  │  BackgroundTask: download img da MinIO → ONNX FDI → ONNX disease
  │                  → matching → result.json + annotated.png + ai/jobs/{job_id}.json su MinIO
  │  POST webhook HMAC → backend /api/internal/ai/callback
  ▼
Spring backend callback
  │  verifica HMAC → scrive patient_document_labels, status=COMPLETED  ← AGGIORNAMENTO DB
  │  emette evento SSE "analysis-completed"
  ▼
Browser → disegna bounding box overlay (SVG)

MinIO: standalone host, raggiunto da backend e ai-service via host.docker.internal:9000
```

### Tre leg di notifica (responsabilità separate)

1. **ai-service → backend**: webhook `POST /api/internal/ai/callback`, firmato HMAC-SHA256, header `X-AI-Signature`, body include `job_id` (idempotency). Retry con backoff (3 tentativi). ai-service conosce solo MinIO + URL callback backend.
2. **backend → UI**: SSE endpoint `GET /api/patients/{patientId}/documents/{docId}/analyses/stream`. `SseEmitter` registrato per (clinicId, analysisId). Callback HMAC, dopo scrittura DB, emette evento. Browser `EventSource` → nessun polling.
3. **reconciliation cron**: `@Scheduled` (es. ogni 2 min) → analisi PROCESSING più vecchie di soglia → poll ai-service `GET /jobs/{id}`; se completed scrive DB + emette SSE. Copre webhook persi e SSE caduti.

---

## 4. FASE A — `dentalcare-ai-service` (Python/FastAPI)

### 4.1 Struttura repository

```
dentalcare-ai-service/
  app/
    main.py              # FastAPI app, include router, startup model load
    config.py            # Pydantic Settings da .env
    security.py          # validazione JWT shared secret DentalCare
    schemas.py           # Pydantic request/response
    minio_client.py      # download/upload/json/exists
    callback.py          # webhook HMAC verso backend + retry
    inference/
      onnx_yolo.py       # OnnxYoloDetector
      preprocessing.py   # letterbox YOLO
      postprocessing.py  # parse output + NMS + rescale box
      pipeline.py        # cascata FDI→disease + matching
      visualization.py   # disegno bbox su immagine annotata
    routers/
      health.py          # GET /health (no JWT)
      models.py          # GET /api/v1/models/status
      inference.py       # POST /api/v1/inference/jobs, GET /api/v1/inference/jobs/{id}
      annotations.py     # POST /api/v1/annotations
      retraining.py      # POST /api/v1/retraining/export-dataset (stub 501)
    services/
      job_service.py     # orchestrazione job + stato index MinIO
      annotation_service.py
    utils/
      logging.py         # JSON line
      ids.py             # uuid job/detection
  models/                # dentex_fdi_v1.onnx, dentex_disease_v1.onnx (gitignored)
  data/.gitkeep
  tests/
    test_health.py
    test_postprocessing.py
    test_matching.py     # IoU + fallback centro (core testabile)
  Dockerfile
  requirements.txt
  .env.example
  README.md
```

### 4.2 Sicurezza JWT (allineata a DentalCare)

DentalCare firma con `Keys.hmacShaKeyFor(secret)` (jjwt), claims: `sub`=providerId, `clinicId`, `schemaName`, `role`, `tenantName`, `iat`, `exp`. **Nessun `iss`/`aud`.**

`security.py`:
- legge `Authorization: Bearer <token>`
- valida firma con `JWT_SECRET` = **stesso valore di `app.jwt.secret`** del backend
- `algorithms=["HS256","HS384","HS512"]` (jjwt sceglie l'algoritmo dalla lunghezza del secret; accettare tutti gli HMAC evita mismatch)
- **issuer/audience: validati solo se `JWT_ISSUER`/`JWT_AUDIENCE` configurati** (di default NON configurati, perché i token DentalCare non li hanno)
- estrae claims (schemaName, clinicId, sub, role); 401 se assente/non valido/scaduto

### 4.3 Pipeline inferenza

**OnnxYoloDetector** (`onnx_yolo.py`):
```python
class OnnxYoloDetector:
    def __init__(self, model_path, class_names: dict[int,str], input_size, conf_threshold, iou_threshold): ...
    def predict(self, image_bgr: np.ndarray) -> list[dict]:
        # ritorna [{"class_id","class_name","confidence","bbox_xyxy":[x1,y1,x2,y2]}]
```

**Preprocessing** (`preprocessing.py`): letterbox (aspect ratio + padding), normalizzazione 0-1, BGR→RGB, NCHW, float32.

**Postprocessing** (`postprocessing.py`): parse output YOLO ONNX, confidence filter, NMS, rescale box → coordinate immagine originale. **Logga la shape output al primo avvio** (export Ultralytics può variare).

**Matching** (`pipeline.py`) — testabile in isolamento:
1. per ogni box patologia, calcola IoU con tutte le box FDI
2. se `IoU >= MATCH_IOU_THRESHOLD` → assegna dente con IoU max, `matching_method="iou"`
3. altrimenti, se `MATCH_CENTER_FALLBACK` e centro box patologia dentro box FDI → assegna, `matching_method="center"`
4. nessun match → `tooth=null`, `needs_review=true`, `matching_method="none"`

Soglie default: `MATCH_IOU_THRESHOLD=0.10`, `DISEASE_CONF_THRESHOLD=0.25`, `FDI_CONF_THRESHOLD=0.25`, `MODEL_IOU_THRESHOLD=0.45`, `MATCH_CENTER_FALLBACK=true`, `*_INPUT_SIZE=1024`.

### 4.4 Job asincrono

`POST /api/v1/inference/jobs` (vedi §6.3 direttiva):
- valida payload, genera `job_id`, scrive index `ai/jobs/{job_id}.json` (status=`queued`) su MinIO (bucket dal payload), schedula BackgroundTask, **ritorna subito** `{job_id, status:"queued"}`
- BackgroundTask: status=`processing` → download img → inferenza → matching → salva `result.json` + `annotated.png` (se `save_annotated_image`) + aggiorna index (status=`completed`/`failed`) → **chiama webhook callback**
- file temporanei in `/tmp/dentalcare-ai/{job_id}/`, puliti a fine job (salvo `SAVE_DEBUG_FILES`)

`GET /api/v1/inference/jobs/{job_id}` → legge index da MinIO (richiede `result_bucket` query param, dato che ai-service è stateless). Usato dalla reconciliation cron.

### 4.5 Webhook callback (`callback.py`)

A job completato/fallito:
```
POST {AI_CALLBACK_URL}   (es. http://dentalcarepro-backend:8080/api/internal/ai/callback)
Headers: X-AI-Signature: hex(HMAC_SHA256(AI_CALLBACK_SECRET, raw_body))
Body: { job_id, status, schema_name, patient_id, document_id, analysis_id,
        result_bucket, result_object_key, annotated_object_key, detections:[...], error? }
```
Retry: 3 tentativi backoff esponenziale. Fallimento definitivo → loggato; reconciliation cron recupererà.

> `schema_name`, `patient_id`, `document_id`, `analysis_id` vengono passati da Spring nel payload `metadata` del job e rimbalzati nel callback, così il backend ricollega il risultato senza stato lato ai-service.

### 4.6 Output MinIO

Per analisi, sotto `patients/{patientId}/{docId}/ai/{analysis_id}/`:
- `result.json` (formato §16 direttiva: detections, raw, models, review status)
- `annotated.png` (immagine con bbox)
Index job: `ai/jobs/{job_id}.json`.

### 4.7 Docker

`Dockerfile` python:3.11-slim + libgl1/libglib2.0-0, `requirements.txt` pinnato (onnxruntime CPU, opencv-headless, fastapi, minio, PyJWT…). Servizio aggiunto a `docker-compose.yml` DentalCare:
```yaml
dentalcare-ai-service:
  build: ./dentalcare-ai-service
  container_name: dentalcare-ai-service
  restart: unless-stopped
  env_file: ./dentalcare-ai-service/.env   # oppure config esterna come backend
  volumes:
    - ./dentalcare-ai-service/models:/app/models:ro
    - ./dentalcare-ai-service/tmp:/tmp/dentalcare-ai
  extra_hosts:
    - "host.docker.internal:host-gateway"
  networks: [dentalcarepro]
```
Backend raggiunge ai-service via `http://dentalcare-ai-service:8000` (nome container, rete condivisa). GPU: `Dockerfile.gpu` + `docker-compose.gpu.yml` futuri (onnxruntime-gpu) — fuori scope MVP.

---

## 5. FASE B0 — Storage bucket-per-tenant

### Convenzione
- Bucket = `dc-{schema sanitizzato}` (es. `t_9d754153` → `dc-t-9d754153`). Lowercase, no underscore, 3-63 char.
- Derivato **server-side da JWT `schemaName`** via `TenantContext`, mai dal client.
- Key dentro bucket: `patients/{patientId}/{docId}/{file}` e `patients/.../ai/{analysisId}/...` (niente prefisso `{schema}/`: il bucket È il tenant).

### Interventi
| # | Intervento | Aggancio |
|---|---|---|
| B0.1 | `MinioStorageService`: `bucketFor(schema)→dc-{schema}`, `ensureBucketExists`, `purgeBucket` | service |
| B0.2 | `PatientDocumentService` (#4): usa bucket tenant, key senza prefisso schema | service |
| B0.3 | **Create bucket** dopo creazione schema | `TenantProvisioningService.provision()` |
| B0.4 | **Delete bucket** (purge + remove), guard demo `t_9d754153` | `TenantAdminService.deleteTenant()` |
| B0.5 | Config `app.minio.bucket-prefix=dc-` (in `config/`, gitignored) | config |
| B0.6 | Migrazione dati #4 esistenti (quasi-zero ora): `dentalcare-docs/{schema}/...` → `dc-{schema}/...` + update `file_path` | script una tantum |

### Safety transazionale (MinIO esterno alla tx DB)
- **Create**: bucket creato in `TransactionSynchronization.afterCommit` (rollback tx → niente bucket orfano). Fallimento create → log, non blocca onboarding (lazy `ensureBucketExists` al primo upload come rete).
- **Delete**: `DROP SCHEMA` committa → `purgeBucket` in `afterCommit`. Fallimento purge → bucket orfano (leak storage, non data-loss) → **reconciliation sweep** rimuove bucket `dc-*` senza schema corrispondente. GDPR: log fino a purge confermata.

---

## 6. FASE B-DB — Schema DB DentalCare

Per ogni schema tenant + template global + `install.sql` mirror.

### `patient_document_analyses`
| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | analysis_id |
| `patient_id` | uuid FK patients | |
| `document_id` | uuid FK patient_documents | l'ortopanoramica analizzata |
| `clinic_id` | uuid | isolamento tenant |
| `job_id` | text | id job ai-service |
| `status` | enum `ai_analysis_status` (`PENDING`,`PROCESSING`,`COMPLETED`,`FAILED`) | |
| `model_fdi` | text | es. `dentex_fdi_v1` |
| `model_disease` | text | |
| `result_bucket` | text | `dc-{schema}` |
| `result_object_key` | text | `patients/.../ai/{id}/result.json` |
| `annotated_object_key` | text null | |
| `detections_count` | int | |
| `needs_review` | boolean | almeno una detection needs_review |
| `review_status` | enum `ai_review_status` (`pending`,`reviewed`,`approved_for_training`,`excluded`) | |
| `reviewed_by_provider_id` | uuid null | |
| `reviewed_at` | timestamptz null | |
| `error_message` | text null | se FAILED |
| `requested_by_provider_id` | uuid | audit |
| `created_at`/`updated_at` | timestamptz | trigger updated_at |

Indici: `(document_id)`, `(patient_id)`, `(job_id)`, `(status)`. FK composite coerenti con pattern progetto.

### `patient_document_labels`
| Colonna | Tipo | Note |
|---------|------|------|
| `id` | uuid PK | |
| `analysis_id` | uuid FK patient_document_analyses (ON DELETE CASCADE) | |
| `tooth_fdi` | text null | es. `16`; null se non matchato |
| `disease` | text | `Caries`/`Deep_Caries`/`Periapical_Lesion`/`Impacted` |
| `disease_confidence` | numeric(5,4) null | |
| `fdi_confidence` | numeric(5,4) null | |
| `bbox_x1`/`y1`/`x2`/`y2` | int | xyxy coordinate immagine originale |
| `matching_method` | text | `iou`/`center`/`none` |
| `matching_score` | numeric(5,4) null | |
| `needs_review` | boolean | |
| `source` | enum `ai_label_source` (`ai`,`human_corrected`) | base per retraining |
| `action` | text null | `confirmed`/`added`/`modified`/`deleted` (revisione umana) |
| `created_at` | timestamptz | |

Indice: `(analysis_id)`.

### Patch `tooth_conditions` (per sync odontogramma)
Aggiungere a tabella esistente (schema tenant + template global + `install.sql` + `EstimateSchemaInitializer` con `ADD COLUMN IF NOT EXISTS` per tenant già esistenti):
| Colonna | Tipo | Note |
|---------|------|------|
| `source` | varchar(10) NOT NULL DEFAULT `'manual'` | `manual` / `ai` — distingue origine |
| `analysis_id` | uuid null FK patient_document_analyses ON DELETE SET NULL | traccia analisi che ha generato la voce AI |

---

## 6.5 FASE B-SYNC — Sincronizzazione odontogramma

**Trigger**: alla revisione dentista (`PUT .../analyses/{id}/review`) quando `review_status` → `reviewed`/`approved_for_training`. NON a COMPLETED (raw AI mai scritto in cartella clinica).

**Mapping disease → condition** (`tooth_condition` vocab):
- `Caries` → `caries`
- `Deep_Caries` → `caries` (nota: "AI: Deep_Caries")
- `Periapical_Lesion`, `Impacted` → **non sincronizzate** in odontogramma; restano in `patient_document_labels` + visibili nella UI analisi.

**Scrittura** (`OdontogramSyncService.syncFromAnalysis(analysisId)`):
- per ogni label confermata (`source` rimane traccia AI, action `confirmed`/`added`) con disease mappabile e `tooth_fdi` non null:
  - upsert in `tooth_conditions` con `condition='caries'`, `source='ai'`, `analysis_id`, `tooth_fdi`, `surface=<default sentinella>` (panoramico non dà superficie; default configurabile, es. `V`; il dentista può editarla in odontogramma), `notes` = origine AI + disease + confidence
- **idempotente**: prima rimuove le voci `source='ai'` di **questo** `analysis_id`, poi reinserisce (re-review non duplica).
- **non distruttivo**: non tocca mai voci `source='manual'`.

**Merge inverso** — `OdontogramService.save()` (salvataggio manuale odontogramma) va modificato: il `DELETE` iniziale deve essere scopato a `source='manual'` (o `source <> 'ai'`), così il salvataggio manuale **non cancella** le voci AI sincronizzate. Simmetricamente, le voci AI sono gestite solo da `OdontogramSyncService`.

**UI**: voci `source='ai'` evidenziate nell'odontogramma (badge/colore "AI"); il dentista può confermarle (diventano `manual`) o rimuoverle.

---

## 7. FASE B-BE — Backend Spring

### Endpoint
```
POST   /api/patients/{patientId}/documents/{docId}/analyses          → avvia analisi (201, analysis PROCESSING)
GET    /api/patients/{patientId}/documents/{docId}/analyses          → lista analisi del documento
GET    /api/patients/{patientId}/documents/{docId}/analyses/{id}     → dettaglio + labels
GET    /api/patients/{patientId}/documents/{docId}/analyses/{id}/stream → SSE (eventi stato)
PUT    /api/patients/{patientId}/documents/{docId}/analyses/{id}/review → salva labels corrette dentista
POST   /api/internal/ai/callback                                      → webhook ai-service (HMAC, no JWT utente)
```
Solo `document_type=rx_panoramica` analizzabile (validazione service). `/api/internal/**` escluso dal filtro JWT, protetto da HMAC.

### Componenti
- DTO: `AnalysisDto`, `LabelDto`, `StartAnalysisResponse`, `ReviewAnalysisRequest`, `AiCallbackRequest`
- `AiInferenceClient` (RestClient/WebClient): `createJob(...)` verso ai-service, inoltra JWT utente, passa `image_bucket=dc-{schema}`, `image_object_key`, `output_prefix`, `metadata{schema_name,patient_id,document_id,analysis_id}`
- `PatientDocumentAnalysisService`: crea analisi (PROCESSING + job_id), persiste, isolamento tenant via `TenantContext`; `applyCallback(...)` scrive labels + COMPLETED idempotente (per job_id/analysis_id); `reconcile()` poll fallback
- `AiCallbackController` + `HmacVerifier` (verifica `X-AI-Signature`, secret `app.ai.hmac-secret`)
- `SseEmitterRegistry`: map (analysisId → SseEmitter), emit su completamento, timeout/cleanup
- `OdontogramSyncService.syncFromAnalysis(analysisId)`: chiamato da `review` quando approvato; upsert voci `caries` `source='ai'` idempotente (§6.5)
- `OdontogramService.save()` **[MOD]**: `DELETE` scopato a `source='manual'` (non cancella voci AI)
- `@Scheduled reconcileStaleAnalyses()` (ogni 2 min)
- Config (in `config/`, gitignored): `app.ai.base-url=http://dentalcare-ai-service:8000`, `app.ai.hmac-secret=<segreto>`, `app.ai.callback-url=http://dentalcarepro-backend:8080/api/internal/ai/callback`

### Idempotenza
`applyCallback` e `reconcile` aggiornano l'analisi solo se ancora `PROCESSING` (guardia stato). Doppio callback / callback+reconcile → no doppia scrittura labels.

---

## 8. FASE B-FE — Frontend Angular

- `patient-analysis.model.ts`: `AnalysisDto`, `LabelDto`, enum status/review, `DISEASE_LABELS`
- `patient-analysis.service.ts`: `start(patientId,docId)`, `list(...)`, `get(...)`, `streamStatus(...)` (EventSource SSE), `saveReview(...)`
- `documento-analisi.component`: overlay **SVG** bbox sopra `<img>` ortopanoramica (box scalati a dimensioni naturali immagine via viewBox), colore per patologia, tooltip dente+confidence, badge `needs_review`
- Integrazione nel tab Documenti (#4): per `rx_panoramica`, bottone **"Analizza con AI"**; stati `idle`/`processing` (spinner, SSE in attesa)/`completed` (overlay)/`failed` (messaggio + retry)
- Lista/storico analisi del documento, stato revisione
- In revisione, conferma/approvazione → trigger sync odontogramma (backend); odontogramma mostra voci `source='ai'` con badge "AI" (confermabili → `manual`, o rimovibili)
- Disclaimer UI: `AI-generated, requires clinician review`

(Editing annotazioni — move/resize/add/delete box + salvataggio `human_corrected` — predisposto da SVG e endpoint review; UI editing completa **out of scope MVP**, vedi §11.)

---

## 9. Error handling

**ai-service**: 401 JWT invalido; 400 payload invalido; 404 oggetto MinIO mancante; 422 immagine non decodificabile; 500 errore modello/runtime (loggato JSON line con job_id). Job fallito → index status=`failed` + callback con `error`.

**backend**: ai-service unreachable a `createJob` → analisi `FAILED` + 502 al client con messaggio leggibile; callback HMAC invalido → 401; documento non `rx_panoramica` → 400; reconciliation logga e ritenta.

**frontend**: stati `failed` con messaggio non tecnico + retry; SSE error → fallback a refresh manuale/polling leggero su GET analysis.

---

## 10. Testing

**ai-service**: unit `test_matching.py` (IoU, fallback centro, no-match), `test_postprocessing.py` (NMS, rescale), `test_health.py`. Mock MinIO.
**backend**: unit `PatientDocumentAnalysisServiceTest` (crea/applyCallback idempotente/reconcile), `HmacVerifierTest`, `MinioStorageServiceTest` (bucketFor/purge). MockMvc per callback HMAC (firma valida/invalida) e avvio analisi.
**frontend**: test service (SSE subscribe, mapping), test component overlay (rendering box da labels).

---

## 11. Out of scope (MVP)

- Retraining automatico (solo struttura dati MinIO `ai/training/{pending,approved,excluded,datasets}/` + endpoint export stub 501)
- UI editing annotazioni completa (move/resize/add/delete) — predisposta, non implementata
- Queue asincrona Redis/RQ + worker pool (in-process ora)
- SSE multi-istanza / pub-sub Redis (single-instance ora; seam noto §2)
- GPU (`Dockerfile.gpu`, `docker-compose.gpu.yml`) — predisposto, non attivo
- Cifratura MinIO (#7, hook già presente in `MinioStorageService`)
- Viewer DICOM, benchmark endpoint
- Superficie dentale precisa da AI: il panoramico non dà granularità per superficie → sync usa surface sentinella default (dentista raffina in odontogramma)

---

## 12. Prerequisiti

- **P0 (manuale, utente)**: export ONNX dei due modelli da `.pt` DENTEX → `dentalcare-ai-service/models/dentex_fdi_v1.onnx` + `dentex_disease_v1.onnx`. Senza modelli il servizio parte ma `models/status` riporta `loaded:false` e i job falliscono.
- Secret JWT condiviso: `JWT_SECRET` ai-service = `app.jwt.secret` backend.
- HMAC secret callback condiviso: `AI_CALLBACK_SECRET` ai-service = `app.ai.hmac-secret` backend.

---

## 13. Ordine di build (WBS)

```
P0 (utente) ───────────────────────────────────┐
FASE A  dentalcare-ai-service (general-purpose) │ paralleli concettuali
B0      bucket-per-tenant     (backend-dev)     │
B-DB    schema analisi/labels + patch tooth_conditions (database-dev) │
                          ▼
B-BE    backend AI            (backend-dev)  ← dipende: B0 + B-DB + contratto A (endpoint+webhook+HMAC)
                          ▼
B-SYNC  odontogram sync       (backend-dev)  ← dipende: B-BE (review) + B-DB patch
                          ▼
B-FE    frontend overlay + badge AI odontogramma (frontend-dev) ← dipende: B-BE + B-SYNC
                          ▼
E2E + review finale whole-branch (opus)
B-DOC   aggiorna proposte-modifiche.md #6 (sostituito) + install.sql mirror
```

Contratti **webhook HMAC** e **SSE** fissati a inizio (§3) così Fase A e B-BE li condividono. B0 precede B-BE (fissa convenzione bucket usata ovunque).
