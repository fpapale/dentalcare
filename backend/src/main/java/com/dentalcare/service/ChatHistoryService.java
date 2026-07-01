package com.dentalcare.service;

import com.dentalcare.dto.ChatMessageDto;
import com.dentalcare.dto.ChatSessionDto;
import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class ChatHistoryService {

    private final NamedParameterJdbcTemplate jdbc;

    public ChatHistoryService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private String s() { return TenantContext.validatedSchema(); }

    private UUID currentProviderId() {
        return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName());
    }

    /** Fails (404, senza rivelare l'esistenza) se la sessione non appartiene al provider corrente. */
    private void assertOwned(UUID sessionId) {
        Integer count = jdbc.queryForObject("""
            SELECT count(*) FROM %s.chat_sessions WHERE id = :id AND provider_id = :pid
            """.formatted(s()),
            new MapSqlParameterSource().addValue("id", sessionId).addValue("pid", currentProviderId()),
            Integer.class);
        if (count == null || count == 0) throw new ResourceNotFoundException("Chat session not found");
    }

    /** Risolve la sessione della richiesta: null -> nuova (del provider corrente); fornita -> deve essere sua. */
    @Transactional
    public UUID resolveOwnedSession(UUID sessionId, String firstMessage) {
        if (sessionId == null) return createSession(firstMessage);
        assertOwned(sessionId);
        return sessionId;
    }

    @Transactional
    public UUID createSession(String firstMessage) {
        UUID id = UUID.randomUUID();
        String title = firstMessage.length() > 60 ? firstMessage.substring(0, 60) + "…" : firstMessage;
        jdbc.update("""
            INSERT INTO %s.chat_sessions (id, provider_id, title)
            VALUES (:id, :pid, :title)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("pid", currentProviderId())
                .addValue("title", title));
        return id;
    }

    @Transactional
    public void appendMessage(UUID sessionId, String role, String content) {
        jdbc.update("""
            INSERT INTO %s.chat_messages (session_id, role, content)
            VALUES (:sid, :role, :content)
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("sid", sessionId)
                .addValue("role", role)
                .addValue("content", content));
        jdbc.update("""
            UPDATE %s.chat_sessions
            SET message_count = message_count + 1, updated_at = now()
            WHERE id = :id
            """.formatted(s()),
            new MapSqlParameterSource().addValue("id", sessionId));
    }

    @Transactional
    public List<ChatSessionDto> listSessions(int retentionDays) {
        UUID pid = currentProviderId();
        // purge expired sessions for this provider
        jdbc.update("""
            DELETE FROM %s.chat_sessions
            WHERE provider_id = :pid
              AND created_at < now() - (:days || ' days')::interval
            """.formatted(s()),
            new MapSqlParameterSource().addValue("pid", pid).addValue("days", retentionDays));

        return jdbc.query("""
            SELECT id, title, message_count, created_at
            FROM %s.chat_sessions
            WHERE provider_id = :pid
            ORDER BY created_at DESC
            """.formatted(s()),
            new MapSqlParameterSource().addValue("pid", pid),
            (rs, n) -> new ChatSessionDto(
                rs.getObject("id", UUID.class),
                rs.getString("title"),
                rs.getInt("message_count"),
                rs.getObject("created_at", OffsetDateTime.class)));
    }

    @Transactional(readOnly = true)
    public List<ChatMessageDto> getSessionMessages(UUID sessionId) {
        assertOwned(sessionId);
        return jdbc.query("""
            SELECT id, role, content, created_at
            FROM %s.chat_messages
            WHERE session_id = :sid
            ORDER BY created_at ASC
            """.formatted(s()),
            new MapSqlParameterSource().addValue("sid", sessionId),
            (rs, n) -> new ChatMessageDto(
                rs.getObject("id", UUID.class),
                rs.getString("role"),
                rs.getString("content"),
                rs.getObject("created_at", OffsetDateTime.class)));
    }

    @Transactional
    public void deleteSession(UUID sessionId) {
        jdbc.update("""
            DELETE FROM %s.chat_sessions
            WHERE id = :id AND provider_id = :pid
            """.formatted(s()),
            new MapSqlParameterSource()
                .addValue("id", sessionId)
                .addValue("pid", currentProviderId()));
    }
}
