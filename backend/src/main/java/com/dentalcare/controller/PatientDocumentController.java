package com.dentalcare.controller;

import com.dentalcare.dto.PatientDocumentSummaryDto;
import com.dentalcare.dto.UpdatePatientDocumentRequest;
import com.dentalcare.service.PatientDocumentService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/documents")
public class PatientDocumentController {

    private final PatientDocumentService docService;

    public PatientDocumentController(PatientDocumentService docService) {
        this.docService = docService;
    }

    @GetMapping
    public List<PatientDocumentSummaryDto> findAll(@PathVariable UUID patientId) {
        return docService.findAll(patientId);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PatientDocumentSummaryDto upload(
            @PathVariable UUID patientId,
            @RequestParam("file") MultipartFile file,
            @RequestParam("title") String title,
            @RequestParam(value = "documentType", defaultValue = "altro") String documentType,
            @RequestParam(value = "notes", required = false) String notes,
            @RequestParam(value = "takenAt", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate takenAt
    ) {
        return docService.upload(patientId, file, title, documentType, notes, takenAt);
    }

    @GetMapping("/{docId}")
    public PatientDocumentSummaryDto findById(
            @PathVariable UUID patientId,
            @PathVariable UUID docId
    ) {
        return docService.findById(patientId, docId);
    }

    @GetMapping("/{docId}/content")
    public ResponseEntity<byte[]> getContent(
            @PathVariable UUID patientId,
            @PathVariable UUID docId
    ) {
        PatientDocumentSummaryDto meta = docService.findById(patientId, docId);
        byte[] content = docService.downloadContent(patientId, docId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType(meta.mimeType()));
        headers.set(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + meta.fileName() + "\"");
        headers.setContentLength(content.length);
        return ResponseEntity.ok().headers(headers).body(content);
    }

    @PutMapping("/{docId}")
    public PatientDocumentSummaryDto update(
            @PathVariable UUID patientId,
            @PathVariable UUID docId,
            @Valid @RequestBody UpdatePatientDocumentRequest request
    ) {
        return docService.updateMetadata(patientId, docId, request);
    }

    @DeleteMapping("/{docId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(
            @PathVariable UUID patientId,
            @PathVariable UUID docId
    ) {
        docService.delete(patientId, docId);
    }
}
