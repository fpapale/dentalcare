package com.dentalcare.controller;

import com.dentalcare.dto.CreatePrescrizioneRequest;
import com.dentalcare.dto.PrescrizioneDto;
import com.dentalcare.service.PrescrizioneService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/prescrizioni")
public class PrescrizioneController {

    private final PrescrizioneService prescrizioneService;

    public PrescrizioneController(PrescrizioneService prescrizioneService) {
        this.prescrizioneService = prescrizioneService;
    }

    @GetMapping
    public List<PrescrizioneDto> findAll(@PathVariable UUID patientId) {
        return prescrizioneService.findByPatient(patientId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PrescrizioneDto create(@PathVariable UUID patientId,
                                   @Valid @RequestBody CreatePrescrizioneRequest request) {
        return prescrizioneService.create(patientId, request);
    }

    @PatchMapping("/{prescrizioneId}/deactivate")
    public PrescrizioneDto deactivate(@PathVariable UUID patientId,
                                       @PathVariable UUID prescrizioneId) {
        return prescrizioneService.deactivate(patientId, prescrizioneId);
    }

    @DeleteMapping("/{prescrizioneId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID patientId, @PathVariable UUID prescrizioneId) {
        prescrizioneService.delete(patientId, prescrizioneId);
    }
}
