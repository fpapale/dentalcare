package com.dentalcare.service;

import com.dentalcare.dto.RecallDto;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Job giornaliero che individua i richiami scaduti e pubblica un suggerimento proattivo
 * (#14.B) sullo stream Copilot di ogni clinica interessata. Il suggerimento propone
 * un'azione — l'utente resta l'unico che puo' confermarla tramite i tool di chat esistenti.
 *
 * <p>Itera le mappature clinic_id -> schema note a {@link TenantSchemaRegistry} (lo stesso
 * registry usato dall'autenticazione JWT) e imposta il {@link TenantContext} per clinica,
 * seguendo lo stesso principio di {@code AnalysisReconciler} che itera gli schema tenant
 * fuori da una richiesta HTTP.</p>
 */
@Component
public class CopilotSuggestionScheduler {

    private static final Logger log = LoggerFactory.getLogger(CopilotSuggestionScheduler.class);
    private static final String OVERDUE_STATUS = "da_contattare";

    private final TenantSchemaRegistry schemaRegistry;
    private final RecallService recallService;
    private final CopilotSuggestionService suggestionService;

    public CopilotSuggestionScheduler(TenantSchemaRegistry schemaRegistry,
                                       RecallService recallService,
                                       CopilotSuggestionService suggestionService) {
        this.schemaRegistry = schemaRegistry;
        this.recallService = recallService;
        this.suggestionService = suggestionService;
    }

    /** Ogni giorno alle 08:00: un suggerimento per clinica se ci sono richiami scaduti da contattare. */
    @Scheduled(cron = "0 0 8 * * *", zone = "Europe/Rome")
    public void publishOverdueRecallSuggestions() {
        for (Map.Entry<String, String> clinic : schemaRegistry.allMappings().entrySet()) {
            String clinicId = clinic.getKey();
            String schema = clinic.getValue();
            try {
                TenantContext.setCurrentClinicId(clinicId);
                TenantContext.setCurrentSchema(schema);

                List<RecallDto> overdue = recallService.findAll(OVERDUE_STATUS, null, null).stream()
                        .filter(r -> r.dueDate() != null && !r.dueDate().isAfter(LocalDate.now()))
                        .toList();

                if (!overdue.isEmpty()) {
                    suggestionService.publish(UUID.fromString(clinicId), "recall_overdue", buildMessage(overdue));
                }
            } catch (Exception e) {
                log.warn("publishOverdueRecallSuggestions fallito per clinic {}: {}", clinicId, e.getMessage());
            } finally {
                TenantContext.clear();
            }
        }
    }

    private String buildMessage(List<RecallDto> overdue) {
        if (overdue.size() == 1) {
            return "Richiamo scaduto da contattare: " + overdue.get(0).patientFullName();
        }
        return overdue.size() + " richiami scaduti da contattare.";
    }
}
