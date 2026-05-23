package com.dentalcare.controller;

import com.dentalcare.dto.DemoConfigResponse;
import com.dentalcare.dto.ForgotPasswordRequest;
import com.dentalcare.dto.LoginConfirmRequest;
import com.dentalcare.dto.LoginPreflightRequest;
import com.dentalcare.dto.LoginPreflightResponse;
import com.dentalcare.dto.LoginResponse;
import com.dentalcare.dto.RegistrationRequest;
import com.dentalcare.dto.RegistrationResponse;
import com.dentalcare.dto.TenantProvisioningResult;
import com.dentalcare.service.AuthService;
import com.dentalcare.service.TenantProvisioningService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Endpoints pubblici — nessuna autenticazione richiesta.
 */
@RestController
@RequestMapping("/api/public")
public class PublicController {

    private static final Logger log = LoggerFactory.getLogger(PublicController.class);

    private final TenantProvisioningService provisioningService;
    private final AuthService authService;

    public PublicController(TenantProvisioningService provisioningService,
                            AuthService authService) {
        this.provisioningService = provisioningService;
        this.authService = authService;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public RegistrationResponse register(@Valid @RequestBody RegistrationRequest request) {
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

    @PostMapping("/login")
    public ResponseEntity<LoginPreflightResponse> login(@Valid @RequestBody LoginPreflightRequest request) {
        return ResponseEntity.ok(authService.preflight(request));
    }

    @PostMapping("/login/confirm")
    public ResponseEntity<LoginResponse> confirm(@Valid @RequestBody LoginConfirmRequest request) {
        return ResponseEntity.ok(authService.confirm(request));
    }

    @GetMapping("/demo-config")
    public ResponseEntity<DemoConfigResponse> demoConfig() {
        return ResponseEntity.ok(authService.demoConfig());
    }

    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request.email());
    }
}
