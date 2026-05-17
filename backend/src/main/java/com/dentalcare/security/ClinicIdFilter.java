package com.dentalcare.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class ClinicIdFilter extends OncePerRequestFilter {

    @Value("${dentalcare.default.clinic-id:9d754153-6579-4b7e-a56b-025f00299cd9}")
    private String defaultClinicId;

    private final TenantSchemaRegistry registry;

    public ClinicIdFilter(TenantSchemaRegistry registry) {
        this.registry = registry;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String clinicId = request.getHeader("X-Clinic-ID");
        if (clinicId == null || clinicId.isBlank()) {
            clinicId = defaultClinicId;
        }
        String schema = registry.getSchemaForClinic(clinicId);
        TenantContext.setCurrentSchema(schema);
        TenantContext.setCurrentClinicId(clinicId);
        try {
            chain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }
}
