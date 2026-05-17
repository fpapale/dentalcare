package com.dentalcare.controller;

import com.dentalcare.dto.RegistrationRequest;
import com.dentalcare.dto.RegistrationResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/**
 * Endpoints pubblici — nessuna autenticazione richiesta.
 * La registrazione è attualmente uno stub: associa sempre al tenant demo.
 * TODO: implementare provisioning reale del nuovo tenant.
 */
@RestController
@RequestMapping("/api/public")
public class PublicController {

    private static final Logger log = LoggerFactory.getLogger(PublicController.class);

    // Clinic ID del tenant demo — finché non esiste il provisioning reale
    private static final String DEMO_CLINIC_ID = "9d754153-6579-4b7e-a56b-025f00299cd9";

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public RegistrationResponse register(@RequestBody RegistrationRequest request) {
        log.info("Nuova registrazione: studio='{}' piano='{}' admin='{} {}' <{}>",
                request.studioName(), request.plan(),
                request.adminNome(), request.adminCognome(), request.adminEmail());

        // TODO: creare schema tenant, inserire in dentalcare.tenants + tenant_clinics,
        //       creare clinic nel nuovo schema, inviare email di benvenuto.
        //       Per ora restituiamo il tenant demo.

        return new RegistrationResponse(
                DEMO_CLINIC_ID,
                request.studioName(),
                "Studio configurato con successo! Controlla la tua email per le credenziali di accesso."
        );
    }
}
