package com.dentalcare.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class EstimateSchemaInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(EstimateSchemaInitializer.class);
    private final JdbcTemplate jdbc;

    public EstimateSchemaInitializer(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void run(ApplicationArguments args) {
        try {
            applyApplicativeSchema();
            applyTenantOperationalPatches();
            log.info("EstimateSchemaInitializer: schema OK");
        } catch (Exception e) {
            log.error("EstimateSchemaInitializer failed", e);
        }
    }

    private void applyApplicativeSchema() {
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.tenants (
                id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                name        text NOT NULL,
                schema_name text NOT NULL UNIQUE,
                email       text,
                phone       text,
                plan        text NOT NULL DEFAULT 'base',
                active      boolean NOT NULL DEFAULT true,
                created_at  timestamptz NOT NULL DEFAULT now(),
                updated_at  timestamptz NOT NULL DEFAULT now()
            )
            """);
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.tenant_clinics (
                clinic_id   uuid PRIMARY KEY,
                tenant_id   uuid NOT NULL REFERENCES dentalcare.tenants(id) ON DELETE CASCADE,
                created_at  timestamptz NOT NULL DEFAULT now()
            )
            """);
        // Seed demo tenant if not present
        jdbc.execute("""
            INSERT INTO dentalcare.tenants (id, name, schema_name, email, plan)
            VALUES ('a0000001-0000-0000-0000-000000000001', 'Studio Demo DentalCare', 't_9d754153', 'demo@dentalcare.it', 'professional')
            ON CONFLICT DO NOTHING
            """);
        // Seed demo tenant_clinics from t_9d754153.clinics if schema exists
        try {
            jdbc.execute("""
                INSERT INTO dentalcare.tenant_clinics (clinic_id, tenant_id)
                SELECT c.id, 'a0000001-0000-0000-0000-000000000001'::uuid
                FROM t_9d754153.clinics c
                ON CONFLICT DO NOTHING
                """);
        } catch (Exception e) {
            // t_9d754153 schema not yet migrated — skip
        }
    }

    private void applyTenantOperationalPatches() {
        // These columns were added by earlier sessions; ensure they exist in tenant schema
        try {
            jdbc.execute("ALTER TABLE t_9d754153.patients ADD COLUMN IF NOT EXISTS photo_url TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS photo_url TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS vat_number TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS fiscal_code TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS professional_register TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS register_number TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_address_street TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_address_zip TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_address_city TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_address_province TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_pec TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_iban TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS billing_sdi_code TEXT");
            jdbc.execute("ALTER TABLE t_9d754153.providers ADD COLUMN IF NOT EXISTS invoice_prefix TEXT");
        } catch (Exception e) {
            log.warn("applyTenantOperationalPatches: {}", e.getMessage());
        }
    }
}
