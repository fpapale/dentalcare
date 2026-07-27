package com.dentalcare.controller;

import com.dentalcare.dto.ProviderPriceDto;
import com.dentalcare.dto.SetProviderPriceRequest;
import com.dentalcare.service.ProviderPriceOverrideService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/** Tariffe per medico (#44): "Le mie tariffe". Un medico gestisce le proprie, l'admin quelle di tutti. */
@RestController
@RequestMapping("/api/providers/{providerId}/prices")
public class ProviderPriceOverrideController {

    private final ProviderPriceOverrideService service;

    public ProviderPriceOverrideController(ProviderPriceOverrideService service) {
        this.service = service;
    }

    @GetMapping
    public List<ProviderPriceDto> list(@PathVariable UUID providerId) {
        return service.list(providerId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public void setPrice(@PathVariable UUID providerId, @Valid @RequestBody SetProviderPriceRequest request) {
        service.setPrice(providerId, request.serviceId(), request.price());
    }

    @DeleteMapping("/{serviceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeOverride(@PathVariable UUID providerId, @PathVariable UUID serviceId) {
        service.removeOverride(providerId, serviceId);
    }
}
