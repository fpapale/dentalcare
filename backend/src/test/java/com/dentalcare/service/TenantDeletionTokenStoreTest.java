package com.dentalcare.service;

import com.dentalcare.service.TenantDeletionTokenStore.PendingDeletion;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TenantDeletionTokenStoreTest {

    @Mock NamedParameterJdbcTemplate jdbc;

    private static final String SCHEMA = "t_abcd1234";
    private final UUID tenantId = UUID.fromString("00000000-0000-0000-0000-000000000009");

    private Map<String, Object> row(Instant expiresAt) {
        return Map.of(
                "schema_name", SCHEMA,
                "tenant_id", tenantId,
                "object_key", "key.zip",
                "expires_at", Timestamp.from(expiresAt));
    }

    @Test
    void issue_insertsAndReturnsToken() {
        TenantDeletionTokenStore store = new TenantDeletionTokenStore(jdbc);
        String token = store.issue(SCHEMA, tenantId, "key.zip", 15);
        assertThat(token).isNotBlank();
        verify(jdbc).update(contains("INSERT INTO dentalcare.tenant_deletion_tokens"), any(SqlParameterSource.class));
    }

    @Test
    void find_validToken_returnsPending() {
        TenantDeletionTokenStore store = new TenantDeletionTokenStore(jdbc);
        when(jdbc.queryForList(anyString(), any(SqlParameterSource.class)))
                .thenReturn(List.of(row(Instant.now().plus(10, ChronoUnit.MINUTES))));

        Optional<PendingDeletion> found = store.find("tok");

        assertThat(found).isPresent();
        assertThat(found.get().schema()).isEqualTo(SCHEMA);
        assertThat(found.get().objectKey()).isEqualTo("key.zip");
    }

    @Test
    void find_expiredToken_returnsEmptyAndDeletes() {
        TenantDeletionTokenStore store = new TenantDeletionTokenStore(jdbc);
        when(jdbc.queryForList(anyString(), any(SqlParameterSource.class)))
                .thenReturn(List.of(row(Instant.now().minus(1, ChronoUnit.MINUTES))));

        Optional<PendingDeletion> found = store.find("tok");

        assertThat(found).isEmpty();
        verify(jdbc).update(contains("DELETE FROM dentalcare.tenant_deletion_tokens"), any(SqlParameterSource.class));
    }

    @Test
    void find_absentToken_returnsEmpty() {
        TenantDeletionTokenStore store = new TenantDeletionTokenStore(jdbc);
        when(jdbc.queryForList(anyString(), any(SqlParameterSource.class))).thenReturn(List.of());
        assertThat(store.find("tok")).isEmpty();
    }

    @Test
    void find_blankToken_returnsEmptyWithoutQuery() {
        TenantDeletionTokenStore store = new TenantDeletionTokenStore(jdbc);
        assertThat(store.find("  ")).isEmpty();
    }
}
