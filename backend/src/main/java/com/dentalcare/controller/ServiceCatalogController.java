package com.dentalcare.controller;

import com.dentalcare.dto.AddBundleItemRequest;
import com.dentalcare.dto.ConditionDefaultDto;
import com.dentalcare.dto.CreateServiceCategoryRequest;
import com.dentalcare.dto.ServiceCategoryDto;
import com.dentalcare.dto.UpdateServiceCategoryRequest;
import com.dentalcare.dto.CreateConditionDefaultRequest;
import com.dentalcare.dto.CreateServiceRequest;
import com.dentalcare.dto.ServiceAdminDto;
import com.dentalcare.dto.ServiceDto;
import com.dentalcare.dto.UpdateServiceRequest;
import com.dentalcare.service.ServiceCatalogService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/services")
public class ServiceCatalogController {

    private final ServiceCatalogService serviceCatalogService;

    public ServiceCatalogController(ServiceCatalogService serviceCatalogService) {
        this.serviceCatalogService = serviceCatalogService;
    }

    @GetMapping
    public List<ServiceDto> findAll(@RequestParam(required = false) Integer toothFdi) {
        return serviceCatalogService.findAll(toothFdi);
    }

    @GetMapping("/condition-defaults")
    public List<ServiceDto> findConditionDefaults(@RequestParam String condition) {
        return serviceCatalogService.findConditionDefaults(condition);
    }

    @GetMapping("/{serviceId}/bundle")
    public List<ServiceDto> findBundleItems(@PathVariable UUID serviceId) {
        return serviceCatalogService.findBundleItems(serviceId);
    }

    // ── Admin: Services CRUD ─────────────────────────────────────────────────

    @GetMapping("/admin")
    public List<ServiceAdminDto> listAdmin() {
        return serviceCatalogService.listAdmin();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceAdminDto create(@Valid @RequestBody CreateServiceRequest request) {
        return serviceCatalogService.create(request);
    }

    @PutMapping("/{id}")
    public ServiceAdminDto update(@PathVariable UUID id, @Valid @RequestBody UpdateServiceRequest request) {
        return serviceCatalogService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        serviceCatalogService.delete(id);
    }

    // ── Admin: Condition defaults CRUD ───────────────────────────────────────

    @GetMapping("/condition-defaults/all")
    public List<ConditionDefaultDto> listConditionDefaults() {
        return serviceCatalogService.listConditionDefaults();
    }

    @PostMapping("/condition-defaults")
    @ResponseStatus(HttpStatus.CREATED)
    public ConditionDefaultDto addConditionDefault(@Valid @RequestBody CreateConditionDefaultRequest request) {
        return serviceCatalogService.addConditionDefault(request);
    }

    @DeleteMapping("/condition-defaults/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteConditionDefault(@PathVariable UUID id) {
        serviceCatalogService.deleteConditionDefault(id);
    }

    // ── Admin: Bundle items CRUD ─────────────────────────────────────────────

    @PostMapping("/{id}/bundle")
    @ResponseStatus(HttpStatus.CREATED)
    public void addBundleItem(@PathVariable UUID id, @Valid @RequestBody AddBundleItemRequest request) {
        serviceCatalogService.addBundleItem(id, request);
    }

    @DeleteMapping("/bundle/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteBundleItem(@PathVariable UUID itemId) {
        serviceCatalogService.deleteBundleItem(itemId);
    }

    // ── Admin: Categorie prestazioni CRUD ────────────────────────────────────

    @GetMapping("/categories")
    public List<ServiceCategoryDto> listCategories() {
        return serviceCatalogService.listCategories();
    }

    @PostMapping("/categories")
    @ResponseStatus(HttpStatus.CREATED)
    public ServiceCategoryDto createCategory(@Valid @RequestBody CreateServiceCategoryRequest request) {
        return serviceCatalogService.createCategory(request);
    }

    @PutMapping("/categories/{id}")
    public ServiceCategoryDto updateCategory(@PathVariable UUID id, @Valid @RequestBody UpdateServiceCategoryRequest request) {
        return serviceCatalogService.updateCategory(id, request);
    }

    @DeleteMapping("/categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(@PathVariable UUID id) {
        serviceCatalogService.deleteCategory(id);
    }
}
