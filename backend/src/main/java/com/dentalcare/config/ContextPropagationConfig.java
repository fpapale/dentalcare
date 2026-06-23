package com.dentalcare.config;

import com.dentalcare.security.TenantContext;
import io.micrometer.context.ContextRegistry;
import io.micrometer.context.ThreadLocalAccessor;
import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import reactor.core.publisher.Hooks;

/**
 * Propaga i ThreadLocal di tenant (schema + clinic_id) e Spring Security ai thread
 * reattivi usati durante lo streaming della chat AI. Senza questo, i tool che leggono
 * {@link TenantContext} o {@link SecurityContextHolder} verrebbero eseguiti su thread
 * reactor privi di contesto, con rischio di errore o accesso cross-tenant.
 */
@Configuration
public class ContextPropagationConfig {

    @PostConstruct
    public void init() {
        Hooks.enableAutomaticContextPropagation();
        ContextRegistry registry = ContextRegistry.getInstance();
        registry.registerThreadLocalAccessor(new TenantSchemaAccessor());
        registry.registerThreadLocalAccessor(new TenantClinicAccessor());
        registry.registerThreadLocalAccessor(new SecurityContextAccessor());
    }

    static final class TenantSchemaAccessor implements ThreadLocalAccessor<String> {
        static final String KEY = "dc.tenant.schema";
        @Override public Object key() { return KEY; }
        @Override public String getValue() { return TenantContext.getCurrentSchema(); }
        @Override public void setValue(String value) { TenantContext.setCurrentSchema(value); }
        @Override public void setValue() { TenantContext.setCurrentSchema(null); }
        @Override public void restore() { TenantContext.setCurrentSchema(null); }
    }

    static final class TenantClinicAccessor implements ThreadLocalAccessor<String> {
        static final String KEY = "dc.tenant.clinic";
        @Override public Object key() { return KEY; }
        @Override public String getValue() { return TenantContext.getCurrentClinicId(); }
        @Override public void setValue(String value) { TenantContext.setCurrentClinicId(value); }
        @Override public void setValue() { TenantContext.setCurrentClinicId(null); }
        @Override public void restore() { TenantContext.setCurrentClinicId(null); }
    }

    static final class SecurityContextAccessor implements ThreadLocalAccessor<SecurityContext> {
        static final String KEY = "dc.security.context";
        @Override public Object key() { return KEY; }
        @Override public SecurityContext getValue() { return SecurityContextHolder.getContext(); }
        @Override public void setValue(SecurityContext value) { SecurityContextHolder.setContext(value); }
        @Override public void setValue() { SecurityContextHolder.clearContext(); }
        @Override public void restore() { SecurityContextHolder.clearContext(); }
    }
}
