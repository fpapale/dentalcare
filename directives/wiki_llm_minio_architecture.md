# Wiki LLM - Progettazione con MinIO Multitenant

## 1. Obiettivo

Implementare una pipeline OCR/Wiki che monitora documenti grezzi (PDF/DOCX) in MinIO, estrae contenuti via GPT-4o, genera Wiki Markdown, e sincronizza SQL — tutto isolato per tenant/paziente dentro MinIO.

---

## 2. Architettura Multitenant

### 2.1 Struttura bucket MinIO

```
Bucket: dc-<tenant_schema>  (es: dc-mydentalclinic)
│
├── patients/
│   ├── <patient_id>/
│   │   ├── documents/          # PDF/DOCX grezzi, radiografie
│   │   │   ├── <doc_id>/
│   │   │   │   ├── source/
│   │   │   │   │   └── file.pdf
│   │   │   │   └── metadata.json
│   │   │   └── ...
│   │   │
│   │   ├── wiki/               # **NEW** Wiki Markdown per paziente
│   │   │   ├── _index.json     # Indice wiki (timestamps, versions)
│   │   │   ├── <doc_id>.md     # Wiki entry (generato da OCR)
│   │   │   ├── <doc_id>-v1.md  # Versioning (backup)
│   │   │   ├── <doc_id>-v2.md
│   │   │   └── ...
│   │   │
│   │   ├── ai/                 # Risultati AI (IA radiografica, ecc.)
│   │   │   ├── <analysis_id>/
│   │   │   │   ├── detections.json
│   │   │   │   └── annotated.png
│   │   │   └── ...
│   │   │
│   │   └── medical_data.json   # Aggregato paziente (da DB)
│   │
│   └── ...
│
└── wiki/                       # **NEW** Wiki globale (shared knowledge)
    ├── _taxonomy.json          # Tassonomia malattie, procedure
    ├── procedures/
    │   ├── root_canal.md
    │   ├── implant.md
    │   └── ...
    ├── conditions/
    │   ├── gingivitis.md
    │   ├── periodontitis.md
    │   └── ...
    └── clinical_notes/
        └── templates.json      # Template note cliniche
```

---

## 3. Flusso Pipeline OCR → Wiki

### 3.1 Trigger e ingresso

```
Evento:  Nuovo file in patients/{patient_id}/documents/{doc_id}/source/
         (monitored via MinIO event notifications, o polling periodico)

Payload: {
  "bucket": "dc-<schema>",
  "patient_id": "P123456",
  "doc_id": "D20250315-001",
  "file_path": "patients/P123456/documents/D20250315-001/source/prescription.pdf",
  "file_type": "pdf|docx|jpg",  # tipi supportati
  "timestamp": "2025-03-15T10:30:00Z",
  "tenant_schema": "mydentalclinic"
}
```

### 3.2 Estrazione contenuto (Engine)

```
1. Download da MinIO
   ├─ via S3/boto3
   └─ salva in /tmp/{doc_id}/

2. OCR/Estrazione testo
   ├─ PDF (nativo): PyMuPDF → testo strutturato
   ├─ Scanned PDF: Docling + Tesseract OCR
   ├─ DOCX: python-docx → testo
   └─ Immagini (JPG): Tesseract OCR

3. Validazione output
   └─ minimo 100 caratteri estratti, altrimenti fail
```

### 3.3 Elaborazione AI (GPT-4o)

**Task A: Estrazione dati DB (LLM)**

```python
prompt_template = """
Estrai da questo documento medico odontoiatrico i dati strutturati:
- patient_id
- exam_date (ISO 8601)
- exam_type (visita|radiografia|terapia|igiene)
- chief_complaint (lamentela principale)
- clinical_summary (riassunto 200-300 parole)
- findings (list: tooth_fdi, diagnosis, severity)
- plan (treatment plan, next steps)

Documento:
{extracted_text}

Output JSON:
{...}
"""

# Output atteso:
{
  "exam_date": "2025-03-15",
  "exam_type": "visita",
  "chief_complaint": "Dolore dente 2.6",
  "clinical_summary": "Paziente presenta carie profonda...",
  "findings": [
    {"tooth_fdi": "26", "diagnosis": "Caries", "severity": "high"},
  ],
  "plan": "Endodonzia, recall 1 mese"
}
```

**Task B: Generazione Wiki Markdown (LLM)**

```python
prompt_template = """
Formatta il seguente estratto medico in Wiki Markdown:

Regole:
- Titolo: # {paziente} - {data} ({tipo_esame})
- Sezioni: ## Summary, ## Clinical Findings, ## Plan, ## Notes
- Link a MinIO raw file in "## Raw Data"
- Niente PHI sensibile escluso ID paziente
- Linguaggio professionale, conciso

Documento:
{extracted_text}

Output Markdown:
{...}
"""

# Output atteso:
# Dr Smith - 2025-03-15 (Visita)
## Summary
Paziente lamenta dolore acuto al quadrante superiore destro...

## Clinical Findings
- Tooth 2.6: Carie profonda, profondità > 3mm
- Radiografia: interessamento della camera pulpare?
- VES: vitalità presente

## Plan
1. Terapia endodontica entro 7 gg
2. Recall radiografico post-terapia
3. Prossimo controllo: 2025-04-15

## Raw Data
- [Original PDF](s3://dc-mydentalclinic/patients/P123456/documents/D20250315-001/source/prescription.pdf)
- Upload timestamp: 2025-03-15T10:30:00Z
```

---

## 4. Salvataggio Wiki in MinIO

### 4.1 Generazione file Markdown

```
Path: patients/{patient_id}/wiki/{doc_id}.md
Content: [output Task B]
Metadata:
  - generated_at: ISO 8601
  - version: 1
  - source_doc_id: {doc_id}
  - exam_type: {exam_type}
  - reviewed: false (inizialmente)
  - reviewer_id: null
```

### 4.2 Versionamento

Se il wiki per lo stesso `{doc_id}` viene rigenerato:

```
Primo salvataggio:
  patients/{patient_id}/wiki/{doc_id}.md  (v=1)

Seconda elaborazione (correzione):
  - Rinomina v1 a v1-archived-{timestamp}.md
  - Salva nuovo come {doc_id}.md (v=2)
  
Index: patients/{patient_id}/wiki/_index.json
{
  "doc_id": {
    "current_version": 2,
    "versions": [
      {"v": 1, "timestamp": "2025-03-15T10:30:00Z", "path": "...v1.md"},
      {"v": 2, "timestamp": "2025-03-15T11:45:00Z", "path": "{doc_id}.md"}
    ],
    "exam_type": "visita",
    "reviewed": true,
    "reviewer_id": "DR001",
    "review_notes": "Confermato dall'odontoiatra"
  }
}
```

---

## 5. Sincronizzazione Database

### 5.1 Payload → PatientDocument (SQL)

```sql
INSERT INTO patient_document (
  patient_id, document_type, exam_date, exam_type, 
  chief_complaint, clinical_summary, findings_json, 
  treatment_plan, source_object_key, wiki_object_key,
  extracted_via_llm, processed_at, metadata
) VALUES (
  'P123456', 'clinical_note', '2025-03-15', 'visita',
  'Dolore dente 2.6', 'Paziente presenta carie profonda...',
  '[{"tooth_fdi":"26","diagnosis":"Caries"}]',
  'Endodonzia, recall 1 mese',
  'patients/P123456/documents/D20250315-001/source/prescription.pdf',
  'patients/P123456/wiki/D20250315-001.md',
  true, NOW(),
  '{"llm_model":"gpt-4o","confidence":0.92,"tokens_used":1240}'
);

-- Opzionale: insert clinical_finding records separati
INSERT INTO clinical_finding (patient_id, document_id, tooth_fdi, diagnosis, severity)
VALUES ('P123456', doc_id, '26', 'Caries', 'high');
```

### 5.2 Callback da AI Service

Se il documento è radiografia, l'AI Service invia callback dopo inferenza:

```json
{
  "job_id": "J20250315-001",
  "patient_id": "P123456",
  "doc_id": "D20250315-R01",  // Radiografia
  "detections": [
    {"tooth": "26", "disease": "Caries", "confidence": 0.87},
    {"tooth": "27", "disease": "Gingivitis", "confidence": 0.72}
  ],
  "detections_object_key": "patients/P123456/ai/J20250315-001/detections.json",
  "annotated_image_object_key": "patients/P123456/ai/J20250315-001/annotated.png"
}
```

Backend aggiorna `clinical_finding` con dati AI + genera wiki supplementare:

```
patients/{patient_id}/wiki/D20250315-R01-ai-summary.md
# AI Analysis - Radiografia 2025-03-15

## Detections (Inferenza Dentex)
- Tooth 2.6: Caries (confidence 87%)
- Tooth 2.7: Gingivitis (confidence 72%)

## Annotated Image
[Link to patients/P123456/ai/.../annotated.png]

## Clinical Correlation
Findings correlano con esame clinico: dolore localizzato a 2.6, conferma carie profonda.
```

---

## 6. Wiki Globale (Knowledge Base)

### 6.1 Tassonomia e Procedure

```
wiki/_taxonomy.json
{
  "disease_codes": {
    "caries": {"icd10": "K02", "description": "Caria dentale"},
    "gingivitis": {"icd10": "K05.0", "description": "Gengivite"},
    "periodontitis": {"icd10": "K05.3", "description": "Parodontite"}
  },
  "procedures": {
    "root_canal": "Terapia endodontica",
    "implant": "Impianto dentale",
    "scaling": "Detartrasi"
  },
  "tooth_numbering": "FDI-ISO-1992 (International)"
}
```

### 6.2 Template Note Cliniche

```
wiki/clinical_notes/templates.json
{
  "visita": {
    "sections": ["Summary", "Chief Complaint", "Clinical Findings", "Plan"],
    "defaults": {
      "exam_type": "visita",
      "include_radiography": true
    }
  },
  "igiene": {
    "sections": ["Summary", "Probing Depth", "Bleeding Index", "Plan"],
    "defaults": {
      "exam_type": "igiene",
      "include_radiography": false
    }
  }
}
```

### 6.3 Popolazione Wiki Globale

- `/wiki/procedures/{procedure}.md` — linee guida (read-only, aggiornate da admin)
- `/wiki/conditions/{condition}.md` — patologie cliniche
- `/wiki/_taxonomy.json` — riferimenti ICD-10, FDI, procedure
- **Accessibilità:** Backend carica wiki globale per suggerimenti LLM, RAG su AI queries

---

## 7. Flusso Completo (Sequence)

```
┌─ Frontend/Backend                    Python Worker                         MinIO
│
1. Upload documento
   patients/P123456/documents/D.../source/file.pdf
   └─────────────────────────────────> (event notification)

2. Download + OCR
   ├─ fetch file da S3
   ├─ estrai testo
   └─ validazione (minimo length)

3. Call GPT-4o (Task A + B)
   ├─ Task A: JSON struct (DB sync)
   ├─ Task B: Markdown wiki
   └─ output: 2 payload

4. Salva Wiki
   └─────────────────────────────────> patients/.../wiki/{doc_id}.md
   └─────────────────────────────────> patients/.../wiki/_index.json

5. POST callback Backend
   <────────────────────────────────── { "wiki_path": "...", "db_fields": {...} }

6. Backend: Update PatientDocument + clinical_finding
   └─────────────────────────────────> SQL

7. Optional: Genera ulteriore wiki da AI radiografia callback
   (se è radiografia, attendi AI Service inference)
```

### 7.1 Diagramma Flusso (Mermaid)

```mermaid
graph TD
    A["Frontend/Backend Upload"] -->|Salva documento| B["MinIO Bucket<br/>patients/{id}/documents/{doc_id}/source/"]
    B -->|Event Notification| C["Python Worker:<br/>MinioWikiListener"]
    
    C -->|1. Download| D["File dal bucket"]
    D -->|2. OCR Extract| E{Tipo File?}
    E -->|PDF nativo| F["PyMuPDF"]
    E -->|PDF scanned/DOCX| G["Docling + Tesseract"]
    E -->|Immagine| H["Tesseract OCR"]
    
    F --> I["Testo estratto"]
    G --> I
    H --> I
    
    I -->|Validazione<br/>min 100 chars| J{OK?}
    J -->|No| K["❌ Dead-Letter<br/>patients/{id}/wiki/failed/"]
    J -->|Sì| L["GPT-4o Dual Task"]
    
    L -->|Task A| M["JSON Struct<br/>exam_type, findings,<br/>treatment_plan"]
    L -->|Task B| N["Markdown Wiki<br/># Title<br/>## Summary<br/>## Findings<br/>## Plan"]
    
    M -->|POST /api/wiki/callback| O["Backend WikiService"]
    N -->|Upload| P["MinIO<br/>patients/{id}/wiki/{doc_id}.md<br/>+ _index.json"]
    
    O -->|Update| Q["SQL: PatientDocument<br/>+ clinical_finding"]
    O -->|Link| P
    
    Q -->|Sync complete| R["✅ Wiki Ready<br/>+ DB Updated"]
    P --> R
    
    R -->|Optional: Radiografia?| S["AI Service Callback"]
    S -->|Detections| T["Crea wiki-ai-summary<br/>patients/{id}/wiki/{doc_id}-ai.md"]
    T --> R
```

---

---

## 8. Configurazione Backend Java

### 8.1 Environment Properties

```properties
# application.properties
app.wiki.enabled=true
app.wiki.llm.provider=openai
app.wiki.llm.model=gpt-4o
app.wiki.llm.api_key=${OPENAI_API_KEY}
app.wiki.llm.temperature=0.3
app.wiki.llm.max_tokens=2000

# MinIO (già esistente)
app.minio.endpoint=host.docker.internal:9000
app.minio.access-key=minioadmin
app.minio.secret-key=minioadmin
app.minio.bucket-prefix=dc-

# Wiki storage
app.wiki.bucket.prefix=dc-
app.wiki.document.max_size=50MB
app.wiki.supported_types=pdf,docx,jpg,png

# OCR fallback
app.ocr.tesseract.enabled=true
app.ocr.tesseract.lang=ita
```

### 8.2 Java Service Architecture

```
Backend (Spring Boot)
│
├── WikiOcrService
│   ├── downloadFromMinio()
│   ├── extractText() [OCR engine dispatcher]
│   └── uploadWikiToMinio()
│
├── WikiLlmService
│   ├── callGpt4oTaskA() → JSON struct
│   ├── callGpt4oTaskB() → Markdown
│   └── retry logic (exponential backoff)
│
├── WikiStorageService (extends MinioStorageService)
│   ├── saveWikiMarkdown(patient_id, doc_id, content)
│   ├── getWikiIndex(patient_id)
│   ├── updateWikiIndex(patient_id, doc_id, metadata)
│   └── getWikiVersions(patient_id, doc_id)
│
├── PatientDocumentService
│   ├── processWikiData(llm_output) → DB sync
│   ├── createClinicalFindings()
│   └── linkWikiToDocument()
│
└── WikiGlobalService (Read-only RAG)
    ├── loadTaxonomy()
    ├── loadProcedures()
    └── queryWikiKb(query) → LLM context
```

---

## 9. Monitoraggio e Error Handling

### 9.1 Event Listener (Python Worker)

```python
class MinioWikiListener:
    def __init__(self, minio_client, config):
        self.minio = minio_client
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def start_listening(self):
        # Option A: MinIO event notifications + webhook
        # Option B: Polling loop ogni 60 secondi
        pass
    
    def process_new_document(self, event):
        try:
            # Estrai metadata evento
            bucket, object_key = event['bucket'], event['object_key']
            # Extract patient_id, doc_id from path
            patient_id, doc_id = self._parse_path(object_key)
            
            # Pipeline
            extracted_text = self._ocr_extract(bucket, object_key)
            task_a_output = self._call_llm_task_a(extracted_text)
            task_b_output = self._call_llm_task_b(extracted_text)
            
            # Upload wiki
            wiki_path = self._upload_wiki(bucket, patient_id, doc_id, task_b_output)
            
            # Callback backend
            self._notify_backend(patient_id, doc_id, task_a_output, wiki_path)
            
            self.logger.info(f"Wiki processed: {wiki_path}")
        
        except Exception as e:
            self.logger.error(f"Failed to process wiki for {doc_id}: {e}")
            # Retry queue, dead-letter bucket, alert
```

### 9.2 Dead-Letter Handling

```
patients/{patient_id}/wiki/failed/
├── {doc_id}-failed-{timestamp}.json
{
  "error": "OCR extraction failed: file corrupted",
  "retries": 3,
  "last_attempt": "2025-03-15T11:50:00Z",
  "source_file": "patients/P123456/documents/D.../source/file.pdf"
}
```

---

## 10. Permessi e Isolamento Tenant

### 10.1 RBAC Backend

```java
// WikiService deve rispettare TenantContext
public WikiDto getWikiForPatient(String patient_id, String doc_id) {
    String schema = TenantContext.validatedSchema();
    String bucket = minioService.bucketFor(schema);
    
    // Path safe: bucket + tenant schema non possono essere cross-contaminated
    String wikiPath = "patients/" + patient_id + "/wiki/" + doc_id + ".md";
    
    // Accedi ai dati solo se:
    // 1. Utente autenticato
    // 2. Paziente appartiene al tenant attuale
    // 3. Utente ha permesso di lettura documento
    
    Patient patient = patientRepo.findByIdAndTenantSchema(patient_id, schema);
    if (patient == null) throw new ResourceNotFoundException(...);
    
    return minioService.download(bucket, wikiPath, WikiDto.class);
}
```

### 10.2 Confidenzialità

- **PHI in Wiki:** redatto se non strettamente necessario (solo ID paziente)
- **AI logs:** memorizzati separati, con tokens sensibili rimossi
- **Git history locale:** NO (non usare per PHI)

---

## 11. Evoluzione Futura

1. **Wiki collaboration:** Permettere correzione wiki da odontoiatri (flag `reviewed`, `reviewer_id`)
2. **RAG per diagnosi:** Backend interroga wiki globale + storico paziente durante AI call
3. **Export:** Scarica wiki per stampa o FHIR
4. **Search:** Indice Elasticsearch su wiki per ricerca full-text tenant-safe
5. **Audit trail:** Registra ogni modifica wiki in `_audit.json`

---

## 12. Checklist Implementazione

- [ ] MinIO bucket structure adattata (wiki/ path)
- [ ] Python worker: OCR engine + GPT-4o integration
- [ ] Backend: WikiStorageService + WikiLlmService
- [ ] Database: Estendi PatientDocument con `wiki_object_key`, `extracted_via_llm`
- [ ] Event listener: Monitoraggio bucket + retry
- [ ] Test: OCR accuracy, LLM consistency, tenant isolation
- [ ] Secrets: API key OpenAI in AWS Secrets / env
- [ ] Documentazione: API wiki GET/POST, formato markdown
- [ ] Monitoring: CloudWatch / custom metrics

---

## 13. Schema SQL

### 13.1 Estensione PatientDocument

```sql
-- Aggiungere colonne a patient_document se non già presenti
ALTER TABLE patient_document 
ADD COLUMN IF NOT EXISTS wiki_object_key VARCHAR(500),
ADD COLUMN IF NOT EXISTS extracted_via_llm BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS llm_model VARCHAR(50) DEFAULT 'gpt-4o',
ADD COLUMN IF NOT EXISTS llm_confidence FLOAT,
ADD COLUMN IF NOT EXISTS llm_metadata JSONB,
ADD COLUMN IF NOT EXISTS wiki_version INT DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_patient_doc_wiki_key 
ON patient_document(tenant_schema, patient_id, wiki_object_key);

CREATE INDEX IF NOT EXISTS idx_patient_doc_llm_processed 
ON patient_document(tenant_schema, extracted_via_llm, processed_at DESC);
```

### 13.2 Nuova tabella: clinical_finding_ai

```sql
-- Tabella per tracciare detections AI (radiografie, inferenza)
CREATE TABLE IF NOT EXISTS clinical_finding_ai (
    id BIGSERIAL PRIMARY KEY,
    tenant_schema VARCHAR(100) NOT NULL,
    patient_id VARCHAR(100) NOT NULL,
    document_id VARCHAR(100) NOT NULL,
    
    -- Fonte AI
    ai_job_id VARCHAR(100),
    ai_model VARCHAR(50) DEFAULT 'dentex-v1',
    ai_provider VARCHAR(50) DEFAULT 'internal',
    
    -- Risultato
    tooth_fdi VARCHAR(10),
    condition_code VARCHAR(20),
    condition_name VARCHAR(200),
    confidence FLOAT NOT NULL,
    severity VARCHAR(20),  -- low, medium, high
    bbox_xyxy INT[],  -- [x1, y1, x2, y2] per visualizzazione
    
    -- Metadati
    annotated_image_object_key VARCHAR(500),
    processed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    FOREIGN KEY (tenant_schema, patient_id) 
        REFERENCES patient(tenant_schema, patient_id) ON DELETE CASCADE,
    
    UNIQUE (tenant_schema, patient_id, document_id, tooth_fdi, condition_code)
);

CREATE INDEX IF NOT EXISTS idx_cf_ai_patient 
ON clinical_finding_ai(tenant_schema, patient_id);

CREATE INDEX IF NOT EXISTS idx_cf_ai_confidence 
ON clinical_finding_ai(tenant_schema, confidence DESC);
```

### 13.3 Tabella: wiki_metadata

```sql
-- Tabella per tracciare storia versioni + audit wiki
CREATE TABLE IF NOT EXISTS wiki_metadata (
    id BIGSERIAL PRIMARY KEY,
    tenant_schema VARCHAR(100) NOT NULL,
    patient_id VARCHAR(100) NOT NULL,
    document_id VARCHAR(100) NOT NULL,
    
    -- Versioning
    version INT NOT NULL,
    wiki_object_key VARCHAR(500) NOT NULL,
    previous_version_key VARCHAR(500),
    
    -- Generazione
    generated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    generated_by_model VARCHAR(50) DEFAULT 'gpt-4o',
    generation_prompt_tokens INT,
    generation_completion_tokens INT,
    
    -- Revisione
    reviewed BOOLEAN DEFAULT false,
    reviewed_at TIMESTAMP,
    reviewed_by_user_id VARCHAR(100),
    review_notes TEXT,
    
    -- Audit
    is_archived BOOLEAN DEFAULT false,
    archived_at TIMESTAMP,
    
    FOREIGN KEY (tenant_schema, patient_id) 
        REFERENCES patient(tenant_schema, patient_id) ON DELETE CASCADE,
    
    UNIQUE (tenant_schema, patient_id, document_id, version)
);

CREATE INDEX IF NOT EXISTS idx_wiki_meta_patient_doc 
ON wiki_metadata(tenant_schema, patient_id, document_id, version DESC);

CREATE INDEX IF NOT EXISTS idx_wiki_meta_reviewed 
ON wiki_metadata(tenant_schema, reviewed, reviewed_at DESC);
```

### 13.4 View: Patient Wiki Summary

```sql
-- View per estrarre riassunto wiki paziente + AI findings
CREATE OR REPLACE VIEW v_patient_wiki_summary AS
SELECT 
    pd.tenant_schema,
    pd.patient_id,
    pd.document_id,
    pd.exam_type,
    pd.exam_date,
    pd.clinical_summary,
    wm.version,
    wm.wiki_object_key,
    wm.reviewed,
    wm.reviewed_by_user_id,
    COUNT(cfa.id) as ai_findings_count,
    STRING_AGG(DISTINCT cfa.condition_name, ', ') as ai_conditions,
    MAX(cfa.confidence) as max_ai_confidence
FROM patient_document pd
LEFT JOIN wiki_metadata wm 
    ON pd.tenant_schema = wm.tenant_schema 
    AND pd.patient_id = wm.patient_id 
    AND pd.document_id = wm.document_id 
    AND wm.version = (
        SELECT MAX(version) FROM wiki_metadata w2 
        WHERE w2.tenant_schema = wm.tenant_schema 
        AND w2.patient_id = wm.patient_id 
        AND w2.document_id = wm.document_id
    )
LEFT JOIN clinical_finding_ai cfa 
    ON pd.tenant_schema = cfa.tenant_schema 
    AND pd.patient_id = cfa.patient_id 
    AND pd.document_id = cfa.document_id
WHERE pd.wiki_object_key IS NOT NULL
GROUP BY 
    pd.tenant_schema, pd.patient_id, pd.document_id,
    pd.exam_type, pd.exam_date, pd.clinical_summary,
    wm.version, wm.wiki_object_key, wm.reviewed, wm.reviewed_by_user_id;
```

---

## 14. Configurazione Python Worker (.env Template)

### 14.1 File: `dentalcare-ai-service/.env.wiki`

```bash
# ============================================================================
# Wiki LLM Pipeline - Environment Configuration
# ============================================================================

# --- MinIO S3 Configuration ---
MINIO_ENDPOINT=host.docker.internal:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false
MINIO_REGION=us-east-1

# Bucket setup (backend usa questo prefisso)
MINIO_BUCKET_PREFIX=dc-

# --- OCR Engine Configuration ---
OCR_ENGINE=docling  # Options: pymupdf, docling, tesseract, hybrid
OCR_TESSERACT_ENABLED=true
OCR_TESSERACT_PATH=/usr/bin/tesseract  # PATH locale, di solito in Docker
OCR_TESSERACT_LANG=ita  # Italian language data
OCR_MIN_CHAR_THRESHOLD=100  # Minimum extracted characters to proceed

# Docling cache (per prestazioni)
DOCLING_CACHE_DIR=/tmp/docling-cache
DOCLING_MODEL_BACKEND=transformers  # transformer-based extraction

# --- LLM Configuration (GPT-4o) ---
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o
LLM_API_KEY=${OPENAI_API_KEY}  # Load from secrets!
LLM_API_ENDPOINT=https://api.openai.com/v1
LLM_TEMPERATURE=0.3  # Low randomness for consistency
LLM_MAX_TOKENS=2000
LLM_TIMEOUT_SEC=60

# Task-specific prompts
LLM_TASK_A_MODEL=gpt-4o  # Structured JSON extraction
LLM_TASK_B_MODEL=gpt-4o  # Wiki Markdown generation

# Retry logic
LLM_RETRY_MAX_ATTEMPTS=3
LLM_RETRY_BACKOFF_BASE=2  # Exponential backoff: 2^attempt seconds
LLM_RETRY_BACKOFF_JITTER=true

# Cost tracking
LLM_TRACK_TOKENS=true
LLM_COST_PER_1M_INPUT=5.00  # USD
LLM_COST_PER_1M_OUTPUT=15.00  # USD

# --- Wiki Pipeline Configuration ---
WIKI_ENABLED=true
WIKI_SAVE_TO_MINIO=true
WIKI_VERSIONING_ENABLED=true

# Processing
WIKI_SUPPORTED_TYPES=pdf,docx,jpg,png  # File types to process
WIKI_MAX_FILE_SIZE_MB=50
WIKI_PROCESSING_TIMEOUT_SEC=300  # 5 minutes per document

# Output paths in MinIO
WIKI_OUTPUT_PATH_TEMPLATE=patients/{patient_id}/wiki/{doc_id}.md
WIKI_INDEX_PATH_TEMPLATE=patients/{patient_id}/wiki/_index.json
WIKI_FAILED_PATH_TEMPLATE=patients/{patient_id}/wiki/failed/{doc_id}-failed-{timestamp}.json

# --- Event Listener Configuration ---
EVENT_LISTENER_MODE=webhook  # Options: webhook, polling, minio_notification
EVENT_WEBHOOK_PORT=8001
EVENT_WEBHOOK_SECRET=change-me-webhook-secret
EVENT_POLLING_INTERVAL_SEC=60  # If polling mode

# MinIO event notifications (if supported)
EVENT_NOTIFICATION_TOPIC=wiki-pipeline
EVENT_NOTIFICATION_QUEUE_PREFIX=wiki-queue-

# --- Backend Callback Configuration ---
BACKEND_CALLBACK_URL=http://dentalcarepro-backend:8080/api/internal/wiki/callback
BACKEND_CALLBACK_SECRET=change-me-callback-secret
BACKEND_CALLBACK_TIMEOUT_SEC=30
BACKEND_CALLBACK_RETRY_MAX=3

# --- Database Configuration ---
DATABASE_URL=postgresql://dentalcare:dentalcare@dentalcare-postgres:5432/dentalcare_dev
DATABASE_SSL_MODE=disable
DATABASE_POOL_SIZE=5

# --- Logging & Monitoring ---
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR
LOG_FORMAT=json  # json or text
LOG_FILE=/var/log/dentalcare-wiki/worker.log
LOG_MAX_SIZE_MB=100
LOG_BACKUP_COUNT=5

# Sentry (error tracking, opzionale)
SENTRY_DSN=
SENTRY_ENVIRONMENT=development
SENTRY_TRACE_SAMPLE_RATE=0.1

# --- Performance Tuning ---
WORKER_THREADS=4
WORKER_QUEUE_SIZE=100
ASYNC_PROCESSING=true  # Process in background, don't block webhook

# File cleanup
TEMP_CLEANUP_AFTER_SEC=3600  # Delete temp files after 1 hour
TEMP_DIR=/tmp/dentalcare-wiki-worker

# --- Security ---
JWT_SECRET=change-me-jwt-secret
JWT_ISSUER=dentalcare-wiki-worker
JWT_AUDIENCE=dentalcare-backend
JWT_ALGORITHM=HS256
JWT_EXPIRY_SEC=3600

# TLS/SSL (opzionale)
SSL_CERT_FILE=
SSL_KEY_FILE=
SSL_VERIFY=true

# --- Feature Flags ---
FEATURE_WIKI_GENERATION=true
FEATURE_AI_SUMMARY=true  # Genera wiki summary da AI findings
FEATURE_GLOBAL_KB=true   # Carica wiki globale per RAG context
FEATURE_ASYNC_CALLBACK=true

# --- Debug & Testing ---
DEBUG_MODE=false
DEBUG_SAVE_EXTRACTED_TEXT=false  # Salva testo estratto per debug
DEBUG_SAVE_LLM_PROMPTS=false     # Salva prompts LLM (PHI risk!)
DRY_RUN=false  # Simula tutto senza salvar niente

# Test data (solo in dev)
TEST_PATIENT_ID=P_TEST_001
TEST_DOC_ID=D_TEST_20250315_001
```

### 14.2 File: `dentalcare-ai-service/wiki_worker.py` (Entry Point)

```python
import os
import json
import logging
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings

from app.wiki.ocr_extractor import OcrExtractor
from app.wiki.llm_processor import LlmProcessor, TaskAOutput, TaskBOutput
from app.wiki.wiki_storage import WikiStorageService
from app.wiki.backend_callback import BackendCallbackService

# --- Config ---
class WikiConfig(BaseSettings):
    minio_endpoint: str
    minio_access_key: str
    minio_secret_key: str
    
    ocr_engine: str = "docling"
    ocr_tesseract_enabled: bool = True
    ocr_min_char_threshold: int = 100
    
    llm_model: str = "gpt-4o"
    llm_api_key: str
    llm_temperature: float = 0.3
    llm_max_tokens: int = 2000
    
    wiki_enabled: bool = True
    wiki_save_to_minio: bool = True
    backend_callback_url: str
    backend_callback_secret: str
    
    debug_mode: bool = False
    log_level: str = "INFO"
    
    class Config:
        env_file = ".env.wiki"
        extra = "ignore"

config = WikiConfig()

# --- Logging ---
logging.basicConfig(
    level=getattr(logging, config.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# --- FastAPI App ---
app = FastAPI(
    title="DentalCare Wiki LLM Pipeline",
    version="0.1.0",
)

# --- Services ---
ocr = OcrExtractor(config)
llm = LlmProcessor(config)
wiki_storage = WikiStorageService(config)
backend_callback = BackendCallbackService(config)

# --- Models ---
class WikiProcessRequest(BaseModel):
    bucket: str
    patient_id: str
    doc_id: str
    file_path: str  # Relative path in bucket
    file_type: str = Field(..., regex="^(pdf|docx|jpg|png)$")
    tenant_schema: str
    timestamp: Optional[str] = Field(default_factory=lambda: datetime.utcnow().isoformat())

class WikiProcessResponse(BaseModel):
    status: str  # "processing", "success", "failed"
    wiki_object_key: Optional[str] = None
    message: str

# --- Endpoints ---
@app.post("/api/wiki/process")
async def process_document(req: WikiProcessRequest, bg_tasks: BackgroundTasks):
    """
    Webhook endpoint per elaborare documento → Wiki
    """
    try:
        if not config.wiki_enabled:
            raise HTTPException(status_code=503, detail="Wiki processing disabled")
        
        # Queue async processing
        if config.async_processing:
            bg_tasks.add_task(
                _process_wiki_async,
                req
            )
            return WikiProcessResponse(
                status="processing",
                message="Document queued for wiki generation"
            )
        else:
            # Sync processing (blocca la response)
            result = await _process_wiki_sync(req)
            return result
    
    except Exception as e:
        logger.error(f"Failed to queue wiki processing: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/wiki/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "wiki-pipeline",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/wiki/config")
async def get_config():
    """Config debug endpoint (redacted)"""
    return {
        "ocr_engine": config.ocr_engine,
        "llm_model": config.llm_model,
        "wiki_enabled": config.wiki_enabled,
        "debug_mode": config.debug_mode,
    }

# --- Internal Functions ---
async def _process_wiki_sync(req: WikiProcessRequest) -> WikiProcessResponse:
    """Elaborazione sincrona"""
    logger.info(f"Processing wiki: {req.doc_id} from {req.file_path}")
    
    try:
        # 1. Download + OCR
        extracted_text = ocr.extract_from_minio(
            req.bucket, req.file_path, req.file_type
        )
        if len(extracted_text) < config.ocr_min_char_threshold:
            raise ValueError(f"OCR extraction too short: {len(extracted_text)} chars")
        
        logger.debug(f"Extracted {len(extracted_text)} chars from {req.doc_id}")
        
        # 2. LLM Task A (JSON struct)
        task_a: TaskAOutput = llm.process_task_a(extracted_text)
        logger.info(f"Task A: {task_a.exam_type} / {len(task_a.findings)} findings")
        
        # 3. LLM Task B (Markdown wiki)
        task_b: TaskBOutput = llm.process_task_b(extracted_text)
        logger.info(f"Task B: Generated {len(task_b.markdown)} chars of wiki")
        
        # 4. Upload wiki to MinIO
        wiki_path = wiki_storage.save_wiki(
            req.bucket, req.patient_id, req.doc_id, task_b.markdown
        )
        logger.info(f"Wiki saved to {wiki_path}")
        
        # 5. Notify backend
        callback_result = await backend_callback.notify(
            req.patient_id,
            req.doc_id,
            task_a,
            wiki_path,
            req.tenant_schema
        )
        logger.info(f"Backend notified: {callback_result}")
        
        return WikiProcessResponse(
            status="success",
            wiki_object_key=wiki_path,
            message=f"Wiki processed successfully"
        )
    
    except Exception as e:
        logger.error(f"Wiki processing failed: {e}", exc_info=True)
        
        # Salva failed document
        wiki_storage.save_failed_document(
            req.bucket, req.patient_id, req.doc_id, str(e)
        )
        
        return WikiProcessResponse(
            status="failed",
            message=str(e)
        )

async def _process_wiki_async(req: WikiProcessRequest):
    """Elaborazione asincrona (background task)"""
    result = await _process_wiki_sync(req)
    logger.info(f"Async task completed: {req.doc_id} → {result.status}")

# --- Main ---
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,
        log_level=config.log_level.lower(),
    )
```

### 14.3 Docker Compose Extension

```yaml
# Aggiungere al docker-compose.yml principale

services:
  # ... (backend, frontend, ai-service, minio)
  
  wiki-worker:
    build:
      context: ./dentalcare-ai-service
      dockerfile: Dockerfile.wiki
    image: dentalcare-wiki-worker:${VERSION:-latest}
    container_name: dentalcare-wiki-worker
    restart: unless-stopped
    environment:
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
      - LLM_API_KEY=${OPENAI_API_KEY}
      - BACKEND_CALLBACK_URL=http://dentalcarepro-backend:8080/api/internal/wiki/callback
      - DATABASE_URL=postgresql://dentalcare:dentalcare@dentalcare-postgres:5432/dentalcare_dev
      - LOG_LEVEL=INFO
      - DEBUG_MODE=false
    ports:
      - "8001:8001"  # Webhook endpoint
    volumes:
      - /tmp/dentalcare-wiki-worker:/tmp/dentalcare-wiki-worker
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/api/wiki/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    depends_on:
      - dentalcarepro-backend
      - minio
    networks:
      - dentalcarepro
      - minio
    deploy:
      resources:
        limits:
          memory: 2g

networks:
  dentalcarepro:
    driver: bridge
  minio:
    external: true
    name: minio_default
```

---
