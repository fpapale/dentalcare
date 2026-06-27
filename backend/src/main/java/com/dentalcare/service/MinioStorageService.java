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
        try {
            s3.listBuckets();
            log.info("MinIO storage initialized: endpoint={}, bucketPrefix={}", endpoint, bucketPrefix);
        } catch (Exception e) {
            log.warn("MinIO connectivity check failed at startup (endpoint={}): {}", endpoint, e.getMessage());
        }
    }

    /** Bucket name for a tenant schema: dc- + schema with underscores replaced by hyphens. */
    public String bucketFor(String schema) {
        return bucketPrefix + schema.replace('_', '-');
    }

    private String currentBucket() {
        return bucketFor(TenantContext.validatedSchema());
    }

    public void ensureBucketExists(String bucket) {
        try {
            s3.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
        } catch (NoSuchBucketException e) {
            try {
                s3.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
                log.info("Created MinIO bucket: {}", bucket);
            } catch (BucketAlreadyOwnedByYouException | BucketAlreadyExistsException raceEx) {
                log.debug("Bucket already exists (race): {}", bucket);
            }
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
                    DeleteObjectsResponse resp = s3.deleteObjects(DeleteObjectsRequest.builder()
                            .bucket(bucket).delete(Delete.builder().objects(ids).build()).build());
                    if (resp.hasErrors()) {
                        resp.errors().forEach(e -> log.error("purgeBucket: failed key={}: {}", e.key(), e.message()));
                        throw new RuntimeException("purgeBucket: " + resp.errors().size() + " object(s) not deleted in bucket " + bucket);
                    }
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
        String bucket = currentBucket();
        ensureBucketExists(bucket);
        byte[] payload = encryption.encrypt(data);
        s3.putObject(
                PutObjectRequest.builder()
                        .bucket(bucket).key(objectKey).contentType(mimeType)
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
