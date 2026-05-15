package com.dentalcare.controller;

import com.dentalcare.dto.*;
import com.dentalcare.service.InvoiceService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/invoices")
public class InvoiceController {

    private final InvoiceService invoiceService;

    public InvoiceController(InvoiceService invoiceService) {
        this.invoiceService = invoiceService;
    }

    @GetMapping
    public List<InvoiceDto> findAll(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) UUID providerId) {
        return invoiceService.findAll(status, providerId);
    }

    @GetMapping("/{id}")
    public InvoiceDetailDto findById(@PathVariable UUID id) {
        return invoiceService.findById(id);
    }

    @PostMapping("/from-estimate")
    @ResponseStatus(HttpStatus.CREATED)
    public UUID createFromEstimate(@Valid @RequestBody CreateInvoiceFromEstimateRequest request) {
        return invoiceService.createFromEstimate(request);
    }

    @PatchMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@PathVariable UUID id,
                       @RequestBody UpdateInvoiceRequest request) {
        invoiceService.update(id, request);
    }

    @PatchMapping("/{id}/status")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateStatus(@PathVariable UUID id,
                             @Valid @RequestBody UpdateInvoiceStatusRequest request) {
        invoiceService.updateStatus(id, request.status());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        invoiceService.delete(id);
    }

    @PostMapping("/{id}/lines")
    @ResponseStatus(HttpStatus.CREATED)
    public UUID addLine(@PathVariable UUID id,
                        @Valid @RequestBody AddInvoiceLineRequest request) {
        return invoiceService.addLine(id, request);
    }

    @DeleteMapping("/{id}/lines/{lineId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteLine(@PathVariable UUID id, @PathVariable UUID lineId) {
        invoiceService.deleteLine(id, lineId);
    }
}
