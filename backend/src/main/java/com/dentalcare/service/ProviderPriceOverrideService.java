package com.dentalcare.service;

import com.dentalcare.dto.ProviderPriceDto;
import com.dentalcare.security.TenantContext;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Override prezzi per medico, versionati per intervallo (#44). "Impostare un prezzo" non è mai
 * un UPDATE in-place: chiude la versione corrente ({@code valid_to = now()}) e ne inserisce una nuova,
 * così lo storico resta e i preventivi passati non cambiano retroattivamente.
 */
@Service
public class ProviderPriceOverrideService {

    private final NamedParameterJdbcTemplate jdbc;
    private final AccessScopeService accessScope;

    public ProviderPriceOverrideService(NamedParameterJdbcTemplate jdbc, AccessScopeService accessScope) {
        this.jdbc = jdbc;
        this.accessScope = accessScope;
    }

    private String s() { return TenantContext.validatedSchema(); }

    /** Un medico gestisce solo le proprie tariffe; l'amministratore quelle di chiunque. */
    private void assertCanManage(UUID providerId) {
        String role = TenantContext.getCurrentRole();
        boolean isAdmin = "admin".equals(role) || "tenant_admin".equals(role);
        UUID caller = accessScope.callerProviderId();
        if (!isAdmin && !providerId.equals(caller)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Puoi gestire solo le tue tariffe");
        }
    }

    /** Elenco prestazioni attive con prezzo studio + eventuale override corrente del medico. */
    public List<ProviderPriceDto> list(UUID providerId) {
        assertCanManage(providerId);
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        String sql = """
            SELECT sc.id AS service_id, sc.name, sc.category, sc.default_price AS catalog_price,
                   ov.price AS override_price
            FROM %s.service_catalog sc
            LEFT JOIN %s.provider_price_overrides ov
              ON ov.service_id = sc.id AND ov.provider_id = :provider AND ov.valid_to IS NULL
            WHERE sc.clinic_id = :clinicId AND sc.is_active = true
            ORDER BY sc.category NULLS FIRST, sc.name
            """.formatted(s(), s());
        return jdbc.query(sql,
                new MapSqlParameterSource().addValue("provider", providerId).addValue("clinicId", clinicId),
                (rs, n) -> {
                    BigDecimal catalog = rs.getBigDecimal("catalog_price");
                    BigDecimal override = rs.getBigDecimal("override_price");
                    BigDecimal effective = override != null ? override : catalog;
                    return new ProviderPriceDto(
                            rs.getObject("service_id", UUID.class),
                            rs.getString("name"),
                            rs.getString("category"),
                            catalog,
                            override,
                            effective,
                            override != null ? "override" : "catalog");
                });
    }

    /** Imposta un override: chiude la versione corrente e ne crea una nuova. */
    @Transactional
    public void setPrice(UUID providerId, UUID serviceId, BigDecimal price) {
        assertCanManage(providerId);
        if (price == null || price.signum() < 0) {
            throw new IllegalArgumentException("Prezzo non valido");
        }
        closeCurrent(providerId, serviceId);
        jdbc.update("""
            INSERT INTO %s.provider_price_overrides (provider_id, service_id, price, created_by)
            VALUES (:provider, :service, :price, :createdBy)
            """.formatted(s()),
                new MapSqlParameterSource()
                        .addValue("provider", providerId)
                        .addValue("service", serviceId)
                        .addValue("price", price)
                        .addValue("createdBy", accessScope.callerProviderId()));
    }

    /** Rimuove l'override corrente (chiude la versione): il prezzo torna al listino studio. */
    @Transactional
    public void removeOverride(UUID providerId, UUID serviceId) {
        assertCanManage(providerId);
        closeCurrent(providerId, serviceId);
    }

    private void closeCurrent(UUID providerId, UUID serviceId) {
        jdbc.update("""
            UPDATE %s.provider_price_overrides SET valid_to = now()
            WHERE provider_id = :provider AND service_id = :service AND valid_to IS NULL
            """.formatted(s()),
                new MapSqlParameterSource().addValue("provider", providerId).addValue("service", serviceId));
    }
}
