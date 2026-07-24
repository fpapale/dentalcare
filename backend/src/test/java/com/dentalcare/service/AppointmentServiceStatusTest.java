package com.dentalcare.service;

import com.dentalcare.exception.ResourceNotFoundException;
import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * updateStatus rispondeva 204 anche quando non aggiornava nulla: l'assistente vocale
 * riceveva "ok" e diceva al paziente che l'appuntamento era stato cancellato mentre
 * era ancora in agenda.
 */
@ExtendWith(MockitoExtension.class)
class AppointmentServiceStatusTest {

    @Mock
    NamedParameterJdbcTemplate jdbc;

    @Mock
    AppointmentEventService events;

    @Mock
    AccessScopeService accessScope;

    AppointmentService service;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID appointmentId = UUID.fromString("00000000-0000-0000-0000-0000000000aa");

    @BeforeEach
    void setup() {
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
        service = new AppointmentService(jdbc, events, accessScope);
    }

    @AfterEach
    void clear() {
        TenantContext.clear();
    }

    @Test
    void appuntamentoInesistenteDaNotFoundNonSuccesso() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(0);

        assertThatThrownBy(() -> service.updateStatus(appointmentId, "cancelled"))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining(appointmentId.toString());

        // niente evento: nessuno deve credere che l'agenda sia cambiata
        verify(events, never()).publish(any(), anyString());
    }

    @Test
    void statoInesistenteRifiutatoPrimaDiToccareIlDatabase() {
        // con zero righe PostgreSQL non valuta il CAST, quindi uno stato inventato
        // passava in silenzio: va fermato prima della query
        assertThatThrownBy(() -> service.updateStatus(appointmentId, "pippo"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("pippo");

        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
        verify(events, never()).publish(any(), anyString());
    }

    @Test
    void statoNullRifiutato() {
        assertThatThrownBy(() -> service.updateStatus(appointmentId, null))
                .isInstanceOf(IllegalArgumentException.class);

        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void aggiornamentoRiuscitoPubblicaLEvento() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(1);

        service.updateStatus(appointmentId, "cancelled");

        verify(events).publish(eq(clinicId), eq("changed"));
    }

    @Test
    void tuttiGliStatiDellEnumSonoAmmessi() {
        when(jdbc.update(anyString(), any(SqlParameterSource.class))).thenReturn(1);

        for (String status : new String[]{
                "scheduled", "confirmed", "presente", "in_progress", "completed", "cancelled", "no_show"}) {
            service.updateStatus(appointmentId, status);
        }
    }
}
