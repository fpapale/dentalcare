package com.dentalcare.service;

import com.dentalcare.dto.DeletionPrepareResponse;
import com.dentalcare.dto.DeletionScheduledResponse;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TenantDeletionServiceTest {

    @Mock NamedParameterJdbcTemplate jdbc;
    @Mock MinioStorageService minio;
    @Mock TenantExportService exportService;
    @Mock TenantSchemaRegistry registry;

    TenantDeletionService service;

    private static final String SCHEMA = "t_abcd1234";
    private final UUID tenantId = UUID.fromString("00000000-0000-0000-0000-000000000009");

    @BeforeEach
    void setup() {
        service = new TenantDeletionService(jdbc, minio, exportService, registry);
        ReflectionTestUtils.setField(service, "graceDays", 30);
        ReflectionTestUtils.setField(service, "tokenTtlMinutes", 15);
        ReflectionTestUtils.setField(service, "demoSchema", "t_9d754153");
        TenantContext.setCurrentSchema(SCHEMA);
    }

    @AfterEach
    void clear() {
        TenantContext.clear();
    }

    /** prepare() genera un token valido; è il prerequisito verificabile per la conferma. */
    private String prepareToken() throws IOException {
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(UUID.class))).thenReturn(tenantId);
        DeletionPrepareResponse resp = service.prepare();
        assertThat(resp.deletionToken()).isNotBlank();
        return resp.deletionToken();
    }

    @Test
    void confirm_withoutValidToken_isRejected() {
        assertThatThrownBy(() -> service.confirmDeleteTenant("bogus-token", "Whatever"))
                .isInstanceOf(IllegalStateException.class);
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void confirm_wrongName_isRejected() throws IOException {
        String token = prepareToken();
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn("Studio Vero");

        assertThatThrownBy(() -> service.confirmDeleteTenant(token, "Nome Sbagliato"))
                .isInstanceOf(IllegalArgumentException.class);
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void confirm_validTokenAndName_softDeletesWithGracePeriod() throws IOException {
        String token = prepareToken();
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn("Studio Vero");

        DeletionScheduledResponse resp = service.confirmDeleteTenant(token, "  Studio Vero  ");

        assertThat(resp.scheduledDropAt()).isNotBlank();
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        verify(jdbc).update(sqlCaptor.capture(), any(SqlParameterSource.class));
        assertThat(sqlCaptor.getValue()).contains("active = false").contains("scheduled_drop_at");
        // il DROP reale NON avviene qui
        verify(minio, never()).purgeBucket(anyString());
    }

    @Test
    void confirm_reusingConsumedToken_isRejected() throws IOException {
        String token = prepareToken();
        when(jdbc.queryForObject(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn("Studio Vero");
        service.confirmDeleteTenant(token, "Studio Vero");

        assertThatThrownBy(() -> service.confirmDeleteTenant(token, "Studio Vero"))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void prepare_onDemoSchema_isRejected() {
        TenantContext.setCurrentSchema("t_9d754153");
        assertThatThrownBy(() -> service.prepare())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void cancel_whenNothingScheduled_isRejected() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(0);
        assertThatThrownBy(() -> service.cancelDeleteTenant())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void cancel_whenScheduledInWindow_reactivates() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(1);
        service.cancelDeleteTenant();
        ArgumentCaptor<String> sqlCaptor = ArgumentCaptor.forClass(String.class);
        verify(jdbc).update(sqlCaptor.capture(), any(SqlParameterSource.class));
        assertThat(sqlCaptor.getValue()).contains("active = true").contains("scheduled_drop_at = NULL");
    }
}
