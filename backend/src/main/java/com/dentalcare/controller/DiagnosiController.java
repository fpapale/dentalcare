package com.dentalcare.controller;

import com.dentalcare.dto.CreateDiagnosiRequest;
import com.dentalcare.dto.DiagnosiDto;
import com.dentalcare.dto.UpdateDiagnosiRequest;
import com.dentalcare.service.DiagnosiService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/diagnosi")
public class DiagnosiController {

    private final DiagnosiService diagnosiService;

    public DiagnosiController(DiagnosiService diagnosiService) {
        this.diagnosiService = diagnosiService;
    }

    @GetMapping
    public List<DiagnosiDto> findAll(@PathVariable UUID patientId) {
        return diagnosiService.findByPatient(patientId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DiagnosiDto create(@PathVariable UUID patientId,
                               @Valid @RequestBody CreateDiagnosiRequest request) {
        return diagnosiService.create(patientId, request);
    }

    @PutMapping("/{diagnosiId}")
    public DiagnosiDto update(@PathVariable UUID patientId,
                               @PathVariable UUID diagnosiId,
                               @Valid @RequestBody UpdateDiagnosiRequest request) {
        return diagnosiService.update(patientId, diagnosiId, request);
    }

    @DeleteMapping("/{diagnosiId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID patientId, @PathVariable UUID diagnosiId) {
        diagnosiService.delete(patientId, diagnosiId);
    }
}
