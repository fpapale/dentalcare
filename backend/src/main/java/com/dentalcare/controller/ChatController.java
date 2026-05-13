package com.dentalcare.controller;

import com.dentalcare.service.ToolLayerService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ToolLayerService toolLayerService;

    public ChatController(ToolLayerService toolLayerService) {
        this.toolLayerService = toolLayerService;
    }

    @PostMapping("/message")
    public ResponseEntity<Map<String, Object>> sendMessage(@RequestBody Map<String, String> request) {
        String message = request.getOrDefault("message", "").toLowerCase();
        
        Map<String, Object> response = new HashMap<>();
        
        try {
            // Mock AI Orchestrator behavior based on keywords
            if (message.contains("agenda") || message.contains("appuntamenti")) {
                Map<String, Object> data = toolLayerService.getTodayAgenda(null, LocalDate.now());
                response.put("text", "Ecco l'agenda di oggi:");
                response.put("data", data);
                response.put("intent", "get_today_agenda");
            } else if (message.contains("paziente") || message.contains("rossi")) {
                Map<String, Object> data = toolLayerService.getPatientSummary("Mario Rossi");
                response.put("text", "Ho trovato il paziente richiesto:");
                response.put("data", data);
                response.put("intent", "get_patient_summary");
            } else {
                response.put("text", "Non sono sicuro di come aiutarti con questa richiesta. Puoi chiedermi dell'agenda o di un paziente.");
                response.put("intent", "unknown");
            }
        } catch (SecurityException ex) {
            response.put("text", ex.getMessage());
            response.put("error", true);
        }

        return ResponseEntity.ok(response);
    }
}
