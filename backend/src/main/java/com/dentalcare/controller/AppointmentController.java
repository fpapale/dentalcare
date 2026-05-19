package com.dentalcare.controller;

import com.dentalcare.dto.AppointmentDto;
import com.dentalcare.dto.CreateAppointmentRequest;
import com.dentalcare.dto.RescheduleAppointmentRequest;
import com.dentalcare.service.AppointmentService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.net.URI;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/appointments")
public class AppointmentController {

    private final AppointmentService appointmentService;

    public AppointmentController(AppointmentService appointmentService) {
        this.appointmentService = appointmentService;
    }

    @GetMapping
    public List<AppointmentDto> findByDate(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) UUID providerId) {
        if (from != null && to != null) {
            return appointmentService.findByDateRange(from, to, providerId);
        }
        return appointmentService.findByDate(date != null ? date : LocalDate.now(), providerId);
    }

    @GetMapping("/patient/{patientId}")
    public List<AppointmentDto> findByPatient(
            @PathVariable UUID patientId,
            @RequestParam(required = false) UUID providerId) {
        return appointmentService.findByPatient(patientId, providerId);
    }

    @PatchMapping("/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateStatus(
            @PathVariable UUID id,
            @RequestParam String status) {
        appointmentService.updateStatus(id, status);
    }

    @PatchMapping("/{id}/reschedule")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reschedule(
            @PathVariable UUID id,
            @Valid @RequestBody RescheduleAppointmentRequest request) {
        appointmentService.reschedule(id, request);
    }

    @GetMapping("/chairs")
    public List<String> findChairLabels() {
        return appointmentService.findChairLabels();
    }

    @PostMapping
    public ResponseEntity<Void> create(@Valid @RequestBody CreateAppointmentRequest request) {
        UUID id = appointmentService.create(request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}").buildAndExpand(id).toUri();
        return ResponseEntity.created(location).build();
    }
}
