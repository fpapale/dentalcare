package com.dentalcare.controller;

import com.dentalcare.service.EncryptionMigrationService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/admin/encryption")
public class EncryptionMigrationController {

    private final EncryptionMigrationService migrationService;

    public EncryptionMigrationController(EncryptionMigrationService migrationService) {
        this.migrationService = migrationService;
    }

    @PostMapping("/migrate")
    public Map<String, Integer> migrate() {
        return Map.of("migrated", migrationService.migrateBirthDate());
    }
}
