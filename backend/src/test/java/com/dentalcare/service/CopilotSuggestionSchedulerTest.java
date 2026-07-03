package com.dentalcare.service;

import com.dentalcare.dto.RecallDto;
import com.dentalcare.security.TenantContext;
import com.dentalcare.security.TenantSchemaRegistry;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CopilotSuggestionSchedulerTest {

    @Mock
    TenantSchemaRegistry schemaRegistry;

    @Mock
    RecallService recallService;

    @Mock
    CopilotSuggestionService suggestionService;

    @InjectMocks
    CopilotSuggestionScheduler scheduler;

    private final UUID clinicId = UUID.fromString("00000000-0000-0000-0000-000000000001");

    @AfterEach
    void clearContext() {
        TenantContext.clear();
    }

    @Test
    void publishOverdueRecallSuggestions_withOverdueRecall_publishesOnce() {
        when(schemaRegistry.allMappings()).thenReturn(Map.of(clinicId.toString(), "t_abcd1234"));
        when(recallService.findAll("da_contattare", null, null))
                .thenReturn(List.of(overdueRecall("Mario Rossi", LocalDate.now().minusDays(2))));

        scheduler.publishOverdueRecallSuggestions();

        verify(suggestionService).publish(eq(clinicId), eq("recall_overdue"), contains("Mario Rossi"));
    }

    @Test
    void publishOverdueRecallSuggestions_noOverdueRecalls_neverPublishes() {
        when(schemaRegistry.allMappings()).thenReturn(Map.of(clinicId.toString(), "t_abcd1234"));
        when(recallService.findAll("da_contattare", null, null))
                .thenReturn(List.of(overdueRecall("Futuro Paziente", LocalDate.now().plusDays(5))));

        scheduler.publishOverdueRecallSuggestions();

        verify(suggestionService, never()).publish(any(), any(), any());
    }

    @Test
    void publishOverdueRecallSuggestions_multipleOverdue_usesCountMessage() {
        when(schemaRegistry.allMappings()).thenReturn(Map.of(clinicId.toString(), "t_abcd1234"));
        when(recallService.findAll("da_contattare", null, null))
                .thenReturn(List.of(
                        overdueRecall("Paziente Uno", LocalDate.now().minusDays(1)),
                        overdueRecall("Paziente Due", LocalDate.now())));

        scheduler.publishOverdueRecallSuggestions();

        verify(suggestionService).publish(eq(clinicId), eq("recall_overdue"), contains("2 richiami scaduti"));
    }

    @Test
    void publishOverdueRecallSuggestions_clearsTenantContextAfterEachClinic() {
        when(schemaRegistry.allMappings()).thenReturn(Map.of(clinicId.toString(), "t_abcd1234"));
        when(recallService.findAll("da_contattare", null, null)).thenReturn(List.of());

        scheduler.publishOverdueRecallSuggestions();

        org.junit.jupiter.api.Assertions.assertNull(TenantContext.getCurrentClinicId());
        org.junit.jupiter.api.Assertions.assertNull(TenantContext.getCurrentSchema());
    }

    private RecallDto overdueRecall(String patientFullName, LocalDate dueDate) {
        return new RecallDto(
                UUID.randomUUID(), UUID.randomUUID(), patientFullName, "+39 000 000000",
                "Controllo periodico", dueDate, "da_contattare", "alta",
                null, 0, null, null, null);
    }
}
