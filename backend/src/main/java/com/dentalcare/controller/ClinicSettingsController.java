package com.dentalcare.controller;

import com.dentalcare.dto.ClinicBillingDto;
import com.dentalcare.dto.ClinicScheduleDto;
import com.dentalcare.dto.CreateClinicRequest;
import com.dentalcare.dto.UpdateClinicBillingRequest;
import com.dentalcare.service.ClinicSettingsService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/settings")
public class ClinicSettingsController {

    private final ClinicSettingsService clinicSettingsService;

    public ClinicSettingsController(ClinicSettingsService clinicSettingsService) {
        this.clinicSettingsService = clinicSettingsService;
    }

    @GetMapping("/clinics")
    public List<ClinicBillingDto> findAll() {
        return clinicSettingsService.findAll();
    }

    @PostMapping("/clinics")
    @ResponseStatus(HttpStatus.CREATED)
    public ClinicBillingDto create(@Valid @RequestBody CreateClinicRequest request) {
        return clinicSettingsService.create(request);
    }

    @GetMapping("/clinic")
    public ClinicBillingDto getClinicBilling() {
        return clinicSettingsService.getClinicBilling();
    }

    @PutMapping("/clinic")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateClinicBilling(@Valid @RequestBody UpdateClinicBillingRequest request) {
        clinicSettingsService.updateClinicBilling(request);
    }

    /** Orari studio usati dalla proposta di disponibilità appuntamenti (#31). */
    @GetMapping("/schedule")
    public ClinicScheduleDto getSchedule() {
        return clinicSettingsService.getSchedule();
    }

    @PutMapping("/schedule")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateSchedule(@RequestBody ClinicScheduleDto request) {
        clinicSettingsService.updateSchedule(request);
    }

    /** Modalità di visibilità pazienti per ruolo della sede (#42): per_provider | shared. */
    @GetMapping("/patient-visibility")
    public com.dentalcare.dto.PatientVisibilityDto getPatientVisibility() {
        return clinicSettingsService.getPatientVisibility();
    }

    @PutMapping("/patient-visibility")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updatePatientVisibility(@RequestBody com.dentalcare.dto.PatientVisibilityDto request) {
        clinicSettingsService.updatePatientVisibility(request);
    }

    /** Modalità di fatturazione della sede (#44): studio | provider. */
    @GetMapping("/billing-mode")
    public com.dentalcare.dto.BillingModeDto getBillingMode() {
        return clinicSettingsService.getBillingMode();
    }

    @PutMapping("/billing-mode")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateBillingMode(@RequestBody com.dentalcare.dto.BillingModeDto request) {
        clinicSettingsService.updateBillingMode(request);
    }
}
