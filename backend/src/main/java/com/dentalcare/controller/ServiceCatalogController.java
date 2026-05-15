package com.dentalcare.controller;

import com.dentalcare.dto.ServiceDto;
import com.dentalcare.service.ServiceCatalogService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/services")
public class ServiceCatalogController {

    private final ServiceCatalogService serviceCatalogService;

    public ServiceCatalogController(ServiceCatalogService serviceCatalogService) {
        this.serviceCatalogService = serviceCatalogService;
    }

    @GetMapping
    public List<ServiceDto> findAll(@RequestParam(required = false) Integer toothFdi) {
        return serviceCatalogService.findAll(toothFdi);
    }

    @GetMapping("/condition-defaults")
    public List<ServiceDto> findConditionDefaults(@RequestParam String condition) {
        return serviceCatalogService.findConditionDefaults(condition);
    }

    @GetMapping("/{serviceId}/bundle")
    public List<ServiceDto> findBundleItems(@PathVariable UUID serviceId) {
        return serviceCatalogService.findBundleItems(serviceId);
    }
}
