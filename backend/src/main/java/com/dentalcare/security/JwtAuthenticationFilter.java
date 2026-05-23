package com.dentalcare.security;

import io.jsonwebtoken.Claims;
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
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    public JwtAuthenticationFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");
        String token;

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            token = authHeader.substring(7);
        } else {
            token = request.getParameter("token");
            if (token == null || token.isBlank()) {
                filterChain.doFilter(request, response);
                return;
            }
        }

        if (!jwtService.isValid(token)) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Invalid or expired token\"}");
            return;
        }

        try {
            Claims claims = jwtService.parse(token);
            String providerId = claims.getSubject();
            String clinicId = claims.get("clinicId", String.class);
            String schemaName = claims.get("schemaName", String.class);
            String role = claims.get("role", String.class);
            claims.get("tenantName", String.class);

            TenantContext.setCurrentClinicId(clinicId);
            TenantContext.setCurrentSchema(schemaName);

            List<SimpleGrantedAuthority> authorities = List.of(
                    new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()));

            UsernamePasswordAuthenticationToken authentication =
                    new UsernamePasswordAuthenticationToken(providerId, null, authorities);

            SecurityContextHolder.getContext().setAuthentication(authentication);

            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
            SecurityContextHolder.clearContext();
        }
    }
}
