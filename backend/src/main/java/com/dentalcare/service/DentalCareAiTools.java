package com.dentalcare.service;

import com.dentalcare.dto.*;
import com.dentalcare.exception.AppointmentConflictException;
import com.dentalcare.exception.ResourceNotFoundException;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
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
    private final PendingActionService pendingActions;

    public DentalCareAiTools(
            AppointmentService appointmentService,
            PatientService patientService,
            EstimateService estimateService,
            RecallService recallService,
            InvoiceService invoiceService,
            DashboardService dashboardService,
            ProviderService providerService,
            PendingActionService pendingActions) {
        this.appointmentService = appointmentService;
        this.patientService = patientService;
        this.estimateService = estimateService;
        this.recallService = recallService;
        this.invoiceService = invoiceService;
        this.dashboardService = dashboardService;
        this.providerService = providerService;
        this.pendingActions = pendingActions;
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

    // --- agenda: slot liberi + scrittura (con conferma) ---

    private static final ZoneId ROME = ZoneId.of("Europe/Rome");
    private static final DateTimeFormatter HHMM = DateTimeFormatter.ofPattern("HH:mm");

    @Tool(description = "Find free appointment slots for a provider on a given date. Returns available start times (HH:mm, Europe/Rome). Use this BEFORE proposing or creating an appointment.")
    public List<String> findFreeSlots(
            @ToolParam(description = "Provider full or partial name. Ignored for medical staff (uses the caller).") String providerName,
            @ToolParam(description = "Date in YYYY-MM-DD format.") String date,
            @ToolParam(description = "Appointment duration in minutes (default 30).") Integer durationMinutes) {
        UUID providerId = isMedical() ? currentProviderId() : resolveProviderByName(providerName);
        if (providerId == null) return List.of();
        int dur = (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 30;
        LocalDate d;
        try { d = LocalDate.parse(date); } catch (Exception e) { return List.of(); }
        return appointmentService.findFreeSlots(providerId, d, dur).stream()
                .map(s -> s.atZoneSameInstant(ROME).format(HHMM))
                .toList();
    }

    @Tool(description = "Prepare creation of a new appointment and return a PREVIEW plus a short confirmation code. This does NOT save anything. Show the preview to the user; when the user confirms, call confirmAction with the returned code.")
    public String createAppointment(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Provider full or partial name. Ignored for medical staff (uses the caller).") String providerName,
            @ToolParam(description = "Date in YYYY-MM-DD format.") String date,
            @ToolParam(description = "Start time HH:mm (24h, Europe/Rome).") String time,
            @ToolParam(description = "Duration in minutes (default 30).") Integer durationMinutes,
            @ToolParam(description = "Chair/room label, e.g. 'Studio 1'. Default 'Studio 1'.") String chairLabel,
            @ToolParam(description = "Optional notes.") String notes) {

        UUID providerId = isMedical() ? currentProviderId() : resolveProviderByName(providerName);
        if (providerId == null) return "Errore: professionista non riconosciuto. Specifica il nome del medico.";

        int dur = (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 30;
        OffsetDateTime start, end;
        try {
            ZonedDateTime z = LocalDate.parse(date).atTime(LocalTime.parse(time)).atZone(ROME);
            start = z.toOffsetDateTime();
            end = z.plusMinutes(dur).toOffsetDateTime();
        } catch (Exception e) {
            return "Errore: data/ora non valide. Usa data YYYY-MM-DD e ora HH:mm.";
        }
        String chair = (chairLabel == null || chairLabel.isBlank()) ? "Studio 1" : chairLabel;
        String patientName = patientName(patientId);

        String summary = "Nuovo appuntamento per " + patientName + " il " + date + " alle " + time
                + " (" + dur + " min, " + chair + ")";
        CreateAppointmentRequest req = new CreateAppointmentRequest(
                UUID.fromString(patientId), providerId, chair, start, end, notes);
        String code = pendingActions.register(PendingActionService.Type.CREATE,
                currentProviderId(), req, null, null, summary);

        return "ANTEPRIMA — nessuna modifica salvata.\n"
                + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare rescheduling (move) of an existing appointment and return a PREVIEW plus a short confirmation code. Can also reassign it to another provider. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String rescheduleAppointment(
            @ToolParam(description = "Appointment UUID from getAppointments.") String appointmentId,
            @ToolParam(description = "New date in YYYY-MM-DD format.") String date,
            @ToolParam(description = "New start time HH:mm (24h, Europe/Rome).") String time,
            @ToolParam(description = "Duration in minutes (default 30).") Integer durationMinutes,
            @ToolParam(description = "Chair/room label. Leave blank to keep the appointment's current chair.") String chairLabel,
            @ToolParam(description = "Optional: full or partial name of a different provider to reassign the appointment to. Leave blank to keep the current provider.") String providerName) {

        UUID apptId;
        try { apptId = UUID.fromString(appointmentId); }
        catch (Exception e) { return "Errore: id appuntamento non valido."; }

        int dur = (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 30;
        OffsetDateTime start, end;
        try {
            ZonedDateTime z = LocalDate.parse(date).atTime(LocalTime.parse(time)).atZone(ROME);
            start = z.toOffsetDateTime();
            end = z.plusMinutes(dur).toOffsetDateTime();
        } catch (Exception e) {
            return "Errore: data/ora non valide. Usa data YYYY-MM-DD e ora HH:mm.";
        }

        // Poltrona: se non indicata, mantieni quella corrente dell'appuntamento.
        String chair = (chairLabel != null && !chairLabel.isBlank())
                ? chairLabel
                : appointmentService.findChairLabel(apptId);
        if (chair == null) return "Appuntamento non trovato.";

        // Medico: medical riassegna solo a se stesso; altrimenti per nome (se indicato).
        UUID newProviderId = null;
        String providerNote = "";
        if (isMedical()) {
            // un medico non riassegna ad altri
            providerNote = "";
        } else if (providerName != null && !providerName.isBlank()) {
            newProviderId = resolveProviderByName(providerName);
            if (newProviderId == null) return "Errore: medico '" + providerName + "' non riconosciuto.";
            // Cambio medico vietato se l'appuntamento è legato a piano di cura/preventivo.
            if (appointmentService.isBoundToClinicalPlan(apptId)) {
                return "Non è possibile cambiare medico: l'appuntamento è legato a un piano di cura o "
                        + "preventivo. Posso spostarlo mantenendo lo stesso medico. Procedo così?";
            }
            providerNote = ", medico: " + providerName;
        }

        String summary = "Spostamento appuntamento al " + date + " alle " + time
                + " (" + dur + " min, " + chair + providerNote + ")";
        RescheduleAppointmentRequest req = new RescheduleAppointmentRequest(start, end, chair, newProviderId);
        String code = pendingActions.register(PendingActionService.Type.RESCHEDULE,
                currentProviderId(), null, apptId, req, summary);

        return "ANTEPRIMA — nessuna modifica salvata.\n"
                + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare cancellation of an appointment and return a PREVIEW plus a short confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String cancelAppointment(
            @ToolParam(description = "Appointment UUID from getAppointments.") String appointmentId) {
        UUID apptId;
        try { apptId = UUID.fromString(appointmentId); }
        catch (Exception e) { return "Errore: id appuntamento non valido."; }

        String summary = "Annullamento dell'appuntamento selezionato";
        String code = pendingActions.register(PendingActionService.Type.CANCEL,
                currentProviderId(), null, apptId, null, summary);

        return "ANTEPRIMA — nessuna modifica salvata.\n"
                + summary + ".\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Execute a previously previewed write action (create/reschedule/cancel appointment) using the confirmation code returned by the preview. Call this only after the user has explicitly confirmed.")
    public String confirmAction(
            @ToolParam(description = "The confirmation code returned by the preview tool.") String code) {
        PendingActionService.Pending p = pendingActions.consume(code);
        if (p == null) return "Codice di conferma non valido o scaduto. Riprova l'operazione.";
        if (!java.util.Objects.equals(p.providerScope(), currentProviderId())) {
            return "Codice di conferma non valido per questo utente.";
        }
        try {
            switch (p.type()) {
                case CREATE -> {
                    UUID id = appointmentService.create(p.create());
                    return "Appuntamento creato (id " + id + "). " + p.summary();
                }
                case RESCHEDULE -> {
                    appointmentService.reschedule(p.appointmentId(), p.reschedule());
                    return "Fatto. " + p.summary();
                }
                case CANCEL -> {
                    boolean ok = appointmentService.cancel(p.appointmentId());
                    return ok ? "Appuntamento annullato." : "Appuntamento non trovato o già annullato.";
                }
                default -> { return "Azione non riconosciuta."; }
            }
        } catch (ResourceNotFoundException nf) {
            return "Appuntamento non trovato.";
        } catch (AppointmentConflictException ce) {
            return "Operazione non possibile: " + ce.getMessage();
        } catch (Exception e) {
            return "Errore nell'esecuzione: " + e.getMessage();
        }
    }

    @Tool(description = "Get today's operational briefing: appointment counts by status plus overdue recalls, overdue invoices and pending estimates.")
    public DailyBriefingDto getDailyBriefing() {
        UUID providerId = isMedical() ? currentProviderId() : null;
        LocalDate today = LocalDate.now();

        List<AppointmentDto> appts = appointmentService.findByDate(today, providerId);
        long total = appts.size();
        long confirmed = appts.stream().filter(a ->
                "confirmed".equals(a.appointmentStatus()) || "scheduled".equals(a.appointmentStatus())).count();
        long completed = appts.stream().filter(a -> "completed".equals(a.appointmentStatus())).count();
        long cancelled = appts.stream().filter(a ->
                "cancelled".equals(a.appointmentStatus()) || "no_show".equals(a.appointmentStatus())).count();

        long overdueRecalls = recallService.findAll("pending", null, null).stream()
                .filter(r -> r.dueDate() != null && r.dueDate().isBefore(today)).count();
        long overdueInvoices = invoiceService.findAll("overdue", providerId).size();
        long pendingEstimates = estimateService.findAll("sent", providerId).size();

        return new DailyBriefingDto(today, total, confirmed, completed, cancelled,
                overdueRecalls, overdueInvoices, pendingEstimates);
    }

    // --- private helpers ---

    private String patientName(String patientId) {
        try {
            return patientService.findById(UUID.fromString(patientId), null)
                    .map(PatientDetailDto::fullName)
                    .orElse(patientId);
        } catch (Exception e) {
            return patientId;
        }
    }

    // Titoli/onorifici da ignorare nel match per nome (es. "dr Marchetti").
    private static final java.util.Set<String> HONORIFICS = java.util.Set.of(
            "dr", "dr.", "dott", "dott.", "dottor", "dottore", "dottoressa",
            "dssa", "dr.ssa", "prof", "prof.", "il", "la", "lo", "del", "della", "dello");

    private UUID resolveProviderByName(String name) {
        if (name == null || name.isBlank()) return null;
        // Tokenizza la query e scarta onorifici: "dr Marchetti" -> ["marchetti"].
        List<String> tokens = java.util.Arrays.stream(name.toLowerCase().trim().split("\\s+"))
                .filter(t -> !t.isBlank() && !HONORIFICS.contains(t))
                .toList();
        if (tokens.isEmpty()) return null;
        return providerService.findAll(true).stream()
                .filter(p -> p.fullName() != null)
                .filter(p -> {
                    String full = p.fullName().toLowerCase();
                    return tokens.stream().allMatch(full::contains);
                })
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
