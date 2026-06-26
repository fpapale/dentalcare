# Spec: Tab Documenti Paziente (#4) — MinIO Storage

**Data:** 2026-06-26
**Proposta originale:** directives/proposte-modifiche.md §4
**Stato:** Approvato per implementazione

---

## Decisioni chiave

| Decisione | Scelta | Motivo |
|-----------|--------|--------|
| Storage file | MinIO (già deployed su 192.168.0.72) | Scalabile, nessuna migrazione futura |
| Proxy vs presigned URL | Proxy Spring | MinIO non esposto al browser, JWT su ogni richiesta |
| Upload format | multipart/form-data | Nessun overhead base64 (+33%), standard HTTP |
| DB migration | Nessuna | `patient_documents` e enum `document_type` già esistenti |

---

## Architettura

```
Angular (upload)
  → POST multipart → Spring PatientDocumentController
      → PatientDocumentService
          → MinioStorageService (upload bytes)
          → JdbcTemplate (insert metadata, file_path = object key)

Angular (preview/download)
  → GET /content → Spring PatientDocumentController
      → PatientDocumentService
          → MinioStorageService (download bytes)
          → StreamingResponseBody → browser
```

---

## Database

La tabella `patient_documents` esiste già in `dentalcare` schema. **Nessuna migration.**

Colonne rilevanti:
- `file_path text NOT NULL` — riutilizzata come MinIO **object key**
  - Pattern: `{tenantSchema}/patients/{patientId}/{docId}/{fileName}`
  - Esempio: `t_9d754153/patients/abc-123/doc-456/rx_panoramica.jpg`
- `document_type` — enum esistente: `rx_endorale`, `rx_panoramica`, `cbct`, `foto_clinica`, `foto_extraorale`, `documento_amministrativo`, `consenso_informato`, `referto`, `altro`
- `mime_type`, `file_size_bytes`, `title`, `notes`, `taken_at` — già presenti
- `uploaded_by_provider_id` — populato dal context autenticato
- `appointment_id` — opzionale, non richiesto per MVP

---

## Backend Spring Boot

### Configurazione

Due file di config (entrambi gitignored in `backend/config/`):

**`backend/config/application.properties`** (dev — accesso via SSH tunnel locale):
```properties
# MinIO — tunnel: ssh -L 9000:127.0.0.1:9000 fpapale@192.168.0.72
app.minio.endpoint=http://127.0.0.1:9000
app.minio.access-key=<segreto>
app.minio.secret-key=<segreto>
app.minio.bucket=dentalcare-docs
```

**`backend/config/application-prod.properties`** (prod — backend Docker container → MinIO sul host):
```properties
# MinIO — backend container accede al host via host.docker.internal
# Richiede extra_hosts in docker-compose.yml (vedi sotto)
app.minio.endpoint=http://host.docker.internal:9000
app.minio.access-key=<segreto>
app.minio.secret-key=<segreto>
app.minio.bucket=dentalcare-docs
```

**`docker-compose.yml`** — aggiungere `extra_hosts` al service `backend`:
```yaml
backend:
  # ... (configurazione esistente)
  extra_hosts:
    - "host.docker.internal:host-gateway"
```

> **Perché host.docker.internal:** MinIO bind su `127.0.0.1:9000` del host (non esposto all'esterno).
> Il container backend (rete bridge) non vede `127.0.0.1` dell'host — serve `host-gateway` come IP del bridge Docker verso il host.

`pom.xml` — aggiungere dipendenza:
```xml
<dependency>
    <groupId>software.amazon.awssdk</groupId>
    <artifactId>s3</artifactId>
    <version>2.25.70</version>
</dependency>
```

### Nuovi file

| File | Package |
|------|---------|
| `MinioStorageService` | `service` |
| `PatientDocumentService` | `service` |
| `PatientDocumentController` | `controller` |
| `PatientDocumentSummaryDto` | `dto` |
| `PatientDocumentDto` | `dto` |
| `UpdatePatientDocumentRequest` | `dto` |

**Nessuna entity JPA** — accesso diretto via `JdbcTemplate` (pattern già usato nel progetto).

### Endpoints REST

```
GET    /api/patients/{patientId}/documents              → lista metadati (no file)
POST   /api/patients/{patientId}/documents              → upload (multipart/form-data)
GET    /api/patients/{patientId}/documents/{docId}      → metadati singolo documento
GET    /api/patients/{patientId}/documents/{docId}/content → stream file (proxy MinIO)
PUT    /api/patients/{patientId}/documents/{docId}      → aggiorna title/notes/takenAt/documentType
DELETE /api/patients/{patientId}/documents/{docId}      → elimina DB + oggetto MinIO
```

### MinioStorageService

```java
@Service
public class MinioStorageService {
    // upload(String objectKey, byte[] data, String mimeType) → void
    // download(String objectKey) → byte[]
    // delete(String objectKey) → void
    // S3Client configurato via @Value app.minio.*
}
```

### PatientDocumentController (multipart upload)

```java
@PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
@ResponseStatus(HttpStatus.CREATED)
public PatientDocumentSummaryDto upload(
    @PathVariable UUID patientId,
    @RequestParam("file") MultipartFile file,
    @RequestParam("title") String title,
    @RequestParam("documentType") String documentType,
    @RequestParam(value = "notes", required = false) String notes,
    @RequestParam(value = "takenAt", required = false) LocalDate takenAt
)
```

Limite upload: 50MB (configura `spring.servlet.multipart.max-file-size=50MB`).

### DTO

```java
// Lista (no contenuto file)
record PatientDocumentSummaryDto(
    UUID id, String documentType, String title,
    String fileName, String mimeType, Long fileSizeBytes,
    String notes, LocalDate takenAt, LocalDateTime createdAt
) {}

// Metadati singolo (stessi campi di Summary — usato per conferma post-update)
record PatientDocumentDto(
    UUID id, String documentType, String title,
    String fileName, String mimeType, Long fileSizeBytes,
    String notes, LocalDate takenAt, LocalDateTime createdAt
) {}

// Aggiornamento metadati
record UpdatePatientDocumentRequest(
    @NotBlank String title,
    String documentType,
    String notes,
    LocalDate takenAt
) {}
```

### Sicurezza

- Tutti gli endpoint sotto `/api/patients/{patientId}/documents` richiedono JWT (già protetti dalla configurazione Spring Security esistente)
- `clinic_id` derivato da `TenantContext` (non dal client)
- Verifica `patient_id + clinic_id` prima di ogni operazione per isolamento tenant
- Object key include lo schema tenant → impossibile accedere a file di altri tenant anche con object key noto

---

## Frontend Angular

### Nuovi file

| File | Path |
|------|------|
| `documenti-tab.component.ts` | `features/pazienti/documenti-tab/` |
| `documenti-tab.component.html` | `features/pazienti/documenti-tab/` |
| `patient-document.model.ts` | `core/models/` |
| `patient-document.service.ts` | `core/services/` |

### Enum document_type (valori DB reali)

Usare i valori enum presenti nel DB, non i nomi della proposta originale:

| DB enum | Label UI |
|---------|----------|
| `rx_panoramica` | Ortopanoramica ⭐ |
| `rx_endorale` | RX Endorale |
| `cbct` | TAC / CBCT |
| `foto_clinica` | Foto clinica |
| `foto_extraorale` | Foto extraorale |
| `consenso_informato` | Consenso informato |
| `referto` | Referto / Lettera |
| `documento_amministrativo` | Documento amministrativo |
| `altro` | Altro |

### Model

```typescript
export interface PatientDocumentSummary {
  id: string;
  documentType: string;
  title: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number | null;
  notes: string | null;
  takenAt: string | null;  // ISO date
  createdAt: string;
}

export interface UpdatePatientDocumentRequest {
  title: string;
  documentType: string;
  notes?: string;
  takenAt?: string;
}
```

### Service

```typescript
@Injectable({ providedIn: 'root' })
export class PatientDocumentService {
  findAll(patientId: string): Observable<PatientDocumentSummary[]>
  upload(patientId: string, formData: FormData): Observable<PatientDocumentSummary>
  update(patientId: string, docId: string, req: UpdatePatientDocumentRequest): Observable<PatientDocumentSummary>
  delete(patientId: string, docId: string): Observable<void>
  getContentUrl(patientId: string, docId: string): string  // costruisce URL lato client: env.apiBaseUrl/patients/{id}/documents/{docId}/content
}
```

### UX Documenti Tab

**Grid card** (2-3 colonne su desktop, 1 su mobile):
- Icona per tipo documento (RX → radiology icon, PDF → picture_as_pdf, foto → photo_camera)
- Titolo + data esame (o data upload) + dimensione file
- Per immagini JPEG/PNG/WebP: thumbnail via `<img [src]="contentUrl">`
- Per PDF: icona `picture_as_pdf`

**Azioni su card:**
- Click → modal preview (immagine full-size o PDF in `<iframe>`)
- Download → `<a [href]="contentUrl" [download]="doc.fileName" target="_blank">`
- Modifica metadati → form inline (no re-upload)
- Elimina → confirm dialog

**Upload:**
- Bottone "+ Aggiungi documento"
- Dialog con: file input (`accept="image/*,application/pdf"`) + campi title, documentType, notes, takenAt
- Limite 50MB lato frontend (validazione prima di inviare)
- Progress state durante upload

**Integrazione `paziente-detail.component.html`:**
Aggiungere branch nel `@else`:
```html
} @else if (activeTab() === 'documenti') {
  @if (paziente) {
    <app-documenti-tab [patientId]="paziente.id" />
  }
}
```

---

## File coinvolti (riepilogo)

| Layer | File | Azione |
|-------|------|--------|
| Infrastruttura | `backend/config/application.properties` | Aggiunta config MinIO |
| Backend | `pom.xml` | Aggiunta dipendenza AWS SDK S3 |
| Backend | `MinioStorageService.java` | Nuovo |
| Backend | `PatientDocumentService.java` | Nuovo |
| Backend | `PatientDocumentController.java` | Nuovo |
| Backend | `PatientDocumentSummaryDto.java` | Nuovo |
| Backend | `PatientDocumentDto.java` | Nuovo |
| Backend | `UpdatePatientDocumentRequest.java` | Nuovo |
| Frontend | `patient-document.model.ts` | Nuovo |
| Frontend | `patient-document.service.ts` | Nuovo |
| Frontend | `documenti-tab.component.ts/.html` | Nuovo |
| Frontend | `paziente-detail.component.html` | Modifica: aggiunta branch documenti |
| Frontend | `paziente-detail.component.ts` | Modifica: import nuovo component |

---

## GDPR — hook cifratura (proposta #7, futura)

Il `MinioStorageService` è il punto di iniezione naturale per la cifratura AES-256-GCM prevista dalla proposta #7:

```java
// Upload: plaintext → encrypt → MinIO
public String upload(String objectKey, byte[] data, String mimeType) {
    byte[] payload = encryptionService.encrypt(data);  // <-- hook futuro
    // PUT object su MinIO con payload cifrato
}

// Download: MinIO → decrypt → plaintext
public byte[] download(String objectKey) {
    byte[] payload = s3Client.getObject(...);
    return encryptionService.decrypt(payload);          // <-- hook futuro
}
```

**Preparazione in questa iterazione:**
- `MinioStorageService` riceve `EncryptionService` via constructor injection (inizialmente no-op)
- Quando #7 sarà implementata, basta sostituire `EncryptionService` con la versione HKDF+AES — zero modifiche a `PatientDocumentService` o ai controller

**Non fare:**
- Non applicare cifratura ora (nessuna chiave di tenant disponibile)
- Non passare bytes raw direttamente senza passare per il service

---

## Out of scope (questa iterazione)

- Retraining AI (#6 — già Fatta ma richiede MinIO integrato, da collegare dopo)
- Signed URL / accesso diretto browser a MinIO
- Migrazione da filesystem a MinIO (nessun dato esistente da migrare)
- Viewer DICOM in-browser
- Paginazione lista documenti (non necessaria per MVP)
