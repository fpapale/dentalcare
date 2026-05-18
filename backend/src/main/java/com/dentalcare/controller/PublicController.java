package com.dentalcare.controller;

import com.dentalcare.dto.RegistrationRequest;
import com.dentalcare.dto.RegistrationResponse;
import com.dentalcare.dto.TenantProvisioningResult;
import com.dentalcare.service.TenantProvisioningService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/**
 * Endpoints pubblici — nessuna autenticazione richiesta.
 */
@RestController
@RequestMapping("/api/public")
public class PublicController {

    private static final Logger log = LoggerFactory.getLogger(PublicController.class);

    private final TenantProvisioningService provisioningService;

    public PublicController(TenantProvisioningService provisioningService) {
        this.provisioningService = provisioningService;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public RegistrationResponse register(@RequestBody RegistrationRequest request) {
        log.info("Nuova registrazione: studio='{}' piano='{}' admin='{} {}' <{}>",
                request.studioName(), request.plan(),
                request.adminNome(), request.adminCognome(), request.adminEmail());

        TenantProvisioningResult result = provisioningService.provision(request);

        return new RegistrationResponse(
                result.clinicId().toString(),
                request.studioName(),
                "Studio configurato con successo! Controlla la tua email per le credenziali di accesso."
        );
    }
}
