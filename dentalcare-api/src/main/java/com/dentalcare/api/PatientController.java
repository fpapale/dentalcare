package com.dentalcare.api;

import com.dentalcare.dto.CreatePatientRequest;
import com.dentalcare.dto.PatientDetailDto;
import com.dentalcare.dto.PatientListDto;
import com.dentalcare.service.PatientService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.net.URI;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients")
public class PatientController {

    private final PatientService patientService;

    public PatientController(PatientService patientService) {
        this.patientService = patientService;
    }

    @GetMapping
    public List<PatientListDto> findAll(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) UUID providerId) {
        return patientService.findAll(search, providerId);
    }

    @GetMapping("/{id}")
    public ResponseEntity<PatientDetailDto> findById(
            @PathVariable UUID id,
            @RequestParam(required = false) UUID providerId) {
        return patientService.findById(id, providerId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Void> create(@Valid @RequestBody CreatePatientRequest request) {
        UUID id = patientService.create(request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}")
                .buildAndExpand(id)
                .toUri();
        return ResponseEntity.created(location).build();
    }
}
