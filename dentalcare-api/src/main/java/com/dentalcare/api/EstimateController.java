package com.dentalcare.api;

import com.dentalcare.dto.EstimateDto;
import com.dentalcare.service.EstimateService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/estimates")
public class EstimateController {

    private final EstimateService estimateService;

    public EstimateController(EstimateService estimateService) {
        this.estimateService = estimateService;
    }

    @GetMapping
    public List<EstimateDto> findAll(@RequestParam(required = false) String status) {
        return estimateService.findAll(status);
    }

    @GetMapping("/patient/{patientId}")
    public List<EstimateDto> findByPatient(@PathVariable UUID patientId) {
        return estimateService.findByPatient(patientId);
    }
}
