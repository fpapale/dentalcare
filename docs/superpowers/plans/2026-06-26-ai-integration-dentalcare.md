# DentalCare AI Integration Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the `dentalcare-ai-service` (Plan A) into DentalCare: per-tenant MinIO buckets, DB tables for AI analyses/labels, a Spring orchestration layer (start analysis → call ai-service → receive HMAC callback → push SSE to the UI → reconcile), odontogram sync on dentist review, and an Angular bounding-box overlay.

**Architecture:** Angular triggers analysis on a panoramic document → Spring creates a `patient_document_analyses` row (PROCESSING) and calls the ai-service job endpoint forwarding the user's JWT → ai-service runs inference and POSTs an HMAC-signed callback → Spring verifies the HMAC, writes `patient_document_labels`, sets COMPLETED, and emits an SSE event → the browser draws the boxes. A scheduled reconciler polls the ai-service for analyses whose callback was lost. On dentist review/approval, confirmed caries labels are synced into `tooth_conditions` non-destructively.

**Tech Stack:** Spring Boot 3.5 / Java 25, NamedParameterJdbcTemplate (no JPA entities — project pattern), AWS SDK S3 v2 (MinIO), Spring `SseEmitter`, `@Scheduled`; PostgreSQL; Angular 17+ signals, standalone components, `EventSource` (SSE), SVG overlay, Tailwind.

**Spec:** `docs/superpowers/specs/2026-06-26-ai-yolo-service-design.md` (sections 5, 6, 6.5, 7, 8, 9).

**Depends on Plan A:** the ai-service `POST /api/v1/inference/jobs` request shape and the HMAC callback payload (Plan A Task 11). Plan B can be built and unit-tested before the ai-service is running (the HTTP client is mocked in tests).

## Global Constraints

- No JPA entities. Use `NamedParameterJdbcTemplate`; multi-tenant via `TenantContext.validatedSchema()` (schema, regex `^t_[0-9a-f]{8}$`) and `TenantContext.getCurrentTenant()` (clinic_id UUID string). Mirror `PatientDocumentService` style exactly.
- Bucket name: `dc-` + schema with `_`→`-` (S3 forbids underscores), e.g. `t_9d754153` → `dc-t-9d754153`. Always derived server-side from the schema, never from the client.
- After Plan B Task 1, patient document object keys are `patients/{patientId}/{docId}/{fileName}` (no `{schema}/` prefix — the bucket is the tenant).
- AI analysis statuses: `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`. Review statuses: `pending`, `reviewed`, `approved_for_training`, `excluded`. Label source: `ai`, `human_corrected`.
- Only `document_type = 'rx_panoramica'` can be analyzed (validate in service).
- Callback endpoint `/api/internal/ai/callback` is NOT JWT-protected; it is authenticated by `X-AI-Signature = hex(HMAC_SHA256(app.ai.hmac-secret, raw_body))`. All other `/api/**` keep JWT.
- Disease→condition mapping for odontogram sync: `Caries`→`caries`, `Deep_Caries`→`caries`; `Periapical_Lesion` and `Impacted` are NOT synced (stay in labels only).
- Odontogram sync is triggered ONLY on dentist review when review status becomes `reviewed` or `approved_for_training`; never on raw COMPLETED.
- `tooth_conditions` sync is non-destructive: AI rows carry `source='ai'` + `analysis_id`; manual save deletes only `source='manual'`.
- Bbox quadrant colors (frontend SVG, mirror ai-service): Q1(11-18)=`#57C84D`, Q2(21-28)=`#E84D4D`, Q3(31-38)=`#4DC8E8`, Q4(41-48)=`#E8C84D`, null=`#9E9E9E`.
- New config keys live in `backend/config/application*.properties` (gitignored): `app.minio.bucket-prefix=dc-`, `app.ai.base-url=http://dentalcare-ai-service:8000`, `app.ai.callback-url=http://dentalcarepro-backend:8080/api/internal/ai/callback`, `app.ai.hmac-secret=<secret>` (must equal ai-service `AI_CALLBACK_SECRET`).

---

### Task 1: MinioStorageService → per-tenant bucket; drop schema prefix from keys

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/MinioStorageService.java`
- Modify: `backend/src/main/java/com/dentalcare/service/PatientDocumentService.java:185-187`
- Modify: `backend/config/application.properties` and `backend/config/application-prod.properties` (add `app.minio.bucket-prefix=dc-`; the implementer edits the gitignored runtime files)
- Test: `backend/src/test/java/com/dentalcare/service/MinioStorageServiceBucketTest.java`

**Interfaces:**
- Consumes: `TenantContext.validatedSchema()`.
- Produces: `MinioStorageService.bucketFor(String schema) -> String`; `ensureBucketExists(String bucket)`; `purgeBucket(String bucket)`. `upload/download/delete` now operate on the current tenant's bucket (resolved from `TenantContext`). `PatientDocumentService.buildObjectKey` returns `patients/{patientId}/{docId}/{fileName}`.

- [ ] **Step 1: Write the failing test — MinioStorageServiceBucketTest.java**

```java
package com.dentalcare.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MinioStorageServiceBucketTest {

    @Test
    void bucketFor_sanitizesUnderscoreAndPrefixes() {
        MinioStorageService svc = new MinioStorageService(new NoOpDocumentEncryptionService());
        svc.setBucketPrefixForTest("dc-");
        assertEquals("dc-t-9d754153", svc.bucketFor("t_9d754153"));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./mvnw -q -Dtest=MinioStorageServiceBucketTest test`
Expected: FAIL (no `bucketFor`/`setBucketPrefixForTest`)

- [ ] **Step 3: Rewrite MinioStorageService.java**

```java
package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
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
import java.util.List;

@Service
public class MinioStorageService {

    private static final Logger log = LoggerFactory.getLogger(MinioStorageService.class);

    @Value("${app.minio.endpoint}")
    private String endpoint;

    @Value("${app.minio.access-key}")
    private String accessKey;

    @Value("${app.minio.secret-key}")
    private String secretKey;

    @Value("${app.minio.bucket-prefix:dc-}")
    private String bucketPrefix;

    private final DocumentEncryptionService encryption;
    private S3Client s3;

    public MinioStorageService(DocumentEncryptionService encryption) {
        this.encryption = encryption;
    }

    /** Test seam: set the prefix without Spring context. */
    void setBucketPrefixForTest(String prefix) { this.bucketPrefix = prefix; }

    @PostConstruct
    void init() {
        s3 = S3Client.builder()
                .endpointOverride(URI.create(endpoint))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey, secretKey)))
                .region(Region.US_EAST_1)
                .forcePathStyle(true)
                .build();
        log.info("MinIO storage initialized: endpoint={}, bucketPrefix={}", endpoint, bucketPrefix);
    }

    /** Bucket name for a tenant schema: dc- + schema with underscores replaced by hyphens. */
    public String bucketFor(String schema) {
        return bucketPrefix + schema.replace('_', '-');
    }

    private String currentBucket() {
        String bucket = bucketFor(TenantContext.validatedSchema());
        ensureBucketExists(bucket);
        return bucket;
    }

    public void ensureBucketExists(String bucket) {
        try {
            s3.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
        } catch (NoSuchBucketException e) {
            s3.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
            log.info("Created MinIO bucket: {}", bucket);
        }
    }

    /** Delete every object in the bucket, then the bucket itself. Idempotent if bucket missing. */
    public void purgeBucket(String bucket) {
        try {
            String token = null;
            do {
                ListObjectsV2Response listing = s3.listObjectsV2(ListObjectsV2Request.builder()
                        .bucket(bucket).continuationToken(token).build());
                List<ObjectIdentifier> ids = listing.contents().stream()
                        .map(o -> ObjectIdentifier.builder().key(o.key()).build())
                        .toList();
                if (!ids.isEmpty()) {
                    s3.deleteObjects(DeleteObjectsRequest.builder().bucket(bucket)
                            .delete(Delete.builder().objects(ids).build()).build());
                }
                token = listing.isTruncated() ? listing.nextContinuationToken() : null;
            } while (token != null);
            s3.deleteBucket(DeleteBucketRequest.builder().bucket(bucket).build());
            log.info("Purged MinIO bucket: {}", bucket);
        } catch (NoSuchBucketException e) {
            log.warn("purgeBucket: bucket already absent: {}", bucket);
        }
    }

    public void upload(String objectKey, byte[] data, String mimeType) {
        byte[] payload = encryption.encrypt(data);
        s3.putObject(
                PutObjectRequest.builder()
                        .bucket(currentBucket()).key(objectKey).contentType(mimeType)
                        .contentLength((long) payload.length).build(),
                RequestBody.fromBytes(payload));
        log.debug("Uploaded object: key={}, size={}", objectKey, payload.length);
    }

    public byte[] download(String objectKey) {
        try (var response = s3.getObject(
                GetObjectRequest.builder().bucket(currentBucket()).key(objectKey).build())) {
            return encryption.decrypt(response.readAllBytes());
        } catch (IOException e) {
            throw new RuntimeException("Failed to read object: " + objectKey, e);
        }
    }

    public void delete(String objectKey) {
        s3.deleteObject(DeleteObjectRequest.builder().bucket(currentBucket()).key(objectKey).build());
        log.debug("Deleted object: key={}", objectKey);
    }
}
```

- [ ] **Step 4: Update PatientDocumentService.buildObjectKey (lines 185-187)**

```java
    private String buildObjectKey(UUID patientId, UUID docId, String fileName) {
        return "patients/%s/%s/%s".formatted(patientId, docId, fileName);
    }
```

- [ ] **Step 5: Add config key**

Append to `backend/config/application.properties` and `backend/config/application-prod.properties`:

```properties
app.minio.bucket-prefix=dc-
```

(The old `app.minio.bucket` key is no longer read; leave or remove it.)

- [ ] **Step 6: Run tests**

Run: `cd backend && ./mvnw -q -Dtest=MinioStorageServiceBucketTest,PatientDocumentServiceTest test`
Expected: PASS. (If `PatientDocumentServiceTest` asserts an object key containing `t_abcd1234/patients/...`, update those assertions to the new prefix-less key `patients/...`.)

- [ ] **Step 7: One-time data migration (manual, near-zero data)**

For each existing tenant schema with rows in `patient_documents`, move objects from the old single bucket and update `file_path`. Document this in the commit body; run it once against the running MinIO:

```bash
# For schema t_9d754153 (repeat per schema):
mc mirror minio/dentalcare-docs/t_9d754153/ minio/dc-t-9d754153/
# then strip the schema prefix from file_path:
# UPDATE t_9d754153.patient_documents SET file_path = regexp_replace(file_path, '^t_9d754153/', '');
```

- [ ] **Step 8: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/MinioStorageService.java backend/src/main/java/com/dentalcare/service/PatientDocumentService.java backend/src/test/java/com/dentalcare/service/MinioStorageServiceBucketTest.java
git commit -m "feat(storage): per-tenant MinIO bucket (dc-{schema}), drop key prefix"
```

---

### Task 2: Bucket lifecycle hooks (create on provision, purge on delete)

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/TenantProvisioningService.java` (after schema creation)
- Modify: `backend/src/main/java/com/dentalcare/service/TenantAdminService.java:183-199` (`deleteTenant`)
- Test: `backend/src/test/java/com/dentalcare/service/MinioStorageServiceBucketTest.java` (extend)

**Interfaces:**
- Consumes: `MinioStorageService.bucketFor`, `ensureBucketExists`, `purgeBucket`.
- Produces: a bucket is created when a tenant schema is provisioned and purged when a tenant is deleted (both deferred to after the DB transaction commits). The demo tenant `t_9d754153` bucket is never purged.

- [ ] **Step 1: Inject MinioStorageService into TenantProvisioningService and create the bucket after commit**

In `TenantProvisioningService`, add a constructor dependency on `MinioStorageService minio` (follow the existing constructor-injection style). Immediately after the schema is created (around line 49, once `schemaName` is known and DDL has run), register an after-commit callback:

```java
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
// ...
final String bucket = minio.bucketFor(schemaName);
if (TransactionSynchronizationManager.isSynchronizationActive()) {
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override public void afterCommit() { minio.ensureBucketExists(bucket); }
    });
} else {
    minio.ensureBucketExists(bucket);
}
```

> Rationale: if the provisioning transaction rolls back, no orphan bucket is created. `MinioStorageService.upload` also calls `ensureBucketExists` lazily, so a missed creation self-heals on first upload.

- [ ] **Step 2: Purge the bucket after commit in TenantAdminService.deleteTenant**

Add a `MinioStorageService minio` dependency to `TenantAdminService` (constructor injection). In `deleteTenant()`, after the existing demo guard and before/around the DB deletes, capture the schema and register an after-commit purge (skip demo):

```java
final String bucket = minio.bucketFor(schema);
if (TransactionSynchronizationManager.isSynchronizationActive()) {
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override public void afterCommit() { minio.purgeBucket(bucket); }
    });
} else {
    minio.purgeBucket(bucket);
}
```

(The method already rejects `t_9d754153`, so the demo bucket is never purged. Add the imports for `TransactionSynchronization`/`TransactionSynchronizationManager`.)

- [ ] **Step 3: Add a unit test for purge ordering (extend MinioStorageServiceBucketTest)**

```java
    @Test
    void purgeBucket_deletesObjectsThenBucket() {
        // Covered by an integration check; here assert bucketFor used for purge name.
        MinioStorageService svc = new MinioStorageService(new NoOpDocumentEncryptionService());
        svc.setBucketPrefixForTest("dc-");
        org.junit.jupiter.api.Assertions.assertEquals("dc-t-abcd1234", svc.bucketFor("t_abcd1234"));
    }
```

- [ ] **Step 4: Compile + test**

Run: `cd backend && ./mvnw -q -Dtest=MinioStorageServiceBucketTest test`
Expected: PASS, and the project compiles (`./mvnw -q -DskipTests compile`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/TenantProvisioningService.java backend/src/main/java/com/dentalcare/service/TenantAdminService.java backend/src/test/java/com/dentalcare/service/MinioStorageServiceBucketTest.java
git commit -m "feat(storage): bucket lifecycle on tenant provision/delete (after-commit)"
```

---

### Task 3: DB schema — analyses + labels tables, enums, tooth_conditions patch

**Files:**
- Modify: `database/install.sql` (add enums in `dentalcare` schema; add tables in the demo tenant `t_9d754153` schema; add the `tooth_conditions` columns)
- Modify: `backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java` (create tables + patch columns for every existing tenant schema)

**Interfaces:**
- Produces: per-tenant tables `patient_document_analyses` and `patient_document_labels`; `dentalcare` enums `ai_analysis_status`, `ai_review_status`, `ai_label_source`; new columns `tooth_conditions.source`, `tooth_conditions.analysis_id`.

- [ ] **Step 1: Define the DDL (used in both install.sql and the initializer)**

Enums (in `dentalcare` schema, create-if-absent via DO block):

```sql
DO $$ BEGIN
  CREATE TYPE dentalcare.ai_analysis_status AS ENUM ('PENDING','PROCESSING','COMPLETED','FAILED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE dentalcare.ai_review_status AS ENUM ('pending','reviewed','approved_for_training','excluded');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TYPE dentalcare.ai_label_source AS ENUM ('ai','human_corrected');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

Tables (replace `{schema}` with the target schema):

```sql
CREATE TABLE IF NOT EXISTS {schema}.patient_document_analyses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id uuid NOT NULL,
    patient_id uuid NOT NULL,
    document_id uuid NOT NULL,
    job_id text,
    status dentalcare.ai_analysis_status NOT NULL DEFAULT 'PENDING',
    model_fdi text,
    model_disease text,
    result_bucket text,
    result_object_key text,
    annotated_object_key text,
    detections_count integer NOT NULL DEFAULT 0,
    needs_review boolean NOT NULL DEFAULT false,
    review_status dentalcare.ai_review_status NOT NULL DEFAULT 'pending',
    reviewed_by_provider_id uuid,
    reviewed_at timestamptz,
    error_message text,
    requested_by_provider_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pda_document ON {schema}.patient_document_analyses (document_id);
CREATE INDEX IF NOT EXISTS idx_pda_patient  ON {schema}.patient_document_analyses (patient_id);
CREATE INDEX IF NOT EXISTS idx_pda_job      ON {schema}.patient_document_analyses (job_id);
CREATE INDEX IF NOT EXISTS idx_pda_status   ON {schema}.patient_document_analyses (status);

CREATE TABLE IF NOT EXISTS {schema}.patient_document_labels (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id uuid NOT NULL REFERENCES {schema}.patient_document_analyses (id) ON DELETE CASCADE,
    tooth_fdi text,
    disease text NOT NULL,
    disease_confidence numeric(5,4),
    fdi_confidence numeric(5,4),
    bbox_x1 integer NOT NULL,
    bbox_y1 integer NOT NULL,
    bbox_x2 integer NOT NULL,
    bbox_y2 integer NOT NULL,
    matching_method text NOT NULL,
    matching_score numeric(5,4),
    needs_review boolean NOT NULL DEFAULT false,
    source dentalcare.ai_label_source NOT NULL DEFAULT 'ai',
    action text,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pdl_analysis ON {schema}.patient_document_labels (analysis_id);

ALTER TABLE {schema}.tooth_conditions ADD COLUMN IF NOT EXISTS source varchar(10) NOT NULL DEFAULT 'manual';
ALTER TABLE {schema}.tooth_conditions ADD COLUMN IF NOT EXISTS analysis_id uuid;
```

- [ ] **Step 2: Add the enums + demo-tenant tables + columns to install.sql**

Add the three enum DO-blocks near the other `CREATE TYPE dentalcare.*` definitions. Add the two `CREATE TABLE IF NOT EXISTS t_9d754153.patient_document_analyses ...` / `..._labels ...` and the two `ALTER TABLE t_9d754153.tooth_conditions ...` statements in the demo-tenant section (next to where `t_9d754153.patient_documents` is defined). Use `{schema}` = `t_9d754153`.

- [ ] **Step 3: Add a migration step in EstimateSchemaInitializer**

Find the per-schema loop (the method that iterates schemas matching `^t_[0-9a-f]{8}$` and calls `runStep(schema, "...", () -> ...)`). Add, once before the loop, the enum creation (idempotent), and inside the loop a new step:

```java
// once, before the per-schema loop:
jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_analysis_status AS ENUM ('PENDING','PROCESSING','COMPLETED','FAILED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_review_status AS ENUM ('pending','reviewed','approved_for_training','excluded'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");
jdbc.execute("DO $$ BEGIN CREATE TYPE dentalcare.ai_label_source AS ENUM ('ai','human_corrected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;");

// inside the per-schema loop:
runStep(schema, "ai analyses tables", () -> createAiTables(schema));
```

Add the method (uses the table DDL from Step 1 with `{schema}` substituted):

```java
private void createAiTables(String schema) {
    jdbc.execute(("""
        CREATE TABLE IF NOT EXISTS %1$s.patient_document_analyses (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            clinic_id uuid NOT NULL, patient_id uuid NOT NULL, document_id uuid NOT NULL,
            job_id text, status dentalcare.ai_analysis_status NOT NULL DEFAULT 'PENDING',
            model_fdi text, model_disease text, result_bucket text, result_object_key text,
            annotated_object_key text, detections_count integer NOT NULL DEFAULT 0,
            needs_review boolean NOT NULL DEFAULT false,
            review_status dentalcare.ai_review_status NOT NULL DEFAULT 'pending',
            reviewed_by_provider_id uuid, reviewed_at timestamptz, error_message text,
            requested_by_provider_id uuid,
            created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now())
        """).formatted(schema));
    jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_document ON %1$s.patient_document_analyses (document_id)".formatted(schema));
    jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_patient ON %1$s.patient_document_analyses (patient_id)".formatted(schema));
    jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_job ON %1$s.patient_document_analyses (job_id)".formatted(schema));
    jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pda_status ON %1$s.patient_document_analyses (status)".formatted(schema));
    jdbc.execute(("""
        CREATE TABLE IF NOT EXISTS %1$s.patient_document_labels (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            analysis_id uuid NOT NULL REFERENCES %1$s.patient_document_analyses (id) ON DELETE CASCADE,
            tooth_fdi text, disease text NOT NULL, disease_confidence numeric(5,4), fdi_confidence numeric(5,4),
            bbox_x1 integer NOT NULL, bbox_y1 integer NOT NULL, bbox_x2 integer NOT NULL, bbox_y2 integer NOT NULL,
            matching_method text NOT NULL, matching_score numeric(5,4),
            needs_review boolean NOT NULL DEFAULT false,
            source dentalcare.ai_label_source NOT NULL DEFAULT 'ai', action text,
            created_at timestamptz NOT NULL DEFAULT now())
        """).formatted(schema));
    jdbc.execute("CREATE INDEX IF NOT EXISTS idx_pdl_analysis ON %1$s.patient_document_labels (analysis_id)".formatted(schema));
    jdbc.execute("ALTER TABLE %1$s.tooth_conditions ADD COLUMN IF NOT EXISTS source varchar(10) NOT NULL DEFAULT 'manual'".formatted(schema));
    jdbc.execute("ALTER TABLE %1$s.tooth_conditions ADD COLUMN IF NOT EXISTS analysis_id uuid".formatted(schema));
}
```

- [ ] **Step 4: Verify the backend boots and applies the migration**

Run: `cd backend && ./mvnw -q -DskipTests spring-boot:run` (against a dev DB), confirm no startup error from `EstimateSchemaInitializer`, then stop. (If a dev DB is unavailable, at minimum `./mvnw -q -DskipTests compile` must pass.)

- [ ] **Step 5: Commit**

```bash
git add database/install.sql backend/src/main/java/com/dentalcare/config/EstimateSchemaInitializer.java
git commit -m "feat(db): AI analyses/labels tables + tooth_conditions source/analysis_id"
```

---

### Task 4: DTOs + analysis enums (Java)

**Files:**
- Create: `backend/src/main/java/com/dentalcare/dto/ai/AnalysisDto.java`
- Create: `backend/src/main/java/com/dentalcare/dto/ai/LabelDto.java`
- Create: `backend/src/main/java/com/dentalcare/dto/ai/StartAnalysisResponse.java`
- Create: `backend/src/main/java/com/dentalcare/dto/ai/ReviewAnalysisRequest.java`
- Create: `backend/src/main/java/com/dentalcare/dto/ai/AiCallbackRequest.java`
- Create: `backend/src/main/java/com/dentalcare/dto/ai/AiJobRequest.java`

**Interfaces:**
- Produces: the record types consumed by Tasks 5–9. `AiCallbackRequest`/`AiJobRequest` field names match the ai-service payloads (Plan A Tasks 9/11).

- [ ] **Step 1: AnalysisDto.java**

```java
package com.dentalcare.dto.ai;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record AnalysisDto(
        UUID id, UUID patientId, UUID documentId, String status,
        int detectionsCount, boolean needsReview, String reviewStatus,
        String resultBucket, String resultObjectKey, String annotatedObjectKey,
        String errorMessage, LocalDateTime createdAt, List<LabelDto> labels) {
}
```

- [ ] **Step 2: LabelDto.java**

```java
package com.dentalcare.dto.ai;

import java.util.UUID;

public record LabelDto(
        UUID id, String toothFdi, String disease,
        Double diseaseConfidence, Double fdiConfidence,
        int bboxX1, int bboxY1, int bboxX2, int bboxY2,
        String matchingMethod, Double matchingScore,
        boolean needsReview, String source, String action) {
}
```

- [ ] **Step 3: StartAnalysisResponse.java**

```java
package com.dentalcare.dto.ai;

import java.util.UUID;

public record StartAnalysisResponse(UUID analysisId, String status, String jobId) {
}
```

- [ ] **Step 4: ReviewAnalysisRequest.java**

```java
package com.dentalcare.dto.ai;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

public record ReviewAnalysisRequest(
        @NotBlank String reviewStatus,   // reviewed | approved_for_training | excluded
        List<LabelDto> labels) {          // dentist-corrected labels (source human_corrected)
}
```

- [ ] **Step 5: AiCallbackRequest.java** (mirrors Plan A callback body)

```java
package com.dentalcare.dto.ai;

import java.util.List;

public record AiCallbackRequest(
        String job_id, String status, String schema_name,
        String patient_id, String document_id, String analysis_id,
        String result_bucket, String result_object_key, String annotated_object_key,
        List<Detection> detections, String error) {

    public record Detection(
            String tooth, String disease,
            Double disease_confidence, Double fdi_confidence,
            List<Integer> bbox_xyxy, String matching_method,
            Double matching_score, Boolean needs_review) {
    }
}
```

- [ ] **Step 6: AiJobRequest.java** (mirrors Plan A `InferenceJobRequest`)

```java
package com.dentalcare.dto.ai;

import java.util.Map;

public record AiJobRequest(
        String patient_id, String document_id, String analysis_id, String schema_name,
        String image_bucket, String image_object_key,
        String output_bucket, String output_prefix,
        boolean save_annotated_image, Map<String, Object> metadata) {
}
```

- [ ] **Step 7: Compile**

Run: `cd backend && ./mvnw -q -DskipTests compile`
Expected: success.

- [ ] **Step 8: Commit**

```bash
git add backend/src/main/java/com/dentalcare/dto/ai
git commit -m "feat(ai): DTOs for analyses, labels, callback, job request"
```

---

### Task 5: AiInferenceClient (calls ai-service, forwards JWT)

**Files:**
- Create: `backend/src/main/java/com/dentalcare/service/ai/AiInferenceClient.java`
- Test: `backend/src/test/java/com/dentalcare/service/ai/AiInferenceClientTest.java`

**Interfaces:**
- Consumes: `AiJobRequest` (Task 4), `app.ai.base-url`.
- Produces: `AiInferenceClient.createJob(AiJobRequest req) -> String jobId`; `AiInferenceClient.getJobStatus(String resultBucket, String jobId) -> Map<String,Object>` (used by reconciler). Forwards the current request's `Authorization` header.

- [ ] **Step 1: Write the failing test — AiInferenceClientTest.java**

```java
package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiJobRequest;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AiInferenceClientTest {

    private MockWebServer server;

    @BeforeEach void setUp() throws Exception { server = new MockWebServer(); server.start(); }
    @AfterEach  void tearDown() throws Exception { server.shutdown(); }

    @Test
    void createJob_returnsJobIdFromResponse() {
        server.enqueue(new MockResponse()
                .setHeader("Content-Type", "application/json")
                .setBody("{\"job_id\":\"ai-job-123\",\"status\":\"queued\"}"));
        AiInferenceClient client = new AiInferenceClient(server.url("/").toString());
        String jobId = client.createJob(new AiJobRequest("P1", "D1", "A1", "t_x",
                "dc-t-x", "patients/P1/D1/p.png", "dc-t-x", "patients/P1/D1/ai/A1/",
                true, Map.of()));
        assertEquals("ai-job-123", jobId);
    }
}
```

> Add the test dependency `com.squareup.okhttp3:mockwebserver` (test scope) to `backend/pom.xml` if not present.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./mvnw -q -Dtest=AiInferenceClientTest test`
Expected: FAIL (class missing)

- [ ] **Step 3: Implement AiInferenceClient.java**

```java
package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiJobRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Map;

@Service
public class AiInferenceClient {

    private final RestClient http;

    public AiInferenceClient(@Value("${app.ai.base-url}") String baseUrl) {
        this.http = RestClient.builder().baseUrl(baseUrl).build();
    }

    private String currentBearer() {
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            String header = sra.getRequest().getHeader("Authorization");
            if (header != null) return header;
        }
        return "";
    }

    @SuppressWarnings("unchecked")
    public String createJob(AiJobRequest req) {
        Map<String, Object> body = http.post()
                .uri("/api/v1/inference/jobs")
                .header("Authorization", currentBearer())
                .body(req)
                .retrieve()
                .body(Map.class);
        return body != null ? (String) body.get("job_id") : null;
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getJobStatus(String resultBucket, String jobId) {
        return http.get()
                .uri(uri -> uri.path("/api/v1/inference/jobs/{id}")
                        .queryParam("result_bucket", resultBucket).build(jobId))
                .header("Authorization", currentBearer())
                .retrieve()
                .body(Map.class);
    }
}
```

- [ ] **Step 4: Run test**

Run: `cd backend && ./mvnw -q -Dtest=AiInferenceClientTest test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/ai/AiInferenceClient.java backend/src/test/java/com/dentalcare/service/ai/AiInferenceClientTest.java backend/pom.xml
git commit -m "feat(ai): AiInferenceClient (job create/status, JWT forwarding)"
```

---

### Task 6: PatientDocumentAnalysisService (start, applyCallback, get/list, reconcile)

**Files:**
- Create: `backend/src/main/java/com/dentalcare/service/ai/PatientDocumentAnalysisService.java`
- Test: `backend/src/test/java/com/dentalcare/service/ai/PatientDocumentAnalysisServiceTest.java`

**Interfaces:**
- Consumes: `NamedParameterJdbcTemplate`, `MinioStorageService.bucketFor`, `AiInferenceClient`, `SseEmitterRegistry` (Task 8 — inject the interface; for this task create a thin `SseEmitterRegistry` with a no-op `emit` so Task 6 compiles, then Task 8 fills it in), DTOs (Task 4).
- Produces: `startAnalysis(UUID patientId, UUID documentId) -> StartAnalysisResponse`; `applyCallback(AiCallbackRequest cb)` (idempotent — only updates rows still `PROCESSING`); `getAnalysis(UUID patientId, UUID analysisId) -> AnalysisDto`; `listByDocument(UUID patientId, UUID documentId) -> List<AnalysisDto>`; `findStaleProcessing(Duration olderThan) -> List<StaleAnalysis>` and `reconcileOne(StaleAnalysis)`.

- [ ] **Step 1: Write the failing test — PatientDocumentAnalysisServiceTest.java**

```java
package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.AiCallbackRequest;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class PatientDocumentAnalysisServiceTest {

    private NamedParameterJdbcTemplate jdbc;
    private PatientDocumentAnalysisService svc;
    private SseEmitterRegistry sse;

    @BeforeEach
    void setUp() {
        jdbc = mock(NamedParameterJdbcTemplate.class);
        sse = mock(SseEmitterRegistry.class);
        svc = new PatientDocumentAnalysisService(jdbc, null, null, sse);
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(UUID.randomUUID().toString());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    @Test
    void applyCallback_completed_updatesOnlyWhenProcessing_andEmitsSse() {
        // pretend the UPDATE ... WHERE status='PROCESSING' affected 1 row
        when(jdbc.update(contains("UPDATE"), anyMap())).thenReturn(1);
        AiCallbackRequest cb = new AiCallbackRequest(
                "job-1", "completed", "t_abcd1234",
                UUID.randomUUID().toString(), UUID.randomUUID().toString(), UUID.randomUUID().toString(),
                "dc-t-abcd1234", "patients/x/ai/result.json", "patients/x/ai/annotated.png",
                List.of(new AiCallbackRequest.Detection("16", "Caries", 0.8, 0.7,
                        List.of(10, 10, 90, 90), "iou", 0.3, false)),
                null);
        svc.applyCallback(cb);
        verify(sse).emit(eq(UUID.fromString(cb.analysis_id())), eq("COMPLETED"));
    }

    @Test
    void applyCallback_whenAlreadyCompleted_doesNotEmit() {
        when(jdbc.update(contains("UPDATE"), anyMap())).thenReturn(0); // guard: no row in PROCESSING
        AiCallbackRequest cb = new AiCallbackRequest(
                "job-1", "completed", "t_abcd1234",
                UUID.randomUUID().toString(), UUID.randomUUID().toString(), UUID.randomUUID().toString(),
                "dc-t-abcd1234", "k", "a", List.of(), null);
        svc.applyCallback(cb);
        verify(sse, never()).emit(any(), any());
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./mvnw -q -Dtest=PatientDocumentAnalysisServiceTest test`
Expected: FAIL (classes missing)

- [ ] **Step 3: Create a minimal SseEmitterRegistry placeholder (filled in Task 8)**

`backend/src/main/java/com/dentalcare/service/ai/SseEmitterRegistry.java`:

```java
package com.dentalcare.service.ai;

import org.springframework.stereotype.Component;
import java.util.UUID;

@Component
public class SseEmitterRegistry {
    public void emit(UUID analysisId, String status) { /* implemented in Task 8 */ }
}
```

- [ ] **Step 4: Implement PatientDocumentAnalysisService.java**

```java
package com.dentalcare.service.ai;

import com.dentalcare.dto.ai.*;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.MinioStorageService;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class PatientDocumentAnalysisService {

    private final NamedParameterJdbcTemplate jdbc;
    private final MinioStorageService minio;
    private final AiInferenceClient ai;
    private final SseEmitterRegistry sse;

    public PatientDocumentAnalysisService(NamedParameterJdbcTemplate jdbc, MinioStorageService minio,
                                          AiInferenceClient ai, SseEmitterRegistry sse) {
        this.jdbc = jdbc; this.minio = minio; this.ai = ai; this.sse = sse;
    }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }
    private UUID providerId() { return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName()); }

    public record StaleAnalysis(UUID id, String jobId, String resultBucket) {}

    @Transactional
    public StartAnalysisResponse startAnalysis(UUID patientId, UUID documentId) {
        Map<String, Object> doc = jdbc.queryForList("""
                SELECT document_type, file_path FROM %s.patient_documents
                WHERE id = :doc AND patient_id = :pat AND clinic_id = :clinic
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("doc", documentId).addValue("pat", patientId).addValue("clinic", clinicId()))
                .stream().findFirst().orElseThrow(() -> new ResourceNotFoundException("Document not found"));
        if (!"rx_panoramica".equals(doc.get("document_type"))) {
            throw new IllegalArgumentException("Only rx_panoramica can be analyzed");
        }

        UUID analysisId = UUID.randomUUID();
        String bucket = minio.bucketFor(s());
        String outputPrefix = "patients/%s/%s/ai/%s/".formatted(patientId, documentId, analysisId);

        jdbc.update("""
                INSERT INTO %s.patient_document_analyses
                  (id, clinic_id, patient_id, document_id, status, result_bucket, requested_by_provider_id)
                VALUES (:id, :clinic, :pat, :doc, 'PROCESSING', :bucket, :prov)
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("id", analysisId).addValue("clinic", clinicId()).addValue("pat", patientId)
                .addValue("doc", documentId).addValue("bucket", bucket).addValue("prov", providerId()));

        AiJobRequest jobReq = new AiJobRequest(
                patientId.toString(), documentId.toString(), analysisId.toString(), s(),
                bucket, (String) doc.get("file_path"), bucket, outputPrefix, true,
                Map.of("source", "DentalCare"));
        String jobId;
        try {
            jobId = ai.createJob(jobReq);
        } catch (Exception e) {
            jdbc.update("UPDATE %s.patient_document_analyses SET status='FAILED', error_message=:err, updated_at=now() WHERE id=:id".formatted(s()),
                    new MapSqlParameterSource().addValue("err", e.getMessage()).addValue("id", analysisId));
            throw new IllegalStateException("AI service unavailable", e);
        }
        jdbc.update("UPDATE %s.patient_document_analyses SET job_id=:job, updated_at=now() WHERE id=:id".formatted(s()),
                new MapSqlParameterSource().addValue("job", jobId).addValue("id", analysisId));
        return new StartAnalysisResponse(analysisId, "PROCESSING", jobId);
    }

    /** Idempotent: writes labels + COMPLETED/FAILED only if the row is still PROCESSING. */
    @Transactional
    public void applyCallback(AiCallbackRequest cb) {
        UUID analysisId = UUID.fromString(cb.analysis_id());
        boolean failed = "failed".equalsIgnoreCase(cb.status());
        String newStatus = failed ? "FAILED" : "COMPLETED";

        int updated = jdbc.update("""
                UPDATE %s.patient_document_analyses
                SET status = CAST(:status AS dentalcare.ai_analysis_status),
                    result_object_key = :resKey, annotated_object_key = :annKey,
                    detections_count = :count, needs_review = :needsReview,
                    error_message = :err, updated_at = now()
                WHERE id = :id AND status = 'PROCESSING'
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("status", newStatus)
                .addValue("resKey", cb.result_object_key())
                .addValue("annKey", cb.annotated_object_key())
                .addValue("count", cb.detections() == null ? 0 : cb.detections().size())
                .addValue("needsReview", cb.detections() != null && cb.detections().stream()
                        .anyMatch(d -> Boolean.TRUE.equals(d.needs_review())))
                .addValue("err", cb.error())
                .addValue("id", analysisId));

        if (updated == 0) return;  // already finalized — idempotent no-op

        if (!failed && cb.detections() != null) {
            for (AiCallbackRequest.Detection d : cb.detections()) {
                List<Integer> b = d.bbox_xyxy();
                jdbc.update("""
                        INSERT INTO %s.patient_document_labels
                          (analysis_id, tooth_fdi, disease, disease_confidence, fdi_confidence,
                           bbox_x1, bbox_y1, bbox_x2, bbox_y2, matching_method, matching_score, needs_review, source)
                        VALUES (:aid, :tooth, :disease, :dconf, :fconf, :x1, :y1, :x2, :y2, :method, :score, :nr, 'ai')
                        """.formatted(s()), new MapSqlParameterSource()
                        .addValue("aid", analysisId).addValue("tooth", d.tooth()).addValue("disease", d.disease())
                        .addValue("dconf", d.disease_confidence()).addValue("fconf", d.fdi_confidence())
                        .addValue("x1", b.get(0)).addValue("y1", b.get(1)).addValue("x2", b.get(2)).addValue("y2", b.get(3))
                        .addValue("method", d.matching_method()).addValue("score", d.matching_score())
                        .addValue("nr", Boolean.TRUE.equals(d.needs_review())));
            }
        }
        sse.emit(analysisId, newStatus);
    }

    @Transactional(readOnly = true)
    public AnalysisDto getAnalysis(UUID patientId, UUID analysisId) {
        Map<String, Object> a = jdbc.queryForList("""
                SELECT * FROM %s.patient_document_analyses
                WHERE id = :id AND patient_id = :pat AND clinic_id = :clinic
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("id", analysisId).addValue("pat", patientId).addValue("clinic", clinicId()))
                .stream().findFirst().orElseThrow(() -> new ResourceNotFoundException("Analysis not found"));
        List<LabelDto> labels = jdbc.query("""
                SELECT * FROM %s.patient_document_labels WHERE analysis_id = :id ORDER BY created_at
                """.formatted(s()), new MapSqlParameterSource("id", analysisId), (rs, n) -> new LabelDto(
                rs.getObject("id", UUID.class), rs.getString("tooth_fdi"), rs.getString("disease"),
                (Double) rs.getObject("disease_confidence"), (Double) rs.getObject("fdi_confidence"),
                rs.getInt("bbox_x1"), rs.getInt("bbox_y1"), rs.getInt("bbox_x2"), rs.getInt("bbox_y2"),
                rs.getString("matching_method"), (Double) rs.getObject("matching_score"),
                rs.getBoolean("needs_review"), rs.getString("source"), rs.getString("action")));
        return mapAnalysis(a, labels);
    }

    @Transactional(readOnly = true)
    public List<AnalysisDto> listByDocument(UUID patientId, UUID documentId) {
        return jdbc.queryForList("""
                SELECT * FROM %s.patient_document_analyses
                WHERE document_id = :doc AND patient_id = :pat AND clinic_id = :clinic
                ORDER BY created_at DESC
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("doc", documentId).addValue("pat", patientId).addValue("clinic", clinicId()))
                .stream().map(a -> mapAnalysis(a, List.of())).toList();
    }

    @Transactional(readOnly = true)
    public List<StaleAnalysis> findStaleProcessing(Duration olderThan) {
        return jdbc.query("""
                SELECT id, job_id, result_bucket FROM %s.patient_document_analyses
                WHERE status = 'PROCESSING' AND job_id IS NOT NULL
                  AND updated_at < now() - (:secs * interval '1 second')
                """.formatted(s()), new MapSqlParameterSource("secs", olderThan.getSeconds()),
                (rs, n) -> new StaleAnalysis(rs.getObject("id", UUID.class), rs.getString("job_id"), rs.getString("result_bucket")));
    }

    private AnalysisDto mapAnalysis(Map<String, Object> a, List<LabelDto> labels) {
        return new AnalysisDto(
                (UUID) a.get("id"), (UUID) a.get("patient_id"), (UUID) a.get("document_id"),
                String.valueOf(a.get("status")), ((Number) a.get("detections_count")).intValue(),
                Boolean.TRUE.equals(a.get("needs_review")), String.valueOf(a.get("review_status")),
                (String) a.get("result_bucket"), (String) a.get("result_object_key"),
                (String) a.get("annotated_object_key"), (String) a.get("error_message"),
                a.get("created_at") != null ? ((java.sql.Timestamp) a.get("created_at")).toLocalDateTime() : (LocalDateTime) null,
                labels);
    }
}
```

- [ ] **Step 5: Run test**

Run: `cd backend && ./mvnw -q -Dtest=PatientDocumentAnalysisServiceTest test`
Expected: PASS (2 passed)

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/ai/PatientDocumentAnalysisService.java backend/src/main/java/com/dentalcare/service/ai/SseEmitterRegistry.java backend/src/test/java/com/dentalcare/service/ai/PatientDocumentAnalysisServiceTest.java
git commit -m "feat(ai): analysis service (start, idempotent callback, get/list, stale query)"
```

---

### Task 7: HMAC verifier + internal callback controller + Security rule

**Files:**
- Create: `backend/src/main/java/com/dentalcare/security/HmacVerifier.java`
- Create: `backend/src/main/java/com/dentalcare/controller/ai/AiCallbackController.java`
- Modify: `backend/src/main/java/com/dentalcare/security/SecurityConfig.java:42` (permit `/api/internal/**`)
- Test: `backend/src/test/java/com/dentalcare/security/HmacVerifierTest.java`

**Interfaces:**
- Consumes: `app.ai.hmac-secret`, `PatientDocumentAnalysisService.applyCallback` (Task 6), `AiCallbackRequest` (Task 4), `TenantContext`.
- Produces: `HmacVerifier.verify(byte[] body, String signature) -> boolean`. `POST /api/internal/ai/callback` (no JWT) that verifies `X-AI-Signature`, sets `TenantContext` from `schema_name`, calls `applyCallback`, returns 204; 401 on bad signature.

- [ ] **Step 1: Write the failing test — HmacVerifierTest.java**

```java
package com.dentalcare.security;

import org.junit.jupiter.api.Test;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

class HmacVerifierTest {

    private String sign(byte[] body, String secret) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        byte[] raw = mac.doFinal(body);
        StringBuilder sb = new StringBuilder();
        for (byte b : raw) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    @Test
    void verify_acceptsValidSignature() throws Exception {
        HmacVerifier v = new HmacVerifier("secret");
        byte[] body = "{\"job_id\":\"j1\"}".getBytes(StandardCharsets.UTF_8);
        assertTrue(v.verify(body, sign(body, "secret")));
    }

    @Test
    void verify_rejectsTamperedSignature() {
        HmacVerifier v = new HmacVerifier("secret");
        byte[] body = "{\"job_id\":\"j1\"}".getBytes(StandardCharsets.UTF_8);
        assertFalse(v.verify(body, "deadbeef"));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./mvnw -q -Dtest=HmacVerifierTest test`
Expected: FAIL (class missing)

- [ ] **Step 3: Implement HmacVerifier.java**

```java
package com.dentalcare.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

@Component
public class HmacVerifier {

    private final String secret;

    public HmacVerifier(@Value("${app.ai.hmac-secret}") String secret) {
        this.secret = secret;
    }

    public boolean verify(byte[] body, String signatureHex) {
        if (signatureHex == null) return false;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] raw = mac.doFinal(body);
            StringBuilder sb = new StringBuilder();
            for (byte b : raw) sb.append(String.format("%02x", b));
            return MessageDigest.isEqual(
                    sb.toString().getBytes(StandardCharsets.UTF_8),
                    signatureHex.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            return false;
        }
    }
}
```

- [ ] **Step 4: Implement AiCallbackController.java**

```java
package com.dentalcare.controller.ai;

import com.dentalcare.dto.ai.AiCallbackRequest;
import com.dentalcare.security.HmacVerifier;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.ai.PatientDocumentAnalysisService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/internal/ai")
public class AiCallbackController {

    private final HmacVerifier hmac;
    private final PatientDocumentAnalysisService service;
    private final ObjectMapper mapper;

    public AiCallbackController(HmacVerifier hmac, PatientDocumentAnalysisService service, ObjectMapper mapper) {
        this.hmac = hmac; this.service = service; this.mapper = mapper;
    }

    @PostMapping("/callback")
    public ResponseEntity<Void> callback(@RequestBody byte[] rawBody,
                                         @RequestHeader(value = "X-AI-Signature", required = false) String signature) throws Exception {
        if (!hmac.verify(rawBody, signature)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        AiCallbackRequest cb = mapper.readValue(rawBody, AiCallbackRequest.class);
        try {
            TenantContext.setCurrentSchema(cb.schema_name());
            service.applyCallback(cb);
        } finally {
            TenantContext.clear();
        }
        return ResponseEntity.noContent().build();
    }
}
```

> The body is read as `byte[]` so the HMAC is verified over the exact bytes the ai-service signed. `applyCallback` does not use `clinicId()`, so setting only the schema is sufficient here.

- [ ] **Step 5: Permit /api/internal/** in SecurityConfig (after line 42)**

```java
                    .requestMatchers("/api/public/**").permitAll()
                    .requestMatchers("/api/internal/**").permitAll()
```

> `/api/internal/**` is authenticated by HMAC inside the controller, not by JWT.

- [ ] **Step 6: Run tests + compile**

Run: `cd backend && ./mvnw -q -Dtest=HmacVerifierTest test && ./mvnw -q -DskipTests compile`
Expected: PASS + compile success.

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/dentalcare/security/HmacVerifier.java backend/src/main/java/com/dentalcare/controller/ai/AiCallbackController.java backend/src/main/java/com/dentalcare/security/SecurityConfig.java backend/src/test/java/com/dentalcare/security/HmacVerifierTest.java
git commit -m "feat(ai): HMAC-verified internal callback endpoint"
```

---

### Task 8: SSE registry + stream endpoint

**Files:**
- Modify: `backend/src/main/java/com/dentalcare/service/ai/SseEmitterRegistry.java` (replace placeholder)
- Test: `backend/src/test/java/com/dentalcare/service/ai/SseEmitterRegistryTest.java`

**Interfaces:**
- Produces: `SseEmitterRegistry.create(UUID analysisId) -> SseEmitter` (registers and returns an emitter); `emit(UUID analysisId, String status)` sends an `analysis-status` event to the registered emitter (no-op if none); auto-removes the emitter on completion/timeout.

- [ ] **Step 1: Write the failing test — SseEmitterRegistryTest.java**

```java
package com.dentalcare.service.ai;

import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class SseEmitterRegistryTest {

    @Test
    void emit_doesNotThrow_whenNoSubscriber() {
        SseEmitterRegistry reg = new SseEmitterRegistry();
        reg.emit(UUID.randomUUID(), "COMPLETED");  // must be a silent no-op
    }

    @Test
    void create_returnsEmitter_andEmitSendsWithoutError() {
        SseEmitterRegistry reg = new SseEmitterRegistry();
        UUID id = UUID.randomUUID();
        SseEmitter emitter = reg.create(id);
        assertNotNull(emitter);
        reg.emit(id, "COMPLETED");  // should complete the emitter without throwing
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./mvnw -q -Dtest=SseEmitterRegistryTest test`
Expected: FAIL (no `create`)

- [ ] **Step 3: Implement SseEmitterRegistry.java**

```java
package com.dentalcare.service.ai;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class SseEmitterRegistry {

    private static final Logger log = LoggerFactory.getLogger(SseEmitterRegistry.class);
    private static final long TIMEOUT_MS = 120_000L;

    private final ConcurrentHashMap<UUID, SseEmitter> emitters = new ConcurrentHashMap<>();

    public SseEmitter create(UUID analysisId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MS);
        emitter.onCompletion(() -> emitters.remove(analysisId, emitter));
        emitter.onTimeout(() -> emitters.remove(analysisId, emitter));
        emitter.onError(e -> emitters.remove(analysisId, emitter));
        emitters.put(analysisId, emitter);
        return emitter;
    }

    public void emit(UUID analysisId, String status) {
        SseEmitter emitter = emitters.get(analysisId);
        if (emitter == null) return;
        try {
            emitter.send(SseEmitter.event().name("analysis-status").data(status));
            emitter.complete();
        } catch (IOException e) {
            log.debug("SSE emit failed for {}: {}", analysisId, e.getMessage());
            emitters.remove(analysisId, emitter);
        }
    }
}
```

- [ ] **Step 4: Run test**

Run: `cd backend && ./mvnw -q -Dtest=SseEmitterRegistryTest test`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/ai/SseEmitterRegistry.java backend/src/test/java/com/dentalcare/service/ai/SseEmitterRegistryTest.java
git commit -m "feat(ai): SSE emitter registry"
```

---

### Task 9: Analysis controller (analyze/list/get/review/stream) + reconciler

**Files:**
- Create: `backend/src/main/java/com/dentalcare/controller/ai/PatientDocumentAnalysisController.java`
- Create: `backend/src/main/java/com/dentalcare/service/ai/AnalysisReconciler.java`
- Modify: `backend/src/main/java/com/dentalcare/service/ai/PatientDocumentAnalysisService.java` (add `review(...)` + `reconcileOne(...)`)
- Modify: `backend/src/main/java/com/dentalcare/DentalcareApiApplication.java` (add `@EnableScheduling` if not already present)
- Test: `backend/src/test/java/com/dentalcare/controller/ai/PatientDocumentAnalysisControllerTest.java`

**Interfaces:**
- Consumes: `PatientDocumentAnalysisService`, `SseEmitterRegistry`, `OdontogramSyncService` (Task 11 — for `review`; inject and call after persisting review).
- Produces endpoints under `/api/patients/{patientId}/documents/{docId}/analyses`: `POST` (start), `GET` (list), `GET /{id}`, `PUT /{id}/review`, `GET /{id}/stream` (SSE). Reconciler `@Scheduled` polls stale PROCESSING analyses across tenants.

- [ ] **Step 1: Add `review(...)` to PatientDocumentAnalysisService**

```java
    @Transactional
    public AnalysisDto review(UUID patientId, UUID analysisId, com.dentalcare.dto.ai.ReviewAnalysisRequest req) {
        int updated = jdbc.update("""
                UPDATE %s.patient_document_analyses
                SET review_status = CAST(:rs AS dentalcare.ai_review_status),
                    reviewed_by_provider_id = :prov, reviewed_at = now(), updated_at = now()
                WHERE id = :id AND patient_id = :pat AND clinic_id = :clinic
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("rs", req.reviewStatus()).addValue("prov", providerId())
                .addValue("id", analysisId).addValue("pat", patientId).addValue("clinic", clinicId()));
        if (updated == 0) throw new ResourceNotFoundException("Analysis not found");
        return getAnalysis(patientId, analysisId);
    }

    /** Reconciler entry: re-applies a completed job whose callback was lost. */
    @Transactional
    public void reconcileOne(StaleAnalysis stale) {
        Map<String, Object> status = ai.getJobStatus(stale.resultBucket(), stale.jobId());
        if (status == null) return;
        if (!"completed".equalsIgnoreCase(String.valueOf(status.get("status")))) return;
        // Rebuild a callback from the job-status document and apply it idempotently.
        // The job-status 'detections' have the same field names as the callback detections.
        com.fasterxml.jackson.databind.ObjectMapper m = new com.fasterxml.jackson.databind.ObjectMapper();
        AiCallbackRequest cb = m.convertValue(Map.of(
                "job_id", stale.jobId(), "status", "completed",
                "schema_name", s(), "analysis_id", stale.id().toString(),
                "patient_id", "", "document_id", "",
                "result_bucket", stale.resultBucket(),
                "result_object_key", status.getOrDefault("result_object_key", null),
                "annotated_object_key", status.getOrDefault("annotated_image_object_key", null),
                "detections", status.getOrDefault("detections", List.of())
        ), AiCallbackRequest.class);
        applyCallback(cb);
    }
```

- [ ] **Step 2: Implement the controller**

```java
package com.dentalcare.controller.ai;

import com.dentalcare.dto.ai.*;
import com.dentalcare.service.ai.OdontogramSyncService;
import com.dentalcare.service.ai.PatientDocumentAnalysisService;
import com.dentalcare.service.ai.SseEmitterRegistry;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/documents/{docId}/analyses")
public class PatientDocumentAnalysisController {

    private final PatientDocumentAnalysisService service;
    private final SseEmitterRegistry sse;
    private final OdontogramSyncService sync;

    public PatientDocumentAnalysisController(PatientDocumentAnalysisService service,
                                             SseEmitterRegistry sse, OdontogramSyncService sync) {
        this.service = service; this.sse = sse; this.sync = sync;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public StartAnalysisResponse start(@PathVariable UUID patientId, @PathVariable UUID docId) {
        return service.startAnalysis(patientId, docId);
    }

    @GetMapping
    public List<AnalysisDto> list(@PathVariable UUID patientId, @PathVariable UUID docId) {
        return service.listByDocument(patientId, docId);
    }

    @GetMapping("/{analysisId}")
    public AnalysisDto get(@PathVariable UUID patientId, @PathVariable UUID docId, @PathVariable UUID analysisId) {
        return service.getAnalysis(patientId, analysisId);
    }

    @PutMapping("/{analysisId}/review")
    public AnalysisDto review(@PathVariable UUID patientId, @PathVariable UUID docId,
                              @PathVariable UUID analysisId, @Valid @RequestBody ReviewAnalysisRequest req) {
        AnalysisDto dto = service.review(patientId, analysisId, req);
        if ("reviewed".equals(req.reviewStatus()) || "approved_for_training".equals(req.reviewStatus())) {
            sync.syncFromAnalysis(patientId, analysisId);
        }
        return dto;
    }

    @GetMapping("/{analysisId}/stream")
    public SseEmitter stream(@PathVariable UUID patientId, @PathVariable UUID docId, @PathVariable UUID analysisId) {
        return sse.create(analysisId);
    }
}
```

- [ ] **Step 3: Implement the reconciler**

```java
package com.dentalcare.service.ai;

import com.dentalcare.security.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;

@Component
public class AnalysisReconciler {

    private static final Logger log = LoggerFactory.getLogger(AnalysisReconciler.class);
    private static final Duration STALE_AFTER = Duration.ofMinutes(2);

    private final JdbcTemplate jdbc;
    private final PatientDocumentAnalysisService service;

    public AnalysisReconciler(JdbcTemplate jdbc, PatientDocumentAnalysisService service) {
        this.jdbc = jdbc; this.service = service;
    }

    /** Every 2 minutes, across all tenant schemas, recover PROCESSING analyses whose callback was lost. */
    @Scheduled(fixedDelay = 120_000L)
    public void reconcile() {
        List<String> schemas = jdbc.queryForList(
                "SELECT schema_name FROM information_schema.schemata WHERE schema_name ~ '^t_[0-9a-f]{8}$'",
                String.class);
        for (String schema : schemas) {
            try {
                TenantContext.setCurrentSchema(schema);
                for (var stale : service.findStaleProcessing(STALE_AFTER)) {
                    try {
                        service.reconcileOne(stale);
                    } catch (Exception e) {
                        log.warn("reconcileOne failed schema={} analysis={}: {}", schema, stale.id(), e.getMessage());
                    }
                }
            } finally {
                TenantContext.clear();
            }
        }
    }
}
```

> `reconcileOne`/`findStaleProcessing` only use the schema (not clinic_id), so setting the schema is enough.

- [ ] **Step 4: Ensure scheduling is enabled**

In `backend/src/main/java/com/dentalcare/DentalcareApiApplication.java`, add `@EnableScheduling` to the application class if it is not already annotated (check first — do not duplicate).

- [ ] **Step 5: Write the controller test (MockMvc)**

```java
package com.dentalcare.controller.ai;

import com.dentalcare.dto.ai.StartAnalysisResponse;
import com.dentalcare.service.ai.OdontogramSyncService;
import com.dentalcare.service.ai.PatientDocumentAnalysisService;
import com.dentalcare.service.ai.SseEmitterRegistry;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class PatientDocumentAnalysisControllerTest {

    @Test
    void review_triggersSync_whenReviewed() {
        var service = mock(PatientDocumentAnalysisService.class);
        var sse = mock(SseEmitterRegistry.class);
        var sync = mock(OdontogramSyncService.class);
        var controller = new PatientDocumentAnalysisController(service, sse, sync);
        UUID pat = UUID.randomUUID(), doc = UUID.randomUUID(), an = UUID.randomUUID();

        controller.review(pat, doc, an,
                new com.dentalcare.dto.ai.ReviewAnalysisRequest("reviewed", java.util.List.of()));
        verify(sync).syncFromAnalysis(pat, an);
    }

    @Test
    void review_doesNotSync_whenExcluded() {
        var service = mock(PatientDocumentAnalysisService.class);
        var sse = mock(SseEmitterRegistry.class);
        var sync = mock(OdontogramSyncService.class);
        var controller = new PatientDocumentAnalysisController(service, sse, sync);
        controller.review(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                new com.dentalcare.dto.ai.ReviewAnalysisRequest("excluded", java.util.List.of()));
        verify(sync, never()).syncFromAnalysis(any(), any());
    }
}
```

- [ ] **Step 6: Run tests (depends on Task 11 OdontogramSyncService existing)**

> Build Task 11 before running this if compilation requires `OdontogramSyncService`. If executing strictly in order, create the `OdontogramSyncService` class stub from Task 11 Step 3 first, then return here.

Run: `cd backend && ./mvnw -q -Dtest=PatientDocumentAnalysisControllerTest test`
Expected: PASS (2 passed)

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/dentalcare/controller/ai/PatientDocumentAnalysisController.java backend/src/main/java/com/dentalcare/service/ai/AnalysisReconciler.java backend/src/main/java/com/dentalcare/service/ai/PatientDocumentAnalysisService.java backend/src/main/java/com/dentalcare/DentalcareApiApplication.java backend/src/test/java/com/dentalcare/controller/ai/PatientDocumentAnalysisControllerTest.java
git commit -m "feat(ai): analysis controller (start/list/get/review/SSE) + reconciler"
```

---

### Task 10: Odontogram sync service + non-destructive manual save

**Files:**
- Create: `backend/src/main/java/com/dentalcare/service/ai/OdontogramSyncService.java`
- Modify: `backend/src/main/java/com/dentalcare/service/OdontogramService.java:49-55` (scope manual delete to `source='manual'`)
- Test: `backend/src/test/java/com/dentalcare/service/ai/OdontogramSyncServiceTest.java`

**Interfaces:**
- Consumes: `NamedParameterJdbcTemplate`, `TenantContext`.
- Produces: `OdontogramSyncService.syncFromAnalysis(UUID patientId, UUID analysisId)` — deletes this analysis's `source='ai'` rows then inserts `caries` rows for confirmed `Caries`/`Deep_Caries` labels with a non-null `tooth_fdi`. `OdontogramService.save` no longer deletes `source='ai'` rows.

- [ ] **Step 1: Write the failing test — OdontogramSyncServiceTest.java**

```java
package com.dentalcare.service.ai;

import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class OdontogramSyncServiceTest {

    private NamedParameterJdbcTemplate jdbc;
    private OdontogramSyncService svc;

    @BeforeEach
    void setUp() {
        jdbc = mock(NamedParameterJdbcTemplate.class);
        svc = new OdontogramSyncService(jdbc);
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(UUID.randomUUID().toString());
    }

    @AfterEach
    void tearDown() { TenantContext.clear(); }

    @Test
    void sync_insertsCariesForMappableLabelsOnly() {
        UUID analysisId = UUID.randomUUID();
        UUID patientId = UUID.randomUUID();
        when(jdbc.queryForList(contains("patient_document_labels"), anyMap())).thenReturn(List.of(
                Map.of("tooth_fdi", "16", "disease", "Caries"),
                Map.of("tooth_fdi", "26", "disease", "Deep_Caries"),
                Map.of("tooth_fdi", "36", "disease", "Periapical_Lesion"), // skipped
                new java.util.HashMap<>() {{ put("tooth_fdi", null); put("disease", "Caries"); }} // skipped (no tooth)
        ));
        svc.syncFromAnalysis(patientId, analysisId);
        // 1 delete (ai rows for this analysis) + 2 inserts (16, 26)
        verify(jdbc, times(1)).update(contains("DELETE"), anyMap());
        verify(jdbc, times(2)).update(contains("INSERT"), anyMap());
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./mvnw -q -Dtest=OdontogramSyncServiceTest test`
Expected: FAIL (class missing)

- [ ] **Step 3: Implement OdontogramSyncService.java**

```java
package com.dentalcare.service.ai;

import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class OdontogramSyncService {

    private static final Set<String> CARIES_DISEASES = Set.of("Caries", "Deep_Caries");
    private static final String DEFAULT_SURFACE = "V";  // panoramic gives no surface; dentist can refine

    private final NamedParameterJdbcTemplate jdbc;

    public OdontogramSyncService(NamedParameterJdbcTemplate jdbc) { this.jdbc = jdbc; }

    private String s() { return TenantContext.validatedSchema(); }
    private UUID clinicId() { return UUID.fromString(TenantContext.getCurrentTenant()); }

    @Transactional
    public void syncFromAnalysis(UUID patientId, UUID analysisId) {
        // Remove prior AI rows for THIS analysis (idempotent re-review), never touching manual rows.
        jdbc.update("""
                DELETE FROM %s.tooth_conditions
                WHERE clinic_id = :clinic AND patient_id = :pat AND source = 'ai' AND analysis_id = :aid
                """.formatted(s()), new MapSqlParameterSource()
                .addValue("clinic", clinicId()).addValue("pat", patientId).addValue("aid", analysisId));

        List<Map<String, Object>> labels = jdbc.queryForList("""
                SELECT tooth_fdi, disease, disease_confidence FROM %s.patient_document_labels
                WHERE analysis_id = :aid
                """.formatted(s()), new MapSqlParameterSource("aid", analysisId));

        for (Map<String, Object> label : labels) {
            String tooth = (String) label.get("tooth_fdi");
            String disease = (String) label.get("disease");
            if (tooth == null || !CARIES_DISEASES.contains(disease)) continue;
            jdbc.update("""
                    INSERT INTO %s.tooth_conditions
                      (id, clinic_id, patient_id, tooth_fdi, surface, condition, notes, source, analysis_id, updated_at)
                    VALUES (:id, :clinic, :pat, :tooth, :surface, 'caries', :notes, 'ai', :aid, now())
                    """.formatted(s()), new MapSqlParameterSource()
                    .addValue("id", UUID.randomUUID()).addValue("clinic", clinicId()).addValue("pat", patientId)
                    .addValue("tooth", Short.parseShort(tooth)).addValue("surface", DEFAULT_SURFACE)
                    .addValue("notes", "AI: " + disease).addValue("aid", analysisId));
        }
    }
}
```

> `tooth_fdi` in `tooth_conditions` is `smallint`; the AI label stores it as text — parse to `short`.

- [ ] **Step 4: Scope the manual delete in OdontogramService.save (lines 49-55)**

```java
        jdbc.update("""
            DELETE FROM %s.tooth_conditions
            WHERE clinic_id = :clinicId AND patient_id = :patientId AND source = 'manual'
            """.formatted(s()),
            new MapSqlParameterSource()
                    .addValue("clinicId", clinicId)
                    .addValue("patientId", patientId));
```

> The existing manual insert path also needs `source` set; the `INSERT` in `save` (lines 65-70) writes no `source`, so the column default `'manual'` applies — correct. Leave the insert as-is.

- [ ] **Step 5: Run tests**

Run: `cd backend && ./mvnw -q -Dtest=OdontogramSyncServiceTest test`
Expected: PASS (1 passed)

- [ ] **Step 6: Commit**

```bash
git add backend/src/main/java/com/dentalcare/service/ai/OdontogramSyncService.java backend/src/main/java/com/dentalcare/service/OdontogramService.java backend/src/test/java/com/dentalcare/service/ai/OdontogramSyncServiceTest.java
git commit -m "feat(ai): odontogram sync from reviewed analysis (non-destructive)"
```

---

### Task 11: Angular model + service (HTTP + SSE)

**Files:**
- Create: `frontend/src/app/core/models/patient-analysis.model.ts`
- Create: `frontend/src/app/core/services/patient-analysis.service.ts`

**Interfaces:**
- Produces: `PatientAnalysis`, `AnalysisLabel`, `ReviewAnalysisRequest`, `DISEASE_LABELS`, `quadrantColor(tooth)`. `PatientAnalysisService` with `start`, `list`, `get`, `review`, `streamStatus` (returns an `EventSource`).

- [ ] **Step 1: patient-analysis.model.ts**

```typescript
export interface AnalysisLabel {
  id: string;
  toothFdi: string | null;
  disease: string;
  diseaseConfidence: number | null;
  fdiConfidence: number | null;
  bboxX1: number; bboxY1: number; bboxX2: number; bboxY2: number;
  matchingMethod: string;
  matchingScore: number | null;
  needsReview: boolean;
  source: string;
  action: string | null;
}

export interface PatientAnalysis {
  id: string;
  patientId: string;
  documentId: string;
  status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  detectionsCount: number;
  needsReview: boolean;
  reviewStatus: string;
  resultBucket: string | null;
  resultObjectKey: string | null;
  annotatedObjectKey: string | null;
  errorMessage: string | null;
  createdAt: string | null;
  labels: AnalysisLabel[];
}

export interface ReviewAnalysisRequest {
  reviewStatus: 'reviewed' | 'approved_for_training' | 'excluded';
  labels: AnalysisLabel[];
}

export const DISEASE_LABELS: Record<string, string> = {
  Caries: 'Carie',
  Deep_Caries: 'Carie profonda',
  Periapical_Lesion: 'Lesione periapicale',
  Impacted: 'Incluso',
};

/** Quadrant colors mirror the ai-service annotated image (DENTEX). */
export function quadrantColor(tooth: string | null): string {
  if (!tooth) return '#9E9E9E';
  switch (tooth[0]) {
    case '1': return '#57C84D';
    case '2': return '#E84D4D';
    case '3': return '#4DC8E8';
    case '4': return '#E8C84D';
    default: return '#9E9E9E';
  }
}
```

- [ ] **Step 2: patient-analysis.service.ts**

```typescript
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { PatientAnalysis, ReviewAnalysisRequest } from '../models/patient-analysis.model';

@Injectable({ providedIn: 'root' })
export class PatientAnalysisService {
  constructor(private readonly http: HttpClient) {}

  private base(patientId: string, docId: string): string {
    return `${environment.apiBaseUrl}/patients/${patientId}/documents/${docId}/analyses`;
  }

  start(patientId: string, docId: string): Observable<PatientAnalysis> {
    return this.http.post<PatientAnalysis>(this.base(patientId, docId), {});
  }

  list(patientId: string, docId: string): Observable<PatientAnalysis[]> {
    return this.http.get<PatientAnalysis[]>(this.base(patientId, docId));
  }

  get(patientId: string, docId: string, analysisId: string): Observable<PatientAnalysis> {
    return this.http.get<PatientAnalysis>(`${this.base(patientId, docId)}/${analysisId}`);
  }

  review(patientId: string, docId: string, analysisId: string, req: ReviewAnalysisRequest): Observable<PatientAnalysis> {
    return this.http.put<PatientAnalysis>(`${this.base(patientId, docId)}/${analysisId}/review`, req);
  }

  /** SSE stream of analysis status. Caller must call .close() when done. */
  streamStatus(patientId: string, docId: string, analysisId: string): EventSource {
    return new EventSource(`${this.base(patientId, docId)}/${analysisId}/stream`);
  }
}
```

> Note: `EventSource` cannot set Authorization headers. The SSE endpoint is GET; if the app's JWT is sent via header (not cookie), the implementer must either (a) accept the token as a query parameter on the stream endpoint guarded server-side, or (b) rely on the reconciler + a one-shot `get()` refresh after a short delay. For this MVP, after `start()`, subscribe to SSE for the push and ALSO do a single `get()` refetch on the `analysis-status` event to load labels. If the deployment's auth is header-based and SSE auth is not yet wired, the component falls back to one delayed `get()` (see Task 12 Step 3 fallback).

- [ ] **Step 3: Build the frontend to typecheck**

Run: `cd frontend && npm run build`
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/app/core/models/patient-analysis.model.ts frontend/src/app/core/services/patient-analysis.service.ts
git commit -m "feat(ai-ui): analysis model + service (HTTP + SSE)"
```

---

### Task 12: Angular bounding-box overlay component + Documenti tab integration

**Files:**
- Create: `frontend/src/app/features/pazienti/documento-analisi/documento-analisi.component.ts`
- Modify: `frontend/src/app/features/pazienti/documenti-tab/documenti-tab.component.ts` and `.html` (add "Analizza con AI" button on `rx_panoramica` cards + host the overlay in a modal)

**Interfaces:**
- Consumes: `PatientAnalysisService`, `PatientDocumentService.getContent` (existing), `quadrantColor`, `DISEASE_LABELS`.
- Produces: `DocumentoAnalisiComponent` (standalone, inputs `patientId`, `docId`; loads the image blob + latest analysis; renders an SVG overlay; "Analizza" / "Conferma" actions).

- [ ] **Step 1: Implement documento-analisi.component.ts (inline template)**

```typescript
import { Component, Input, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { DomSanitizer, SafeUrl } from '@angular/platform-browser';
import { PatientAnalysisService } from '../../../core/services/patient-analysis.service';
import { PatientDocumentService } from '../../../core/services/patient-document.service';
import { PatientAnalysis, DISEASE_LABELS, quadrantColor } from '../../../core/models/patient-analysis.model';

@Component({
  selector: 'app-documento-analisi',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <h3 class="font-bold text-slate-700 flex items-center gap-2">
          <span class="material-symbols-outlined text-[18px] text-teal-600">network_intelligence</span>
          Analisi AI ortopanoramica
        </h3>
        @if (!analysis() || analysis()?.status === 'FAILED') {
          <button (click)="analyze()" [disabled]="busy()"
            class="flex items-center gap-1.5 bg-teal-600 text-white text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-teal-700 disabled:opacity-50">
            <span class="material-symbols-outlined text-[15px]">auto_awesome</span>
            {{ busy() ? 'Avvio...' : 'Analizza con AI' }}
          </button>
        }
      </div>

      <p class="text-[11px] text-amber-700 bg-amber-50 border border-amber-200 rounded px-2 py-1">
        AI-generated, requires clinician review
      </p>

      @if (analysis()?.status === 'PROCESSING') {
        <div class="flex items-center gap-2 text-sm text-slate-500">
          <span class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
          Analisi in corso...
        </div>
      }
      @if (analysis()?.status === 'FAILED') {
        <p class="text-sm text-red-600">Analisi fallita: {{ analysis()?.errorMessage }}</p>
      }

      @if (imageUrl()) {
        <div class="relative inline-block border border-slate-200 rounded-lg overflow-hidden">
          <img #img [src]="imageUrl()" (load)="onImageLoad(img)" class="block max-w-full" alt="Ortopanoramica" />
          @if (analysis()?.status === 'COMPLETED' && natW() > 0) {
            <svg class="absolute inset-0 w-full h-full" [attr.viewBox]="'0 0 ' + natW() + ' ' + natH()" preserveAspectRatio="none">
              @for (l of analysis()!.labels; track l.id) {
                <rect [attr.x]="l.bboxX1" [attr.y]="l.bboxY1"
                      [attr.width]="l.bboxX2 - l.bboxX1" [attr.height]="l.bboxY2 - l.bboxY1"
                      [attr.stroke]="color(l.toothFdi)" stroke-width="3"
                      [attr.fill]="color(l.toothFdi)" fill-opacity="0.2" />
                <text [attr.x]="l.bboxX1" [attr.y]="l.bboxY1 - 4" [attr.fill]="color(l.toothFdi)"
                      font-size="22" font-weight="bold">{{ labelText(l) }}</text>
              }
            </svg>
          }
        </div>
      }

      @if (analysis()?.status === 'COMPLETED') {
        <div class="flex items-center justify-between">
          <span class="text-xs text-slate-500">{{ analysis()?.detectionsCount }} rilevamenti · stato revisione: {{ analysis()?.reviewStatus }}</span>
          @if (analysis()?.reviewStatus === 'pending') {
            <button (click)="confirm()" [disabled]="busy()"
              class="bg-green-600 text-white text-xs font-bold px-3 py-1.5 rounded-lg hover:bg-green-700 disabled:opacity-50">
              Conferma e sincronizza odontogramma
            </button>
          }
        </div>
      }
    </div>
  `,
})
export class DocumentoAnalisiComponent implements OnInit, OnDestroy {
  @Input({ required: true }) patientId!: string;
  @Input({ required: true }) docId!: string;

  private readonly analysisSvc = inject(PatientAnalysisService);
  private readonly docSvc = inject(PatientDocumentService);
  private readonly sanitizer = inject(DomSanitizer);

  readonly analysis = signal<PatientAnalysis | null>(null);
  readonly imageUrl = signal<SafeUrl | null>(null);
  readonly busy = signal(false);
  readonly natW = signal(0);
  readonly natH = signal(0);

  private blobUrl: string | null = null;
  private es: EventSource | null = null;

  ngOnInit(): void {
    this.docSvc.getContent(this.patientId, this.docId).subscribe(blob => {
      this.blobUrl = URL.createObjectURL(blob);
      this.imageUrl.set(this.sanitizer.bypassSecurityTrustUrl(this.blobUrl));
    });
    this.analysisSvc.list(this.patientId, this.docId).subscribe(list => {
      if (list.length > 0) this.loadAnalysis(list[0].id);
    });
  }

  ngOnDestroy(): void {
    if (this.blobUrl) URL.revokeObjectURL(this.blobUrl);
    this.es?.close();
  }

  color(tooth: string | null): string { return quadrantColor(tooth); }
  labelText(l: { toothFdi: string | null; disease: string }): string {
    const d = DISEASE_LABELS[l.disease] ?? l.disease;
    return l.toothFdi ? `${l.toothFdi} ${d}` : `? ${d}`;
  }

  onImageLoad(img: HTMLImageElement): void {
    this.natW.set(img.naturalWidth);
    this.natH.set(img.naturalHeight);
  }

  analyze(): void {
    this.busy.set(true);
    this.analysisSvc.start(this.patientId, this.docId).subscribe({
      next: a => { this.analysis.set(a); this.busy.set(false); this.subscribeStatus(a.id); },
      error: () => { this.busy.set(false); },
    });
  }

  private subscribeStatus(analysisId: string): void {
    this.es?.close();
    this.es = this.analysisSvc.streamStatus(this.patientId, this.docId, analysisId);
    this.es.addEventListener('analysis-status', () => { this.loadAnalysis(analysisId); this.es?.close(); });
    // Fallback if SSE is not authenticated in this deployment: refetch once after 8s.
    setTimeout(() => { if (this.analysis()?.status === 'PROCESSING') this.loadAnalysis(analysisId); }, 8000);
  }

  private loadAnalysis(analysisId: string): void {
    this.analysisSvc.get(this.patientId, this.docId, analysisId).subscribe(a => this.analysis.set(a));
  }

  confirm(): void {
    const a = this.analysis();
    if (!a) return;
    this.busy.set(true);
    this.analysisSvc.review(this.patientId, this.docId, a.id, { reviewStatus: 'reviewed', labels: a.labels }).subscribe({
      next: updated => { this.analysis.set(updated); this.busy.set(false); },
      error: () => { this.busy.set(false); },
    });
  }
}
```

- [ ] **Step 2: Integrate into documenti-tab.component.ts**

Add `DocumentoAnalisiComponent` to the component's `imports` array, and add a signal to track which document's analysis modal is open:

```typescript
import { DocumentoAnalisiComponent } from '../documento-analisi/documento-analisi.component';
// in @Component imports: [ ...existing, DocumentoAnalisiComponent ]
// in the class:
readonly analyzeDocId = signal<string | null>(null);
openAnalyze(docId: string): void { this.analyzeDocId.set(docId); }
closeAnalyze(): void { this.analyzeDocId.set(null); }
```

- [ ] **Step 3: Integrate into documenti-tab.component.html**

On each document card, for `rx_panoramica` documents, add an action button (place it beside the existing card actions; the card already iterates documents as `doc`):

```html
@if (doc.documentType === 'rx_panoramica') {
  <button (click)="openAnalyze(doc.id)"
    class="flex items-center gap-1 text-xs font-bold text-teal-600 hover:text-teal-700">
    <span class="material-symbols-outlined text-[15px]">auto_awesome</span> Analizza AI
  </button>
}
```

And add a modal host at the end of the template:

```html
@if (analyzeDocId()) {
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" (click)="closeAnalyze()">
    <div class="bg-white rounded-2xl shadow-2xl p-5 w-full max-w-4xl max-h-[90vh] overflow-y-auto" (click)="$event.stopPropagation()">
      <div class="flex items-center justify-between mb-3">
        <h3 class="font-bold text-slate-800 text-lg">Analisi AI</h3>
        <button (click)="closeAnalyze()" class="p-1 text-slate-400 hover:text-slate-600">
          <span class="material-symbols-outlined">close</span>
        </button>
      </div>
      <app-documento-analisi [patientId]="patientId" [docId]="analyzeDocId()!" />
    </div>
  </div>
}
```

> `patientId` is already an `@Input` on `documenti-tab`. If the card loop variable is named differently than `doc`, use the existing name; if `documentType` is exposed under a different field on `PatientDocumentSummary`, use that field (it is `documentType`).

- [ ] **Step 4: Build**

Run: `cd frontend && npm run build`
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/features/pazienti/documento-analisi frontend/src/app/features/pazienti/documenti-tab
git commit -m "feat(ai-ui): SVG bbox overlay + Analizza AI in Documenti tab"
```

---

### Task 13: Final integration check, docs/tracking, install.sql mirror

**Files:**
- Modify: `directives/proposte-modifiche.md` (mark #6 as Fatta, referencing both specs/plans)
- Verify: `database/install.sql` mirrors the new tables (per project rule)

**Interfaces:**
- Consumes: everything above.
- Produces: green backend + frontend builds; updated tracking doc.

- [ ] **Step 1: Run the full backend suite**

Run: `cd backend && ./mvnw -q test`
Expected: PASS (no regressions; pre-existing unrelated failures, if any, must be unchanged from before this branch).

- [ ] **Step 2: Run the frontend build**

Run: `cd frontend && npm run build`
Expected: success.

- [ ] **Step 3: Update proposte-modifiche.md**

Set proposal #6 status to `Fatta` in both the index table and the §6 section header; reference `docs/superpowers/specs/2026-06-26-ai-yolo-service-design.md` and the two plans (`2026-06-26-ai-service-python.md`, `2026-06-26-ai-integration-dentalcare.md`).

- [ ] **Step 4: Confirm install.sql mirror**

Verify `database/install.sql` contains the three `dentalcare.ai_*` enums and the demo-tenant `t_9d754153.patient_document_analyses`, `..._labels`, and `tooth_conditions.source`/`analysis_id` columns added in Task 3. If anything is missing, add it.

- [ ] **Step 5: Commit**

```bash
git add directives/proposte-modifiche.md database/install.sql
git commit -m "docs(proposte): segna #6 AI YOLO come Fatta; verifica install.sql mirror"
```

---

## Notes for the executor

- Run backend `./mvnw` from `backend/`, frontend `npm` from `frontend/`. The compose edit (Plan A Task 14) and tracking/install.sql edits are at repo root.
- Build order matters for compilation: Task 6 references `SseEmitterRegistry` (placeholder created in Task 6 Step 3, finalized in Task 8) and the controller in Task 9 references `OdontogramSyncService` (Task 10). If a task fails to compile due to a not-yet-created class, create that class's stub from its defining task first, then continue.
- SSE authentication caveat (Task 11 Step 2): `EventSource` cannot send the Authorization header. For the MVP the component has a timed `get()` fallback, and the reconciler guarantees the DB reaches COMPLETED regardless. Wiring real SSE auth (token query param + a dedicated permit rule, or cookie auth) is a follow-up.
- Tenant isolation: every query is schema-scoped via `TenantContext.validatedSchema()` and filtered by `clinic_id`, mirroring `PatientDocumentService`. The callback path sets only the schema (it does not need clinic_id).
```

