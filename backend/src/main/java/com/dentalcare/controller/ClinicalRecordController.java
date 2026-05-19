package com.dentalcare.controller;

import com.dentalcare.dto.ClinicalHistoryEntryDto;
import com.dentalcare.dto.CreateClinicalHistoryEntryRequest;
import com.dentalcare.dto.OdontogramSummaryDto;
import com.dentalcare.dto.TreatmentPlanSummaryDto;
import com.dentalcare.dto.UpdateClinicalHistoryEntryRequest;
import com.dentalcare.service.ClinicalRecordService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/clinical-record")
public class ClinicalRecordController {

    private final ClinicalRecordService clinicalRecordService;

    public ClinicalRecordController(ClinicalRecordService clinicalRecordService) {
        this.clinicalRecordService = clinicalRecordService;
    }

    @GetMapping("/diary")
    public List<ClinicalHistoryEntryDto> getDiary(@PathVariable UUID patientId) {
        return clinicalRecordService.findDiary(patientId);
    }

    @PostMapping("/diary")
    @ResponseStatus(HttpStatus.CREATED)
    public ClinicalHistoryEntryDto createDiaryEntry(
            @PathVariable UUID patientId,
            @Valid @RequestBody CreateClinicalHistoryEntryRequest request) {
        return clinicalRecordService.createDiaryEntry(patientId, request);
    }

    @GetMapping("/diary/{entryId}")
    public ClinicalHistoryEntryDto getDiaryEntry(
            @PathVariable UUID patientId,
            @PathVariable UUID entryId) {
        return clinicalRecordService.findDiaryEntry(patientId, entryId);
    }

    @PutMapping("/diary/{entryId}")
    public ClinicalHistoryEntryDto updateDiaryEntry(
            @PathVariable UUID patientId,
            @PathVariable UUID entryId,
            @Valid @RequestBody UpdateClinicalHistoryEntryRequest request) {
        return clinicalRecordService.updateDiaryEntry(patientId, entryId, request);
    }

    @GetMapping("/treatment-plans")
    public List<TreatmentPlanSummaryDto> getTreatmentPlans(@PathVariable UUID patientId) {
        return clinicalRecordService.findTreatmentPlans(patientId);
    }

    @GetMapping("/odontogram-summary")
    public OdontogramSummaryDto getOdontogramSummary(@PathVariable UUID patientId) {
        return clinicalRecordService.findOdontogramSummary(patientId);
    }
}
