package com.dentalcare.controller;

import com.dentalcare.dto.CreateTenantClinicRequest;
import com.dentalcare.dto.CreateTenantUserRequest;
import com.dentalcare.dto.TenantClinicDto;
import com.dentalcare.dto.TenantUserDto;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.TenantAdminService;
import com.dentalcare.service.TenantExportService;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/tenant-admin")
public class TenantAdminController {

    private final TenantAdminService tenantAdminService;
    private final TenantExportService tenantExportService;

    public TenantAdminController(TenantAdminService tenantAdminService,
                                 TenantExportService tenantExportService) {
        this.tenantAdminService = tenantAdminService;
        this.tenantExportService = tenantExportService;
    }

    @GetMapping("/clinics")
    public List<TenantClinicDto> listClinics() {
        return tenantAdminService.findClinics();
    }

    @PostMapping("/clinics")
    @ResponseStatus(HttpStatus.CREATED)
    public TenantClinicDto createClinic(@Valid @RequestBody CreateTenantClinicRequest request) {
        return tenantAdminService.createClinic(request);
    }

    @DeleteMapping("/clinics/{clinicId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteClinic(@PathVariable UUID clinicId) {
        tenantAdminService.deleteClinic(clinicId);
    }

    @GetMapping("/clinics/{clinicId}/users")
    public List<TenantUserDto> listUsers(@PathVariable UUID clinicId) {
        return tenantAdminService.findUsers(clinicId);
    }

    @PostMapping("/clinics/{clinicId}/users")
    @ResponseStatus(HttpStatus.CREATED)
    public TenantUserDto createUser(@PathVariable UUID clinicId,
                                    @Valid @RequestBody CreateTenantUserRequest request) {
        return tenantAdminService.createUser(clinicId, request);
    }

    @GetMapping("/export")
    public void export(HttpServletResponse response) throws IOException {
        response.setContentType("application/zip");
        String filename = "tenant_" + TenantContext.validatedSchema()
                + "_export_" + LocalDate.now() + ".zip";
        response.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        tenantExportService.exportToStream(response.getOutputStream());
        response.flushBuffer();
    }
}
