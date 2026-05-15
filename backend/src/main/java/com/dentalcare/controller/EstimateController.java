package com.dentalcare.controller;

import com.dentalcare.dto.*;
import com.dentalcare.service.EstimateService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
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
    public List<EstimateDto> findAll(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID providerId) {
        return estimateService.findAll(status, providerId);
    }

    @GetMapping("/patient/{patientId}")
    public List<EstimateDto> findByPatient(@PathVariable UUID patientId) {
        return estimateService.findByPatient(patientId);
    }

    @GetMapping("/{id}")
    public EstimateDetailDto findById(@PathVariable UUID id) {
        return estimateService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UUID create(@Valid @RequestBody CreateEstimateRequest request) {
        return estimateService.create(request);
    }

    @PatchMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateHeader(@PathVariable UUID id,
                             @RequestBody UpdateEstimateHeaderRequest request) {
        estimateService.updateHeader(id, request);
    }

    @PatchMapping("/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateStatus(@PathVariable UUID id,
                             @Valid @RequestBody UpdateEstimateStatusRequest request) {
        estimateService.updateStatus(id, request.status());
    }

    @PostMapping("/{id}/lines")
    @ResponseStatus(HttpStatus.CREATED)
    public UUID addLine(@PathVariable UUID id,
                        @Valid @RequestBody AddEstimateLineRequest request) {
        return estimateService.addLine(id, request);
    }

    @DeleteMapping("/{id}/lines/{lineId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteLine(@PathVariable UUID id, @PathVariable UUID lineId) {
        estimateService.deleteLine(id, lineId);
    }

    @GetMapping("/by-plan/{planId}")
    public List<EstimateDto> findByPlan(@PathVariable UUID planId) {
        return estimateService.findByPlan(planId);
    }

    @GetMapping("/plan-coverage/{planId}")
    public List<PlanItemCoverageDto> getPlanCoverage(@PathVariable UUID planId) {
        return estimateService.getPlanCoverage(planId);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        estimateService.delete(id);
    }
}
