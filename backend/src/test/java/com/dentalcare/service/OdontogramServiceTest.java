package com.dentalcare.service;

import com.dentalcare.dto.SaveOdontogramRequest;
import com.dentalcare.dto.ToothConditionDto;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.times;

@ExtendWith(MockitoExtension.class)
class OdontogramServiceTest {

    @Mock
    NamedParameterJdbcTemplate jdbc;

    @InjectMocks
    OdontogramService service;

    private final UUID clinicId  = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID patientId = UUID.fromString("00000000-0000-0000-0000-000000000002");

    @BeforeEach
    void setupContext() {
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
    }

    @AfterEach
    void clearContext() {
        TenantContext.clear();
    }

    /** Clearing an AI finding must delete the AI row, even when there is nothing else to save. */
    @Test
    void save_deletesRemovedAiRow_evenWithNoConditions() {
        SaveOdontogramRequest req = new SaveOdontogramRequest(
                List.of(),
                List.of(new SaveOdontogramRequest.ToothRef(46, "B")));

        service.save(patientId, req);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        // Two updates: DELETE manual rows, DELETE the removed AI row. No inserts (no conditions).
        verify(jdbc, times(2)).update(sql.capture(), any(MapSqlParameterSource.class));
        assertThat(sql.getAllValues())
                .anySatisfy(s -> assertThat(s)
                        .contains("DELETE FROM")
                        .contains("source = 'ai'"));
    }

    /** An untouched save (no conditions, no removals) only clears manual rows — never AI. */
    @Test
    void save_withoutRemovedAi_doesNotDeleteAiRows() {
        service.save(patientId, new SaveOdontogramRequest(List.of()));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, times(1)).update(sql.capture(), any(MapSqlParameterSource.class));
        assertThat(sql.getValue()).contains("source = 'manual'");
    }

    /** A manual condition is upserted as source='manual'. */
    @Test
    void save_insertsManualCondition() {
        SaveOdontogramRequest req = new SaveOdontogramRequest(
                List.of(new ToothConditionDto(46, "B", "cavity", null, "manual")));

        service.save(patientId, req);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        // DELETE manual + INSERT ... ON CONFLICT.
        verify(jdbc, times(2)).update(sql.capture(), any(MapSqlParameterSource.class));
        assertThat(sql.getAllValues())
                .anySatisfy(s -> assertThat(s).contains("INSERT INTO").contains("'manual'"));
    }
}
