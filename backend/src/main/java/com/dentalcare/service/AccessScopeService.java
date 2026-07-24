package com.dentalcare.service;

import com.dentalcare.security.RoleConstants;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

/**
 * Scope di visibilità dei pazienti per ruolo (#42), guidato dall'impostazione
 * per-tenant {@code clinics.patient_visibility_mode} (per_provider | shared).
 *
 * <p>Regola unica di autorizzazione, applicata **lato server** (chiude il gap #24
 * per cui il filtro provider arrivava dal client):
 * <ul>
 *   <li>ruolo non clinico (segreteria/admin) → il filtro provider passato resta un
 *       filtro facoltativo di comodo, non un confine;</li>
 *   <li>ruolo clinico + modalità {@code shared} → nessun filtro: vede tutti i
 *       pazienti della **sede corrente**;</li>
 *   <li>ruolo clinico + modalità {@code per_provider} (default) → forzato ai
 *       **propri** pazienti, ignorando qualunque provider richiesto dal client.</li>
 * </ul>
 * La sessione è già legata a una sola sede via {@code clinicId} del JWT, quindi
 * "tutti" significa sempre "tutti della sede", mai cross-tenant.
 */
@Service
public class AccessScopeService {

    public static final String MODE_PER_PROVIDER = "per_provider";
    public static final String MODE_SHARED = "shared";

    private final NamedParameterJdbcTemplate jdbc;

    public AccessScopeService(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** true se il ruolo corrente (dal JWT) è clinico. */
    public boolean isCallerMedical() {
        return RoleConstants.isMedical(TenantContext.getCurrentRole());
    }

    /** providerId del chiamante (subject del JWT), o null se non risolvibile. */
    public UUID callerProviderId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) return null;
        try {
            return UUID.fromString(auth.getPrincipal().toString());
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    /** Modalità di visibilità della sede corrente; default {@code per_provider}. */
    public String visibilityMode() {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        List<String> rows = jdbc.queryForList(
                "SELECT patient_visibility_mode FROM " + TenantContext.validatedSchema()
                        + ".clinics WHERE id = :id",
                new MapSqlParameterSource("id", clinicId), String.class);
        String mode = rows.isEmpty() ? null : rows.get(0);
        return MODE_SHARED.equals(mode) ? MODE_SHARED : MODE_PER_PROVIDER;
    }

    /**
     * Filtro provider effettivo da applicare, derivato lato server dalla regola sopra.
     * {@code requested} è il providerId proposto dal client (usato solo per i ruoli non clinici).
     */
    public UUID resolveProviderFilter(UUID requested) {
        if (!isCallerMedical()) {
            return requested;
        }
        if (MODE_SHARED.equals(visibilityMode())) {
            return null;
        }
        return callerProviderId();
    }
}
