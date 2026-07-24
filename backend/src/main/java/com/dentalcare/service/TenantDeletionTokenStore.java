package com.dentalcare.service;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Store persistente dei token monouso di cancellazione (#47 follow-up): tabella globale
 * {@code dentalcare.tenant_deletion_tokens}, sopravvive al riavvio del backend. Il token è
 * consumato alla conferma; quelli scaduti vengono ripuliti a ogni emissione.
 */
@Component
public class TenantDeletionTokenStore {

    public record PendingDeletion(String schema, UUID tenantId, String objectKey, Instant expiresAt) {
    }

    private final NamedParameterJdbcTemplate jdbc;

    public TenantDeletionTokenStore(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Emette e persiste un nuovo token con TTL indicato; ritorna il token. Ripulisce gli scaduti. */
    public String issue(String schema, UUID tenantId, String objectKey, int ttlMinutes) {
        deleteExpired();
        String token = UUID.randomUUID().toString();
        Instant expiresAt = Instant.now().plus(ttlMinutes, ChronoUnit.MINUTES);
        jdbc.update(
                "INSERT INTO dentalcare.tenant_deletion_tokens (token, schema_name, tenant_id, object_key, expires_at) "
                        + "VALUES (:token, :schema, :tenantId, :objectKey, :expiresAt)",
                new MapSqlParameterSource("token", token)
                        .addValue("schema", schema)
                        .addValue("tenantId", tenantId)
                        .addValue("objectKey", objectKey)
                        .addValue("expiresAt", Timestamp.from(expiresAt)));
        return token;
    }

    /** Ritorna il token se presente e non scaduto; altrimenti vuoto (e rimuove l'eventuale scaduto). */
    public Optional<PendingDeletion> find(String token) {
        if (token == null || token.isBlank()) {
            return Optional.empty();
        }
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT schema_name, tenant_id, object_key, expires_at "
                        + "FROM dentalcare.tenant_deletion_tokens WHERE token = :token",
                new MapSqlParameterSource("token", token));
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        Map<String, Object> row = rows.get(0);
        Instant expiresAt = ((Timestamp) row.get("expires_at")).toInstant();
        if (expiresAt.isBefore(Instant.now())) {
            consume(token);
            return Optional.empty();
        }
        return Optional.of(new PendingDeletion(
                (String) row.get("schema_name"),
                (UUID) row.get("tenant_id"),
                (String) row.get("object_key"),
                expiresAt));
    }

    /** Consuma (elimina) il token. */
    public void consume(String token) {
        jdbc.update("DELETE FROM dentalcare.tenant_deletion_tokens WHERE token = :token",
                new MapSqlParameterSource("token", token));
    }

    private void deleteExpired() {
        jdbc.update("DELETE FROM dentalcare.tenant_deletion_tokens WHERE expires_at < now()",
                new MapSqlParameterSource());
    }
}
