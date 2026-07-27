package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProviderPriceOverrideServiceTest {

    @Mock NamedParameterJdbcTemplate jdbc;
    @Mock AccessScopeService accessScope;

    ProviderPriceOverrideService service;

    private final UUID own = UUID.fromString("00000000-0000-0000-0000-0000000000aa");
    private final UUID other = UUID.fromString("00000000-0000-0000-0000-0000000000bb");
    private final UUID serviceId = UUID.fromString("00000000-0000-0000-0000-0000000000cc");
    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");

    @BeforeEach
    void setup() {
        service = new ProviderPriceOverrideService(jdbc, accessScope);
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
    }

    @AfterEach
    void clear() {
        TenantContext.clear();
    }

    @Test
    void setPrice_ownProvider_closesCurrentThenInsertsNewVersion() {
        TenantContext.setCurrentRole("dentist");
        when(accessScope.callerProviderId()).thenReturn(own);

        service.setPrice(own, serviceId, new BigDecimal("120.00"));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, times(2)).update(sql.capture(), any(SqlParameterSource.class));
        assertThat(sql.getAllValues()).anySatisfy(q -> assertThat(q).contains("valid_to = now()"));
        assertThat(sql.getAllValues()).anySatisfy(q -> assertThat(q).contains("INSERT INTO"));
    }

    @Test
    void setPrice_negativePrice_rejected() {
        TenantContext.setCurrentRole("dentist");
        when(accessScope.callerProviderId()).thenReturn(own);
        assertThatThrownBy(() -> service.setPrice(own, serviceId, new BigDecimal("-1")))
                .isInstanceOf(IllegalArgumentException.class);
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void setPrice_otherProviderNonAdmin_forbidden() {
        TenantContext.setCurrentRole("dentist");
        when(accessScope.callerProviderId()).thenReturn(own);
        assertThatThrownBy(() -> service.setPrice(other, serviceId, new BigDecimal("10")))
                .isInstanceOf(ResponseStatusException.class)
                .satisfies(e -> assertThat(((ResponseStatusException) e).getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN));
        verify(jdbc, never()).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void setPrice_adminCanManageAnyProvider() {
        TenantContext.setCurrentRole("tenant_admin");
        lenient().when(accessScope.callerProviderId()).thenReturn(null);
        service.setPrice(other, serviceId, new BigDecimal("55"));
        verify(jdbc, times(2)).update(anyString(), any(SqlParameterSource.class));
    }

    @Test
    void removeOverride_closesCurrentVersionOnly() {
        TenantContext.setCurrentRole("dentist");
        when(accessScope.callerProviderId()).thenReturn(own);

        service.removeOverride(own, serviceId);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, times(1)).update(sql.capture(), any(SqlParameterSource.class));
        assertThat(sql.getValue()).contains("valid_to = now()");
    }
}
