package com.dentalcare.config;

// TenantAspect disabled - clinic_id filtering is done explicitly in each service
// via TenantContext.getCurrentTenant() without relying on PostgreSQL set_config()
public class TenantAspect {
}
