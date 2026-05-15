package com.dentalcare.controller;

import com.dentalcare.dto.CreateSupplierRequest;
import com.dentalcare.dto.SupplierDto;
import com.dentalcare.service.SupplierService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/suppliers")
public class SupplierController {

    private final SupplierService supplierService;

    public SupplierController(SupplierService supplierService) {
        this.supplierService = supplierService;
    }

    @GetMapping
    public List<SupplierDto> findAll(
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return supplierService.findAll(includeInactive);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SupplierDto create(@RequestBody CreateSupplierRequest request) {
        return supplierService.create(request);
    }

    @PutMapping("/{id}")
    public SupplierDto update(@PathVariable UUID id,
                              @RequestBody CreateSupplierRequest request) {
        return supplierService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        supplierService.delete(id);
    }
}
