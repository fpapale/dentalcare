package com.dentalcare.controller;

import com.dentalcare.dto.ProviderDto;
import com.dentalcare.service.ProviderService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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
}
