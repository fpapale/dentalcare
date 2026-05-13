package com.dentalcare.api;

import com.dentalcare.dto.SaveOdontogramRequest;
import com.dentalcare.dto.ToothConditionDto;
import com.dentalcare.service.OdontogramService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/patients/{patientId}/odontogram")
public class OdontogramController {

    private final OdontogramService odontogramService;

    public OdontogramController(OdontogramService odontogramService) {
        this.odontogramService = odontogramService;
    }

    @GetMapping
    public List<ToothConditionDto> get(@PathVariable UUID patientId) {
        return odontogramService.findByPatient(patientId);
    }

    @PutMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void save(
            @PathVariable UUID patientId,
            @RequestBody SaveOdontogramRequest request) {
        odontogramService.save(patientId, request);
    }
}
