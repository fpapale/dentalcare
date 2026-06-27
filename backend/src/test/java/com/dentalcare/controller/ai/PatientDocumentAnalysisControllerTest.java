package com.dentalcare.controller.ai;

import com.dentalcare.service.ai.OdontogramSyncService;
import com.dentalcare.service.ai.PatientDocumentAnalysisService;
import com.dentalcare.service.ai.SseEmitterRegistry;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class PatientDocumentAnalysisControllerTest {

    @Test
    void review_triggersSync_whenReviewed() {
        var service = mock(PatientDocumentAnalysisService.class);
        var sse = mock(SseEmitterRegistry.class);
        var sync = mock(OdontogramSyncService.class);
        var controller = new PatientDocumentAnalysisController(service, sse, sync);
        UUID pat = UUID.randomUUID(), doc = UUID.randomUUID(), an = UUID.randomUUID();
        when(service.review(any(), any(), any())).thenReturn(org.mockito.Mockito.mock(com.dentalcare.dto.ai.AnalysisDto.class));

        controller.review(pat, doc, an,
                new com.dentalcare.dto.ai.ReviewAnalysisRequest("reviewed", java.util.List.of()));
        verify(sync).syncFromAnalysis(pat, an);
    }

    @Test
    void review_doesNotSync_whenExcluded() {
        var service = mock(PatientDocumentAnalysisService.class);
        var sse = mock(SseEmitterRegistry.class);
        var sync = mock(OdontogramSyncService.class);
        var controller = new PatientDocumentAnalysisController(service, sse, sync);
        controller.review(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                new com.dentalcare.dto.ai.ReviewAnalysisRequest("excluded", java.util.List.of()));
        verify(sync, never()).syncFromAnalysis(any(), any());
    }
}
