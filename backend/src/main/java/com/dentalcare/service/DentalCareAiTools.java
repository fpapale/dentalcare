package com.dentalcare.service;

import com.dentalcare.dto.*;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Component
public class DentalCareAiTools {

    private final AppointmentService appointmentService;
    private final PatientService patientService;
    private final EstimateService estimateService;
    private final RecallService recallService;
    private final InvoiceService invoiceService;
    private final DashboardService dashboardService;
    private final ProviderService providerService;

    public DentalCareAiTools(
            AppointmentService appointmentService,
            PatientService patientService,
            EstimateService estimateService,
            RecallService recallService,
            InvoiceService invoiceService,
            DashboardService dashboardService,
            ProviderService providerService) {
        this.appointmentService = appointmentService;
        this.patientService = patientService;
        this.estimateService = estimateService;
        this.recallService = recallService;
        this.invoiceService = invoiceService;
        this.dashboardService = dashboardService;
        this.providerService = providerService;
    }

    // --- role helpers ---

    private String currentRole() {
        return SecurityContextHolder.getContext().getAuthentication().getAuthorities()
                .stream().findFirst()
                .map(a -> a.getAuthority().replace("ROLE_", "").toLowerCase())
                .orElse("doctor");
    }

    private UUID currentProviderId() {
        return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName());
    }

    private boolean isMedical() {
        String r = currentRole();
        return "doctor".equals(r) || "hygienist".equals(r);
    }

    // --- tools ---

    @Tool(description = "Get appointments for a specific date (YYYY-MM-DD) or a date range. Optionally filter by provider name.")
    public List<AppointmentDto> getAppointments(
            @ToolParam(description = "Single date in YYYY-MM-DD format. Use this for 'today', 'tomorrow', or a specific day.") String date,
            @ToolParam(description = "Start date YYYY-MM-DD for a range query (use with dateTo).") String dateFrom,
            @ToolParam(description = "End date YYYY-MM-DD for a range query (use with dateFrom).") String dateTo,
            @ToolParam(description = "Provider full name or partial name to filter (optional, ignored for non-secretary roles).") String providerName) {

        // Medical roles see only their own appointments
        UUID providerId = isMedical() ? currentProviderId() : resolveProviderByName(providerName);

        if (date != null && !date.isBlank()) {
            return appointmentService.findByDate(LocalDate.parse(date), providerId);
        }
        if (dateFrom != null && dateTo != null && !dateFrom.isBlank() && !dateTo.isBlank()) {
            return appointmentService.findByDateRange(LocalDate.parse(dateFrom), LocalDate.parse(dateTo), providerId);
        }
        return appointmentService.findByDate(LocalDate.now(), providerId);
    }

    @Tool(description = "Search patients by name, phone, or email. Returns a list of matching patients.")
    public List<PatientListDto> searchPatients(
            @ToolParam(description = "Search query: patient name, phone number, or email address.") String query) {
        // Medical roles see only their own patients
        UUID providerId = isMedical() ? currentProviderId() : null;
        return patientService.findAll(query, providerId);
    }

    @Tool(description = "Get detailed information about a specific patient. Medical staff see full clinical data for their own patients; secretaries see overview, estimates, recalls and invoices only.")
    public Object getPatientDetail(
            @ToolParam(description = "Patient UUID as returned by searchPatients.") String patientId) {
        UUID pid = UUID.fromString(patientId);
        if (isMedical()) {
            // Only returns data if patient belongs to this provider
            return patientService.findById(pid, currentProviderId()).orElse(null);
        }
        // Secretary: return summary without clinical fields
        return patientService.findById(pid, null)
                .map(this::toSummary)
                .orElse(null);
    }

    @Tool(description = "Get estimates (preventivi) filtered by status and/or patient. Status values: draft, proposed, accepted, rejected.")
    public List<EstimateDto> getEstimates(
            @ToolParam(description = "Status filter: draft, proposed, accepted, rejected. Leave blank for all.") String status,
            @ToolParam(description = "Patient UUID to filter estimates for a specific patient (optional).") String patientId) {
        String s = (status == null || status.isBlank()) ? null : status;
        if (patientId != null && !patientId.isBlank()) {
            return estimateService.findByPatient(UUID.fromString(patientId));
        }
        // Medical roles: filter by own provider
        UUID providerId = isMedical() ? currentProviderId() : null;
        return estimateService.findAll(s, providerId);
    }

    @Tool(description = "Get recalls (richiami) filtered by status, priority, or patient. Status: pending, done, cancelled. Priority: low, medium, high. For non-secretary roles a patient UUID is required.")
    public List<RecallDto> getRecalls(
            @ToolParam(description = "Status filter: pending, done, cancelled. Leave blank for all.") String status,
            @ToolParam(description = "Priority filter: low, medium, high. Leave blank for all.") String priority,
            @ToolParam(description = "Patient UUID to filter recalls for a specific patient (required for non-secretary roles).") String patientId) {
        // Medical roles require patientId; return empty if missing
        if (isMedical() && (patientId == null || patientId.isBlank())) {
            return List.of();
        }
        UUID pid = (patientId != null && !patientId.isBlank()) ? UUID.fromString(patientId) : null;
        return recallService.findAll(
                (status == null || status.isBlank()) ? null : status,
                (priority == null || priority.isBlank()) ? null : priority,
                pid);
    }

    @Tool(description = "Get invoices (fatture) filtered by status. Status values: draft, sent, paid, overdue.")
    public List<InvoiceDto> getInvoices(
            @ToolParam(description = "Status filter: draft, sent, paid, overdue. Leave blank for all.") String status) {
        String s = (status == null || status.isBlank()) ? null : status;
        // Medical roles see only invoices for their own patients
        UUID providerId = isMedical() ? currentProviderId() : null;
        return invoiceService.findAll(s, providerId);
    }

    @Tool(description = "Get the clinic dashboard summary: today's appointments count, patient stats, treatment plan overview.")
    public DashboardDto getDashboard() {
        return dashboardService.getDashboard(null);
    }

    @Tool(description = "Get the list of all active providers (doctors, hygienists) in the clinic.")
    public List<ProviderDto> getProviders() {
        return providerService.findAll(true);
    }

    // --- private helpers ---

    private UUID resolveProviderByName(String name) {
        if (name == null || name.isBlank()) return null;
        String nameLower = name.toLowerCase();
        return providerService.findAll(true).stream()
                .filter(p -> p.fullName() != null && p.fullName().toLowerCase().contains(nameLower))
                .map(ProviderDto::providerId)
                .findFirst().orElse(null);
    }

    private PatientSummaryDto toSummary(PatientDetailDto d) {
        return new PatientSummaryDto(
                d.patientId(), d.firstName(), d.lastName(), d.fullName(),
                d.fiscalCode(), d.birthDate(), d.ageYears(),
                d.phone(), d.email(), d.city(), d.province(), d.addressLine1(), d.postalCode(),
                d.notes(), d.totalAppointments(), d.treatmentPlansCount(),
                d.openTreatmentItemsCount(), d.photoUrl(),
                d.primaryProviderId(), d.primaryProviderName());
    }
}
