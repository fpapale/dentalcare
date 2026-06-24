# Sistema AI di Revisione Radiografica — Analisi di Fattibilità e Design del Processo

> **Stato**: Bozza architetturale  
> **Data**: 2026-06-18  
> **Ambito**: Inferenza, revisione human-in-the-loop, retraining pipeline

---

## 1. Fattibilità — Valutazione Rapida

### 1.1 Cosa Claude può fare su OPG (Orthopantomograms)

Claude Vision (Sonnet / Opus) riceve immagini in base64 e restituisce output strutturato JSON.

| Capacità | Fattibile con Claude | Note |
|---|---|---|
| Riconoscimento carie sospette | ✅ | Output testuale + zona approssimativa |
| Lesioni periapicali | ✅ | Richiede prompt calibrato |
| Perdita ossea | ✅ | Meglio con esempi few-shot |
| Numerazione dentale FDI | ✅ | Accuratezza ~80% senza fine-tuning |
| Segmentazione dente per dente | ⚠️ | Claude descrive zone, NON restituisce maschere pixel |
| Bounding box pixel-precise | ❌ | Claude non fa detection object-level |
| Retraining del modello | ❌ | Claude è closed-model, non addestrabile |

**Conclusione**: Claude è adatto per l'analisi semantica e il report clinico. Per bounding box precisi e segmentazione serve un modello dedicato affiancato.

---

### 1.2 Architettura consigliata — Dual-Engine

```
OPG Image
    │
    ├──► [DETECTOR] YOLOv8 / SAM ──► bounding box + maschere per dente
    │         (modello trainabile, sostituito ad ogni ciclo)
    │
    └──► [REASONER] Claude API ──── analisi semantica, classificazione,
              (prompt evolution)        note cliniche, livello confidenza
                   │
                   ▼
         Findings unificati JSON
                   │
                   ▼
          UI Revisione Dentista
                   │
                   ▼
           Database Correzioni
                   │
           ┌───────┴────────┐
           ▼                ▼
    Prompt Evolution    Retraining YOLO/SAM
    (few-shot update)   (ogni N immagini validate)
```

Se si vuole iniziare con solo Claude (MVP senza detector separato), si accetta coordinazione approssimativa e si investe sul prompt. Il detector si aggiunge in una seconda fase.

---

## 2. Schema Dati

### 2.1 Entità principali

```sql
-- Immagine radiografica
CREATE TABLE radiographic_image (
    id              BIGSERIAL PRIMARY KEY,
    patient_id      BIGINT NOT NULL REFERENCES patient(id),
    acquisition_date DATE NOT NULL,
    file_path       VARCHAR(500) NOT NULL,
    image_type      VARCHAR(50) NOT NULL DEFAULT 'OPG',  -- OPG, BITEWING, PERIAPICAL
    file_hash       VARCHAR(64),                          -- sha256 per deduplication
    uploaded_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    uploaded_by     BIGINT REFERENCES app_user(id)
);

-- Finding prodotto dall'AI (immutabile dopo creazione)
CREATE TABLE ai_finding (
    id                BIGSERIAL PRIMARY KEY,
    image_id          BIGINT NOT NULL REFERENCES radiographic_image(id),
    tooth_number      SMALLINT,                  -- notazione FDI (11-48)
    finding_type      VARCHAR(50) NOT NULL,      -- CARIE, LESIONE_PERIAPICALE, PERDITA_OSSEA,
                                                 -- CORONA, IMPIANTO, OTTURAZIONE, ALTRO
    bbox_x            FLOAT,                     -- top-left X normalizzato [0,1]
    bbox_y            FLOAT,                     -- top-left Y normalizzato [0,1]
    bbox_w            FLOAT,                     -- larghezza normalizzata [0,1]
    bbox_h            FLOAT,                     -- altezza normalizzata [0,1]
    mask_polygon      JSONB,                     -- array di punti [{x,y}] per segmentazione
    ai_confidence     FLOAT,                     -- [0.0, 1.0]
    ai_description    TEXT,
    ai_raw_response   JSONB,                     -- risposta completa Claude per audit
    model_version_id  BIGINT NOT NULL REFERENCES model_version(id),
    created_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Revisione del dentista (ogni azione è un record separato)
CREATE TABLE doctor_review (
    id                    BIGSERIAL PRIMARY KEY,
    image_id              BIGINT NOT NULL REFERENCES radiographic_image(id),
    ai_finding_id         BIGINT REFERENCES ai_finding(id),  -- NULL se aggiunta dal medico
    doctor_id             BIGINT NOT NULL REFERENCES app_user(id),
    action                VARCHAR(20) NOT NULL,  -- CONFIRMED, REJECTED, MODIFIED, ADDED
    tooth_number          SMALLINT,
    finding_type          VARCHAR(50),
    bbox_x                FLOAT,
    bbox_y                FLOAT,
    bbox_w                FLOAT,
    bbox_h                FLOAT,
    mask_polygon          JSONB,
    clinical_notes        TEXT,
    certainty_level       SMALLINT CHECK (certainty_level BETWEEN 1 AND 5),  -- 1=dubbio, 5=certo
    is_training_approved  BOOLEAN NOT NULL DEFAULT FALSE,  -- il dentista approva per training
    reviewed_at           TIMESTAMP NOT NULL DEFAULT NOW(),
    model_version_id      BIGINT NOT NULL REFERENCES model_version(id)
);

-- Versione del modello (sia Claude prompt che detector)
CREATE TABLE model_version (
    id                BIGSERIAL PRIMARY KEY,
    model_name        VARCHAR(100) NOT NULL,  -- 'claude-sonnet-4-6', 'yolov8-dental-v3'
    version_tag       VARCHAR(50) NOT NULL,
    model_type        VARCHAR(20) NOT NULL,   -- REASONER, DETECTOR
    prompt_hash       VARCHAR(64),            -- sha256 del prompt per REASONER
    training_samples  INTEGER,
    performance_metrics JSONB,               -- precision, recall, F1 per finding_type
    deployed_at       TIMESTAMP,
    created_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sessione di revisione (aggrega più review per immagine)
CREATE TABLE review_session (
    id            BIGSERIAL PRIMARY KEY,
    image_id      BIGINT NOT NULL REFERENCES radiographic_image(id),
    doctor_id     BIGINT NOT NULL REFERENCES app_user(id),
    status        VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',  -- IN_PROGRESS, COMPLETED
    started_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at  TIMESTAMP
);

-- Indici critici per performance
CREATE INDEX idx_ai_finding_image ON ai_finding(image_id);
CREATE INDEX idx_doctor_review_image ON doctor_review(image_id);
CREATE INDEX idx_doctor_review_training ON doctor_review(is_training_approved, reviewed_at);
CREATE INDEX idx_review_session_doctor ON review_session(doctor_id, status);
```

---

## 3. Pipeline di Inferenza

### 3.1 Flusso step-by-step

```
[1] Upload OPG
    POST /api/radiographic-images
    → salva file (S3 / filesystem)
    → crea record radiographic_image
    → pubblica evento ASYNC: image.uploaded

[2] Analisi AI (asincrona, ~5-15s)
    Consumer: image.uploaded
    → [DETECTOR] se attivo: YOLOv8 → bbox per ogni dente/area
    → [REASONER] Claude API: analisi semantica su immagine completa
    → merge risultati
    → salva N record ai_finding
    → pubblica evento: analysis.completed

[3] Notifica al frontend
    WebSocket o polling GET /api/radiographic-images/{id}/findings
    → stato: PENDING | ANALYZING | READY | ERROR

[4] UI Revisione
    GET /api/radiographic-images/{id}/findings
    → mostra immagine con overlay findings
    → dentista interagisce (conferma/rifiuta/modifica/aggiunge)
    → ogni azione → POST /api/doctor-reviews

[5] Completamento sessione
    POST /api/review-sessions/{id}/complete
    → stato sessione → COMPLETED
    → opzionale: genera report PDF
```

### 3.2 Prompt Claude per OPG

```
SYSTEM:
Sei un sistema di supporto alla diagnosi radiologica dentale.
Analizza l'immagine OPG (Orthopantomogram) fornita.
Restituisci SOLO JSON valido, senza testo aggiuntivo.

Notazione FDI: quadranti 1-4, denti 1-8.
Quadrante 1: 11-18 (superiore destro)
Quadrante 2: 21-28 (superiore sinistro)
Quadrante 3: 31-38 (inferiore sinistro)
Quadrante 4: 41-48 (inferiore destro)

USER:
Analizza questa OPG. Per ogni finding individua:
- tooth_number: codice FDI (null se interessa zona generale)
- finding_type: uno tra CARIE, LESIONE_PERIAPICALE, PERDITA_OSSEA, CORONA, IMPIANTO, OTTURAZIONE, ALTRO
- location_zone: SUPERIORE_DESTRA | SUPERIORE_SINISTRA | INFERIORE_DESTRA | INFERIORE_SINISTRA | GLOBALE
- severity: LIEVE | MODERATA | SEVERA
- confidence: float 0.0-1.0
- description: max 150 caratteri, italiano clinico
- requires_attention: boolean

Restituisci:
{
  "findings": [...],
  "general_observations": "...",
  "bone_loss_assessment": "NORMALE|LIEVE|MODERATA|SEVERA",
  "image_quality": "BUONA|ACCETTABILE|SCARSA",
  "analysis_limitations": "..."
}

[FEW-SHOT EXAMPLES: iniettati dinamicamente dai casi validati]
[IMAGE: base64 OPG]
```

### 3.3 Gestione coordinate

Claude non restituisce pixel coordinates. Due strategie:

**MVP (solo Claude):**
- `location_zone` + `tooth_number` → UI mostra marker su dente della mappa dentale standard
- Dentista clicca sull'OPG per posizionare il box manualmente
- Il box salvato diventa ground truth per il training

**Produzione (con YOLO):**
- YOLO restituisce bbox normalizzati [x, y, w, h]
- Claude arricchisce con classificazione semantica
- Merge per finding_id condiviso

---

## 4. Pipeline di Training / Miglioramento

### 4.1 Due cicli distinti

```
CICLO A — Prompt Evolution (Claude, continuo)
┌─────────────────────────────────────────────────────┐
│ Ogni settimana / ogni 100 review completate:        │
│                                                     │
│ 1. Seleziona top-K casi validati con              │
│    is_training_approved = TRUE                      │
│    AND certainty_level >= 4                         │
│    (per finding_type e diversità)                   │
│                                                     │
│ 2. Costruisci few-shot examples:                    │
│    {image_description, expected_output_json}        │
│                                                     │
│ 3. Aggiorna prompt template                         │
│ 4. Test su validation set interno                   │
│ 5. Deploy nuovo prompt → nuova model_version        │
│    (model_type = REASONER)                          │
└─────────────────────────────────────────────────────┘

CICLO B — Retraining Detector (YOLO/SAM, periodico)
┌─────────────────────────────────────────────────────┐
│ Trigger: 500 nuove immagini validate                │
│         oppure mensile (il primo che arriva)        │
│                                                     │
│ 1. Estrai dataset: doctor_review WHERE              │
│    is_training_approved = TRUE                      │
│    AND action IN ('CONFIRMED', 'MODIFIED', 'ADDED') │
│    AND bbox_x IS NOT NULL                           │
│                                                     │
│ 2. Converti in formato YOLO:                        │
│    {image, label_file con bbox normalizzati}        │
│                                                     │
│ 3. Split: 80% train / 10% val / 10% test           │
│    (stratificato per finding_type)                  │
│                                                     │
│ 4. Fine-tuning YOLOv8 su base pretrainata          │
│                                                     │
│ 5. Valuta: precision, recall, mAP50 per classe     │
│    → deve superare soglie minime:                   │
│      - precision > 0.75                             │
│      - recall > 0.70                                │
│                                                     │
│ 6. Test su holdout set (mai usato in training)     │
│                                                     │
│ 7. Review manuale da clinico + tecnico             │
│    → approvazione esplicita prima di deploy        │
│                                                     │
│ 8. Deploy graduale (shadow mode → 10% → 100%)      │
│ 9. Salva model_version con metrics                 │
└─────────────────────────────────────────────────────┘
```

### 4.2 Quality Gate — Dati per Training

Non tutti i dati vanno in training. Filtro obbligatorio:

```sql
SELECT dr.*
FROM doctor_review dr
JOIN radiographic_image ri ON ri.id = dr.image_id
WHERE dr.is_training_approved = TRUE      -- medico ha approvato esplicitamente
  AND dr.certainty_level >= 4             -- medico era abbastanza sicuro
  AND dr.action != 'REJECTED'            -- i rejected NON vanno come positivi
                                          -- (ma possono essere usati come negativi)
  AND ri.image_quality != 'SCARSA'       -- immagini scarse fuori dal training
ORDER BY dr.reviewed_at DESC;
```

Casi `REJECTED` (falsi positivi AI) → esempi negativi hard per training detector.

### 4.3 Dataset Management

```
dataset/
├── raw/                  # immagini originali (immutabili)
│   └── {image_id}.jpg
├── annotations/          # generato da export script
│   ├── train/
│   │   ├── images/
│   │   └── labels/       # formato YOLO txt
│   ├── val/
│   └── test/
├── versions/
│   └── v{N}/
│       ├── dataset.yaml  # config YOLO
│       ├── stats.json    # distribuzione classi
│       └── split.csv     # quale immagine in quale split
└── holdout/              # MAI toccato durante training, solo test finale
    ├── images/
    └── labels/
```

---

## 5. API Backend — Endpoint da Implementare

```
# Immagini
POST   /api/radiographic-images                    # upload OPG
GET    /api/radiographic-images/{id}               # dettaglio + stato analisi
GET    /api/radiographic-images/{id}/findings      # findings AI + review status
GET    /api/patients/{patientId}/radiographic-images

# Findings AI
GET    /api/ai-findings/{id}                       # singolo finding

# Review del dentista
POST   /api/doctor-reviews                         # crea review (confirm/reject/modify/add)
PUT    /api/doctor-reviews/{id}                    # modifica review esistente
DELETE /api/doctor-reviews/{id}                    # rimuovi review

# Sessioni di revisione
POST   /api/review-sessions                        # apre sessione per immagine
GET    /api/review-sessions/{id}
POST   /api/review-sessions/{id}/complete          # chiude sessione

# Training
GET    /api/training/export                        # esporta dataset validato (admin)
GET    /api/training/stats                         # statistiche dataset
POST   /api/training/approve-batch                 # approvazione batch per training

# Versioni modello
GET    /api/model-versions                         # lista versioni
GET    /api/model-versions/active                  # versioni attive
```

---

## 6. Frontend Angular — Componenti Chiave

```
features/
└── radiographic-review/
    ├── radiographic-review.routes.ts
    ├── pages/
    │   ├── image-upload/           # upload OPG
    │   ├── review-workspace/       # canvas principale
    │   └── review-history/         # storico revisioni paziente
    ├── components/
    │   ├── opg-canvas/             # immagine con overlay interattivo
    │   │   ├── finding-overlay/    # box / marker per finding
    │   │   └── annotation-tool/    # disegno box manuale
    │   ├── finding-panel/          # lista findings laterale
    │   │   ├── finding-card/       # singolo finding con azioni
    │   │   └── add-finding-form/   # aggiungi finding manuale
    │   ├── review-toolbar/         # conferma tutto / rifiuta tutto / completa
    │   └── dental-chart/           # schema denti FDI per navigazione
    └── services/
        ├── radiographic-image.service.ts
        ├── ai-finding.service.ts
        ├── doctor-review.service.ts
        └── review-session.service.ts
```

### 6.1 Stato della review workspace

```typescript
interface ReviewWorkspaceState {
  image: RadiographicImageDto;
  findings: AiFindingWithReviewDto[];  // finding AI + review corrente
  session: ReviewSessionDto;
  selectedFindingId: number | null;
  mode: 'VIEW' | 'ANNOTATE' | 'EDIT_BOX';
  pendingReviews: DoctorReviewDto[];   // non ancora salvati
}

interface AiFindingWithReviewDto {
  aiFinding: AiFindingDto;
  review: DoctorReviewDto | null;      // null = non ancora revisionato
  status: 'PENDING' | 'CONFIRMED' | 'REJECTED' | 'MODIFIED';
}
```

---

## 7. Limitazioni e Rischi

### 7.1 Limitazioni Claude

| Limitazione | Impatto | Mitigazione |
|---|---|---|
| No pixel bbox | Bassa precisione localizzazione MVP | Affianca YOLO in fase 2 |
| No retraining | Miglioramento solo via prompt | Prompt evolution strutturato |
| Latenza ~5-15s | UX non real-time | Analisi asincrona + notifica |
| Costo per immagine | Scala con volume | Cache su immagini già analizzate |
| Variabilità output | JSON malformato possibile | Schema validation + retry |

### 7.2 Rischi clinici

- **MAI deploy automatico** in produzione senza validazione clinica
- Ogni finding AI deve essere esplicitamente validato dal dentista
- Il sistema è **supporto alla decisione**, non diagnosi autonoma
- Documentare chiaramente nel UI: "Analisi AI — Richiede validazione medica"
- Per uso come dispositivo medico: percorso CE/FDA separato

### 7.3 Rischi tecnici

- Qualità immagine OPG molto variabile → pre-processing obbligatorio
- Dataset class imbalance (carie >> lesioni periapicali rare)
- Overfitting su un singolo dentista se dataset piccolo
- Deriva del modello nel tempo senza monitoraggio

---

## 8. Roadmap implementativa

### Fase 1 — MVP Claude-only (8 settimane)

- [ ] Schema DB + migrazioni Flyway
- [ ] Upload OPG + storage
- [ ] Integrazione Claude API (inferenza asincrona)
- [ ] API review dentista (CRUD completo)
- [ ] UI: canvas OPG + overlay findings + pannello review
- [ ] Dental chart FDI per navigazione
- [ ] Export dataset validato

### Fase 2 — Detector (6 settimane)

- [ ] Integrazione YOLOv8 per bbox
- [ ] Merge output YOLO + Claude
- [ ] Annotation tool nel canvas (draw bbox manuale)
- [ ] Pipeline training automatizzata
- [ ] Metriche e dashboard performance modello

### Fase 3 — Production Hardening (4 settimane)

- [ ] Shadow mode per nuove versioni modello
- [ ] A/B testing tra versioni
- [ ] Monitoring drift
- [ ] Report PDF per paziente
- [ ] Audit trail completo

---

## 9. Stack Tecnologico

| Layer | Tecnologia |
|---|---|
| Frontend | Angular + Fabric.js (canvas) |
| Backend | Spring Boot 3 |
| AI Reasoner | Claude API (claude-sonnet-4-6) |
| AI Detector | YOLOv8 (Ultralytics) — Python microservice |
| Comunicazione AI | REST interno → Python FastAPI |
| Storage immagini | MinIO / S3 |
| DB | PostgreSQL |
| Async | Spring Events / RabbitMQ |
| Training pipeline | Python + PyTorch + Ultralytics |

---

## 10. Primo Step Concreto

Prima di scrivere codice:

1. **Raccogliere 50-100 OPG anonimizzate** per test prompt Claude
2. **Calibrare il prompt** con un dentista su casi reali
3. **Definire le classi esatte** (finding_type) con il clinico
4. **Decidere MVP scope**: solo Claude o subito YOLO?
5. **Scegliere storage immagini** (GDPR, anonimizzazione, backup)

Il punto 1 è il collo di bottiglia reale. Senza dati, niente training.
