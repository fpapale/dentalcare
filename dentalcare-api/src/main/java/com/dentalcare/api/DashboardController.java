package com.dentalcare.api;

import com.dentalcare.dto.DashboardDto;
import com.dentalcare.service.DashboardService;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    public DashboardDto getDashboard(@RequestParam(required = false) UUID providerId) {
        return dashboardService.getDashboard(providerId);
    }
}
