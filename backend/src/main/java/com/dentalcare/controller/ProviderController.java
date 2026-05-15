package com.dentalcare.controller;

import com.dentalcare.dto.CreateProviderRequest;
import com.dentalcare.dto.ProviderDto;
import com.dentalcare.dto.UpdateProviderBillingRequest;
import com.dentalcare.dto.UpdateProviderProfileRequest;
import com.dentalcare.service.ProviderService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/providers")
public class ProviderController {

    private final ProviderService providerService;

    public ProviderController(ProviderService providerService) {
        this.providerService = providerService;
    }

    @GetMapping
    public List<ProviderDto> findAll(@RequestParam(defaultValue = "true") boolean activeOnly) {
        return providerService.findAll(activeOnly);
    }

    @GetMapping("/{id}")
    public ProviderDto findById(@PathVariable UUID id) {
        return providerService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProviderDto create(@Valid @RequestBody CreateProviderRequest request) {
        return providerService.create(request);
    }

    @PutMapping("/{id}/profile")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateProfile(@PathVariable UUID id,
                              @Valid @RequestBody UpdateProviderProfileRequest request) {
        providerService.updateProfile(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        providerService.delete(id);
    }

    @PutMapping("/{id}/billing")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateBilling(@PathVariable UUID id,
                              @RequestBody UpdateProviderBillingRequest request) {
        providerService.updateBilling(id, request);
    }
}
