package com.dentalcare.controller.ai;

import com.dentalcare.dto.ai.AiCallbackRequest;
import com.dentalcare.security.HmacVerifier;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.ai.PatientDocumentAnalysisService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/internal/ai")
public class AiCallbackController {

    private final HmacVerifier hmac;
    private final PatientDocumentAnalysisService service;
    private final ObjectMapper mapper;

    public AiCallbackController(HmacVerifier hmac, PatientDocumentAnalysisService service, ObjectMapper mapper) {
        this.hmac = hmac;
        this.service = service;
        this.mapper = mapper;
    }

    @PostMapping("/callback")
    public ResponseEntity<Void> callback(
            @RequestBody byte[] rawBody,
            @RequestHeader(value = "X-AI-Signature", required = false) String signature) throws Exception {
        if (!hmac.verify(rawBody, signature)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        AiCallbackRequest cb = mapper.readValue(rawBody, AiCallbackRequest.class);
        try {
            TenantContext.setCurrentSchema(cb.schema_name());
            service.applyCallback(cb);
        } finally {
            TenantContext.clear();
        }
        return ResponseEntity.noContent().build();
    }
}
