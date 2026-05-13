package com.dentalcare.controller;

import com.dentalcare.dto.AnamnesisCategoryDto;
import com.dentalcare.dto.SaveAnamnesisRequest;
import com.dentalcare.service.AnamnesisService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/anamnesis")
public class AnamnesisController {

    private final AnamnesisService anamnesisService;

    public AnamnesisController(AnamnesisService anamnesisService) {
        this.anamnesisService = anamnesisService;
    }

    @GetMapping
    public List<AnamnesisCategoryDto> getAnamnesis(@PathVariable UUID patientId) {
        return anamnesisService.getPatientAnamnesis(patientId);
    }

    @PutMapping
    public ResponseEntity<Void> saveAnamnesis(
            @PathVariable UUID patientId,
            @Valid @RequestBody SaveAnamnesisRequest request
    ) {
        anamnesisService.savePatientAnamnesis(patientId, request);
        return ResponseEntity.noContent().build();
    }
}
