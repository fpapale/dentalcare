package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import com.dentalcare.security.crypto.TenantEncryptionService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PatientServiceTest {

    @Mock
    NamedParameterJdbcTemplate jdbc;

    @Mock
    TenantEncryptionService enc;

    PatientService service;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID providerId = UUID.fromString("00000000-0000-0000-0000-000000000004");

    @BeforeEach
    void setupContext() {
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(providerId.toString(), null, List.of()));
        service = new PatientService(jdbc, enc);
    }

    @AfterEach
    void clearContext() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    @Test
    @SuppressWarnings("unchecked")
    void testRicercaCFusaBlindIndex() {
        when(jdbc.query(anyString(), any(SqlParameterSource.class), any(RowMapper.class))).thenReturn(List.of());
        when(enc.blindIndex(anyString(), anyString())).thenReturn("idxhex");

        List<?> result = service.findAll("RSSMRA80A01H501U", null);

        assertThat(result).isEmpty();
        verify(enc).blindIndex(eq("RSSMRA80A01H501U"), eq("t_abcd1234"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void testRicercaVuotaNonChiamaBlindIndex() {
        when(jdbc.query(anyString(), any(SqlParameterSource.class), any(RowMapper.class))).thenReturn(List.of());

        List<?> result = service.findAll(null, null);

        assertThat(result).isEmpty();
        verify(enc, never()).blindIndex(anyString(), anyString());
    }
}
