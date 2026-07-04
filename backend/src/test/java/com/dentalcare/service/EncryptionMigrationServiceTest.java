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
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.sql.ResultSet;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EncryptionMigrationServiceTest {

    @Mock
    NamedParameterJdbcTemplate jdbc;

    @Mock
    TenantEncryptionService enc;

    EncryptionMigrationService service;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID providerId = UUID.fromString("00000000-0000-0000-0000-000000000004");
    private final UUID patientId1 = UUID.fromString("00000000-0000-0000-0000-000000000010");
    private final UUID patientId2 = UUID.fromString("00000000-0000-0000-0000-000000000011");

    @BeforeEach
    void setupContext() {
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(providerId.toString(), null, List.of()));
        service = new EncryptionMigrationService(jdbc, enc);
    }

    @AfterEach
    void clearContext() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    /**
     * Stubs jdbc.query(sql, RowMapper) by capturing the real RowMapper lambda passed by the
     * service and invoking it against mocked ResultSet rows. This produces genuine instances of
     * the service's private Row record without needing reflection or access to that type.
     */
    @SuppressWarnings("unchecked")
    private void stubSelectRows(List<UUID> ids, List<LocalDate> birthDates) throws Exception {
        ResultSet[] resultSets = new ResultSet[ids.size()];
        for (int i = 0; i < ids.size(); i++) {
            ResultSet rs = mock(ResultSet.class);
            when(rs.getObject("id", UUID.class)).thenReturn(ids.get(i));
            when(rs.getObject("birth_date", LocalDate.class)).thenReturn(birthDates.get(i));
            resultSets[i] = rs;
        }

        when(jdbc.query(anyString(), any(RowMapper.class))).thenAnswer(invocation -> {
            RowMapper<?> mapper = invocation.getArgument(1);
            List<Object> mapped = new java.util.ArrayList<>();
            for (int i = 0; i < resultSets.length; i++) {
                mapped.add(mapper.mapRow(resultSets[i], i));
            }
            return mapped;
        });
    }

    @Test
    void migratesOnlyUnmigratedRows() throws Exception {
        LocalDate birthDate1 = LocalDate.of(1990, 1, 1);
        LocalDate birthDate2 = LocalDate.of(1985, 5, 20);
        stubSelectRows(List.of(patientId1, patientId2), List.of(birthDate1, birthDate2));
        when(enc.encrypt(anyString(), anyString())).thenReturn("ciphertext");
        when(jdbc.update(anyString(), any(MapSqlParameterSource.class))).thenReturn(1);

        int migrated = service.migrateBirthDate();

        assertThat(migrated).isEqualTo(2);

        verify(jdbc).query(contains("SELECT id, birth_date FROM t_abcd1234.patients"), any(RowMapper.class));
        verify(jdbc).query(contains("WHERE birth_date_enc IS NULL AND birth_date IS NOT NULL"), any(RowMapper.class));

        verify(enc, times(2)).encrypt(anyString(), eq("t_abcd1234"));
        verify(enc).encrypt(eq(birthDate1.toString()), eq("t_abcd1234"));
        verify(enc).encrypt(eq(birthDate2.toString()), eq("t_abcd1234"));

        verify(jdbc, times(2)).update(contains("UPDATE t_abcd1234.patients SET birth_date_enc"), any(MapSqlParameterSource.class));
    }

    @Test
    void secondRunMigratesZero() throws Exception {
        stubSelectRows(List.of(), List.of());

        int migrated = service.migrateBirthDate();

        assertThat(migrated).isZero();
        verifyNoInteractions(enc);
        verify(jdbc, never()).update(anyString(), any(MapSqlParameterSource.class));
    }
}
