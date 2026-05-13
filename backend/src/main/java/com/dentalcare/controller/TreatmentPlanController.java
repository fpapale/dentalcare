package com.dentalcare.controller;

import com.dentalcare.dto.*;
import com.dentalcare.service.TreatmentPlanService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/treatment-plans")
public class TreatmentPlanController {

    private final TreatmentPlanService treatmentPlanService;

    public TreatmentPlanController(TreatmentPlanService treatmentPlanService) {
        this.treatmentPlanService = treatmentPlanService;
    }

    @GetMapping
    public List<TreatmentPlanSummaryDto> findByPatient(@RequestParam UUID patientId) {
        return treatmentPlanService.findByPatient(patientId);
    }

    @GetMapping("/{id}")
    public TreatmentPlanDto findById(@PathVariable UUID id) {
        return treatmentPlanService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UUID create(@Valid @RequestBody CreateTreatmentPlanRequest request) {
        return treatmentPlanService.create(request);
    }

    @PatchMapping("/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateStatus(@PathVariable UUID id,
                             @Valid @RequestBody UpdateTreatmentPlanStatusRequest request) {
        treatmentPlanService.updateStatus(id, request.status());
    }

    @PostMapping("/{planId}/items")
    @ResponseStatus(HttpStatus.CREATED)
    public UUID addItem(@PathVariable UUID planId,
                        @Valid @RequestBody AddTreatmentPlanItemRequest request) {
        return treatmentPlanService.addItem(planId, request);
    }

    @PatchMapping("/{planId}/items/{itemId}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateItemStatus(@PathVariable UUID planId,
                                 @PathVariable UUID itemId,
                                 @Valid @RequestBody UpdateTreatmentPlanStatusRequest request) {
        treatmentPlanService.updateItemStatus(planId, itemId, request.status());
    }

    @DeleteMapping("/{planId}/items/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteItem(@PathVariable UUID planId, @PathVariable UUID itemId) {
        treatmentPlanService.deleteItem(planId, itemId);
    }
}
