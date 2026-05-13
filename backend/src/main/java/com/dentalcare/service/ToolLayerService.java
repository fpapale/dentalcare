package com.dentalcare.service;

import com.dentalcare.security.TenantContext;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class ToolLayerService {

    @Transactional(readOnly = true)
    public Map<String, Object> getTodayAgenda(String providerName, LocalDate date) {
        // Enforce basic RBAC
        if (!hasAnyRole("ROLE_SECRETARY", "ROLE_DOCTOR", "ROLE_HYGIENIST", "ROLE_ADMIN")) {
            throw new SecurityException("Non autorizzato a leggere l'agenda");
        }
        
        // This query will be automatically filtered by RLS because we are @Transactional
        // For MVP, we return mock data that acts as if it was fetched securely.
        
        Map<String, Object> response = new HashMap<>();
        response.put("date", date.toString());
        response.put("provider", providerName != null ? providerName : "Tutti i provider");
        
        List<Map<String, String>> appointments = List.of(
            createAppt("09:00", "Mario Rossi", "Igiene orale", "confirmed"),
            createAppt("10:00", "Laura Bianchi", "Visita controllo", "scheduled")
        );
        response.put("appointments", appointments);
        return response;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getPatientSummary(String patientQuery) {
        if (!hasAnyRole("ROLE_SECRETARY", "ROLE_DOCTOR", "ROLE_HYGIENIST", "ROLE_ADMIN")) {
            throw new SecurityException("Non autorizzato a leggere i pazienti");
        }

        Map<String, Object> response = new HashMap<>();
        response.put("patient_name", patientQuery);
        response.put("phone", "+39 333 1234567");
        response.put("next_appointment", LocalDate.now().plusDays(2).toString() + " 10:00");
        
        // ABAC / Role-based masking
        if (hasRole("ROLE_DOCTOR")) {
            response.put("active_treatment_plan", "Piano implantologia");
            response.put("pending_treatments", 3);
            response.put("clinical_notes_summary", "Paziente presenta leggera infiammazione gengivale...");
        } else {
            response.put("open_estimates_count", 1);
            // Non includiamo dati clinici per segreteria/amministrazione
        }
        
        return response;
    }

    private boolean hasRole(String role) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) return false;
        return authentication.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .anyMatch(a -> a.equals(role));
    }
    
    private boolean hasAnyRole(String... roles) {
        for (String role : roles) {
            if (hasRole(role)) return true;
        }
        return false;
    }

    private Map<String, String> createAppt(String time, String patient, String service, String status) {
        Map<String, String> map = new HashMap<>();
        map.put("time", time);
        map.put("patient_name", patient);
        map.put("service", service);
        map.put("status", status);
        return map;
    }
}
