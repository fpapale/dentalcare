package com.dentalcare.service;

import com.dentalcare.dto.AppointmentDto;
import com.dentalcare.dto.DashboardDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class DashboardService {

    private final NamedParameterJdbcTemplate jdbc;
    private final AppointmentService appointmentService;

    public DashboardService(NamedParameterJdbcTemplate jdbc, AppointmentService appointmentService) {
        this.jdbc = jdbc;
        this.appointmentService = appointmentService;
    }

    private static final Set<String> ADMIN_ROLES = Set.of("ROLE_ADMIN", "ROLE_TENANT_ADMIN", "ROLE_SECRETARY");

    private String s() { return TenantContext.validatedSchema(); }

    private UUID callerProviderId() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) return null;
        try { return UUID.fromString(auth.getPrincipal().toString()); } catch (IllegalArgumentException e) { return null; }
    }

    private boolean callerIsMedical() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return false;
        return auth.getAuthorities().stream().noneMatch(a -> ADMIN_ROLES.contains(a.getAuthority()));
    }

    public DashboardDto getDashboard(UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());
        // medical roles: always own UUID from JWT (cannot be overridden by client)
        // admin/secretary: use client-supplied value (null=all, UUID=filter by doctor, e.g. demo persona)
        UUID effectiveProviderId = callerIsMedical() ? callerProviderId() : providerId;

        String sql = """
            SELECT clinic_name, city,
                   patients_count, active_providers_count,
                   in_progress_treatment_plans_count
            FROM %s.v_clinic_dashboard
            WHERE clinic_id = :clinicId
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);
        Map<String, Object> row = jdbc.queryForMap(sql, params);

        String estProviderFilter  = effectiveProviderId != null ? "AND created_by_provider_id = :providerId" : "";
        String planProviderFilter = effectiveProviderId != null ? "AND created_by_provider_id = :providerId" : "";
        MapSqlParameterSource scopedParams = new MapSqlParameterSource().addValue("clinicId", clinicId);
        if (effectiveProviderId != null) scopedParams.addValue("providerId", effectiveProviderId);

        String estSql = """
            SELECT
              COUNT(*) FILTER (WHERE status <> 'draft') AS sent_count,
              COALESCE(SUM(total_amount) FILTER (WHERE status = 'accepted'), 0.00) AS accepted_amount
            FROM %s.estimates
            WHERE clinic_id = :clinicId %s
            """.formatted(s(), estProviderFilter);
        Map<String, Object> estRow = jdbc.queryForMap(estSql, scopedParams);

        String plansSql = """
            SELECT
              COUNT(*) FILTER (WHERE status = 'draft')    AS plans_draft,
              COUNT(*) FILTER (WHERE status = 'proposed') AS plans_proposed,
              COUNT(*) FILTER (WHERE status = 'accepted') AS plans_accepted,
              COUNT(*) FILTER (WHERE status = 'rejected') AS plans_rejected
            FROM %s.treatment_plans
            WHERE clinic_id = :clinicId AND status <> 'completed' %s
            """.formatted(s(), planProviderFilter);
        Map<String, Object> planRow = jdbc.queryForMap(plansSql, scopedParams);

        List<AppointmentDto> todayAppts = appointmentService.findByDate(LocalDate.now(), effectiveProviderId);

        java.time.OffsetDateTime now = java.time.OffsetDateTime.now();
        boolean hasActiveToday = todayAppts.stream().anyMatch(a ->
                !"cancelled".equals(a.appointmentStatus())
                && !"no_show".equals(a.appointmentStatus())
                && a.endsAt().isAfter(now));

        boolean nextDay = false;
        List<AppointmentDto> displayAppts = todayAppts;
        if (!hasActiveToday) {
            List<AppointmentDto> tomorrowAppts = appointmentService.findByDate(LocalDate.now().plusDays(1), effectiveProviderId);
            if (!tomorrowAppts.isEmpty()) {
                displayAppts = tomorrowAppts;
                nextDay = true;
            }
        }

        long todayTotal = todayAppts.size();
        long todayConfirmed = todayAppts.stream()
                .filter(a -> "confirmed".equals(a.appointmentStatus()) || "scheduled".equals(a.appointmentStatus())).count();
        long todayCompleted = todayAppts.stream()
                .filter(a -> "completed".equals(a.appointmentStatus())).count();
        long todayCancelled = todayAppts.stream()
                .filter(a -> "cancelled".equals(a.appointmentStatus()) || "no_show".equals(a.appointmentStatus())).count();

        return new DashboardDto(
                (String) row.get("clinic_name"),
                (String) row.get("city"),
                toLong(row.get("patients_count")),
                toLong(row.get("active_providers_count")),
                toLong(row.get("in_progress_treatment_plans_count")),
                toLong(estRow.get("sent_count")),
                (BigDecimal) estRow.get("accepted_amount"),
                todayTotal,
                todayConfirmed,
                todayCompleted,
                todayCancelled,
                displayAppts,
                toLong(planRow.get("plans_draft")),
                toLong(planRow.get("plans_proposed")),
                toLong(planRow.get("plans_accepted")),
                toLong(planRow.get("plans_rejected")),
                nextDay
        );
    }

    private long toLong(Object val) {
        if (val == null) return 0L;
        return ((Number) val).longValue();
    }
}
