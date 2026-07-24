package com.dentalcare.controller;

import com.dentalcare.dto.CreateTenantClinicRequest;
import com.dentalcare.dto.CreateTenantUserRequest;
import com.dentalcare.dto.DeleteTenantRequest;
import com.dentalcare.dto.DeletionPrepareResponse;
import com.dentalcare.dto.DeletionScheduledResponse;
import com.dentalcare.dto.LoginResponse;
import com.dentalcare.dto.TenantClinicDto;
import com.dentalcare.dto.TenantUserDto;
import com.dentalcare.security.TenantContext;
import com.dentalcare.service.TenantAdminService;
import com.dentalcare.service.TenantDeletionService;
import com.dentalcare.service.TenantExportService;
import jakarta.servlet.http.HttpServletResponse;
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

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/tenant-admin")
public class TenantAdminController {

    private final TenantAdminService tenantAdminService;
    private final TenantExportService tenantExportService;
    private final TenantDeletionService tenantDeletionService;

    public TenantAdminController(TenantAdminService tenantAdminService,
                                 TenantExportService tenantExportService,
                                 TenantDeletionService tenantDeletionService) {
        this.tenantAdminService = tenantAdminService;
        this.tenantExportService = tenantExportService;
        this.tenantDeletionService = tenantDeletionService;
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

    @PutMapping("/clinics/{clinicId}")
    public TenantClinicDto updateClinic(@PathVariable UUID clinicId,
                                        @Valid @RequestBody CreateTenantClinicRequest request) {
        return tenantAdminService.updateClinic(clinicId, request);
    }

    @DeleteMapping("/clinics/{clinicId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteClinic(@PathVariable UUID clinicId) {
        tenantAdminService.deleteClinic(clinicId);
    }

    // --- Cancellazione tenant guidata (#47): prepare -> confirm -> cancel ---

    /** Genera l'export completo (retention cifrata su MinIO) e rilascia il token monouso richiesto. */
    @PostMapping("/tenant/deletion/prepare")
    public DeletionPrepareResponse prepareDeletion() throws IOException {
        return tenantDeletionService.prepare();
    }

    /** Scarica la copia di export preparata, validando il token. */
    @GetMapping("/tenant/deletion/export")
    public void downloadPreparedExport(@RequestParam("deletionToken") String deletionToken,
                                       HttpServletResponse response) throws IOException {
        response.setContentType("application/zip");
        String filename = "tenant_" + TenantContext.validatedSchema()
                + "_predelete_export_" + LocalDate.now() + ".zip";
        response.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        tenantDeletionService.streamPreparedExport(deletionToken, response.getOutputStream());
        response.flushBuffer();
    }

    /** Conferma: valida token + nome digitato, soft-delete con grace period (nessun drop immediato). */
    @DeleteMapping("/tenant")
    public DeletionScheduledResponse deleteTenant(@Valid @RequestBody DeleteTenantRequest request) {
        return tenantDeletionService.confirmDeleteTenant(request.deletionToken(), request.confirmationName());
    }

    /** Annulla una cancellazione programmata, se ancora nella finestra di grazia. */
    @PostMapping("/tenant/deletion/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelDeletion() {
        tenantDeletionService.cancelDeleteTenant();
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

    @GetMapping("/clinics/self-admin")
    public List<String> getSelfAdminClinicIds() {
        return tenantAdminService.getSelfAdminClinicIds();
    }

    @PostMapping("/clinics/{clinicId}/self-admin")
    @ResponseStatus(HttpStatus.CREATED)
    public TenantUserDto addSelfAsClinicAdmin(@PathVariable UUID clinicId) {
        return tenantAdminService.addSelfAsClinicAdmin(clinicId);
    }

    @DeleteMapping("/clinics/{clinicId}/self-admin")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeSelfAsClinicAdmin(@PathVariable UUID clinicId) {
        tenantAdminService.removeSelfAsClinicAdmin(clinicId);
    }

    @PostMapping("/clinics/{clinicId}/enter")
    public LoginResponse enterClinic(@PathVariable UUID clinicId) {
        return tenantAdminService.enterClinic(clinicId);
    }

    @GetMapping("/clinics/{clinicId}/export")
    public void exportClinic(@PathVariable UUID clinicId, HttpServletResponse response) throws IOException {
        response.setContentType("application/zip");
        String filename = "clinic_" + clinicId + "_export_" + LocalDate.now() + ".zip";
        response.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        tenantExportService.exportClinicToStream(clinicId, response.getOutputStream());
        response.flushBuffer();
    }

    /** Export di un sottoinsieme di cliniche selezionate (#47): {@code ?ids=uuid,uuid}. */
    @GetMapping("/export/clinics")
    public void exportClinics(@RequestParam("ids") List<UUID> ids, HttpServletResponse response) throws IOException {
        if (ids == null || ids.isEmpty()) {
            throw new IllegalArgumentException("Nessuna clinica selezionata");
        }
        response.setContentType("application/zip");
        String filename = "clinics_export_" + LocalDate.now() + ".zip";
        response.setHeader("Content-Disposition", "attachment; filename=\"" + filename + "\"");
        tenantExportService.exportClinicsToStream(ids, response.getOutputStream());
        response.flushBuffer();
    }
}
