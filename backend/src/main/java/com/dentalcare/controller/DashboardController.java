package com.dentalcare.controller;

import com.dentalcare.dto.DashboardDto;
import com.dentalcare.service.DashboardService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    public DashboardDto getDashboard() {
        return dashboardService.getDashboard();
    }
}
