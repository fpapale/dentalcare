package com.dentalcare.service;

import com.dentalcare.dto.AppointmentDto;
import com.dentalcare.dto.DashboardDto;
import com.dentalcare.security.TenantContext;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class DashboardService {

    private final NamedParameterJdbcTemplate jdbc;
    private final AppointmentService appointmentService;

    public DashboardService(NamedParameterJdbcTemplate jdbc, AppointmentService appointmentService) {
        this.jdbc = jdbc;
        this.appointmentService = appointmentService;
    }

    private String s() { return TenantContext.validatedSchema(); }

    public DashboardDto getDashboard(UUID providerId) {
        UUID clinicId = UUID.fromString(TenantContext.getCurrentTenant());

        String sql = """
            SELECT clinic_name, city,
                   patients_count, active_providers_count,
                   in_progress_treatment_plans_count
            FROM %s.v_clinic_dashboard
            WHERE clinic_id = :clinicId
            """.formatted(s());
        MapSqlParameterSource params = new MapSqlParameterSource().addValue("clinicId", clinicId);
        Map<String, Object> row = jdbc.queryForMap(sql, params);

        String estProviderFilter  = providerId != null ? "AND created_by_provider_id = :providerId" : "";
        String planProviderFilter = providerId != null ? "AND provider_id = :providerId" : "";
        MapSqlParameterSource scopedParams = new MapSqlParameterSource().addValue("clinicId", clinicId);
        if (providerId != null) scopedParams.addValue("providerId", providerId);

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

        List<AppointmentDto> todayAppts = appointmentService.findByDate(LocalDate.now(), providerId);

        java.time.OffsetDateTime now = java.time.OffsetDateTime.now();
        boolean hasActiveToday = todayAppts.stream().anyMatch(a ->
                !"cancelled".equals(a.appointmentStatus())
                && !"no_show".equals(a.appointmentStatus())
                && a.endsAt().isAfter(now));

        boolean nextDay = false;
        List<AppointmentDto> displayAppts = todayAppts;
        if (!hasActiveToday) {
            List<AppointmentDto> tomorrowAppts = appointmentService.findByDate(LocalDate.now().plusDays(1), providerId);
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
