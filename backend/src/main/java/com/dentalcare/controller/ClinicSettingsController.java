package com.dentalcare.controller;

import com.dentalcare.dto.ClinicBillingDto;
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
}
