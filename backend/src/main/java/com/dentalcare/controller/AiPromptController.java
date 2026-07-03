package com.dentalcare.controller;

import com.dentalcare.dto.AiPromptDto;
import com.dentalcare.dto.UpdateAiPromptRequest;
import com.dentalcare.service.PromptService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Gestione dei prompt AI da parte dell'admin di studio. Solo modifica dei valori per lingua
 * (override) o reset; le chiavi sono definite dagli sviluppatori.
 * Protetto da SecurityConfig: /api/admin/** richiede ruolo ADMIN o TENANT_ADMIN.
 */
@RestController
@RequestMapping("/api/admin/ai-prompts")
public class AiPromptController {

    private final PromptService promptService;

    public AiPromptController(PromptService promptService) {
        this.promptService = promptService;
    }

    @GetMapping
    public List<AiPromptDto> list() {
        return promptService.listForAdmin();
    }

    @PutMapping("/{key}/{locale}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void update(@PathVariable String key,
                       @PathVariable String locale,
                       @Valid @RequestBody UpdateAiPromptRequest request) {
        promptService.upsertOverride(key, locale, request.value());
    }

    @DeleteMapping("/{key}/{locale}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reset(@PathVariable String key, @PathVariable String locale) {
        promptService.deleteOverride(key, locale);
    }
}
