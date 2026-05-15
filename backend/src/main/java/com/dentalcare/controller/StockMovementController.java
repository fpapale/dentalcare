package com.dentalcare.controller;

import com.dentalcare.dto.CreateStockMovementRequest;
import com.dentalcare.dto.StockMovementDto;
import com.dentalcare.service.StockMovementService;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/stock-movements")
public class StockMovementController {

    private final StockMovementService stockMovementService;

    public StockMovementController(StockMovementService stockMovementService) {
        this.stockMovementService = stockMovementService;
    }

    @GetMapping
    public List<StockMovementDto> findAll(
            @RequestParam(required = false) UUID productId) {
        return stockMovementService.findAll(productId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public StockMovementDto create(@RequestBody CreateStockMovementRequest request) {
        return stockMovementService.create(request);
    }
}
