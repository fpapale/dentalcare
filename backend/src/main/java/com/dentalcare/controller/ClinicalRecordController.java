package com.dentalcare.controller;

import com.dentalcare.dto.ClinicalHistoryEntryDto;
import com.dentalcare.dto.OdontogramSummaryDto;
import com.dentalcare.dto.TreatmentPlanSummaryDto;
import com.dentalcare.service.ClinicalRecordService;
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

    @GetMapping("/treatment-plans")
    public List<TreatmentPlanSummaryDto> getTreatmentPlans(@PathVariable UUID patientId) {
        return clinicalRecordService.findTreatmentPlans(patientId);
    }

    @GetMapping("/odontogram-summary")
    public OdontogramSummaryDto getOdontogramSummary(@PathVariable UUID patientId) {
        return clinicalRecordService.findOdontogramSummary(patientId);
    }
}
