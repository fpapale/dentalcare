package com.dentalcare.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/tenant-admin")
public class TenantAdminController {

    @GetMapping("/clinics")
    public List<Object> listClinics() {
        return List.of();
    }
}
