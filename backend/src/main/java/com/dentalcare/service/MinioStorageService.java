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
                .region(Region.US_EAST_1)
                .forcePathStyle(true)
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
