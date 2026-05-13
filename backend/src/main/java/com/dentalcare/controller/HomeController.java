package com.dentalcare.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
public class HomeController {

    @GetMapping("/")
    public Map<String, Object> home() {
        Map<String, Object> response = new HashMap<>();
        response.put("application", "DentalCare API");
        response.put("version", "0.0.1-SNAPSHOT");
        response.put("java_version", System.getProperty("java.version"));
        response.put("status", "running");
        response.put("endpoints", Map.of(
            "h2_console", "/h2-console",
            "chat_api", "/api/chat/message",
            "health", "/actuator/health (if available)"
        ));
        response.put("message", "DentalCare API is running on Java 25 with Spring Boot 3.5.0");
        return response;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("message", "DentalCare API is healthy");
        return response;
    }

}
