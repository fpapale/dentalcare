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
import java.util.Set;
import java.util.UUID;

@Component
public class DentalCareAiTools {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(DentalCareAiTools.class);

    private final AppointmentService appointmentService;
    private final PatientService patientService;
    private final EstimateService estimateService;
    private final RecallService recallService;
    private final InvoiceService invoiceService;
    private final DashboardService dashboardService;
    private final ProviderService providerService;
    private final PendingActionService pendingActions;
    private final AiAuditService auditService;
    private final TreatmentPlanService treatmentPlanService;
    private final ClinicalRecordService clinicalRecordService;
    private final DiagnosiService diagnosiService;
    private final PrescrizioneService prescrizioneService;
    private final OdontogramService odontogramService;
    private final ServiceCatalogService serviceCatalogService;
    private final ProductService productService;
    private final AnamnesisService anamnesisService;

    public DentalCareAiTools(
            AppointmentService appointmentService,
            PatientService patientService,
            EstimateService estimateService,
            RecallService recallService,
            InvoiceService invoiceService,
            DashboardService dashboardService,
            ProviderService providerService,
            PendingActionService pendingActions,
            AiAuditService auditService,
            TreatmentPlanService treatmentPlanService,
            ClinicalRecordService clinicalRecordService,
            DiagnosiService diagnosiService,
            PrescrizioneService prescrizioneService,
            OdontogramService odontogramService,
            ServiceCatalogService serviceCatalogService,
            ProductService productService,
            AnamnesisService anamnesisService) {
        this.appointmentService = appointmentService;
        this.patientService = patientService;
        this.estimateService = estimateService;
        this.recallService = recallService;
        this.invoiceService = invoiceService;
        this.dashboardService = dashboardService;
        this.providerService = providerService;
        this.pendingActions = pendingActions;
        this.auditService = auditService;
        this.treatmentPlanService = treatmentPlanService;
        this.clinicalRecordService = clinicalRecordService;
        this.diagnosiService = diagnosiService;
        this.prescrizioneService = prescrizioneService;
        this.odontogramService = odontogramService;
        this.serviceCatalogService = serviceCatalogService;
        this.productService = productService;
        this.anamnesisService = anamnesisService;
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

    // Ruoli clinici (provider_role nel DB) abilitati a leggere/scrivere dati clinici.
    // NB: il DB usa 'dentist', non 'doctor'; 'doctor' resta per retrocompatibilità.
    private static final Set<String> MEDICAL_ROLES =
            Set.of("dentist", "hygienist", "orthodontist", "surgeon", "doctor");

    private boolean isMedical() {
        return MEDICAL_ROLES.contains(currentRole());
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

    @Tool(description = "Get estimates (preventivi) filtered by status and/or patient. Status values: draft, sent, accepted, rejected, expired, cancelled.")
    public List<EstimateDto> getEstimates(
            @ToolParam(description = "Status filter: draft, sent, accepted, rejected, expired, cancelled. Leave blank for all.") String status,
            @ToolParam(description = "Patient UUID to filter estimates for a specific patient (optional).") String patientId) {
        String s = (status == null || status.isBlank()) ? null : status;
        if (patientId != null && !patientId.isBlank()) {
            return estimateService.findByPatient(UUID.fromString(patientId));
        }
        // Medical roles: filter by own provider
        UUID providerId = isMedical() ? currentProviderId() : null;
        return estimateService.findAll(s, providerId);
    }

    @Tool(description = "Get recalls (richiami) filtered by status, priority, or patient. Status values: da_contattare, contattato, in_attesa, confermato, chiuso, annullato. Priority values: alta, media, bassa. For non-secretary roles a patient UUID is required.")
    public List<RecallDto> getRecalls(
            @ToolParam(description = "Status filter: da_contattare, contattato, in_attesa, confermato, chiuso, annullato. Leave blank for all.") String status,
            @ToolParam(description = "Priority filter: alta, media, bassa. Leave blank for all.") String priority,
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

    @Tool(description = "Get invoices (fatture) filtered by status. Status values: draft, issued, paid, cancelled.")
    public List<InvoiceDto> getInvoices(
            @ToolParam(description = "Status filter: draft, issued, paid, cancelled. Leave blank for all.") String status) {
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
        String code = pendingActions.register("CREATE_APPOINTMENT", currentProviderId(), summary,
                () -> {
                    UUID id = appointmentService.create(req);
                    return "Appuntamento creato (id " + id + "). " + summary;
                });

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

        log.info("rescheduleAppointment in: id='{}' date='{}' time='{}' dur={} chair='{}' provider='{}'",
                appointmentId, date, time, durationMinutes, chairLabel, providerName);
        UUID apptId;
        try { apptId = UUID.fromString(appointmentId); }
        catch (Exception e) {
            log.warn("rescheduleAppointment: id non parsabile '{}'", appointmentId);
            return "Errore: id appuntamento non valido.";
        }

        int dur = (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 30;
        OffsetDateTime start, end;
        try {
            ZonedDateTime z = LocalDate.parse(date).atTime(LocalTime.parse(time)).atZone(ROME);
            start = z.toOffsetDateTime();
            end = z.plusMinutes(dur).toOffsetDateTime();
        } catch (Exception e) {
            return "Errore: data/ora non valide. Usa data YYYY-MM-DD e ora HH:mm.";
        }

        // Verifica SEMPRE che l'appuntamento esista (l'id non va inventato né ricordato dai turni).
        String currentChair = appointmentService.findChairLabel(apptId);
        if (currentChair == null)
            return "Appuntamento non trovato. Richiama getAppointments per il giorno dell'appuntamento "
                    + "e usa l'appointmentId esatto restituito, poi riprova.";

        // Poltrona: se non indicata, mantieni quella corrente dell'appuntamento.
        String chair = (chairLabel != null && !chairLabel.isBlank()) ? chairLabel : currentChair;

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

        RescheduleAppointmentRequest req = new RescheduleAppointmentRequest(start, end, chair, newProviderId);

        // Pre-check conflitti: non presentare un'anteprima confermabile su uno slot impossibile.
        // Mai cambiare poltrona/orario in silenzio: avvisa e PROPONI, la conferma resta all'utente.
        AppointmentConflictException conflict = appointmentService.rescheduleConflict(apptId, req);
        if (conflict != null) {
            log.info("rescheduleAppointment conflict in anteprima: apptId={} type={} date={} time={} msg='{}'",
                    apptId, conflict.getConflictType(), date, time, conflict.getMessage());
            // Riporta SEMPRE data+ora tentate: rende l'errore trasparente e auto-correggibile.
            String when = "Per il " + date + " alle " + time + ": ";
            return switch (conflict.getConflictType()) {
                case "CHAIR_CONFLICT" -> {
                    List<String> freeChairs = appointmentService.findFreeChairs(start, end);
                    yield when + conflict.getMessage() + (freeChairs.isEmpty()
                            ? " Nessun'altra poltrona libera in questo orario: scegli un altro orario."
                            : " Poltrone libere a quell'ora: " + String.join(", ", freeChairs)
                              + ". Vuoi spostarlo in una di queste?");
                }
                case "PROVIDER_CONFLICT" -> {
                    UUID provId = newProviderId != null ? newProviderId : appointmentService.findProviderId(apptId);
                    List<String> slots = provId == null ? List.of()
                            : appointmentService.findFreeSlots(provId, LocalDate.parse(date), dur).stream()
                                    .map(s -> s.atZoneSameInstant(ROME).format(HHMM)).limit(5).toList();
                    yield when + conflict.getMessage() + (slots.isEmpty()
                            ? " Nessuno slot libero per il medico quel giorno: prova un'altra data."
                            : " Orari liberi del medico il " + date + ": " + String.join(", ", slots)
                              + ". Quale preferisci?");
                }
                default -> when + conflict.getMessage() + " Indica un altro orario o un'altra poltrona.";
            };
        }

        String summary = "Spostamento appuntamento al " + date + " alle " + time
                + " (" + dur + " min, " + chair + providerNote + ")";
        String code = pendingActions.register("RESCHEDULE_APPOINTMENT", currentProviderId(), summary,
                () -> {
                    log.info("confirmAction RESCHEDULE: apptId={} req={}", apptId, req);
                    appointmentService.reschedule(apptId, req);
                    return "Fatto. " + summary;
                });
        log.info("rescheduleAppointment preview ok: apptId={} chair='{}' newProvider={} code={}",
                apptId, chair, newProviderId, code);

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
        String code = pendingActions.register("CANCEL_APPOINTMENT", currentProviderId(), summary,
                () -> {
                    boolean ok = appointmentService.cancel(apptId);
                    return ok ? "Appuntamento annullato." : "Appuntamento non trovato o già annullato.";
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n"
                + summary + ".\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Execute one or more previously previewed write actions (create/reschedule/cancel appointment) using the confirmation code(s) returned by the preview tools. To confirm several actions at once pass all their codes separated by commas/spaces. Call this only after the user has explicitly confirmed.")
    public String confirmAction(
            @ToolParam(description = "One or more confirmation codes returned by the preview tools, separated by commas or spaces (e.g. '1234, 5678').") String code) {
        // Estrai i codici (gruppi di cifre) se presenti: supporta conferma multipla.
        List<String> codes = code == null ? List.of()
                : java.util.regex.Pattern.compile("\\d+")
                        .matcher(code).results().map(m -> m.group()).toList();

        List<PendingActionService.Pending> toRun = new java.util.ArrayList<>();
        for (String c : codes) {
            PendingActionService.Pending p = pendingActions.consume(c);
            log.info("confirmAction: code={} found={}", c, p != null);
            if (p != null) toRun.add(p);
        }
        // Il modello spesso non riporta il codice tra i turni (non è nella history visibile):
        // se nessun codice combacia, conferma le anteprime in sospeso per questo utente.
        if (toRun.isEmpty()) {
            toRun = pendingActions.consumeAllForScope(currentProviderId());
            log.info("confirmAction fallback scope: pending={}", toRun.size());
        }
        if (toRun.isEmpty())
            return "Nessuna azione in attesa di conferma. Indica di nuovo la modifica da fare.";

        List<String> results = new java.util.ArrayList<>();
        for (PendingActionService.Pending p : toRun) results.add(execute(p));
        return String.join("\n", results);
    }

    private String execute(PendingActionService.Pending p) {
        UUID providerId = currentProviderId();
        if (!java.util.Objects.equals(p.providerScope(), providerId)) {
            log.warn("confirmAction: scope mismatch scope={} caller={}",
                    p.providerScope(), providerId);
            String result = "Azione non valida per questo utente.";
            auditService.log(providerId, p.actionType(), null, p.summary(), result);
            return result;
        }
        String result;
        try {
            result = p.action().get();
        } catch (ResourceNotFoundException nf) {
            log.warn("confirmAction not found: {}", nf.getMessage());
            result = "Elemento non trovato.";
        } catch (AppointmentConflictException ce) {
            log.warn("confirmAction conflict: {}", ce.getMessage());
            result = "Operazione non possibile: " + ce.getMessage();
        } catch (Exception e) {
            log.error("confirmAction error", e);
            result = "Errore nell'esecuzione: " + e.getMessage();
        }
        auditService.log(providerId, p.actionType(), null, p.summary(), result);
        return result;
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

    // ═══════════════════════════════════════════════════════════════════════
    // --- nuovi tool di LETTURA ---
    // ═══════════════════════════════════════════════════════════════════════

    @Tool(description = "Get the treatment plans (piani di cura) of a patient, with item counts by status.")
    public List<TreatmentPlanSummaryDto> getTreatmentPlans(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId) {
        return treatmentPlanService.findByPatient(UUID.fromString(patientId));
    }

    @Tool(description = "Get the odontogram (tooth conditions) of a patient, including conditions detected by AI radiograph analysis (source='ai') and manual entries (source='manual'). Medical staff only.")
    public Object getOdontogram(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        return odontogramService.findByPatient(UUID.fromString(patientId));
    }

    @Tool(description = "Get anamnesis alerts for a patient: allergies, ongoing therapies (anticoagulants, bisphosphonates, etc.) and other clinical alert items. Medical staff only.")
    public Object getAnamnesisAlerts(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        return anamnesisService.getPatientAnamnesis(UUID.fromString(patientId)).stream()
                .map(cat -> new java.util.LinkedHashMap<String, Object>() {{
                    put("category", cat.name());
                    put("alerts", cat.items().stream()
                            .filter(AnamnesisItemDto::selected)
                            .map(i -> i.isAlert() ? "⚠ " + i.label() : i.label())
                            .toList());
                }})
                .filter(m -> !((List<?>) m.get("alerts")).isEmpty())
                .toList();
    }

    @Tool(description = "Get the service catalog (listino prestazioni) optionally filtered by name/code. Returns name, category, default price and duration.")
    public List<ServiceDto> getServiceCatalog(
            @ToolParam(description = "Optional search text to filter by name or code. Leave blank for the full catalog.") String query) {
        List<ServiceDto> all = serviceCatalogService.findAll();
        if (query == null || query.isBlank()) return all;
        String q = query.toLowerCase().trim();
        return all.stream()
                .filter(s -> (s.name() != null && s.name().toLowerCase().contains(q))
                        || (s.code() != null && s.code().toLowerCase().contains(q))
                        || (s.category() != null && s.category().toLowerCase().contains(q)))
                .toList();
    }

    @Tool(description = "Get warehouse products (magazzino) optionally filtered by name/SKU. Returns current stock and stock status.")
    public List<ProductDto> getInventory(
            @ToolParam(description = "Optional search text to filter by product name or SKU. Leave blank for all active products.") String query) {
        List<ProductDto> all = productService.findAll(false);
        if (query == null || query.isBlank()) return all;
        String q = query.toLowerCase().trim();
        return all.stream()
                .filter(p -> (p.name() != null && p.name().toLowerCase().contains(q))
                        || (p.sku() != null && p.sku().toLowerCase().contains(q)))
                .toList();
    }

    @Tool(description = "Get warehouse products with low or critical stock level (sotto scorta), to flag reordering needs.")
    public List<ProductDto> getLowStock() {
        return productService.findAll(true);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // --- nuovi tool di SCRITTURA (preview, confirm-gated via confirmAction) ---
    // ═══════════════════════════════════════════════════════════════════════

    // ── Preventivi ───────────────────────────────────────────────────────────

    @Tool(description = "Prepare creation of a new estimate (preventivo) for a patient and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewCreateEstimate(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Estimate title (optional, default 'Preventivo').") String title,
            @ToolParam(description = "Optional notes.") String notes,
            @ToolParam(description = "Optional treatment plan UUID this estimate refers to.") String treatmentPlanId,
            @ToolParam(description = "Optional expiry date YYYY-MM-DD.") String validUntil) {
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }
        UUID planId = parseUuidOrNull(treatmentPlanId);
        LocalDate validUntilDate = parseDateOrNull(validUntil);

        String patientName = patientName(patientId);
        String summary = "Nuovo preventivo per " + patientName
                + (title != null && !title.isBlank() ? " (" + title + ")" : "");
        CreateEstimateRequest req = new CreateEstimateRequest(pid, planId, currentProviderId(), title, notes, validUntilDate);
        String code = pendingActions.register("CREATE_ESTIMATE", currentProviderId(), summary,
                () -> {
                    UUID id = estimateService.create(req);
                    return "Preventivo creato (id " + id + "). " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare adding a line item (prestazione) to an existing estimate and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewAddEstimateLine(
            @ToolParam(description = "Estimate UUID from getEstimates.") String estimateId,
            @ToolParam(description = "Service UUID from getServiceCatalog.") String serviceId,
            @ToolParam(description = "Quantity (default 1).") java.math.BigDecimal quantity,
            @ToolParam(description = "Unit price override (optional, defaults to the service's catalog price).") java.math.BigDecimal unitPrice,
            @ToolParam(description = "Discount amount (optional).") java.math.BigDecimal discountAmount,
            @ToolParam(description = "VAT rate (optional).") java.math.BigDecimal vatRate,
            @ToolParam(description = "Tooth number/FDI this line refers to (optional).") String toothSnapshot) {
        UUID eid, sid;
        try { eid = UUID.fromString(estimateId); sid = UUID.fromString(serviceId); }
        catch (Exception e) { return "Errore: id preventivo o servizio non valido."; }

        String summary = "Aggiunta riga al preventivo selezionato (servizio " + serviceId + ")";
        AddEstimateLineRequest req = new AddEstimateLineRequest(
                sid, null, null, toothSnapshot, quantity, unitPrice, discountAmount, vatRate, null);
        String code = pendingActions.register("ADD_ESTIMATE_LINE", currentProviderId(), summary,
                () -> {
                    UUID lineId = estimateService.addLine(eid, req);
                    return "Riga aggiunta al preventivo (id " + lineId + ").";
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare a status change for an estimate (preventivo) and return a PREVIEW plus a confirmation code. Status values: draft, sent, accepted, rejected, expired, cancelled. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewUpdateEstimateStatus(
            @ToolParam(description = "Estimate UUID from getEstimates.") String estimateId,
            @ToolParam(description = "New status: draft, sent, accepted, rejected, expired, cancelled.") String status) {
        UUID eid;
        try { eid = UUID.fromString(estimateId); } catch (Exception e) { return "Errore: id preventivo non valido."; }
        if (status == null || status.isBlank()) return "Errore: indica il nuovo stato del preventivo.";

        String summary = "Cambio stato preventivo a '" + status + "'";
        String code = pendingActions.register("UPDATE_ESTIMATE_STATUS", currentProviderId(), summary,
                () -> {
                    estimateService.updateStatus(eid, status);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    // ── Richiami ─────────────────────────────────────────────────────────────

    @Tool(description = "Prepare creation of a new recall (richiamo) for a patient and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewCreateRecall(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Recall type/reason, e.g. 'Controllo periodico'.") String recallType,
            @ToolParam(description = "Due date YYYY-MM-DD.") String dueDate,
            @ToolParam(description = "Priority: alta, media, bassa (optional, auto-computed from due date if omitted).") String priority,
            @ToolParam(description = "Optional notes.") String notes) {
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }
        LocalDate due = parseDateOrNull(dueDate);
        if (due == null) return "Errore: data di scadenza non valida. Usa YYYY-MM-DD.";

        String patientName = patientName(patientId);
        String summary = "Nuovo richiamo per " + patientName + " (" + recallType + ") entro il " + dueDate;
        CreateRecallRequest req = new CreateRecallRequest(pid, recallType, due, priority, notes, null);
        String code = pendingActions.register("CREATE_RECALL", currentProviderId(), summary,
                () -> {
                    RecallDto created = recallService.create(req);
                    return "Richiamo creato (id " + created.recallId() + "). " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare marking a recall (richiamo) as contacted ('contattato') and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewMarkRecallContacted(
            @ToolParam(description = "Recall UUID from getRecalls.") String recallId,
            @ToolParam(description = "Optional notes about the contact.") String notes) {
        UUID rid;
        try { rid = UUID.fromString(recallId); } catch (Exception e) { return "Errore: id richiamo non valido."; }

        String summary = "Richiamo segnato come 'contattato'";
        UpdateRecallRequest req = new UpdateRecallRequest("contattato", null, null, null, notes);
        String code = pendingActions.register("MARK_RECALL_CONTACTED", currentProviderId(), summary,
                () -> {
                    recallService.update(rid, req);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare closing a recall (richiamo, status 'chiuso') and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewCloseRecall(
            @ToolParam(description = "Recall UUID from getRecalls.") String recallId) {
        UUID rid;
        try { rid = UUID.fromString(recallId); } catch (Exception e) { return "Errore: id richiamo non valido."; }

        String summary = "Chiusura del richiamo selezionato";
        UpdateRecallRequest req = new UpdateRecallRequest("chiuso", null, null, null, null);
        String code = pendingActions.register("CLOSE_RECALL", currentProviderId(), summary,
                () -> {
                    recallService.update(rid, req);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    // ── Pazienti ─────────────────────────────────────────────────────────────

    @Tool(description = "Prepare creation of a new patient and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewCreatePatient(
            @ToolParam(description = "First name.") String firstName,
            @ToolParam(description = "Last name.") String lastName,
            @ToolParam(description = "Fiscal code (codice fiscale), optional.") String fiscalCode,
            @ToolParam(description = "Birth date YYYY-MM-DD, optional.") String birthDate,
            @ToolParam(description = "Phone number, optional.") String phone,
            @ToolParam(description = "Email address, optional.") String email,
            @ToolParam(description = "Address line, optional.") String addressLine1,
            @ToolParam(description = "City, optional.") String city,
            @ToolParam(description = "Province code, optional.") String province,
            @ToolParam(description = "Postal code, optional.") String postalCode,
            @ToolParam(description = "Notes, optional.") String notes) {
        if (firstName == null || firstName.isBlank() || lastName == null || lastName.isBlank())
            return "Errore: nome e cognome sono obbligatori.";

        LocalDate birth = parseDateOrNull(birthDate);
        String summary = "Nuovo paziente " + firstName + " " + lastName;
        CreatePatientRequest req = new CreatePatientRequest(
                firstName, lastName, fiscalCode, birth, phone, email,
                addressLine1, city, province, postalCode, notes, null);
        String code = pendingActions.register("CREATE_PATIENT", currentProviderId(), summary,
                () -> {
                    UUID id = patientService.create(req);
                    return "Paziente creato (id " + id + "). " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare updating an existing patient's data and return a PREVIEW plus a confirmation code. Only non-blank fields are considered; provide all fields you want to keep, as this replaces the whole record. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewUpdatePatient(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "First name.") String firstName,
            @ToolParam(description = "Last name.") String lastName,
            @ToolParam(description = "Fiscal code (codice fiscale), optional.") String fiscalCode,
            @ToolParam(description = "Birth date YYYY-MM-DD, optional.") String birthDate,
            @ToolParam(description = "Phone number, optional.") String phone,
            @ToolParam(description = "Email address, optional.") String email,
            @ToolParam(description = "Address line, optional.") String addressLine1,
            @ToolParam(description = "City, optional.") String city,
            @ToolParam(description = "Province code, optional.") String province,
            @ToolParam(description = "Postal code, optional.") String postalCode,
            @ToolParam(description = "Notes, optional.") String notes) {
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }

        var existing = patientService.findById(pid, null).orElse(null);
        if (existing == null) return "Paziente non trovato.";

        String fn = blankToExisting(firstName, existing.firstName());
        String ln = blankToExisting(lastName, existing.lastName());
        LocalDate birth = parseDateOrNull(birthDate);
        if (birth == null) birth = existing.birthDate();

        String summary = "Aggiornamento dati anagrafici di " + existing.fullName();
        UpdatePatientRequest req = new UpdatePatientRequest(
                fn, ln,
                blankToExisting(fiscalCode, existing.fiscalCode()),
                birth,
                blankToExisting(phone, existing.phone()),
                blankToExisting(email, existing.email()),
                blankToExisting(addressLine1, existing.addressLine1()),
                blankToExisting(city, existing.city()),
                blankToExisting(province, existing.province()),
                blankToExisting(postalCode, existing.postalCode()),
                blankToExisting(notes, existing.notes()),
                existing.primaryProviderId());
        String code = pendingActions.register("UPDATE_PATIENT", currentProviderId(), summary,
                () -> {
                    patientService.update(pid, req);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    // ── Piani di cura ────────────────────────────────────────────────────────

    @Tool(description = "Prepare creation of a new treatment plan (piano di cura) for a patient and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewCreatePlan(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Plan name.") String name,
            @ToolParam(description = "Optional description.") String description) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }
        if (name == null || name.isBlank()) return "Errore: indica un nome per il piano di cura.";

        String patientName = patientName(patientId);
        String summary = "Nuovo piano di cura '" + name + "' per " + patientName;
        CreateTreatmentPlanRequest req = new CreateTreatmentPlanRequest(pid, name, description);
        String code = pendingActions.register("CREATE_TREATMENT_PLAN", currentProviderId(), summary,
                () -> {
                    UUID id = treatmentPlanService.create(req);
                    return "Piano di cura creato (id " + id + "). " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare adding an item (prestazione) to an existing treatment plan and return a PREVIEW plus a confirmation code. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewAddPlanItem(
            @ToolParam(description = "Treatment plan UUID from getTreatmentPlans.") String planId,
            @ToolParam(description = "Service UUID from getServiceCatalog.") String serviceId,
            @ToolParam(description = "Tooth number/FDI, optional.") String toothNumber,
            @ToolParam(description = "Quadrant 1-4, optional.") Integer quadrant,
            @ToolParam(description = "Planned price override, optional (defaults to catalog price).") java.math.BigDecimal plannedPrice,
            @ToolParam(description = "Priority (lower = higher priority), optional.") Integer priority,
            @ToolParam(description = "Planned date YYYY-MM-DD, optional.") String plannedDate,
            @ToolParam(description = "Clinical notes, optional.") String clinicalNotes) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        UUID plId, sid;
        try { plId = UUID.fromString(planId); sid = UUID.fromString(serviceId); }
        catch (Exception e) { return "Errore: id piano o servizio non valido."; }

        LocalDate planned = parseDateOrNull(plannedDate);
        String summary = "Aggiunta prestazione al piano di cura selezionato";
        AddTreatmentPlanItemRequest req = new AddTreatmentPlanItemRequest(
                sid, currentProviderId(), toothNumber, quadrant, plannedPrice, priority, planned, clinicalNotes);
        String code = pendingActions.register("ADD_PLAN_ITEM", currentProviderId(), summary,
                () -> {
                    UUID id = treatmentPlanService.addItem(plId, req);
                    return "Prestazione aggiunta al piano di cura (id " + id + ").";
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    // ── Clinico (solo personale medico) ─────────────────────────────────────

    @Tool(description = "Prepare adding a clinical diary entry (diario clinico) for a patient and return a PREVIEW plus a confirmation code. Medical staff only. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewAddDiaryNote(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Clinical notes for the diary entry.") String clinicalNotes,
            @ToolParam(description = "Entry date YYYY-MM-DD, optional (default today).") String entryDate,
            @ToolParam(description = "Tooth number/FDI, optional.") String toothNumber,
            @ToolParam(description = "Service code, optional.") String serviceCode,
            @ToolParam(description = "Service name, optional.") String serviceName,
            @ToolParam(description = "Materials used, optional.") String materialsUsed,
            @ToolParam(description = "Notes for the next visit, optional.") String nextVisitNotes) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }
        if (clinicalNotes == null || clinicalNotes.isBlank()) return "Errore: indica il contenuto della nota clinica.";

        LocalDate entry = parseDateOrNull(entryDate);
        String patientName = patientName(patientId);
        String summary = "Nuova nota di diario clinico per " + patientName;
        CreateClinicalHistoryEntryRequest req = new CreateClinicalHistoryEntryRequest(
                currentProviderId(), entry, toothNumber, serviceCode, serviceName, clinicalNotes, materialsUsed, nextVisitNotes);
        String code = pendingActions.register("ADD_DIARY_NOTE", currentProviderId(), summary,
                () -> {
                    clinicalRecordService.createDiaryEntry(pid, req);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare adding a diagnosis (diagnosi) for a patient and return a PREVIEW plus a confirmation code. Medical staff only. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewAddDiagnosis(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Diagnosis title.") String title,
            @ToolParam(description = "Tooth number/FDI, optional.") String toothNumber,
            @ToolParam(description = "Description, optional.") String description,
            @ToolParam(description = "ICD code, optional.") String icdCode,
            @ToolParam(description = "Diagnosed date YYYY-MM-DD, optional (default today).") String diagnosedAt) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }
        if (title == null || title.isBlank()) return "Errore: indica il titolo della diagnosi.";

        LocalDate diagnosed = parseDateOrNull(diagnosedAt);
        String patientName = patientName(patientId);
        String summary = "Nuova diagnosi '" + title + "' per " + patientName;
        CreateDiagnosiRequest req = new CreateDiagnosiRequest(
                currentProviderId(), toothNumber, title, description, icdCode, diagnosed);
        String code = pendingActions.register("ADD_DIAGNOSIS", currentProviderId(), summary,
                () -> {
                    diagnosiService.create(pid, req);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
    }

    @Tool(description = "Prepare adding a prescription (prescrizione) for a patient and return a PREVIEW plus a confirmation code. Medical staff only. This does NOT save anything. Show the preview; when the user confirms, call confirmAction with the returned code.")
    public String previewAddPrescription(
            @ToolParam(description = "Patient UUID from searchPatients.") String patientId,
            @ToolParam(description = "Drug name.") String drugName,
            @ToolParam(description = "Dosage, optional.") String dosage,
            @ToolParam(description = "Frequency, optional.") String frequency,
            @ToolParam(description = "Duration, optional.") String duration,
            @ToolParam(description = "Notes, optional.") String notes,
            @ToolParam(description = "Prescribed date YYYY-MM-DD, optional (default today).") String prescribedAt,
            @ToolParam(description = "Expiry date YYYY-MM-DD, optional.") String expiresAt) {
        if (!isMedical()) return "Funzione riservata al personale medico.";
        UUID pid;
        try { pid = UUID.fromString(patientId); } catch (Exception e) { return "Errore: id paziente non valido."; }
        if (drugName == null || drugName.isBlank()) return "Errore: indica il nome del farmaco.";

        LocalDate prescribed = parseDateOrNull(prescribedAt);
        LocalDate expires = parseDateOrNull(expiresAt);
        String patientName = patientName(patientId);
        String summary = "Nuova prescrizione '" + drugName + "' per " + patientName;
        CreatePrescrizioneRequest req = new CreatePrescrizioneRequest(
                currentProviderId(), drugName, dosage, frequency, duration, notes, prescribed, expires);
        String code = pendingActions.register("ADD_PRESCRIPTION", currentProviderId(), summary,
                () -> {
                    prescrizioneService.create(pid, req);
                    return "Fatto. " + summary;
                });

        return "ANTEPRIMA — nessuna modifica salvata.\n" + summary + "\n"
                + "Per confermare chiama confirmAction con il codice " + code + ".";
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

    private UUID parseUuidOrNull(String value) {
        try { return (value == null || value.isBlank()) ? null : UUID.fromString(value.trim()); }
        catch (Exception e) { return null; }
    }

    private LocalDate parseDateOrNull(String value) {
        try { return (value == null || value.isBlank()) ? null : LocalDate.parse(value.trim()); }
        catch (Exception e) { return null; }
    }

    /** Ritorna il nuovo valore se non vuoto, altrimenti mantiene quello esistente (per update parziali via chat). */
    private String blankToExisting(String newValue, String existing) {
        return (newValue != null && !newValue.isBlank()) ? newValue : existing;
    }
}
