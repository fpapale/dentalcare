package com.dentalcare.controller;

import com.dentalcare.dto.*;
import com.dentalcare.service.AnamnesisCatalogService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/admin/anamnesis")
public class AnamnesisCatalogController {

    private final AnamnesisCatalogService service;

    public AnamnesisCatalogController(AnamnesisCatalogService service) {
        this.service = service;
    }

    // ── Categories ────────────────────────────────────────────────────────────

    @GetMapping("/categories")
    public List<CatalogCategoryDto> findAllCategories() {
        return service.findAllCategories();
    }

    @PostMapping("/categories")
    @ResponseStatus(HttpStatus.CREATED)
    public CatalogCategoryDto createCategory(@Valid @RequestBody CreateCatalogCategoryRequest req) {
        return service.createCategory(req);
    }

    @PutMapping("/categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateCategory(@PathVariable UUID id,
                               @Valid @RequestBody UpdateCatalogCategoryRequest req) {
        service.updateCategory(id, req);
    }

    @DeleteMapping("/categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteCategory(@PathVariable UUID id) {
        service.deleteCategory(id);
    }

    // ── Items ─────────────────────────────────────────────────────────────────

    @GetMapping("/categories/{categoryId}/items")
    public List<CatalogItemDto> findItems(@PathVariable UUID categoryId) {
        return service.findItemsByCategory(categoryId);
    }

    @PostMapping("/items")
    @ResponseStatus(HttpStatus.CREATED)
    public CatalogItemDto createItem(@Valid @RequestBody CreateCatalogItemRequest req) {
        return service.createItem(req);
    }

    @PutMapping("/items/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateItem(@PathVariable UUID id,
                           @Valid @RequestBody UpdateCatalogItemRequest req) {
        service.updateItem(id, req);
    }

    @DeleteMapping("/items/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteItem(@PathVariable UUID id) {
        service.deleteItem(id);
    }
}
