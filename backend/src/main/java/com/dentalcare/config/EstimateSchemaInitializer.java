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
            applyEstimateView();
            applyTriggerFunction();
            applyPatch();
            log.info("EstimateSchemaInitializer: schema OK");
        } catch (Exception e) {
            log.error("EstimateSchemaInitializer failed", e);
        }
    }

    private void applyEstimateView() {
        jdbc.execute("""
            CREATE OR REPLACE VIEW dentalcare.v_patient_estimates_summary AS
            WITH line_agg AS (
                SELECT clinic_id, estimate_id, COUNT(*) AS estimate_lines_count
                FROM dentalcare.estimate_lines
                GROUP BY clinic_id, estimate_id
            )
            SELECT
                c.id AS clinic_id,
                c.name AS clinic_name,
                p.id AS patient_id,
                p.last_name AS patient_last_name,
                p.first_name AS patient_first_name,
                concat_ws(' ', p.last_name, p.first_name) AS patient_full_name,
                p.fiscal_code AS patient_fiscal_code,
                p.phone AS patient_phone,
                p.email AS patient_email,
                e.id AS estimate_id,
                e.estimate_number,
                e.version,
                e.status AS estimate_status,
                e.title AS estimate_title,
                e.currency,
                e.subtotal_amount,
                e.discount_amount,
                e.taxable_amount,
                e.vat_amount,
                e.total_amount,
                e.total_amount AS total_net,
                e.issued_at,
                e.sent_at,
                e.valid_until,
                e.accepted_at,
                e.rejected_at,
                e.created_at AS estimate_created_at,
                e.updated_at AS estimate_updated_at,
                tp.id AS treatment_plan_id,
                tp.name AS treatment_plan_name,
                tp.status AS treatment_plan_status,
                COALESCE(la.estimate_lines_count, 0) AS estimate_lines_count,
                CASE
                    WHEN e.valid_until IS NULL THEN false
                    WHEN e.status IN ('accepted', 'rejected', 'cancelled') THEN false
                    WHEN e.valid_until < current_date THEN true
                    ELSE false
                END AS is_expired_by_date,
                CASE
                    WHEN e.valid_until IS NULL THEN NULL
                    ELSE e.valid_until - current_date
                END AS days_to_expiry
            FROM dentalcare.clinics c
            JOIN dentalcare.patients p ON p.clinic_id = c.id
            JOIN dentalcare.estimates e ON e.patient_id = p.id AND e.clinic_id = p.clinic_id
            LEFT JOIN dentalcare.treatment_plans tp
              ON tp.id = e.treatment_plan_id AND tp.clinic_id = e.clinic_id
            LEFT JOIN line_agg la ON la.estimate_id = e.id AND la.clinic_id = e.clinic_id
            """);
    }

    private void applyTriggerFunction() {
        jdbc.execute("""
            CREATE OR REPLACE FUNCTION dentalcare.recalc_estimate_totals(p_estimate_id uuid)
            RETURNS void AS $func$
            BEGIN
                UPDATE dentalcare.estimates e
                SET subtotal_amount = COALESCE(t.subtotal_amount, 0),
                    discount_amount = COALESCE(t.discount_amount, 0),
                    taxable_amount  = COALESCE(t.taxable_amount, 0),
                    vat_amount      = COALESCE(t.vat_amount, 0),
                    total_amount    = COALESCE(t.total_amount, 0),
                    updated_at      = now()
                FROM (
                    SELECT estimate_id,
                           round(SUM(line_subtotal), 2)   AS subtotal_amount,
                           round(SUM(discount_amount), 2) AS discount_amount,
                           round(SUM(line_taxable), 2)    AS taxable_amount,
                           round(SUM(line_vat_amount), 2) AS vat_amount,
                           round(SUM(line_total), 2)      AS total_amount
                    FROM dentalcare.estimate_lines
                    WHERE estimate_id = p_estimate_id
                    GROUP BY estimate_id
                ) t
                WHERE e.id = p_estimate_id AND e.id = t.estimate_id;

                UPDATE dentalcare.estimates
                SET subtotal_amount = 0, discount_amount = 0, taxable_amount = 0,
                    vat_amount = 0, total_amount = 0, updated_at = now()
                WHERE id = p_estimate_id
                  AND NOT EXISTS (
                      SELECT 1 FROM dentalcare.estimate_lines WHERE estimate_id = p_estimate_id
                  );
            END;
            $func$ LANGUAGE plpgsql
            """);

        jdbc.execute("""
            CREATE OR REPLACE FUNCTION dentalcare.trg_recalc_estimate_totals()
            RETURNS trigger AS $func$
            BEGIN
                IF TG_OP = 'INSERT' THEN
                    PERFORM dentalcare.recalc_estimate_totals(NEW.estimate_id);
                    RETURN NEW;
                ELSIF TG_OP = 'UPDATE' THEN
                    IF NEW.estimate_id <> OLD.estimate_id THEN
                        PERFORM dentalcare.recalc_estimate_totals(OLD.estimate_id);
                    END IF;
                    PERFORM dentalcare.recalc_estimate_totals(NEW.estimate_id);
                    RETURN NEW;
                ELSIF TG_OP = 'DELETE' THEN
                    PERFORM dentalcare.recalc_estimate_totals(OLD.estimate_id);
                    RETURN OLD;
                END IF;
                RETURN NULL;
            END;
            $func$ LANGUAGE plpgsql
            """);

        jdbc.execute("""
            DROP TRIGGER IF EXISTS trg_estimate_lines_recalc_totals
            ON dentalcare.estimate_lines
            """);

        jdbc.execute("""
            CREATE TRIGGER trg_estimate_lines_recalc_totals
            AFTER INSERT OR UPDATE OR DELETE ON dentalcare.estimate_lines
            FOR EACH ROW EXECUTE FUNCTION dentalcare.trg_recalc_estimate_totals()
            """);
    }

    private void applyPatch() {
        jdbc.execute("""
            ALTER TABLE dentalcare.estimates
            ADD COLUMN IF NOT EXISTS created_by_provider_id uuid
            """);

        jdbc.execute("""
            CREATE INDEX IF NOT EXISTS ix_estimates_provider
            ON dentalcare.estimates(clinic_id, created_by_provider_id)
            WHERE created_by_provider_id IS NOT NULL
            """);

        jdbc.execute("""
            ALTER TABLE dentalcare.estimates
            DROP CONSTRAINT IF EXISTS ux_estimates_plan_version
            """);

        jdbc.execute("""
            CREATE INDEX IF NOT EXISTS ix_estimates_treatment_plan
            ON dentalcare.estimates(clinic_id, treatment_plan_id)
            WHERE treatment_plan_id IS NOT NULL
            """);

        jdbc.execute("""
            CREATE INDEX IF NOT EXISTS ix_estimate_lines_plan_item
            ON dentalcare.estimate_lines(clinic_id, treatment_plan_item_id)
            WHERE treatment_plan_item_id IS NOT NULL
            """);
    }
}
