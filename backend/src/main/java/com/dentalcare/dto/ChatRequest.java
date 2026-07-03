package com.dentalcare.dto;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.UUID;

public record ChatRequest(@NotBlank String message, List<ChatTurnDto> history,
                          UUID sessionId, String locale, ChatContext context) {

    /**
     * Contesto UI opzionale: schermata/paziente correntemente visualizzati dall'utente.
     * Solo informativo per il prompt — nessun controllo di sicurezza si basa su questi valori.
     */
    public record ChatContext(UUID patientId, String patientName, String view) {}
}
