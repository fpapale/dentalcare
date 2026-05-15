package com.dentalcare.controller;

import com.dentalcare.dto.*;
import com.dentalcare.service.RecallService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/recalls")
public class RecallController {

    private final RecallService recallService;

    public RecallController(RecallService recallService) {
        this.recallService = recallService;
    }

    @GetMapping
    public List<RecallDto> findAll(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String priority) {
        return recallService.findAll(status, priority);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public RecallDto create(@RequestBody CreateRecallRequest request) {
        return recallService.create(request);
    }

    @PutMapping("/{id}")
    public RecallDto update(@PathVariable UUID id, @RequestBody UpdateRecallRequest request) {
        return recallService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        recallService.delete(id);
    }

    @PostMapping("/generate")
    public GenerateRecallsResponse generate(
            @RequestParam(defaultValue = "6") int intervalMonths) {
        return recallService.generateRecalls(intervalMonths);
    }

    @GetMapping("/{id}/contacts")
    public List<RecallContactDto> findContacts(@PathVariable UUID id) {
        return recallService.findContacts(id);
    }

    @PostMapping("/{id}/contacts")
    @ResponseStatus(HttpStatus.CREATED)
    public RecallContactDto addContact(
            @PathVariable UUID id,
            @RequestBody CreateRecallContactRequest request) {
        return recallService.addContact(id, request);
    }
}
