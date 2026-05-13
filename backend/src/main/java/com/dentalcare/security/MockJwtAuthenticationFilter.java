package com.dentalcare.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.List;

/**
 * For MVP/development purposes. 
 * This mock filter reads the "Authorization" header. If it starts with "Bearer mock-",
 * it parses the roles and tenant ID. 
 * Format: Bearer mock-tenantId-role
 * Example: Bearer mock-12345678-1234-1234-1234-123456789012-doctor
 */
@Component
public class MockJwtAuthenticationFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        
        String authHeader = request.getHeader("Authorization");
        
        if (authHeader != null && authHeader.startsWith("Bearer mock-")) {
            String token = authHeader.substring(12); // Remove "Bearer mock-"
            String[] parts = token.split("-role-");
            
            if (parts.length == 2) {
                String tenantId = parts[0];
                String role = parts[1];
                
                List<SimpleGrantedAuthority> authorities = Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()));
                
                UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                        "mock-user", null, authorities);
                
                SecurityContextHolder.getContext().setAuthentication(authentication);
                TenantContext.setCurrentTenant(tenantId);
            }
        }
        
        try {
            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }
}
