package com.dentalcare.controller.ai;

import com.dentalcare.dto.ai.*;
import com.dentalcare.service.ai.OdontogramSyncService;
import com.dentalcare.service.ai.PatientDocumentAnalysisService;
import com.dentalcare.service.ai.SseEmitterRegistry;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/documents/{docId}/analyses")
public class PatientDocumentAnalysisController {

    private final PatientDocumentAnalysisService service;
    private final SseEmitterRegistry sse;
    private final OdontogramSyncService sync;

    public PatientDocumentAnalysisController(PatientDocumentAnalysisService service,
                                             SseEmitterRegistry sse, OdontogramSyncService sync) {
        this.service = service; this.sse = sse; this.sync = sync;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public StartAnalysisResponse start(@PathVariable UUID patientId, @PathVariable UUID docId) {
        return service.startAnalysis(patientId, docId);
    }

    @GetMapping
    public List<AnalysisDto> list(@PathVariable UUID patientId, @PathVariable UUID docId) {
        return service.listByDocument(patientId, docId);
    }

    @GetMapping("/{analysisId}")
    public AnalysisDto get(@PathVariable UUID patientId, @PathVariable UUID docId, @PathVariable UUID analysisId) {
        return service.getAnalysis(patientId, analysisId);
    }

    @PutMapping("/{analysisId}/review")
    public AnalysisDto review(@PathVariable UUID patientId, @PathVariable UUID docId,
                              @PathVariable UUID analysisId, @Valid @RequestBody ReviewAnalysisRequest req) {
        AnalysisDto dto = service.review(patientId, analysisId, req);
        if ("reviewed".equals(req.reviewStatus()) || "approved_for_training".equals(req.reviewStatus())) {
            sync.syncFromAnalysis(patientId, analysisId);
        }
        return dto;
    }

    // EventSource cannot send headers — clients authenticate this SSE endpoint via ?token=<jwt> (supported by JwtAuthenticationFilter)
    @GetMapping("/{analysisId}/stream")
    public SseEmitter stream(@PathVariable UUID patientId, @PathVariable UUID docId, @PathVariable UUID analysisId) {
        return sse.create(analysisId);
    }
}
