package com.dentalcare.service;

import com.dentalcare.dto.DeletionPrepareResponse;
import com.dentalcare.dto.DeletionScheduledResponse;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
import com.dentalcare.service.TenantDeletionTokenStore.PendingDeletion;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TenantDeletionServiceTest {

    @Mock NamedParameterJdbcTemplate jdbc;
    @Mock MinioStorageService minio;
    @Mock TenantExportService exportService;
    @Mock TenantSchemaRegistry registry;
    @Mock TenantDeletionTokenStore tokenStore;

    TenantDeletionService service;

    private static final String SCHEMA = "t_abcd1234";
    private static final String TOKEN = "tok-123";
    private final UUID tenantId = UUID.fromString("00000000-0000-0000-0000-000000000009");

    @BeforeEach
    void setup() {
        service = new TenantDeletionService(jdbc, minio, exportService, registry, tokenStore);
        ReflectionTestUtils.setField(service, "graceDays", 30);
        ReflectionTestUtils.setField(service, "tokenTtlMinutes", 15);
        ReflectionTestUtils.setField(service, "demoSchema", "t_9d754153");
        TenantContext.setCurrentSchema(SCHEMA);
    }

    @AfterEach
    void clear() {
        TenantContext.clear();
    }

    private PendingDeletion validPending() {
        return new PendingDeletion(SCHEMA, tenantId, "key.zip", Instant.now().plus(10, ChronoUnit.MINUTES));
    }

    @Test
    void prepare_returnsOneTimeArchivePasswordAndToken() throws IOException {
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(UUID.class))).thenReturn(tenantId);
        when(tokenStore.issue(eq(SCHEMA), eq(tenantId), anyString(), anyInt())).thenReturn(TOKEN);

        DeletionPrepareResponse resp = service.prepare();

        assertThat(resp.deletionToken()).isEqualTo(TOKEN);
        assertThat(resp.archivePassword()).isNotBlank();
    }

    @Test
    void prepare_onDemoSchema_isRejected() {
        TenantContext.setCurrentSchema("t_9d754153");
        assertThatThrownBy(() -> service.prepare())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void confirm_withoutValidToken_isRejected() {
        when(tokenStore.find(anyString())).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.confirmDeleteTenant("bogus", "Whatever"))
                .isInstanceOf(IllegalStateException.class);
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void confirm_tokenForDifferentTenant_isRejected() {
        when(tokenStore.find(TOKEN)).thenReturn(Optional.of(
                new PendingDeletion("t_00000000", tenantId, "key.zip", Instant.now().plus(10, ChronoUnit.MINUTES))));
        assertThatThrownBy(() -> service.confirmDeleteTenant(TOKEN, "Studio Vero"))
                .isInstanceOf(IllegalStateException.class);
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void confirm_wrongName_isRejected() {
        when(tokenStore.find(TOKEN)).thenReturn(Optional.of(validPending()));
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn("Studio Vero");
        assertThatThrownBy(() -> service.confirmDeleteTenant(TOKEN, "Nome Sbagliato"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void confirm_validTokenAndName_softDeletesFreezesAndConsumesToken() {
        when(tokenStore.find(TOKEN)).thenReturn(Optional.of(validPending()));
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn("Studio Vero");

        DeletionScheduledResponse resp = service.confirmDeleteTenant(TOKEN, "  Studio Vero  ");

        assertThat(resp.scheduledDropAt()).isNotBlank();
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, atLeastOnce()).update(sql.capture(), any(SqlParameterSource.class));
        assertThat(sql.getAllValues()).anySatisfy(s ->
                assertThat(s).contains("active = false").contains("scheduled_drop_at"));
        verify(tokenStore).consume(TOKEN);
        verify(registry).markSchemaInactive(SCHEMA);
        verify(minio, never()).purgeBucket(anyString());   // il DROP reale NON avviene qui
    }

    @Test
    void cancel_whenNothingScheduled_isRejected() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(0);
        assertThatThrownBy(() -> service.cancelDeleteTenant())
                .isInstanceOf(IllegalStateException.class);
        verify(registry, never()).markSchemaActive(anyString());
    }

    @Test
    void cancel_whenScheduledInWindow_reactivatesAndUnfreezes() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(1);
        service.cancelDeleteTenant();
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, atLeastOnce()).update(sql.capture(), any(SqlParameterSource.class));
        assertThat(sql.getAllValues()).anySatisfy(s ->
                assertThat(s).contains("active = true").contains("scheduled_drop_at = NULL"));
        verify(registry).markSchemaActive(SCHEMA);
    }
}
