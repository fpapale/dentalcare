package com.dentalcare.service;

import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ChatHistoryServiceTest {

    private NamedParameterJdbcTemplate jdbc;
    private ChatHistoryService svc;
    private final UUID provider = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        jdbc = mock(NamedParameterJdbcTemplate.class);
        svc = new ChatHistoryService(jdbc);
        TenantContext.setCurrentSchema("t_abcd1234");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(provider.toString(), null, List.of()));
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    @Test
    void resolveOwnedSession_nullSessionId_createsNewSession() {
        UUID id = svc.resolveOwnedSession(null, "ciao");
        assertNotNull(id);
        verify(jdbc, times(1)).update(contains("INSERT INTO t_abcd1234.chat_sessions"), any(MapSqlParameterSource.class));
    }

    @Test
    void resolveOwnedSession_foreignSession_throwsNotFound() {
        when(jdbc.queryForObject(contains("count(*)"), any(MapSqlParameterSource.class), eq(Integer.class))).thenReturn(0);
        assertThrows(ResourceNotFoundException.class,
                () -> svc.resolveOwnedSession(UUID.randomUUID(), "x"));
    }

    @Test
    void resolveOwnedSession_ownedSession_returnsSameIdWithoutCreating() {
        UUID own = UUID.randomUUID();
        when(jdbc.queryForObject(contains("count(*)"), any(MapSqlParameterSource.class), eq(Integer.class))).thenReturn(1);
        assertEquals(own, svc.resolveOwnedSession(own, "x"));
        verify(jdbc, never()).update(contains("INSERT INTO t_abcd1234.chat_sessions"), any(MapSqlParameterSource.class));
    }

    @Test
    void getSessionMessages_foreignSession_throwsNotFound() {
        when(jdbc.queryForObject(contains("count(*)"), any(MapSqlParameterSource.class), eq(Integer.class))).thenReturn(0);
        assertThrows(ResourceNotFoundException.class,
                () -> svc.getSessionMessages(UUID.randomUUID()));
    }
}
