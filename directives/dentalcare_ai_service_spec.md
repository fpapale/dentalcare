# DentalCare AI Service — Specifica tecnica per implementazione con Claude Code

## 1. Obiettivo

Realizzare un servizio Python containerizzato, richiamabile da DentalCare tramite API REST protette da JWT, per eseguire inferenza AI su ortopanoramiche dentali.

Il servizio deve:

1. ricevere da DentalCare una richiesta di analisi per una ortopanoramica già caricata su MinIO;
2. scaricare l'immagine da MinIO;
3. eseguire inferenza con due modelli ONNX:
   - `dentex_fdi_v1`: rilevazione / classificazione FDI del dente;
   - `dentex_disease_v1`: rilevazione patologie;
4. combinare i risultati dei due modelli tramite matching delle bounding box;
5. salvare su MinIO:
   - JSON risultato inferenza;
   - eventuale immagine annotata con bounding box;
   - metadati utili per audit e revisione clinica;
6. esporre API per recuperare risultati, revisionare annotazioni e salvare correzioni del dentista;
7. predisporre una struttura dati per futuro retraining supervisionato.

Il servizio deve essere installabile in Docker su una CT Proxmox, inizialmente anche senza GPU. In futuro dovrà poter usare GPU NVIDIA se disponibile.

---

## 2. Architettura generale

### Componenti

- **DentalCare Backend**
  - Sistema gestionale principale.
  - Autentica gli utenti.
  - Carica le immagini DICOM/PNG/JPEG su MinIO.
  - Chiama il servizio AI tramite REST JWT.

- **DentalCare AI Service**
  - Servizio Python FastAPI.
  - Espone API REST.
  - Verifica JWT.
  - Scarica immagini da MinIO.
  - Esegue inferenza con ONNX Runtime.
  - Salva risultati su MinIO.
  - Riceve annotazioni corrette dal dentista.

- **MinIO**
  - Object storage S3-compatible.
  - Contiene immagini sorgenti, risultati AI, immagini annotate, dataset per retraining.

- **ONNX Runtime**
  - Runtime di inferenza CPU/GPU.
  - Versione CPU per deployment iniziale.
  - Possibile passaggio futuro a `onnxruntime-gpu`.

- **Database opzionale**
  - Non obbligatorio nella prima versione.
  - I risultati possono essere salvati su MinIO in JSON.
  - In futuro si può aggiungere PostgreSQL per audit, job queue e tracciamento.

---

## 3. Flusso principale di inferenza

```text
DentalCare
   |
   | POST /api/v1/inference/jobs
   | JWT + patient_id + study_id + minio_object_key
   v
DentalCare AI Service
   |
   | scarica immagine da MinIO
   v
Preprocessing immagine
   |
   | normalizzazione / resize / letterbox
   v
ONNX Runtime
   |-----------------------------|
   | dentex_fdi_v1.onnx          |
   | dentex_disease_v1.onnx      |
   |-----------------------------|
   v
Post-processing
   |
   | matching FDI + patologie tramite IoU / centro box
   v
Risultato clinico strutturato
   |
   | salva JSON + preview annotata su MinIO
   v
DentalCare riceve job_id e/o risultato
```

---

## 4. Pipeline logica dei due modelli

### 4.1 Modello FDI

Nome previsto:

```text
models/dentex_fdi_v1.onnx
```

Classi previste:

```text
0  -> tooth_11
1  -> tooth_12
2  -> tooth_13
3  -> tooth_14
4  -> tooth_15
5  -> tooth_16
6  -> tooth_17
7  -> tooth_18
8  -> tooth_21
9  -> tooth_22
10 -> tooth_23
11 -> tooth_24
12 -> tooth_25
13 -> tooth_26
14 -> tooth_27
15 -> tooth_28
16 -> tooth_31
17 -> tooth_32
18 -> tooth_33
19 -> tooth_34
20 -> tooth_35
21 -> tooth_36
22 -> tooth_37
23 -> tooth_38
24 -> tooth_41
25 -> tooth_42
26 -> tooth_43
27 -> tooth_44
28 -> tooth_45
29 -> tooth_46
30 -> tooth_47
31 -> tooth_48
```

### 4.2 Modello patologie

Nome previsto:

```text
models/dentex_disease_v1.onnx
```

Classi previste:

```text
0 -> Impacted
1 -> Caries
2 -> Periapical_Lesion
3 -> Deep_Caries
```

### 4.3 Matching tra FDI e patologia

Per ogni box patologia:

1. cercare le box FDI candidate;
2. calcolare IoU tra box patologia e box FDI;
3. se `IoU >= MATCH_IOU_THRESHOLD`, assegnare la patologia al dente con IoU più alta;
4. se IoU è bassa, usare fallback basato sul centro della box patologia:
   - se il centro della patologia cade dentro una box FDI, assegnare quella;
5. se non c'è match, restituire `tooth: null` e `needs_review: true`.

Valori iniziali consigliati:

```env
MATCH_IOU_THRESHOLD=0.10
MATCH_CENTER_FALLBACK=true
DISEASE_CONF_THRESHOLD=0.25
FDI_CONF_THRESHOLD=0.25
```

Nota: sulle radiografie, le box delle patologie possono essere molto più piccole delle box FDI. Per questo l'IoU può essere basso. Il fallback sul centro è importante.

---

## 5. Struttura repository richiesta

Claude Code deve generare una struttura simile:

```text
dentalcare-ai-service/
  app/
    __init__.py
    main.py
    config.py
    security.py
    schemas.py
    minio_client.py
    inference/
      __init__.py
      onnx_yolo.py
      preprocessing.py
      postprocessing.py
      pipeline.py
      visualization.py
    routers/
      __init__.py
      health.py
      inference.py
      annotations.py
      models.py
    services/
      __init__.py
      job_service.py
      annotation_service.py
      retraining_service.py
    utils/
      __init__.py
      logging.py
      ids.py
  models/
    .gitkeep
  data/
    .gitkeep
  tests/
    test_health.py
    test_postprocessing.py
  Dockerfile
  docker-compose.yml
  docker-compose.gpu.yml
  requirements.txt
  .env.example
  README.md
```

---

## 6. API REST richieste

Base path:

```text
/api/v1
```

Tutte le API applicative devono richiedere JWT Bearer token, tranne `/health`.

### 6.1 Health check

```http
GET /health
```

Risposta:

```json
{
  "status": "ok",
  "service": "dentalcare-ai-service",
  "version": "0.1.0"
}
```

### 6.2 Model status

```http
GET /api/v1/models/status
Authorization: Bearer <JWT>
```

Risposta:

```json
{
  "runtime": "onnxruntime",
  "providers": ["CPUExecutionProvider"],
  "models": {
    "fdi": {
      "name": "dentex_fdi_v1",
      "path": "/app/models/dentex_fdi_v1.onnx",
      "loaded": true
    },
    "disease": {
      "name": "dentex_disease_v1",
      "path": "/app/models/dentex_disease_v1.onnx",
      "loaded": true
    }
  }
}
```

### 6.3 Creazione job inferenza

```http
POST /api/v1/inference/jobs
Authorization: Bearer <JWT>
Content-Type: application/json
```

Payload:

```json
{
  "patient_id": "PATIENT-123",
  "study_id": "STUDY-456",
  "image_bucket": "dentalcare-docs",
  "image_object_key": "patients/PATIENT-123/studies/STUDY-456/panoramic.png",
  "output_bucket": "dentalcare-docs",
  "output_prefix": "patients/PATIENT-123/studies/STUDY-456/ai/",
  "save_annotated_image": true,
  "metadata": {
    "source": "DentalCare",
    "operator_id": "USER-001"
  }
}
```

Risposta sincrona iniziale consigliata:

```json
{
  "job_id": "ai-job-uuid",
  "status": "completed",
  "result_object_key": "patients/PATIENT-123/studies/STUDY-456/ai/result.json",
  "annotated_image_object_key": "patients/PATIENT-123/studies/STUDY-456/ai/annotated.png",
  "summary": {
    "detections": 3,
    "needs_review": true
  },
  "detections": [
    {
      "tooth": "16",
      "disease": "Caries",
      "disease_confidence": 0.82,
      "fdi_confidence": 0.76,
      "matching_method": "iou",
      "matching_score": 0.34,
      "bbox_xyxy": [120, 330, 180, 390],
      "needs_review": false
    }
  ]
}
```

Nella prima versione si può fare inferenza sincrona. In futuro si potrà introdurre job queue asincrona con Redis/RQ/Celery.

### 6.4 Recupero risultato inferenza da MinIO

```http
GET /api/v1/inference/jobs/{job_id}
Authorization: Bearer <JWT>
```

Se non si usa database, questa API può richiedere anche `result_bucket` e `result_object_key` come query parameter, oppure DentalCare può leggere direttamente da MinIO.

Consiglio per prima versione: salvare anche un indice JSON in MinIO:

```text
ai/jobs/{job_id}.json
```

### 6.5 Salvataggio annotazioni corrette dal dentista

```http
POST /api/v1/annotations
Authorization: Bearer <JWT>
Content-Type: application/json
```

Payload:

```json
{
  "patient_id": "PATIENT-123",
  "study_id": "STUDY-456",
  "image_bucket": "dentalcare-docs",
  "image_object_key": "patients/PATIENT-123/studies/STUDY-456/panoramic.png",
  "annotation_bucket": "dentalcare-docs",
  "annotation_object_key": "patients/PATIENT-123/studies/STUDY-456/ai/reviewed_annotations.json",
  "reviewer": {
    "user_id": "DENTIST-001",
    "role": "dentist"
  },
  "annotations": [
    {
      "tooth": "16",
      "disease": "Caries",
      "bbox_xyxy": [120, 330, 180, 390],
      "confidence": null,
      "source": "human_corrected",
      "action": "confirmed"
    },
    {
      "tooth": "26",
      "disease": "Periapical_Lesion",
      "bbox_xyxy": [550, 340, 610, 410],
      "confidence": null,
      "source": "human_corrected",
      "action": "added"
    }
  ]
}
```

Risposta:

```json
{
  "status": "saved",
  "annotation_object_key": "patients/PATIENT-123/studies/STUDY-456/ai/reviewed_annotations.json",
  "training_sample_object_key": "ai/training/pending/STUDY-456.json"
}
```

### 6.6 Creazione dataset per retraining futuro

```http
POST /api/v1/retraining/export-dataset
Authorization: Bearer <JWT>
Content-Type: application/json
```

Payload:

```json
{
  "source_prefix": "ai/training/approved/",
  "output_bucket": "dentalcare-docs",
  "output_prefix": "ai/datasets/dataset_2026_06_26/",
  "format": "yolo"
}
```

Per ora questa API può essere implementata come stub, restituendo `501 Not Implemented` o salvando solo il job request. Deve però essere prevista nella struttura.

---

## 7. Sicurezza JWT

Il servizio deve verificare JWT in ogni endpoint `/api/v1/*`.

Configurazione `.env`:

```env
JWT_ALGORITHM=HS256
JWT_SECRET=change-me-in-production
JWT_ISSUER=dentalcare
JWT_AUDIENCE=dentalcare-ai-service
```

Implementare in `app/security.py`:

- lettura header `Authorization: Bearer <token>`;
- validazione firma;
- validazione issuer/audience se configurati;
- estrazione claim utente;
- sollevare HTTP 401 se token assente/non valido.

Claim minimi attesi:

```json
{
  "sub": "user-id",
  "role": "dentist",
  "iss": "dentalcare",
  "aud": "dentalcare-ai-service",
  "exp": 1790000000
}
```

---

## 8. MinIO

### Variabili ambiente

```env
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false
MINIO_DEFAULT_BUCKET=dentalcare-docs
```

### Funzioni richieste in `app/minio_client.py`

Implementare:

```python
def download_object(bucket: str, object_key: str, local_path: str) -> str:
    ...

def upload_file(bucket: str, object_key: str, local_path: str, content_type: str | None = None) -> None:
    ...

def upload_json(bucket: str, object_key: str, data: dict) -> None:
    ...

def object_exists(bucket: str, object_key: str) -> bool:
    ...
```

Il servizio non deve salvare permanentemente dati paziente nel filesystem del container. Usare directory temporanee per job, ad esempio:

```text
/tmp/dentalcare-ai/{job_id}/
```

Pulire i file temporanei al termine del job, salvo debug esplicitamente abilitato.

---

## 9. Inferenza ONNX Runtime

### Pacchetti

Per CPU:

```text
onnxruntime
opencv-python-headless
numpy
pillow
fastapi
uvicorn[standard]
python-multipart
minio
pydantic
pydantic-settings
PyJWT
```

Per GPU futura:

```text
onnxruntime-gpu
```

Non installare contemporaneamente `onnxruntime` e `onnxruntime-gpu` nella stessa immagine finale, salvo scelta consapevole.

### Classe richiesta

Creare `app/inference/onnx_yolo.py` con una classe:

```python
class OnnxYoloDetector:
    def __init__(self, model_path: str, class_names: dict[int, str], input_size: int, conf_threshold: float, iou_threshold: float):
        ...

    def predict(self, image_bgr: np.ndarray) -> list[dict]:
        ...
```

Ogni detection deve avere formato:

```python
{
    "class_id": 1,
    "class_name": "Caries",
    "confidence": 0.82,
    "bbox_xyxy": [x1, y1, x2, y2]
}
```

### Preprocessing

Implementare letterbox compatibile YOLO:

- mantenere aspect ratio;
- padding;
- normalizzazione 0-1;
- BGR -> RGB;
- shape NCHW;
- float32.

### Postprocessing

Implementare:

- parsing output YOLO ONNX;
- confidence filtering;
- NMS;
- conversione box da coordinate modello a coordinate immagine originale.

Nota: l'output esatto ONNX può dipendere dalla versione Ultralytics/export. Scrivere codice robusto e testarlo con i file `.onnx` generati. Prevedere log della shape dell'output al primo avvio.

---

## 10. Configurazione applicativa

File `app/config.py` con Pydantic Settings.

Variabili `.env.example`:

```env
APP_NAME=dentalcare-ai-service
APP_VERSION=0.1.0
APP_ENV=development
LOG_LEVEL=INFO

API_PREFIX=/api/v1

JWT_ALGORITHM=HS256
JWT_SECRET=change-me-in-production
JWT_ISSUER=dentalcare
JWT_AUDIENCE=dentalcare-ai-service

MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false
MINIO_DEFAULT_BUCKET=dentalcare-docs

FDI_MODEL_PATH=/app/models/dentex_fdi_v1.onnx
DISEASE_MODEL_PATH=/app/models/dentex_disease_v1.onnx

FDI_INPUT_SIZE=1024
DISEASE_INPUT_SIZE=1024
FDI_CONF_THRESHOLD=0.25
DISEASE_CONF_THRESHOLD=0.25
MODEL_IOU_THRESHOLD=0.45
MATCH_IOU_THRESHOLD=0.10
MATCH_CENTER_FALLBACK=true

SAVE_DEBUG_FILES=false
TMP_DIR=/tmp/dentalcare-ai
```

---

## 11. Dockerfile CPU

Creare `Dockerfile`:

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app /app/app
COPY models /app/models

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 12. requirements.txt CPU

```text
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.8.2
pydantic-settings==2.4.0
python-multipart==0.0.9
minio==7.2.8
PyJWT==2.9.0
onnxruntime==1.19.2
opencv-python-headless==4.10.0.84
numpy==1.26.4
pillow==10.4.0
python-dotenv==1.0.1
```

Le versioni possono essere aggiornate da Claude Code se necessario, mantenendo compatibilità Python 3.11.

---

## 13. docker-compose.yml CPU

Questo compose deve avviare il servizio AI. Se MinIO esiste già nel compose di DentalCare, non duplicarlo: collegarsi alla stessa rete Docker.

Versione con MinIO incluso per ambiente standalone:

```yaml
services:
  dentalcare-ai-service:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: dentalcare-ai-service
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8008:8000"
    volumes:
      - ./models:/app/models:ro
      - ./tmp:/tmp/dentalcare-ai
    depends_on:
      - minio
    networks:
      - dentalcare-ai-net

  minio:
    image: minio/minio:latest
    container_name: dentalcare-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    networks:
      - dentalcare-ai-net

volumes:
  minio_data:

networks:
  dentalcare-ai-net:
    driver: bridge
```

Versione se MinIO è già esistente nel progetto DentalCare:

```yaml
services:
  dentalcare-ai-service:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: dentalcare-ai-service
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8008:8000"
    volumes:
      - ./models:/app/models:ro
      - ./tmp:/tmp/dentalcare-ai
    networks:
      - dentalcare-net

networks:
  dentalcare-net:
    external: true
```

---

## 14. docker-compose.gpu.yml futuro

Da usare solo se la CT/VM Proxmox ha accesso a GPU NVIDIA e Docker NVIDIA Container Toolkit è configurato.

```yaml
services:
  dentalcare-ai-service:
    build:
      context: .
      dockerfile: Dockerfile.gpu
    container_name: dentalcare-ai-service-gpu
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8008:8000"
    volumes:
      - ./models:/app/models:ro
      - ./tmp:/tmp/dentalcare-ai
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      ORT_PROVIDERS: CUDAExecutionProvider,CPUExecutionProvider
    networks:
      - dentalcare-net

networks:
  dentalcare-net:
    external: true
```

Creare anche `Dockerfile.gpu` con `onnxruntime-gpu` al posto di `onnxruntime`.

---

## 15. Posizione modelli

I file ONNX devono stare in:

```text
./models/dentex_fdi_v1.onnx
./models/dentex_disease_v1.onnx
```

Da Kaggle esportare i modelli così:

```python
from ultralytics import YOLO

model = YOLO('/kaggle/working/runs/dentex_fdi_v1/weights/best.pt')
model.export(format='onnx', imgsz=1024, simplify=True)

model = YOLO('/kaggle/working/runs/dentex_disease_v1/weights/best.pt')
model.export(format='onnx', imgsz=1024, simplify=True)
```

Rinominare i file esportati:

```text
dentex_fdi_v1.onnx
dentex_disease_v1.onnx
```

---

## 16. Formato risultato salvato su MinIO

Il servizio deve salvare un JSON come:

```json
{
  "job_id": "ai-job-uuid",
  "patient_id": "PATIENT-123",
  "study_id": "STUDY-456",
  "source_image": {
    "bucket": "dentalcare-docs",
    "object_key": "patients/PATIENT-123/studies/STUDY-456/panoramic.png"
  },
  "models": {
    "fdi": "dentex_fdi_v1",
    "disease": "dentex_disease_v1"
  },
  "status": "completed",
  "created_at": "2026-06-26T10:00:00Z",
  "detections": [
    {
      "id": "det-uuid",
      "tooth": "16",
      "disease": "Caries",
      "disease_confidence": 0.82,
      "fdi_confidence": 0.76,
      "bbox_xyxy": [120, 330, 180, 390],
      "matching_method": "iou",
      "matching_score": 0.34,
      "needs_review": false
    }
  ],
  "raw": {
    "fdi_detections": [],
    "disease_detections": []
  },
  "review": {
    "status": "pending",
    "reviewed_by": null,
    "reviewed_at": null
  }
}
```

---

## 17. Interfaccia di annotazione futura

L'interfaccia può essere realizzata in DentalCare o come frontend separato. Il servizio AI deve però fornire dati compatibili.

Funzionalità richieste lato UI:

1. caricare immagine da MinIO o tramite URL firmata;
2. mostrare bounding box AI;
3. permettere al dentista di:
   - confermare detection;
   - modificare dente FDI;
   - modificare patologia;
   - spostare/ridimensionare box;
   - eliminare falso positivo;
   - aggiungere falso negativo;
4. salvare annotazioni revisionate via API `/api/v1/annotations`;
5. marcare campione come:
   - `pending_review`;
   - `reviewed`;
   - `approved_for_training`;
   - `excluded`.

Formato annotazioni consigliato:

```json
{
  "schema_version": "1.0",
  "image": {
    "bucket": "dentalcare-docs",
    "object_key": "patients/PATIENT-123/studies/STUDY-456/panoramic.png",
    "width": 1800,
    "height": 900
  },
  "annotations": [
    {
      "tooth": "16",
      "disease": "Caries",
      "bbox_xyxy": [120, 330, 180, 390],
      "source": "human_corrected",
      "action": "confirmed"
    }
  ]
}
```

---

## 18. Dataset per retraining futuro

Salvare i campioni approvati in MinIO con struttura:

```text
ai/training/
  pending/
    {study_id}.json
  approved/
    {study_id}.json
  excluded/
    {study_id}.json
  datasets/
    dataset_YYYY_MM_DD/
      images/
      labels_disease/
      labels_fdi/
      disease.yaml
      fdi.yaml
```

Il retraining non deve essere eseguito automaticamente nella prima versione. Deve essere predisposto come processo futuro, ad esempio:

```text
1. esporta dataset revisionato da MinIO
2. crea formato YOLO
3. addestra su Kaggle o macchina GPU
4. esporta ONNX
5. versiona modello
6. aggiorna servizio Docker
```

Versionamento modelli:

```text
models/
  dentex_fdi_v1.onnx
  dentex_fdi_v2.onnx
  dentex_disease_v1.onnx
  dentex_disease_v2.onnx
```

Configurare `.env` per scegliere quale versione caricare.

---

## 19. Logging e audit

Loggare sempre:

- `job_id`;
- `patient_id` solo se consentito dalla policy privacy interna;
- `study_id`;
- object key immagine;
- tempi di inferenza;
- numero detection;
- errori MinIO;
- errori modello.

Non loggare dati sanitari non necessari.

Formato log consigliato JSON line.

---

## 20. Performance attesa

Deployment CPU-only:

- usare ONNX Runtime CPU;
- modelli consigliati per produzione iniziale:
  - FDI: YOLOv8m o YOLOv8s a 1024 px;
  - Disease: YOLOv8m o YOLOv8l a 1024/1280 px;
- eseguire benchmark reale.

Endpoint benchmark richiesto:

```http
POST /api/v1/inference/benchmark
```

Può essere implementato in futuro. Deve misurare:

```json
{
  "download_ms": 120,
  "preprocess_ms": 40,
  "fdi_inference_ms": 1800,
  "disease_inference_ms": 2400,
  "postprocess_ms": 80,
  "upload_ms": 150,
  "total_ms": 4590
}
```

---

## 21. Requisiti di qualità

Claude Code deve implementare:

- FastAPI con router separati;
- Pydantic schemas per request/response;
- gestione errori HTTP chiara;
- sicurezza JWT;
- client MinIO riutilizzabile;
- pipeline inferenza separata dal router;
- funzioni testabili per IoU e matching;
- test unitari minimi;
- Dockerfile funzionante;
- docker-compose funzionante;
- README con istruzioni di avvio.

---

## 22. Comandi di avvio attesi

```bash
cp .env.example .env
mkdir -p models tmp
# copiare i modelli ONNX in ./models

docker compose up -d --build
```

Health check:

```bash
curl http://localhost:8008/health
```

Test model status:

```bash
curl -H "Authorization: Bearer <TOKEN>" \
  http://localhost:8008/api/v1/models/status
```

---

## 23. Nota clinica e legale

Il servizio deve essere considerato supporto decisionale e non sostituto del dentista. Ogni risultato deve essere marcato come:

```text
AI-generated, requires clinician review
```

Nessuna diagnosi deve essere automaticamente confermata senza revisione del professionista.

---

## 24. Task prioritari per Claude Code

Implementare in questo ordine:

1. creare scheletro FastAPI;
2. configurazione `.env`;
3. health endpoint;
4. sicurezza JWT;
5. client MinIO;
6. loader ONNX Runtime;
7. preprocessing/postprocessing YOLO;
8. pipeline a due modelli;
9. endpoint `/api/v1/inference/jobs`;
10. salvataggio risultati JSON e immagine annotata su MinIO;
11. endpoint `/api/v1/annotations`;
12. Dockerfile e docker-compose;
13. test unitari su matching IoU;
14. README.

