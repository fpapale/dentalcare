package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AccessScopeServiceTest {

    @Mock NamedParameterJdbcTemplate jdbc;

    AccessScopeService service;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UUID ownProvider = UUID.fromString("00000000-0000-0000-0000-0000000000aa");
    private final UUID otherProvider = UUID.fromString("00000000-0000-0000-0000-0000000000bb");

    @BeforeEach
    void setup() {
        service = new AccessScopeService(jdbc);
        TenantContext.setCurrentSchema("t_abcd1234");
        TenantContext.setCurrentClinicId(clinicId.toString());
    }

    @AfterEach
    void clear() {
        TenantContext.clear();
        SecurityContextHolder.clearContext();
    }

    private void authAs(UUID providerId) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(providerId.toString(), null, List.of()));
    }

    private void stubMode(String mode) {
        when(jdbc.queryForList(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn(List.of(mode));
    }

    @Test
    void nonMedicalRole_keepsClientProvidedFilter() {
        TenantContext.setCurrentRole("secretary");
        assertThat(service.resolveProviderFilter(otherProvider)).isEqualTo(otherProvider);
        assertThat(service.resolveProviderFilter(null)).isNull();
    }

    @Test
    void medicalRole_perProviderMode_forcesOwnAndIgnoresRequested() {
        TenantContext.setCurrentRole("dentist");
        stubMode("per_provider");
        authAs(ownProvider);
        assertThat(service.resolveProviderFilter(otherProvider)).isEqualTo(ownProvider);
    }

    @Test
    void medicalRole_sharedMode_returnsNull() {
        TenantContext.setCurrentRole("hygienist");
        stubMode("shared");
        authAs(ownProvider);
        assertThat(service.resolveProviderFilter(otherProvider)).isNull();
    }

    @Test
    void visibilityMode_defaultsToPerProviderWhenUnset() {
        TenantContext.setCurrentRole("dentist");
        lenient().when(jdbc.queryForList(anyString(), any(SqlParameterSource.class), eq(String.class)))
                .thenReturn(List.of());
        assertThat(service.visibilityMode()).isEqualTo("per_provider");
    }
}
