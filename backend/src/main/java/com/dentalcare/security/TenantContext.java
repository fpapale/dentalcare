package com.dentalcare.security;

public class TenantContext {

    private static final ThreadLocal<String> CURRENT_SCHEMA = new ThreadLocal<>();
    private static final ThreadLocal<String> CURRENT_CLINIC_ID = new ThreadLocal<>();

    public static String getCurrentSchema() {
        return CURRENT_SCHEMA.get();
    }

    public static void setCurrentSchema(String schema) {
        CURRENT_SCHEMA.set(schema);
    }

    public static String getCurrentClinicId() {
        return CURRENT_CLINIC_ID.get();
    }

    public static void setCurrentClinicId(String clinicId) {
        CURRENT_CLINIC_ID.set(clinicId);
    }

    /** Validates schema name against pattern ^t_[0-9a-f]{8}$ to prevent SQL injection. */
    public static String validatedSchema() {
        String schema = CURRENT_SCHEMA.get();
        if (schema == null || !schema.matches("^t_[0-9a-f]{8}$")) {
            throw new IllegalStateException("Invalid or missing tenant schema: " + schema);
        }
        return schema;
    }

    /** Keep for backward compatibility during migration — returns clinic_id as UUID string */
    public static String getCurrentTenant() {
        return CURRENT_CLINIC_ID.get();
    }

    public static void clear() {
        CURRENT_SCHEMA.remove();
        CURRENT_CLINIC_ID.remove();
    }
}
