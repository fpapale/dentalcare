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
