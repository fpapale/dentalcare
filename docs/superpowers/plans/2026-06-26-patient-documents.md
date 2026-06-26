# Patient Documents Tab — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementare la tab "Documenti" nella scheda paziente con upload/preview/download/delete di file medici (RX, PDF, foto) su MinIO.

**Architecture:** Spring Boot proxia tutto il traffico file verso MinIO (nessuna URL MinIO esposta al browser). Upload via `multipart/form-data`. Preview/download via `GET /content` con risposta `byte[]`. Layer cifratura injectable (no-op ora, HKDF+AES per proposta #7).

**Tech Stack:** Spring Boot 3.5, Java 25, AWS SDK S3 v2 (compatibile MinIO), NamedParameterJdbcTemplate, Angular 17+ signals, Tailwind CSS.

## Global Constraints

- Tenant schema via `TenantContext.validatedSchema()` — mai hardcodare schema name
- `clinic_id` via `TenantContext.getCurrentTenant()` — mai fidarsi del client
- `uploaded_by_provider_id` via `SecurityContextHolder.getContext().getAuthentication().getName()`
- Enum DB reale: `dentalcare.document_type` — valori: `rx_panoramica`, `rx_endorale`, `cbct`, `foto_clinica`, `foto_extraorale`, `consenso_informato`, `referto`, `documento_amministrativo`, `altro`
- Cast SQL obbligatorio: `:value::dentalcare.document_type`
- Nessuna entity JPA — solo `NamedParameterJdbcTemplate` (pattern del progetto)
- Tailwind inline, nessun file CSS componente separato
- File non creati: `file_base64` non esiste — `file_path` è l'object key MinIO
- Limite upload: 50MB
- MinIO dev: `http://127.0.0.1:9000` (via SSH tunnel); prod: `http://host.docker.internal:9000`
- Credenziali MinIO: solo in `backend/config/` (gitignored) — mai in `src/main/resources/`

---

## File Map

### Backend — nuovi file

| File | Scopo |
|------|-------|
| `service/DocumentEncryptionService.java` | Interfaccia hook cifratura GDPR futura |
| `service/NoOpDocumentEncryptionService.java` | Implementazione no-op (default) |
| `service/MinioStorageService.java` | Client S3/MinIO: upload, download, delete |
| `service/PatientDocumentService.java` | Logica CRUD documenti + orchestrazione MinIO |
| `controller/PatientDocumentController.java` | REST endpoints `/api/patients/{id}/documents` |
| `dto/PatientDocumentSummaryDto.java` | DTO risposta lista (no contenuto file) |
| `dto/UpdatePatientDocumentRequest.java` | DTO aggiornamento metadati |

### Backend — file modificati

| File | Modifica |
|------|----------|
| `backend/pom.xml` | Aggiunta dipendenza AWS SDK S3 v2 |
| `backend/src/main/resources/application.properties` | Limiti multipart upload |
| `backend/config/application.properties` | Config MinIO dev (gitignored) |
| `backend/config/application-prod.properties` | Config MinIO prod (gitignored) |
| `docker-compose.yml` | `extra_hosts` al service `backend` |

### Frontend — nuovi file

| File | Scopo |
|------|-------|
| `core/models/patient-document.model.ts` | Interfacce TS + enum labels |
| `core/services/patient-document.service.ts` | HTTP client documenti |
| `features/pazienti/documenti-tab/documenti-tab.component.ts` | Logica tab documenti |
| `features/pazienti/documenti-tab/documenti-tab.component.html` | Template tab |

### Frontend — file modificati

| File | Modifica |
|------|----------|
| `features/pazienti/paziente-detail/paziente-detail.component.ts` | Import + aggiungi branch `documenti` |
| `features/pazienti/paziente-detail/paziente-detail.component.html` | Branch `@else if (activeTab() === 'documenti')` |

---

## Task 1: Backend — dipendenze, config, docker-compose

**Files:**
- Modify: `backend/pom.xml`
- Modify: `backend/src/main/resources/application.properties`
- Modify: `backend/config/application.properties` (gitignored)
- Modify: `backend/config/application-prod.properties` (gitignored)
- Modify: `docker-compose.yml`

**Interfaces:**
- Produces: proprietà `app.minio.*` disponibili via `@Value`; upload accetta file fino a 50MB

- [ ] **Step 1: Aggiungere dipendenza AWS SDK S3 a pom.xml**

  Aprire `backend/pom.xml`. Prima del tag `</dependencies>` inserire:

  ```xml
  <!-- AWS SDK S3 v2 — compatibile con MinIO -->
  <dependency>
      <groupId>software.amazon.awssdk</groupId>
      <artifactId>s3</artifactId>
      <version>2.25.70</version>
  </dependency>
  ```

  Nota: `software.amazon.awssdk:s3:2.25.70` non è gestita da Spring BOM — la versione va dichiarata esplicitamente.

- [ ] **Step 2: Aggiungere limiti multipart a `src/main/resources/application.properties`**

  Aggiungere in fondo al file:

  ```properties
  # Upload documenti paziente
  spring.servlet.multipart.max-file-size=50MB
  spring.servlet.multipart.max-request-size=52MB
  ```

- [ ] **Step 3: Aggiungere config MinIO dev a `backend/config/application.properties`**

  Aggiungere in fondo:

  ```properties
  # MinIO — accesso via SSH tunnel: ssh -L 9000:127.0.0.1:9000 fpapale@192.168.0.72
  app.minio.endpoint=http://127.0.0.1:9000
  app.minio.access-key=fpapale
  app.minio.secret-key=ViaGoceano2021
  app.minio.bucket=dentalcare-docs
  ```

- [ ] **Step 4: Aggiungere config MinIO prod a `backend/config/application-prod.properties`**

  Aggiungere in fondo:

  ```properties
  # MinIO — backend Docker → MinIO sul host via host-gateway
  app.minio.endpoint=http://host.docker.internal:9000
  app.minio.access-key=fpapale
  app.minio.secret-key=ViaGoceano2021
  app.minio.bucket=dentalcare-docs
  ```

- [ ] **Step 5: Aggiungere extra_hosts a docker-compose.yml**

  Nel service `backend`, aggiungere `extra_hosts` dopo `environment:`:

  ```yaml
  backend:
    # ... configurazione esistente
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - SPRING_CONFIG_ADDITIONAL_LOCATION=optional:file:/app/config/
    extra_hosts:
      - "host.docker.internal:host-gateway"
  ```

  Questo permette al container backend di raggiungere `127.0.0.1` del host dove gira MinIO.

- [ ] **Step 6: Verificare che Maven risolva la dipendenza**

  ```bash
  cd backend
  ./mvnw dependency:resolve -Dinclude=software.amazon.awssdk:s3
  ```

  Atteso: `BUILD SUCCESS` con `software.amazon.awssdk:s3:2.25.70`

- [ ] **Step 7: Commit**

  ```bash
  git add backend/pom.xml backend/src/main/resources/application.properties docker-compose.yml
  git commit -m "feat(docs): aggiungi dipendenza AWS SDK S3 e config MinIO"
  ```

  Nota: `backend/config/` è gitignored, non va committato.

---

## Task 2: Backend — DocumentEncryptionService + MinioStorageService

**Files:**
- Create: `backend/src/main/java/com/dentalcare/service/DocumentEncryptionService.java`
- Create: `backend/src/main/java/com/dentalcare/service/NoOpDocumentEncryptionService.java`
- Create: `backend/src/main/java/com/dentalcare/service/MinioStorageService.java`

**Interfaces:**
- Produces:
  - `MinioStorageService.upload(String objectKey, byte[] data, String mimeType): void`
  - `MinioStorageService.download(String objectKey): byte[]`
  - `MinioStorageService.delete(String objectKey): void`
- Consumes: `app.minio.endpoint`, `app.minio.access-key`, `app.minio.secret-key`, `app.minio.bucket` via `@Value`

- [ ] **Step 1: Creare DocumentEncryptionService.java**

  ```java
  package com.dentalcare.service;

  public interface DocumentEncryptionService {
      byte[] encrypt(byte[] data);
      byte[] decrypt(byte[] data);
  }
  ```

- [ ] **Step 2: Creare NoOpDocumentEncryptionService.java**

  ```java
  package com.dentalcare.service;

  import org.springframework.stereotype.Service;

  @Service
  public class NoOpDocumentEncryptionService implements DocumentEncryptionService {

      @Override
      public byte[] encrypt(byte[] data) { return data; }

      @Override
      public byte[] decrypt(byte[] data) { return data; }
  }
  ```

- [ ] **Step 3: Creare MinioStorageService.java**

  ```java
  package com.dentalcare.service;

  import jakarta.annotation.PostConstruct;
  import org.slf4j.Logger;
  import org.slf4j.LoggerFactory;
  import org.springframework.beans.factory.annotation.Value;
  import org.springframework.stereotype.Service;
  import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
  import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
  import software.amazon.awssdk.core.sync.RequestBody;
  import software.amazon.awssdk.regions.Region;
  import software.amazon.awssdk.services.s3.S3Client;
  import software.amazon.awssdk.services.s3.model.*;

  import java.io.IOException;
  import java.net.URI;

  @Service
  public class MinioStorageService {

      private static final Logger log = LoggerFactory.getLogger(MinioStorageService.class);

      @Value("${app.minio.endpoint}")
      private String endpoint;

      @Value("${app.minio.access-key}")
      private String accessKey;

      @Value("${app.minio.secret-key}")
      private String secretKey;

      @Value("${app.minio.bucket}")
      private String bucket;

      private final DocumentEncryptionService encryption;
      private S3Client s3;

      public MinioStorageService(DocumentEncryptionService encryption) {
          this.encryption = encryption;
      }

      @PostConstruct
      void init() {
          s3 = S3Client.builder()
                  .endpointOverride(URI.create(endpoint))
                  .credentialsProvider(StaticCredentialsProvider.create(
                          AwsBasicCredentials.create(accessKey, secretKey)))
                  .region(Region.US_EAST_1)   // MinIO ignora la region ma richiede un valore
                  .forcePathStyle(true)        // obbligatorio per MinIO (non AWS)
                  .build();

          ensureBucketExists();
          log.info("MinIO storage initialized: endpoint={}, bucket={}", endpoint, bucket);
      }

      public void upload(String objectKey, byte[] data, String mimeType) {
          byte[] payload = encryption.encrypt(data);
          s3.putObject(
                  PutObjectRequest.builder()
                          .bucket(bucket)
                          .key(objectKey)
                          .contentType(mimeType)
                          .contentLength((long) payload.length)
                          .build(),
                  RequestBody.fromBytes(payload));
          log.debug("Uploaded object: key={}, size={}", objectKey, payload.length);
      }

      public byte[] download(String objectKey) {
          try (var response = s3.getObject(
                  GetObjectRequest.builder().bucket(bucket).key(objectKey).build())) {
              return encryption.decrypt(response.readAllBytes());
          } catch (IOException e) {
              throw new RuntimeException("Failed to read object: " + objectKey, e);
          }
      }

      public void delete(String objectKey) {
          s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(objectKey).build());
          log.debug("Deleted object: key={}", objectKey);
      }

      private void ensureBucketExists() {
          try {
              s3.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
          } catch (NoSuchBucketException e) {
              s3.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
              log.info("Created MinIO bucket: {}", bucket);
          }
      }
  }
  ```

- [ ] **Step 4: Verificare che il progetto compili**

  ```bash
  cd backend
  ./mvnw compile -q
  ```

  Atteso: `BUILD SUCCESS` senza errori. Se la build fallisce perché MinIO non è raggiungibile, è normale — `@PostConstruct` gira solo a runtime, non in compilazione.

- [ ] **Step 5: Commit**

  ```bash
  git add backend/src/main/java/com/dentalcare/service/DocumentEncryptionService.java \
          backend/src/main/java/com/dentalcare/service/NoOpDocumentEncryptionService.java \
          backend/src/main/java/com/dentalcare/service/MinioStorageService.java
  git commit -m "feat(docs): aggiungi MinioStorageService con hook cifratura no-op"
  ```

---

## Task 3: Backend — DTOs + PatientDocumentService

**Files:**
- Create: `backend/src/main/java/com/dentalcare/dto/PatientDocumentSummaryDto.java`
- Create: `backend/src/main/java/com/dentalcare/dto/UpdatePatientDocumentRequest.java`
- Create: `backend/src/main/java/com/dentalcare/service/PatientDocumentService.java`
- Test: `backend/src/test/java/com/dentalcare/service/PatientDocumentServiceTest.java`

**Interfaces:**
- Consumes: `MinioStorageService.upload/download/delete`, `TenantContext.validatedSchema()`, `TenantContext.getCurrentTenant()`
- Produces:
  - `PatientDocumentService.findAll(UUID patientId): List<PatientDocumentSummaryDto>`
  - `PatientDocumentService.upload(UUID, MultipartFile, String, String, String, LocalDate): PatientDocumentSummaryDto`
  - `PatientDocumentService.findById(UUID patientId, UUID docId): PatientDocumentSummaryDto`
  - `PatientDocumentService.downloadContent(UUID patientId, UUID docId): byte[]`
  - `PatientDocumentService.updateMetadata(UUID, UUID, UpdatePatientDocumentRequest): PatientDocumentSummaryDto`
  - `PatientDocumentService.delete(UUID patientId, UUID docId): void`

- [ ] **Step 1: Creare PatientDocumentSummaryDto.java**

  ```java
  package com.dentalcare.dto;

  import java.time.LocalDate;
  import java.time.LocalDateTime;
  import java.util.UUID;

  public record PatientDocumentSummaryDto(
          UUID id,
          String documentType,
          String title,
          String fileName,
          String mimeType,
          Long fileSizeBytes,
          String notes,
          LocalDate takenAt,
          LocalDateTime createdAt
  ) {}
  ```

- [ ] **Step 2: Creare UpdatePatientDocumentRequest.java**

  ```java
  package com.dentalcare.dto;

  import jakarta.validation.constraints.NotBlank;
  import java.time.LocalDate;

  public record UpdatePatientDocumentRequest(
          @NotBlank String title,
          String documentType,
          String notes,
          LocalDate takenAt
  ) {}
  ```

- [ ] **Step 3: Scrivere il test (TDD — prima il test)**

  Creare `backend/src/test/java/com/dentalcare/service/PatientDocumentServiceTest.java`:

  ```java
  package com.dentalcare.service;

  import com.dentalcare.dto.PatientDocumentSummaryDto;
  import com.dentalcare.dto.UpdatePatientDocumentRequest;
  import com.dentalcare.exception.ResourceNotFoundException;
  import com.dentalcare.security.TenantContext;
  import org.junit.jupiter.api.AfterEach;
  import org.junit.jupiter.api.BeforeEach;
  import org.junit.jupiter.api.Test;
  import org.junit.jupiter.api.extension.ExtendWith;
  import org.mockito.InjectMocks;
  import org.mockito.Mock;
  import org.mockito.junit.jupiter.MockitoExtension;
  import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
  import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
  import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
  import org.springframework.security.core.context.SecurityContextHolder;

  import java.time.LocalDateTime;
  import java.util.List;
  import java.util.Map;
  import java.util.UUID;

  import static org.assertj.core.api.Assertions.assertThat;
  import static org.assertj.core.api.Assertions.assertThatThrownBy;
  import static org.mockito.ArgumentMatchers.*;
  import static org.mockito.Mockito.*;

  @ExtendWith(MockitoExtension.class)
  class PatientDocumentServiceTest {

      @Mock
      NamedParameterJdbcTemplate jdbc;

      @Mock
      MinioStorageService minio;

      @InjectMocks
      PatientDocumentService service;

      private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
      private final UUID patientId = UUID.fromString("00000000-0000-0000-0000-000000000002");
      private final UUID docId = UUID.fromString("00000000-0000-0000-0000-000000000003");
      private final UUID providerId = UUID.fromString("00000000-0000-0000-0000-000000000004");

      @BeforeEach
      void setupContext() {
          TenantContext.setCurrentSchema("t_abcd1234");
          TenantContext.setCurrentClinicId(clinicId.toString());
          SecurityContextHolder.getContext().setAuthentication(
                  new UsernamePasswordAuthenticationToken(providerId.toString(), null, List.of()));
      }

      @AfterEach
      void clearContext() {
          TenantContext.clear();
          SecurityContextHolder.clearContext();
      }

      @Test
      void findAll_returnsListFromDb() {
          java.sql.Timestamp now = java.sql.Timestamp.valueOf(LocalDateTime.now());
          Map<String, Object> row = Map.of(
                  "id", docId, "document_type", "rx_panoramica", "title", "RX 2026",
                  "file_name", "rx.jpg", "mime_type", "image/jpeg",
                  "file_size_bytes", 1024L, "created_at", now);

          when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                  .thenReturn(List.of(row));

          List<PatientDocumentSummaryDto> result = service.findAll(patientId);

          assertThat(result).hasSize(1);
          assertThat(result.getFirst().documentType()).isEqualTo("rx_panoramica");
          assertThat(result.getFirst().title()).isEqualTo("RX 2026");
      }

      @Test
      void findById_throwsWhenNotFound() {
          when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                  .thenReturn(List.of());

          assertThatThrownBy(() -> service.findById(patientId, docId))
                  .isInstanceOf(ResourceNotFoundException.class)
                  .hasMessageContaining(docId.toString());
      }

      @Test
      void updateMetadata_throwsWhenNotFound() {
          when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(0);

          assertThatThrownBy(() -> service.updateMetadata(patientId, docId,
                  new UpdatePatientDocumentRequest("Titolo", "altro", null, null)))
                  .isInstanceOf(ResourceNotFoundException.class);
      }

      @Test
      void delete_callsMinioDeleteAfterDbDelete() {
          String objectKey = "t_abcd1234/patients/" + patientId + "/" + docId + "/file.jpg";
          when(jdbc.queryForList(anyString(), any(MapSqlParameterSource.class)))
                  .thenReturn(List.of(Map.of("file_path", objectKey)));
          when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(1);

          service.delete(patientId, docId);

          verify(jdbc).update(anyString(), any(MapSqlParameterSource.class));
          verify(minio).delete(objectKey);
      }
  }
  ```

- [ ] **Step 4: Eseguire il test — atteso FAIL (PatientDocumentService non esiste)**

  ```bash
  cd backend
  ./mvnw test -pl . -Dtest=PatientDocumentServiceTest -q 2>&1 | tail -20
  ```

  Atteso: errore di compilazione `PatientDocumentService not found`.

- [ ] **Step 5: Creare PatientDocumentService.java**

  ```java
  package com.dentalcare.service;

  import com.dentalcare.dto.PatientDocumentSummaryDto;
  import com.dentalcare.dto.UpdatePatientDocumentRequest;
  import com.dentalcare.exception.ResourceNotFoundException;
  import com.dentalcare.security.TenantContext;
  import org.slf4j.Logger;
  import org.slf4j.LoggerFactory;
  import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
  import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
  import org.springframework.security.core.context.SecurityContextHolder;
  import org.springframework.stereotype.Service;
  import org.springframework.transaction.annotation.Transactional;
  import org.springframework.web.multipart.MultipartFile;

  import java.io.IOException;
  import java.sql.Timestamp;
  import java.time.LocalDate;
  import java.util.List;
  import java.util.Map;
  import java.util.UUID;

  @Service
  public class PatientDocumentService {

      private static final Logger log = LoggerFactory.getLogger(PatientDocumentService.class);

      private final NamedParameterJdbcTemplate jdbc;
      private final MinioStorageService minio;

      public PatientDocumentService(NamedParameterJdbcTemplate jdbc, MinioStorageService minio) {
          this.jdbc = jdbc;
          this.minio = minio;
      }

      private String s() { return TenantContext.validatedSchema(); }
      private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }
      private UUID currentProviderId() {
          return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName());
      }

      @Transactional(readOnly = true)
      public List<PatientDocumentSummaryDto> findAll(UUID patientId) {
          String sql = """
              SELECT id, document_type, title, file_name, mime_type, file_size_bytes, notes, taken_at, created_at
              FROM %s.patient_documents
              WHERE patient_id = :patientId AND clinic_id = :clinicId
              ORDER BY taken_at DESC NULLS LAST, created_at DESC
              """.formatted(s());
          List<Map<String, Object>> rows = jdbc.queryForList(sql,
                  new MapSqlParameterSource()
                          .addValue("patientId", patientId)
                          .addValue("clinicId", clinicId()));
          return rows.stream().map(this::mapSummary).toList();
      }

      @Transactional
      public PatientDocumentSummaryDto upload(UUID patientId, MultipartFile file,
                                              String title, String documentType,
                                              String notes, LocalDate takenAt) {
          UUID clinic = clinicId();
          UUID docId = UUID.randomUUID();
          String safeFileName = sanitizeFileName(file.getOriginalFilename());
          String objectKey = buildObjectKey(patientId, docId, safeFileName);
          String mimeType = file.getContentType() != null ? file.getContentType() : "application/octet-stream";

          try {
              minio.upload(objectKey, file.getBytes(), mimeType);
          } catch (IOException e) {
              throw new RuntimeException("Upload failed for patient " + patientId, e);
          }

          String sql = """
              INSERT INTO %s.patient_documents
                  (id, clinic_id, patient_id, document_type, title, file_name, file_path,
                   file_size_bytes, mime_type, notes, taken_at, uploaded_by_provider_id)
              VALUES
                  (:id, :clinicId, :patientId, :documentType::dentalcare.document_type, :title,
                   :fileName, :filePath, :fileSizeBytes, :mimeType, :notes, :takenAt, :uploadedBy)
              """.formatted(s());

          jdbc.update(sql, new MapSqlParameterSource()
                  .addValue("id", docId)
                  .addValue("clinicId", clinic)
                  .addValue("patientId", patientId)
                  .addValue("documentType", documentType != null ? documentType : "altro")
                  .addValue("title", title)
                  .addValue("fileName", safeFileName)
                  .addValue("filePath", objectKey)
                  .addValue("fileSizeBytes", file.getSize())
                  .addValue("mimeType", mimeType)
                  .addValue("notes", notes)
                  .addValue("takenAt", takenAt)
                  .addValue("uploadedBy", currentProviderId()));

          return findById(patientId, docId);
      }

      @Transactional(readOnly = true)
      public PatientDocumentSummaryDto findById(UUID patientId, UUID docId) {
          UUID clinic = clinicId();
          String sql = """
              SELECT id, document_type, title, file_name, mime_type, file_size_bytes, notes, taken_at, created_at
              FROM %s.patient_documents
              WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
              """.formatted(s());
          List<Map<String, Object>> rows = jdbc.queryForList(sql,
                  new MapSqlParameterSource()
                          .addValue("id", docId)
                          .addValue("patientId", patientId)
                          .addValue("clinicId", clinic));
          if (rows.isEmpty()) throw new ResourceNotFoundException("Document not found: " + docId);
          return mapSummary(rows.getFirst());
      }

      @Transactional(readOnly = true)
      public byte[] downloadContent(UUID patientId, UUID docId) {
          UUID clinic = clinicId();
          String sql = """
              SELECT file_path FROM %s.patient_documents
              WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
              """.formatted(s());
          List<Map<String, Object>> rows = jdbc.queryForList(sql,
                  new MapSqlParameterSource()
                          .addValue("id", docId)
                          .addValue("patientId", patientId)
                          .addValue("clinicId", clinic));
          if (rows.isEmpty()) throw new ResourceNotFoundException("Document not found: " + docId);
          return minio.download((String) rows.getFirst().get("file_path"));
      }

      @Transactional
      public PatientDocumentSummaryDto updateMetadata(UUID patientId, UUID docId,
                                                       UpdatePatientDocumentRequest req) {
          UUID clinic = clinicId();
          String sql = """
              UPDATE %s.patient_documents
              SET title       = :title,
                  document_type = :documentType::dentalcare.document_type,
                  notes       = :notes,
                  taken_at    = :takenAt,
                  updated_at  = now()
              WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
              """.formatted(s());
          int updated = jdbc.update(sql, new MapSqlParameterSource()
                  .addValue("title", req.title())
                  .addValue("documentType", req.documentType() != null ? req.documentType() : "altro")
                  .addValue("notes", req.notes())
                  .addValue("takenAt", req.takenAt())
                  .addValue("id", docId)
                  .addValue("patientId", patientId)
                  .addValue("clinicId", clinic));
          if (updated == 0) throw new ResourceNotFoundException("Document not found: " + docId);
          return findById(patientId, docId);
      }

      @Transactional
      public void delete(UUID patientId, UUID docId) {
          UUID clinic = clinicId();
          String selectSql = """
              SELECT file_path FROM %s.patient_documents
              WHERE id = :id AND patient_id = :patientId AND clinic_id = :clinicId
              """.formatted(s());
          List<Map<String, Object>> rows = jdbc.queryForList(selectSql,
                  new MapSqlParameterSource()
                          .addValue("id", docId)
                          .addValue("patientId", patientId)
                          .addValue("clinicId", clinic));
          if (rows.isEmpty()) throw new ResourceNotFoundException("Document not found: " + docId);
          String objectKey = (String) rows.getFirst().get("file_path");

          jdbc.update("DELETE FROM %s.patient_documents WHERE id = :id AND clinic_id = :clinicId".formatted(s()),
                  new MapSqlParameterSource().addValue("id", docId).addValue("clinicId", clinic));

          try {
              minio.delete(objectKey);
          } catch (Exception e) {
              log.warn("MinIO delete failed for key={} (file orphaned): {}", objectKey, e.getMessage());
          }
      }

      private String buildObjectKey(UUID patientId, UUID docId, String fileName) {
          return "%s/patients/%s/%s/%s".formatted(s(), patientId, docId, fileName);
      }

      private String sanitizeFileName(String original) {
          if (original == null || original.isBlank()) return "document";
          return original.replaceAll("[^a-zA-Z0-9._-]", "_").toLowerCase();
      }

      private PatientDocumentSummaryDto mapSummary(Map<String, Object> row) {
          return new PatientDocumentSummaryDto(
                  (UUID) row.get("id"),
                  (String) row.get("document_type"),
                  (String) row.get("title"),
                  (String) row.get("file_name"),
                  (String) row.get("mime_type"),
                  row.get("file_size_bytes") != null ? ((Number) row.get("file_size_bytes")).longValue() : null,
                  (String) row.get("notes"),
                  row.get("taken_at") != null ? ((java.sql.Date) row.get("taken_at")).toLocalDate() : null,
                  row.get("created_at") != null ? ((Timestamp) row.get("created_at")).toLocalDateTime() : null
          );
      }
  }
  ```

- [ ] **Step 6: Eseguire i test**

  ```bash
  cd backend
  ./mvnw test -pl . -Dtest=PatientDocumentServiceTest -q 2>&1 | tail -20
  ```

  Atteso: `Tests run: 4, Failures: 0, Errors: 0, Skipped: 0`.

- [ ] **Step 7: Commit**

  ```bash
  git add backend/src/main/java/com/dentalcare/dto/PatientDocumentSummaryDto.java \
          backend/src/main/java/com/dentalcare/dto/UpdatePatientDocumentRequest.java \
          backend/src/main/java/com/dentalcare/service/PatientDocumentService.java \
          backend/src/test/java/com/dentalcare/service/PatientDocumentServiceTest.java
  git commit -m "feat(docs): aggiungi PatientDocumentService e DTO"
  ```

---

## Task 4: Backend — PatientDocumentController

**Files:**
- Create: `backend/src/main/java/com/dentalcare/controller/PatientDocumentController.java`

**Interfaces:**
- Consumes: `PatientDocumentService.*`
- Produces: REST endpoints:
  - `GET /api/patients/{patientId}/documents`
  - `POST /api/patients/{patientId}/documents` (multipart)
  - `GET /api/patients/{patientId}/documents/{docId}`
  - `GET /api/patients/{patientId}/documents/{docId}/content`
  - `PUT /api/patients/{patientId}/documents/{docId}`
  - `DELETE /api/patients/{patientId}/documents/{docId}`

- [ ] **Step 1: Creare PatientDocumentController.java**

  ```java
  package com.dentalcare.controller;

  import com.dentalcare.dto.PatientDocumentSummaryDto;
  import com.dentalcare.dto.UpdatePatientDocumentRequest;
  import com.dentalcare.service.PatientDocumentService;
  import jakarta.validation.Valid;
  import org.springframework.format.annotation.DateTimeFormat;
  import org.springframework.http.HttpHeaders;
  import org.springframework.http.HttpStatus;
  import org.springframework.http.MediaType;
  import org.springframework.http.ResponseEntity;
  import org.springframework.web.bind.annotation.*;
  import org.springframework.web.multipart.MultipartFile;

  import java.time.LocalDate;
  import java.util.List;
  import java.util.UUID;

  @RestController
  @RequestMapping("/api/patients/{patientId}/documents")
  public class PatientDocumentController {

      private final PatientDocumentService docService;

      public PatientDocumentController(PatientDocumentService docService) {
          this.docService = docService;
      }

      @GetMapping
      public List<PatientDocumentSummaryDto> findAll(@PathVariable UUID patientId) {
          return docService.findAll(patientId);
      }

      @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
      @ResponseStatus(HttpStatus.CREATED)
      public PatientDocumentSummaryDto upload(
              @PathVariable UUID patientId,
              @RequestParam("file") MultipartFile file,
              @RequestParam("title") String title,
              @RequestParam(value = "documentType", defaultValue = "altro") String documentType,
              @RequestParam(value = "notes", required = false) String notes,
              @RequestParam(value = "takenAt", required = false)
              @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate takenAt
      ) {
          return docService.upload(patientId, file, title, documentType, notes, takenAt);
      }

      @GetMapping("/{docId}")
      public PatientDocumentSummaryDto findById(
              @PathVariable UUID patientId,
              @PathVariable UUID docId
      ) {
          return docService.findById(patientId, docId);
      }

      @GetMapping("/{docId}/content")
      public ResponseEntity<byte[]> getContent(
              @PathVariable UUID patientId,
              @PathVariable UUID docId
      ) {
          PatientDocumentSummaryDto meta = docService.findById(patientId, docId);
          byte[] content = docService.downloadContent(patientId, docId);
          HttpHeaders headers = new HttpHeaders();
          headers.setContentType(MediaType.parseMediaType(meta.mimeType()));
          headers.set(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + meta.fileName() + "\"");
          headers.setContentLength(content.length);
          return ResponseEntity.ok().headers(headers).body(content);
      }

      @PutMapping("/{docId}")
      public PatientDocumentSummaryDto update(
              @PathVariable UUID patientId,
              @PathVariable UUID docId,
              @Valid @RequestBody UpdatePatientDocumentRequest request
      ) {
          return docService.updateMetadata(patientId, docId, request);
      }

      @DeleteMapping("/{docId}")
      @ResponseStatus(HttpStatus.NO_CONTENT)
      public void delete(
              @PathVariable UUID patientId,
              @PathVariable UUID docId
      ) {
          docService.delete(patientId, docId);
      }
  }
  ```

- [ ] **Step 2: Compilare e verificare**

  ```bash
  cd backend
  ./mvnw compile -q 2>&1 | tail -10
  ```

  Atteso: `BUILD SUCCESS`.

- [ ] **Step 3: Test manuale backend (con il backend avviato + tunnel SSH attivo)**

  ```bash
  # Token JWT ottenuto da login
  TOKEN="..."

  # Lista documenti (deve ritornare [])
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:8080/api/patients/{PATIENT_UUID}/documents | jq .

  # Upload documento di test
  curl -s -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@/tmp/test.jpg" \
    -F "title=RX Test" \
    -F "documentType=rx_panoramica" \
    http://localhost:8080/api/patients/{PATIENT_UUID}/documents | jq .

  # Verifica download
  curl -s -H "Authorization: Bearer $TOKEN" \
    http://localhost:8080/api/patients/{PATIENT_UUID}/documents/{DOC_UUID}/content \
    --output /tmp/downloaded.jpg && echo "Download OK"
  ```

  Atteso: lista vuota, poi upload ritorna JSON con `id`, download crea file identico all'originale.

- [ ] **Step 4: Commit**

  ```bash
  git add backend/src/main/java/com/dentalcare/controller/PatientDocumentController.java
  git commit -m "feat(docs): aggiungi PatientDocumentController REST"
  ```

---

## Task 5: Frontend — model + service

**Files:**
- Create: `frontend/src/app/core/models/patient-document.model.ts`
- Create: `frontend/src/app/core/services/patient-document.service.ts`

**Interfaces:**
- Produces:
  - `PatientDocumentSummary` (interface TS)
  - `UpdatePatientDocumentRequest` (interface TS)
  - `DOCUMENT_TYPE_LABELS` (Record<string, string>)
  - `PatientDocumentService.findAll(patientId): Observable<PatientDocumentSummary[]>`
  - `PatientDocumentService.upload(patientId, FormData): Observable<PatientDocumentSummary>`
  - `PatientDocumentService.update(patientId, docId, req): Observable<PatientDocumentSummary>`
  - `PatientDocumentService.delete(patientId, docId): Observable<void>`
  - `PatientDocumentService.getContent(patientId, docId): Observable<Blob>`

- [ ] **Step 1: Creare patient-document.model.ts**

  ```typescript
  export interface PatientDocumentSummary {
    id: string;
    documentType: string;
    title: string;
    fileName: string;
    mimeType: string;
    fileSizeBytes: number | null;
    notes: string | null;
    takenAt: string | null;
    createdAt: string;
  }

  export interface UpdatePatientDocumentRequest {
    title: string;
    documentType?: string;
    notes?: string;
    takenAt?: string;
  }

  export const DOCUMENT_TYPE_LABELS: Record<string, string> = {
    rx_panoramica:           'Ortopanoramica',
    rx_endorale:             'RX Endorale',
    cbct:                    'TAC / CBCT',
    foto_clinica:            'Foto clinica',
    foto_extraorale:         'Foto extraorale',
    consenso_informato:      'Consenso informato',
    referto:                 'Referto / Lettera',
    documento_amministrativo:'Documento amministrativo',
    altro:                   'Altro',
  };
  ```

- [ ] **Step 2: Creare patient-document.service.ts**

  ```typescript
  import { Injectable } from '@angular/core';
  import { HttpClient } from '@angular/common/http';
  import { Observable } from 'rxjs';
  import { environment } from '../../../environments/environment';
  import { PatientDocumentSummary, UpdatePatientDocumentRequest } from '../models/patient-document.model';

  @Injectable({ providedIn: 'root' })
  export class PatientDocumentService {
    constructor(private readonly http: HttpClient) {}

    private base(patientId: string): string {
      return `${environment.apiBaseUrl}/patients/${patientId}/documents`;
    }

    findAll(patientId: string): Observable<PatientDocumentSummary[]> {
      return this.http.get<PatientDocumentSummary[]>(this.base(patientId));
    }

    upload(patientId: string, formData: FormData): Observable<PatientDocumentSummary> {
      return this.http.post<PatientDocumentSummary>(this.base(patientId), formData);
    }

    update(patientId: string, docId: string, req: UpdatePatientDocumentRequest): Observable<PatientDocumentSummary> {
      return this.http.put<PatientDocumentSummary>(`${this.base(patientId)}/${docId}`, req);
    }

    delete(patientId: string, docId: string): Observable<void> {
      return this.http.delete<void>(`${this.base(patientId)}/${docId}`);
    }

    getContent(patientId: string, docId: string): Observable<Blob> {
      return this.http.get(`${this.base(patientId)}/${docId}/content`, { responseType: 'blob' });
    }
  }
  ```

  Nota: `getContent` ritorna `Observable<Blob>`. La componente crea `URL.createObjectURL(blob)` per uso in `<img>` e `<iframe>` — nessun token JWT esposto in URL.

- [ ] **Step 3: Verificare TypeScript compile**

  ```bash
  cd frontend
  npx tsc --noEmit 2>&1 | head -30
  ```

  Atteso: nessun errore relativo ai nuovi file.

- [ ] **Step 4: Commit**

  ```bash
  git add frontend/src/app/core/models/patient-document.model.ts \
          frontend/src/app/core/services/patient-document.service.ts
  git commit -m "feat(docs): aggiungi model e service Angular per documenti paziente"
  ```

---

## Task 6: Frontend — documenti-tab component

**Files:**
- Create: `frontend/src/app/features/pazienti/documenti-tab/documenti-tab.component.ts`
- Create: `frontend/src/app/features/pazienti/documenti-tab/documenti-tab.component.html`

**Interfaces:**
- Consumes: `PatientDocumentService.*`, `PatientDocumentSummary`, `DOCUMENT_TYPE_LABELS`
- Input: `@Input({ required: true }) patientId: string`
- Selector: `app-documenti-tab`

- [ ] **Step 1: Creare documenti-tab.component.ts**

  Creare la directory `frontend/src/app/features/pazienti/documenti-tab/` se non esiste.

  ```typescript
  import { Component, Input, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
  import { CommonModule } from '@angular/common';
  import { FormsModule } from '@angular/forms';
  import { DomSanitizer, SafeResourceUrl } from '@angular/platform-browser';
  import { PatientDocumentService } from '../../../core/services/patient-document.service';
  import {
    DOCUMENT_TYPE_LABELS,
    PatientDocumentSummary,
    UpdatePatientDocumentRequest,
  } from '../../../core/models/patient-document.model';

  @Component({
    selector: 'app-documenti-tab',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './documenti-tab.component.html',
  })
  export class DocumentiTabComponent implements OnInit, OnDestroy {
    @Input({ required: true }) patientId!: string;

    private readonly docService = inject(PatientDocumentService);
    private readonly sanitizer = inject(DomSanitizer);

    docs = signal<PatientDocumentSummary[]>([]);
    loading = signal(true);
    error = signal<string | null>(null);

    showUploadForm = signal(false);
    uploading = signal(false);
    uploadError = signal<string | null>(null);
    pendingFile: File | null = null;
    uploadForm = { title: '', documentType: 'altro', notes: '', takenAt: '' };

    editingDocId = signal<string | null>(null);
    editForm: UpdatePatientDocumentRequest & { takenAt?: string; notes?: string } = { title: '', documentType: 'altro' };
    saving = signal(false);

    previewDoc = signal<PatientDocumentSummary | null>(null);
    previewBlobUrl = signal<string | null>(null);
    previewLoading = signal(false);

    safePdfUrl = computed((): SafeResourceUrl | null => {
      const url = this.previewBlobUrl();
      return url ? this.sanitizer.bypassSecurityTrustResourceUrl(url) : null;
    });

    confirmDeleteId = signal<string | null>(null);

    readonly documentTypes = Object.entries(DOCUMENT_TYPE_LABELS).map(([key, label]) => ({ key, label }));

    ngOnInit(): void { this.load(); }

    ngOnDestroy(): void { this.revokeBlobUrl(); }

    load(): void {
      this.loading.set(true);
      this.error.set(null);
      this.docService.findAll(this.patientId).subscribe({
        next: data => { this.docs.set(data); this.loading.set(false); },
        error: () => { this.error.set('Errore nel caricamento documenti'); this.loading.set(false); },
      });
    }

    onFileSelected(event: Event): void {
      const file = (event.target as HTMLInputElement).files?.[0];
      if (!file) return;
      if (file.size > 50 * 1024 * 1024) {
        this.uploadError.set('File troppo grande (max 50 MB)');
        return;
      }
      this.pendingFile = file;
      this.uploadError.set(null);
      if (!this.uploadForm.title) {
        this.uploadForm.title = file.name.replace(/\.[^.]+$/, '');
      }
    }

    submitUpload(): void {
      if (!this.pendingFile || this.uploading()) return;
      if (!this.uploadForm.title.trim()) { this.uploadError.set('Inserisci un titolo'); return; }

      const fd = new FormData();
      fd.append('file', this.pendingFile);
      fd.append('title', this.uploadForm.title.trim());
      fd.append('documentType', this.uploadForm.documentType);
      if (this.uploadForm.notes) fd.append('notes', this.uploadForm.notes);
      if (this.uploadForm.takenAt) fd.append('takenAt', this.uploadForm.takenAt);

      this.uploading.set(true);
      this.docService.upload(this.patientId, fd).subscribe({
        next: () => {
          this.uploading.set(false);
          this.showUploadForm.set(false);
          this.resetUploadForm();
          this.load();
        },
        error: () => { this.uploading.set(false); this.uploadError.set('Errore durante il caricamento'); },
      });
    }

    openPreview(doc: PatientDocumentSummary): void {
      this.revokeBlobUrl();
      this.previewDoc.set(doc);
      this.previewLoading.set(true);
      this.docService.getContent(this.patientId, doc.id).subscribe({
        next: blob => {
          this.previewBlobUrl.set(URL.createObjectURL(blob));
          this.previewLoading.set(false);
        },
        error: () => { this.previewLoading.set(false); },
      });
    }

    closePreview(): void {
      this.revokeBlobUrl();
      this.previewDoc.set(null);
    }

    downloadDoc(doc: PatientDocumentSummary): void {
      this.docService.getContent(this.patientId, doc.id).subscribe({
        next: blob => {
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = doc.fileName;
          a.click();
          URL.revokeObjectURL(url);
        },
      });
    }

    startEdit(doc: PatientDocumentSummary): void {
      this.editingDocId.set(doc.id);
      this.editForm = {
        title: doc.title,
        documentType: doc.documentType,
        notes: doc.notes ?? '',
        takenAt: doc.takenAt ?? '',
      };
    }

    saveEdit(doc: PatientDocumentSummary): void {
      if (this.saving()) return;
      this.saving.set(true);
      const req: UpdatePatientDocumentRequest = {
        title: this.editForm.title,
        documentType: this.editForm.documentType,
        notes: (this.editForm.notes as string) || undefined,
        takenAt: (this.editForm.takenAt as string) || undefined,
      };
      this.docService.update(this.patientId, doc.id, req).subscribe({
        next: updated => {
          this.docs.update(list => list.map(d => (d.id === doc.id ? updated : d)));
          this.editingDocId.set(null);
          this.saving.set(false);
        },
        error: () => { this.saving.set(false); },
      });
    }

    cancelEdit(): void { this.editingDocId.set(null); }

    confirmDelete(id: string): void { this.confirmDeleteId.set(id); }
    cancelDelete(): void { this.confirmDeleteId.set(null); }

    doDelete(id: string): void {
      this.docService.delete(this.patientId, id).subscribe({
        next: () => {
          this.docs.update(list => list.filter(d => d.id !== id));
          this.confirmDeleteId.set(null);
        },
      });
    }

    isImage(mimeType: string): boolean { return mimeType?.startsWith('image/') ?? false; }
    isPdf(mimeType: string): boolean { return mimeType === 'application/pdf'; }
    typeLabel(type: string): string { return DOCUMENT_TYPE_LABELS[type] ?? type; }

    formatSize(bytes: number | null): string {
      if (!bytes) return '';
      if (bytes < 1024) return `${bytes} B`;
      if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }

    formatDate(iso: string | null): string {
      if (!iso) return '';
      return new Date(iso).toLocaleDateString('it-IT', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    private revokeBlobUrl(): void {
      const url = this.previewBlobUrl();
      if (url) { URL.revokeObjectURL(url); this.previewBlobUrl.set(null); }
    }

    private resetUploadForm(): void {
      this.pendingFile = null;
      this.uploadForm = { title: '', documentType: 'altro', notes: '', takenAt: '' };
      this.uploadError.set(null);
    }
  }
  ```

- [ ] **Step 2: Creare documenti-tab.component.html**

  ```html
  <div class="space-y-4">

    <!-- Header -->
    <div class="flex items-center justify-between">
      <h2 class="font-bold text-slate-700 flex items-center gap-2">
        <span class="material-symbols-outlined text-[18px] text-teal-600">folder_open</span>
        Documenti ({{ docs().length }})
      </h2>
      <button (click)="showUploadForm.set(!showUploadForm())"
        class="flex items-center gap-1.5 bg-teal-600 text-white text-sm font-bold px-3 py-2 rounded-xl hover:bg-teal-700 transition-colors shadow-sm">
        <span class="material-symbols-outlined text-[16px]">upload_file</span>
        Aggiungi documento
      </button>
    </div>

    <!-- Error -->
    @if (error()) {
      <div class="flex items-center gap-3 bg-red-50 border border-red-200 rounded-xl px-4 py-3">
        <span class="material-symbols-outlined text-red-500">error</span>
        <p class="text-sm text-red-700">{{ error() }}</p>
      </div>
    }

    <!-- Upload Form -->
    @if (showUploadForm()) {
      <div class="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
        <h3 class="font-semibold text-slate-700">Nuovo documento</h3>

        <div>
          <label class="block w-full cursor-pointer">
            <div class="border-2 border-dashed rounded-xl p-6 text-center transition-colors"
              [class.border-teal-500]="pendingFile"
              [class.border-slate-300]="!pendingFile"
              [class.hover:border-teal-400]="!pendingFile">
              @if (pendingFile) {
                <span class="material-symbols-outlined text-2xl text-teal-500 block mb-1">check_circle</span>
                <p class="text-sm font-semibold text-teal-700">{{ pendingFile.name }}</p>
                <p class="text-xs text-slate-400 mt-1">{{ formatSize(pendingFile.size) }}</p>
              } @else {
                <span class="material-symbols-outlined text-3xl text-slate-300 block mb-2">cloud_upload</span>
                <p class="text-sm text-slate-500">Clicca per selezionare (max 50 MB)</p>
                <p class="text-xs text-slate-400 mt-1">JPEG · PNG · WebP · PDF</p>
              }
            </div>
            <input type="file" class="hidden"
              accept="image/jpeg,image/png,image/webp,application/pdf"
              (change)="onFileSelected($event)">
          </label>
          @if (uploadError()) {
            <p class="text-xs text-red-600 mt-1">{{ uploadError() }}</p>
          }
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="block text-xs text-slate-400 mb-1">Titolo *</label>
            <input type="text" [(ngModel)]="uploadForm.title"
              class="w-full text-sm border border-slate-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-400" />
          </div>
          <div>
            <label class="block text-xs text-slate-400 mb-1">Tipo documento</label>
            <select [(ngModel)]="uploadForm.documentType"
              class="w-full text-sm border border-slate-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-400">
              @for (t of documentTypes; track t.key) {
                <option [value]="t.key">{{ t.label }}</option>
              }
            </select>
          </div>
          <div>
            <label class="block text-xs text-slate-400 mb-1">Data esame</label>
            <input type="date" [(ngModel)]="uploadForm.takenAt"
              class="w-full text-sm border border-slate-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-400" />
          </div>
          <div>
            <label class="block text-xs text-slate-400 mb-1">Note</label>
            <input type="text" [(ngModel)]="uploadForm.notes" placeholder="Opzionale"
              class="w-full text-sm border border-slate-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-400" />
          </div>
        </div>

        <div class="flex gap-2 justify-end pt-1">
          <button (click)="showUploadForm.set(false)"
            class="px-4 py-2 text-sm font-semibold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors">
            Annulla
          </button>
          <button (click)="submitUpload()" [disabled]="!pendingFile || uploading()"
            class="px-4 py-2 text-sm font-semibold bg-teal-600 text-white hover:bg-teal-700 disabled:opacity-50 rounded-xl transition-colors flex items-center gap-2">
            @if (uploading()) {
              <span class="material-symbols-outlined text-[16px] animate-spin">progress_activity</span>
            }
            {{ uploading() ? 'Caricamento...' : 'Carica' }}
          </button>
        </div>
      </div>
    }

    <!-- Loading skeleton -->
    @if (loading()) {
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        @for (i of [1,2,3]; track i) {
          <div class="bg-white rounded-xl border border-slate-200 p-4 animate-pulse space-y-3">
            <div class="flex gap-3">
              <div class="w-8 h-8 bg-slate-200 rounded"></div>
              <div class="flex-1 space-y-2">
                <div class="h-3 w-28 bg-slate-200 rounded"></div>
                <div class="h-2 w-20 bg-slate-100 rounded"></div>
              </div>
            </div>
          </div>
        }
      </div>

    <!-- Empty state -->
    } @else if (docs().length === 0 && !showUploadForm()) {
      <div class="flex flex-col items-center justify-center py-16 text-slate-400">
        <span class="material-symbols-outlined text-5xl mb-3">folder_open</span>
        <p class="text-sm font-semibold">Nessun documento</p>
        <p class="text-xs mt-1">Usa "Aggiungi documento" per caricare il primo file</p>
      </div>

    <!-- Document grid -->
    } @else {
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        @for (doc of docs(); track doc.id) {
          <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden hover:border-teal-300 transition-colors">

            <!-- Card clickable area → preview -->
            <button class="w-full p-4 text-left" (click)="openPreview(doc)">
              <div class="flex items-start gap-3">
                <span class="material-symbols-outlined text-3xl shrink-0"
                  [class.text-blue-500]="isImage(doc.mimeType)"
                  [class.text-red-500]="isPdf(doc.mimeType)"
                  [class.text-slate-400]="!isImage(doc.mimeType) && !isPdf(doc.mimeType)">
                  {{ isImage(doc.mimeType) ? 'image' : isPdf(doc.mimeType) ? 'picture_as_pdf' : 'insert_drive_file' }}
                </span>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-semibold text-slate-800 truncate">{{ doc.title }}</p>
                  <p class="text-xs text-teal-600 mt-0.5">{{ typeLabel(doc.documentType) }}</p>
                  <p class="text-xs text-slate-400 mt-1">
                    {{ formatDate(doc.takenAt ?? doc.createdAt) }}
                  </p>
                  @if (doc.fileSizeBytes) {
                    <p class="text-xs text-slate-300 mt-0.5">{{ formatSize(doc.fileSizeBytes) }}</p>
                  }
                </div>
              </div>
              @if (doc.notes) {
                <p class="text-xs text-slate-500 mt-2 line-clamp-2">{{ doc.notes }}</p>
              }
            </button>

            <!-- Card actions area -->
            @if (editingDocId() === doc.id) {
              <div class="px-4 pb-4 border-t border-slate-100 pt-3 space-y-2">
                <input type="text" [(ngModel)]="editForm.title" placeholder="Titolo"
                  class="w-full text-xs border border-slate-300 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-400" />
                <select [(ngModel)]="editForm.documentType"
                  class="w-full text-xs border border-slate-300 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-400">
                  @for (t of documentTypes; track t.key) {
                    <option [value]="t.key">{{ t.label }}</option>
                  }
                </select>
                <input type="date" [(ngModel)]="editForm.takenAt"
                  class="w-full text-xs border border-slate-300 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-400" />
                <input type="text" [(ngModel)]="editForm.notes" placeholder="Note"
                  class="w-full text-xs border border-slate-300 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-400" />
                <div class="flex gap-1.5 pt-1">
                  <button (click)="saveEdit(doc)" [disabled]="saving()"
                    class="flex-1 py-1.5 text-xs font-bold bg-teal-600 text-white rounded-lg disabled:opacity-50 transition-colors">
                    {{ saving() ? '...' : 'Salva' }}
                  </button>
                  <button (click)="cancelEdit()"
                    class="flex-1 py-1.5 text-xs font-semibold bg-slate-100 text-slate-600 rounded-lg transition-colors">
                    Annulla
                  </button>
                </div>
              </div>

            } @else if (confirmDeleteId() === doc.id) {
              <div class="px-4 pb-3 border-t border-slate-100 pt-2 flex items-center gap-2">
                <span class="text-xs text-slate-500 flex-1">Eliminare definitivamente?</span>
                <button (click)="doDelete(doc.id)"
                  class="px-2.5 py-1 text-xs font-bold text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition-colors">Sì</button>
                <button (click)="cancelDelete()"
                  class="px-2.5 py-1 text-xs font-semibold text-slate-500 border border-slate-200 rounded-lg hover:bg-slate-50 transition-colors">No</button>
              </div>

            } @else {
              <div class="px-4 pb-3 border-t border-slate-100 pt-2 flex items-center gap-1">
                <button (click)="downloadDoc(doc)" title="Scarica"
                  class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors">
                  <span class="material-symbols-outlined text-[18px]">download</span>
                </button>
                <button (click)="startEdit(doc)" title="Modifica metadati"
                  class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-slate-100 text-slate-400 hover:text-teal-600 transition-colors">
                  <span class="material-symbols-outlined text-[18px]">edit</span>
                </button>
                <button (click)="confirmDelete(doc.id)" title="Elimina"
                  class="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-red-50 text-slate-400 hover:text-red-500 transition-colors ml-auto">
                  <span class="material-symbols-outlined text-[18px]">delete</span>
                </button>
              </div>
            }
          </div>
        }
      </div>
    }

  </div>

  <!-- Preview Modal -->
  @if (previewDoc()) {
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
      (click)="closePreview()">
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] flex flex-col"
        (click)="$event.stopPropagation()">

        <!-- Modal header -->
        <div class="flex items-center justify-between px-5 py-4 border-b border-slate-200 shrink-0">
          <div class="min-w-0">
            <p class="font-bold text-slate-800 truncate">{{ previewDoc()!.title }}</p>
            <p class="text-xs text-slate-400 mt-0.5">
              {{ typeLabel(previewDoc()!.documentType) }}
              @if (previewDoc()!.takenAt) { · {{ formatDate(previewDoc()!.takenAt) }} }
            </p>
          </div>
          <div class="flex items-center gap-2 ml-4 shrink-0">
            <button (click)="downloadDoc(previewDoc()!)"
              class="flex items-center gap-1 px-3 py-1.5 text-sm font-semibold border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 transition-colors">
              <span class="material-symbols-outlined text-[16px]">download</span>
              Scarica
            </button>
            <button (click)="closePreview()"
              class="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors">
              <span class="material-symbols-outlined">close</span>
            </button>
          </div>
        </div>

        <!-- Modal body -->
        <div class="flex-1 overflow-auto flex items-center justify-center p-4 bg-slate-50">
          @if (previewLoading()) {
            <div class="flex items-center gap-2 text-slate-400">
              <span class="material-symbols-outlined animate-spin">progress_activity</span>
              <span class="text-sm">Caricamento...</span>
            </div>
          } @else if (previewBlobUrl() && isImage(previewDoc()!.mimeType)) {
            <img [src]="previewBlobUrl()!" class="max-w-full max-h-full object-contain rounded-lg shadow-sm"
              [alt]="previewDoc()!.title">
          } @else if (safePdfUrl() && isPdf(previewDoc()!.mimeType)) {
            <iframe [src]="safePdfUrl()!" class="w-full h-[60vh] rounded-lg border-0"></iframe>
          } @else if (previewBlobUrl()) {
            <div class="text-center text-slate-400 py-8">
              <span class="material-symbols-outlined text-5xl mb-3 block">insert_drive_file</span>
              <p class="text-sm">Anteprima non disponibile per questo tipo di file</p>
              <p class="text-xs mt-1">Usa "Scarica" per aprirlo</p>
            </div>
          }
        </div>
      </div>
    </div>
  }
  ```

- [ ] **Step 3: Verificare TypeScript compile**

  ```bash
  cd frontend
  npx tsc --noEmit 2>&1 | head -30
  ```

  Atteso: nessun errore nel file `documenti-tab.component.ts`.

- [ ] **Step 4: Commit**

  ```bash
  git add frontend/src/app/features/pazienti/documenti-tab/
  git commit -m "feat(docs): aggiungi DocumentiTabComponent Angular"
  ```

---

## Task 7: Frontend — integrazione in paziente-detail

**Files:**
- Modify: `frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.ts`
- Modify: `frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.html`

**Interfaces:**
- Consumes: `DocumentiTabComponent` (selector `app-documenti-tab`, `@Input patientId`)

- [ ] **Step 1: Aggiungere import in paziente-detail.component.ts**

  Aprire `frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.ts`.

  Aggiungere import:
  ```typescript
  import { DocumentiTabComponent } from '../documenti-tab/documenti-tab.component';
  ```

  Nel decoratore `@Component`, aggiungere `DocumentiTabComponent` all'array `imports`:
  ```typescript
  imports: [CommonModule, FormsModule, RouterLink, CartellaClinicalTabComponent,
            AnamnesiTabComponent, OdontogrammaTabComponent, PianoCuraTabComponent,
            RichiamiTabComponent, DocumentiTabComponent],
  ```

- [ ] **Step 2: Aggiungere branch documenti nel template**

  Aprire `frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.html`.

  Trovare il blocco `@else` finale (riga ~438 circa):
  ```html
    } @else {
      <div class="flex items-center justify-center h-40 text-slate-400">
        <div class="text-center">
          <span class="material-symbols-outlined text-[40px] block mb-2">construction</span>
          <p class="text-sm font-semibold">Sezione in sviluppo</p>
          <p class="text-xs mt-1">Seleziona "Panoramica" per vedere i dati disponibili</p>
        </div>
      </div>
    }
  ```

  Sostituirlo con:
  ```html
    } @else if (activeTab() === 'documenti') {
      @if (paziente) {
        <app-documenti-tab [patientId]="paziente.id" />
      }

    } @else if (activeTab() === 'preventivi') {
      <div class="flex items-center justify-center h-40 text-slate-400">
        <div class="text-center">
          <span class="material-symbols-outlined text-[40px] block mb-2">construction</span>
          <p class="text-sm font-semibold">Sezione in sviluppo</p>
          <p class="text-xs mt-1">Seleziona "Panoramica" per vedere i dati disponibili</p>
        </div>
      </div>

    } @else {
      <div class="flex items-center justify-center h-40 text-slate-400">
        <div class="text-center">
          <span class="material-symbols-outlined text-[40px] block mb-2">construction</span>
          <p class="text-sm font-semibold">Sezione in sviluppo</p>
        </div>
      </div>
    }
  ```

  Nota: "preventivi" era nel `@else` catch-all — ora ha il suo branch esplicito e rimane "in sviluppo". `documenti` ottiene il component reale.

- [ ] **Step 3: Verificare TypeScript compile**

  ```bash
  cd frontend
  npx tsc --noEmit 2>&1 | head -30
  ```

  Atteso: nessun errore.

- [ ] **Step 4: Avviare il frontend e testare manualmente**

  ```bash
  cd frontend
  npm start
  ```

  Test da eseguire nel browser:
  1. Aprire scheda paziente → tab "Documenti" → deve mostrare "Nessun documento"
  2. Cliccare "Aggiungi documento" → selezionare un JPEG o PDF
  3. Compilare titolo, tipo documento, cliccare "Carica"
  4. Il documento compare nella griglia → cliccare → modal preview funzionante
  5. Cliccare "Scarica" → file scaricato correttamente
  6. Cliccare icona modifica → aggiornare titolo → salvare → card aggiornata
  7. Cliccare icona elimina → confermare → card rimossa

- [ ] **Step 5: Commit finale**

  ```bash
  git add frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.ts \
          frontend/src/app/features/pazienti/paziente-detail/paziente-detail.component.html
  git commit -m "feat(docs): integra DocumentiTabComponent in paziente-detail"
  ```

---

## Self-Review — Spec Coverage Check

| Requisito spec | Task |
|----------------|------|
| MinIO proxy Spring (no URL esposta) | Task 2 + Task 4 (`getContent` → `byte[]`) |
| Upload multipart/form-data | Task 3 + Task 4 |
| Lista metadati senza contenuto | Task 3 (`findAll`) |
| Preview immagini + PDF | Task 6 (blob URL + iframe SafeResourceUrl) |
| Download | Task 6 (`downloadDoc`) |
| Edit metadati senza re-upload | Task 6 (`saveEdit`) |
| Delete DB + MinIO | Task 3 (`delete`) |
| Config dev vs prod separati | Task 1 |
| docker-compose extra_hosts | Task 1 |
| Hook cifratura GDPR (no-op) | Task 2 |
| Enum DB reali (rx_panoramica etc.) | Task 5 (DOCUMENT_TYPE_LABELS) |
| Isolamento tenant (clinic_id dal context) | Task 3 |
| Limite 50MB lato frontend | Task 6 |
| Limite 50MB lato backend | Task 1 (multipart config) |
| Nessuna entity JPA | Task 2-4 (solo JdbcTemplate) |
| `file_path` = MinIO object key | Task 3 |
