package com.dentalcare.service;

import com.dentalcare.config.EstimateSchemaInitializer;
import com.dentalcare.dto.RegistrationRequest;
import com.dentalcare.dto.TenantProvisioningResult;
import com.dentalcare.security.TenantSchemaRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TenantProvisioningServiceTest {

    @Mock JdbcTemplate jdbc;
    @Mock TenantSchemaRegistry registry;
    @Mock PasswordEncoder passwordEncoder;
    @Mock EmailService emailService;
    @Mock MinioStorageService minio;
    @Mock EstimateSchemaInitializer estimateSchemaInitializer;

    @InjectMocks TenantProvisioningService service;

    private RegistrationRequest req() {
        return new RegistrationRequest("basic", "Studio X", "000", "studio@x.it",
                "via Roma 1", "Roma", "RM", "IT01234567890",
                "Mario", "Rossi", "admin@x.it");
    }

    @BeforeEach
    void setup() {
        ReflectionTestUtils.setField(service, "frontendBaseUrl", "http://localhost:4200");
        when(passwordEncoder.encode(anyString())).thenReturn("hash");
        // create_tenant(): JdbcTemplate.queryForObject(sql, UUID.class, <15 varargs>)
        when(jdbc.queryForObject(anyString(), eq(UUID.class),
                any(), any(), any(), any(), any(), any(), any(), any(),
                any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(UUID.randomUUID());
        when(minio.bucketFor(anyString())).thenReturn("dc-bucket");
    }

    @Test
    void provisionPatchesTheSchemaItRegistered() {
        service.provision(req());

        // Lo schema passato a patchSchema deve essere quello registrato nel registry.
        ArgumentCaptor<String> registered = ArgumentCaptor.forClass(String.class);
        verify(registry).register(anyString(), registered.capture());
        verify(estimateSchemaInitializer).patchSchema(registered.getValue());
        assertThat(registered.getValue()).matches("^t_[0-9a-f]{8}$");
    }

    @Test
    void provisionSurvivesPatchSchemaFailure() {
        doThrow(new RuntimeException("boom")).when(estimateSchemaInitializer).patchSchema(anyString());

        // Best-effort: patchSchema fallito NON deve propagare (provision non lancia).
        TenantProvisioningResult result = service.provision(req());

        // I passi successivi (bucket MinIO, email) vengono comunque eseguiti.
        assertThat(result.schemaName()).matches("^t_[0-9a-f]{8}$");
        verify(minio).ensureBucketExists(anyString());
        verify(emailService).sendStudioWelcomeTempPassword(
                anyString(), anyString(), anyString(), anyString(), anyString());
    }
}
