package com.dentalcare.controller;

import com.dentalcare.dto.CreateProductRequest;
import com.dentalcare.dto.ProductCategoryDto;
import com.dentalcare.dto.ProductDto;
import com.dentalcare.service.ProductService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping("/api/products")
    public List<ProductDto> findAll(
            @RequestParam(defaultValue = "false") boolean lowStockOnly) {
        return productService.findAll(lowStockOnly);
    }

    @GetMapping("/api/product-categories")
    public List<ProductCategoryDto> findCategories() {
        return productService.findCategories();
    }

    @PostMapping("/api/products")
    @ResponseStatus(HttpStatus.CREATED)
    public ProductDto create(@RequestBody CreateProductRequest request) {
        return productService.create(request);
    }

    @PutMapping("/api/products/{id}")
    public ProductDto update(@PathVariable UUID id,
                             @RequestBody CreateProductRequest request) {
        return productService.update(id, request);
    }

    @DeleteMapping("/api/products/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id) {
        productService.delete(id);
    }
}
