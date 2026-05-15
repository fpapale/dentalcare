package com.dentalcare.controller;

import com.dentalcare.dto.ClinicBillingDto;
import com.dentalcare.dto.UpdateClinicBillingRequest;
import com.dentalcare.service.ClinicSettingsService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/settings")
public class ClinicSettingsController {

    private final ClinicSettingsService clinicSettingsService;

    public ClinicSettingsController(ClinicSettingsService clinicSettingsService) {
        this.clinicSettingsService = clinicSettingsService;
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
