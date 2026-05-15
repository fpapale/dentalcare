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
            applyInvoiceSchema();
            applyInventorySchema();
            applyInventorySeed();
            applyRecallSchema();
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
                END AS days_to_expiry,
                e.created_by_provider_id
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

    private void applyInvoiceSchema() {
        // 1. Provider billing columns
        jdbc.execute("""
            ALTER TABLE dentalcare.providers
            ADD COLUMN IF NOT EXISTS vat_number               text,
            ADD COLUMN IF NOT EXISTS fiscal_code              text,
            ADD COLUMN IF NOT EXISTS professional_register    text,
            ADD COLUMN IF NOT EXISTS register_number          text,
            ADD COLUMN IF NOT EXISTS billing_address_street   text,
            ADD COLUMN IF NOT EXISTS billing_address_zip      text,
            ADD COLUMN IF NOT EXISTS billing_address_city     text,
            ADD COLUMN IF NOT EXISTS billing_address_province text,
            ADD COLUMN IF NOT EXISTS billing_pec              text,
            ADD COLUMN IF NOT EXISTS billing_iban             text,
            ADD COLUMN IF NOT EXISTS billing_sdi_code         text,
            ADD COLUMN IF NOT EXISTS invoice_prefix           text DEFAULT 'PARC'
            """);

        // 2. ENUMs
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.invoice_document_type AS ENUM
                    ('fattura','ricevuta','parcella','nota_credito');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.invoice_status AS ENUM
                    ('draft','issued','paid','cancelled');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.invoice_issuer_type AS ENUM
                    ('clinic','provider');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // 3. invoices table
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.invoices (
                id                  uuid                              PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id           uuid                              NOT NULL
                                        REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                invoice_number      text                              NOT NULL,
                document_type       dentalcare.invoice_document_type  NOT NULL DEFAULT 'fattura',
                invoice_date        date                              NOT NULL DEFAULT current_date,
                due_date            date,
                status              dentalcare.invoice_status         NOT NULL DEFAULT 'draft',
                issuer_type         dentalcare.invoice_issuer_type    NOT NULL DEFAULT 'clinic',
                provider_id         uuid,
                patient_id          uuid                              NOT NULL,
                estimate_id         uuid,
                issuer_name         text,
                issuer_vat_number   text,
                issuer_fiscal_code  text,
                issuer_address      text,
                issuer_email        text,
                issuer_pec          text,
                issuer_sdi_code     text,
                issuer_iban         text,
                patient_full_name   text,
                patient_fiscal_code text,
                patient_address     text,
                patient_email       text,
                subtotal_amount     numeric(12,2)                     NOT NULL DEFAULT 0,
                discount_amount     numeric(12,2)                     NOT NULL DEFAULT 0,
                taxable_amount      numeric(12,2)                     NOT NULL DEFAULT 0,
                vat_amount          numeric(12,2)                     NOT NULL DEFAULT 0,
                total_amount        numeric(12,2)                     NOT NULL DEFAULT 0,
                currency            char(3)                           NOT NULL DEFAULT 'EUR',
                notes               text,
                payment_method      text,
                paid_at             timestamptz,
                issued_at           timestamptz,
                created_at          timestamptz                       NOT NULL DEFAULT now(),
                updated_at          timestamptz                       NOT NULL DEFAULT now(),
                CONSTRAINT invoices_unique_per_clinic UNIQUE (id, clinic_id),
                CONSTRAINT ux_invoices_number         UNIQUE (clinic_id, invoice_number)
            )
            """);

        // FK constraints on invoices (idempotent via DO blocks)
        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.invoices ADD CONSTRAINT fk_invoices_provider
                    FOREIGN KEY (provider_id, clinic_id)
                    REFERENCES dentalcare.providers(id, clinic_id)
                    ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.invoices ADD CONSTRAINT fk_invoices_patient
                    FOREIGN KEY (patient_id, clinic_id)
                    REFERENCES dentalcare.patients(id, clinic_id)
                    ON DELETE RESTRICT;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.invoices ADD CONSTRAINT fk_invoices_estimate
                    FOREIGN KEY (estimate_id, clinic_id)
                    REFERENCES dentalcare.estimates(id, clinic_id)
                    ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // 4. invoice_lines table
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.invoice_lines (
                id              uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id       uuid          NOT NULL
                                    REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                invoice_id      uuid          NOT NULL,
                line_position   integer       NOT NULL DEFAULT 1,
                description     text          NOT NULL,
                tooth_info      text,
                quantity        numeric(10,2) NOT NULL DEFAULT 1,
                unit_price      numeric(12,2) NOT NULL DEFAULT 0,
                discount_amount numeric(12,2) NOT NULL DEFAULT 0,
                vat_rate        numeric(5,2)  NOT NULL DEFAULT 0,
                line_subtotal   numeric(12,2) GENERATED ALWAYS AS (round(quantity * unit_price, 2)) STORED,
                line_taxable    numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(quantity * unit_price - discount_amount, 0), 2)) STORED,
                line_vat_amount numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(quantity * unit_price - discount_amount, 0) * vat_rate / 100, 2)) STORED,
                line_total      numeric(12,2) GENERATED ALWAYS AS (round(GREATEST(quantity * unit_price - discount_amount, 0) * (1 + vat_rate / 100), 2)) STORED,
                created_at      timestamptz   NOT NULL DEFAULT now(),
                CONSTRAINT invoice_lines_unique_per_clinic UNIQUE (id, clinic_id)
            )
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.invoice_lines ADD CONSTRAINT fk_invoice_lines_invoice
                    FOREIGN KEY (invoice_id, clinic_id)
                    REFERENCES dentalcare.invoices(id, clinic_id)
                    ON DELETE CASCADE;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // 5. Indexes
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_invoices_clinic_status ON dentalcare.invoices(clinic_id, status, invoice_date DESC)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_invoices_patient ON dentalcare.invoices(clinic_id, patient_id)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_invoices_estimate ON dentalcare.invoices(clinic_id, estimate_id) WHERE estimate_id IS NOT NULL");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_invoice_lines_invoice ON dentalcare.invoice_lines(clinic_id, invoice_id)");

        // 6. updated_at trigger on invoices
        jdbc.execute("DROP TRIGGER IF EXISTS trg_invoices_set_updated_at ON dentalcare.invoices");
        jdbc.execute("""
            CREATE TRIGGER trg_invoices_set_updated_at
            BEFORE UPDATE ON dentalcare.invoices
            FOR EACH ROW EXECUTE FUNCTION set_updated_at()
            """);

        // 7. recalc_invoice_totals function + trigger
        jdbc.execute("""
            CREATE OR REPLACE FUNCTION dentalcare.recalc_invoice_totals(p_invoice_id uuid)
            RETURNS void
            LANGUAGE plpgsql
            SET search_path = dentalcare
            AS $func$
            BEGIN
                UPDATE invoices i
                SET subtotal_amount = COALESCE(t.subtotal_amount, 0),
                    discount_amount = COALESCE(t.discount_amount, 0),
                    taxable_amount  = COALESCE(t.taxable_amount, 0),
                    vat_amount      = COALESCE(t.vat_amount, 0),
                    total_amount    = COALESCE(t.total_amount, 0),
                    updated_at      = now()
                FROM (
                    SELECT invoice_id,
                           round(SUM(line_subtotal), 2)   AS subtotal_amount,
                           round(SUM(discount_amount), 2) AS discount_amount,
                           round(SUM(line_taxable), 2)    AS taxable_amount,
                           round(SUM(line_vat_amount), 2) AS vat_amount,
                           round(SUM(line_total), 2)      AS total_amount
                    FROM invoice_lines
                    WHERE invoice_id = p_invoice_id
                    GROUP BY invoice_id
                ) t
                WHERE i.id = p_invoice_id AND i.id = t.invoice_id;

                UPDATE invoices SET subtotal_amount=0, discount_amount=0,
                    taxable_amount=0, vat_amount=0, total_amount=0, updated_at=now()
                WHERE id = p_invoice_id
                  AND NOT EXISTS (SELECT 1 FROM invoice_lines WHERE invoice_id = p_invoice_id);
            END;
            $func$
            """);

        jdbc.execute("""
            CREATE OR REPLACE FUNCTION dentalcare.trg_recalc_invoice_totals()
            RETURNS trigger
            LANGUAGE plpgsql
            SET search_path = dentalcare
            AS $func$
            BEGIN
                IF TG_OP = 'INSERT' THEN
                    PERFORM dentalcare.recalc_invoice_totals(NEW.invoice_id); RETURN NEW;
                ELSIF TG_OP = 'UPDATE' THEN
                    IF NEW.invoice_id <> OLD.invoice_id THEN
                        PERFORM dentalcare.recalc_invoice_totals(OLD.invoice_id);
                    END IF;
                    PERFORM dentalcare.recalc_invoice_totals(NEW.invoice_id); RETURN NEW;
                ELSIF TG_OP = 'DELETE' THEN
                    PERFORM dentalcare.recalc_invoice_totals(OLD.invoice_id); RETURN OLD;
                END IF;
                RETURN NULL;
            END;
            $func$
            """);

        jdbc.execute("DROP TRIGGER IF EXISTS trg_invoice_lines_recalc_totals ON dentalcare.invoice_lines");
        jdbc.execute("""
            CREATE TRIGGER trg_invoice_lines_recalc_totals
            AFTER INSERT OR UPDATE OR DELETE ON dentalcare.invoice_lines
            FOR EACH ROW EXECUTE FUNCTION dentalcare.trg_recalc_invoice_totals()
            """);

        jdbc.execute("""
            CREATE INDEX IF NOT EXISTS ix_invoices_provider
            ON dentalcare.invoices(clinic_id, provider_id)
            WHERE provider_id IS NOT NULL
            """);
    }

    private void applyInventorySchema() {
        // suppliers
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.suppliers (
                id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id       uuid        NOT NULL REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                name            text        NOT NULL,
                contact_person  text,
                phone           text,
                email           text,
                notes           text,
                is_active       boolean     NOT NULL DEFAULT true,
                created_at      timestamptz NOT NULL DEFAULT now(),
                updated_at      timestamptz NOT NULL DEFAULT now(),
                UNIQUE (id, clinic_id)
            )
            """);

        // product_categories
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.product_categories (
                id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id   uuid    NOT NULL REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                name        text    NOT NULL,
                UNIQUE (id, clinic_id),
                UNIQUE (clinic_id, name)
            )
            """);

        // stock_movement_type ENUM
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.stock_movement_type AS ENUM
                    ('carico','scarico','rettifica','rientro');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // products
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.products (
                id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id           uuid          NOT NULL REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                category_id         uuid,
                supplier_id         uuid,
                name                text          NOT NULL,
                description         text,
                sku                 text,
                unit                text          NOT NULL DEFAULT 'pz',
                min_stock_quantity  numeric(10,2) NOT NULL DEFAULT 0,
                reorder_quantity    numeric(10,2) NOT NULL DEFAULT 0,
                unit_cost           numeric(12,2),
                is_active           boolean       NOT NULL DEFAULT true,
                created_at          timestamptz   NOT NULL DEFAULT now(),
                updated_at          timestamptz   NOT NULL DEFAULT now(),
                UNIQUE (id, clinic_id)
            )
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.products ADD CONSTRAINT fk_products_category
                    FOREIGN KEY (category_id, clinic_id)
                    REFERENCES dentalcare.product_categories(id, clinic_id)
                    ON DELETE SET NULL;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.products ADD CONSTRAINT fk_products_supplier
                    FOREIGN KEY (supplier_id, clinic_id)
                    REFERENCES dentalcare.suppliers(id, clinic_id)
                    ON DELETE SET NULL;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // stock_movements
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.stock_movements (
                id                      uuid                            PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id               uuid                            NOT NULL REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                product_id              uuid                            NOT NULL,
                movement_type           dentalcare.stock_movement_type  NOT NULL,
                quantity                numeric(10,2)                   NOT NULL,
                unit_cost               numeric(12,2),
                notes                   text,
                reference_doc           text,
                created_by_provider_id  uuid,
                created_at              timestamptz                     NOT NULL DEFAULT now(),
                UNIQUE (id, clinic_id)
            )
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.stock_movements ADD CONSTRAINT fk_stock_movements_product
                    FOREIGN KEY (product_id, clinic_id)
                    REFERENCES dentalcare.products(id, clinic_id)
                    ON DELETE RESTRICT;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // product_stock_v view
        jdbc.execute("""
            CREATE OR REPLACE VIEW dentalcare.product_stock_v AS
            SELECT
                p.id            AS product_id,
                p.clinic_id,
                p.name,
                p.sku,
                p.unit,
                p.min_stock_quantity,
                p.reorder_quantity,
                p.unit_cost,
                p.is_active,
                p.category_id,
                pc.name         AS category_name,
                p.supplier_id,
                s.name          AS supplier_name,
                p.description,
                p.created_at,
                p.updated_at,
                COALESCE(SUM(
                    CASE m.movement_type
                        WHEN 'scarico' THEN -m.quantity
                        ELSE m.quantity
                    END
                ), 0) AS current_stock,
                CASE
                    WHEN COALESCE(SUM(CASE m.movement_type WHEN 'scarico' THEN -m.quantity ELSE m.quantity END), 0)
                         < p.min_stock_quantity
                      THEN 'critico'
                    WHEN COALESCE(SUM(CASE m.movement_type WHEN 'scarico' THEN -m.quantity ELSE m.quantity END), 0)
                         < p.min_stock_quantity * 1.2
                      THEN 'basso'
                    ELSE 'ok'
                END AS stock_status
            FROM dentalcare.products p
            LEFT JOIN dentalcare.product_categories pc ON pc.id = p.category_id AND pc.clinic_id = p.clinic_id
            LEFT JOIN dentalcare.suppliers s ON s.id = p.supplier_id AND s.clinic_id = p.clinic_id
            LEFT JOIN dentalcare.stock_movements m ON m.product_id = p.id AND m.clinic_id = p.clinic_id
            GROUP BY p.id, p.clinic_id, p.name, p.sku, p.unit, p.min_stock_quantity,
                     p.reorder_quantity, p.unit_cost, p.is_active, p.category_id, pc.name,
                     p.supplier_id, s.name, p.description, p.created_at, p.updated_at
            """);

        // indexes
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_products_clinic ON dentalcare.products(clinic_id) WHERE is_active = true");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_products_category ON dentalcare.products(clinic_id, category_id)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_stock_movements_product ON dentalcare.stock_movements(clinic_id, product_id, created_at DESC)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_suppliers_clinic ON dentalcare.suppliers(clinic_id) WHERE is_active = true");

        // triggers
        jdbc.execute("DROP TRIGGER IF EXISTS trg_suppliers_updated_at ON dentalcare.suppliers");
        jdbc.execute("""
            CREATE TRIGGER trg_suppliers_updated_at
            BEFORE UPDATE ON dentalcare.suppliers
            FOR EACH ROW EXECUTE FUNCTION set_updated_at()
            """);
        jdbc.execute("DROP TRIGGER IF EXISTS trg_products_updated_at ON dentalcare.products");
        jdbc.execute("""
            CREATE TRIGGER trg_products_updated_at
            BEFORE UPDATE ON dentalcare.products
            FOR EACH ROW EXECUTE FUNCTION set_updated_at()
            """);

        // seed default categories for every clinic
        jdbc.execute("""
            DO $$
            DECLARE v_clinic_id uuid;
            BEGIN
                FOR v_clinic_id IN SELECT id FROM dentalcare.clinics LOOP
                    INSERT INTO dentalcare.product_categories(clinic_id, name)
                    VALUES
                        (v_clinic_id, 'Farmaci'),
                        (v_clinic_id, 'Materiali'),
                        (v_clinic_id, 'DPI'),
                        (v_clinic_id, 'Chirurgia'),
                        (v_clinic_id, 'Medicazione'),
                        (v_clinic_id, 'Strumentario')
                    ON CONFLICT (clinic_id, name) DO NOTHING;
                END LOOP;
            END $$
            """);
    }

    private void applyInventorySeed() {
        jdbc.execute("""
            DO $$
            DECLARE
                v_clinic_id      uuid;
                v_s_dentsply     uuid;
                v_s_voco         uuid;
                v_s_septodont    uuid;
                v_c_farmaci      uuid;
                v_c_materiali    uuid;
                v_c_dpi          uuid;
                v_c_chirurgia    uuid;
                v_c_medicazione  uuid;
                v_c_strumentario uuid;
            BEGIN
                FOR v_clinic_id IN SELECT id FROM dentalcare.clinics LOOP

                IF EXISTS (SELECT 1 FROM dentalcare.products WHERE clinic_id = v_clinic_id LIMIT 1) THEN
                    CONTINUE;
                END IF;

                INSERT INTO dentalcare.suppliers (id, clinic_id, name, contact_person, phone, email, notes)
                VALUES
                    (gen_random_uuid(), v_clinic_id, 'Dentsply Sirona Italia', 'Marco Ferretti',  '02 1234 5678', 'ordini@dentsply.it',  'Fornitore principale materiali endodonzia e conservativa'),
                    (gen_random_uuid(), v_clinic_id, 'VOCO GmbH Italia',       'Giulia Marini',   '02 9876 5432', 'info@voco.it',        'Compositi e materiali restaurativi'),
                    (gen_random_uuid(), v_clinic_id, 'Septodont Italia',        'Andrea Conti',    '06 5555 1234', 'ordini@septodont.it', 'Anestetici e farmaci per uso odontoiatrico');

                SELECT id INTO v_s_dentsply  FROM dentalcare.suppliers WHERE clinic_id = v_clinic_id AND name = 'Dentsply Sirona Italia' LIMIT 1;
                SELECT id INTO v_s_voco      FROM dentalcare.suppliers WHERE clinic_id = v_clinic_id AND name = 'VOCO GmbH Italia'       LIMIT 1;
                SELECT id INTO v_s_septodont FROM dentalcare.suppliers WHERE clinic_id = v_clinic_id AND name = 'Septodont Italia'       LIMIT 1;

                SELECT id INTO v_c_farmaci      FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Farmaci'      LIMIT 1;
                SELECT id INTO v_c_materiali    FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Materiali'    LIMIT 1;
                SELECT id INTO v_c_dpi          FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'DPI'          LIMIT 1;
                SELECT id INTO v_c_chirurgia    FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Chirurgia'    LIMIT 1;
                SELECT id INTO v_c_medicazione  FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Medicazione'  LIMIT 1;
                SELECT id INTO v_c_strumentario FROM dentalcare.product_categories WHERE clinic_id = v_clinic_id AND name = 'Strumentario' LIMIT 1;

                -- Farmaci
                INSERT INTO dentalcare.products (clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost) VALUES
                    (v_clinic_id, v_c_farmaci, v_s_septodont, 'Articaina 4% + epinefrina 1:100.000 (Septanest)', 'Anestetico locale con vasocostrittore. CHIR, ENDO, CONS, IMP.', 'SEPT-ART100', 'carpule', 20, 50, 0.55),
                    (v_clinic_id, v_c_farmaci, v_s_septodont, 'Mepivacaina 3% senza vasocostrittore (Scandonest)', 'Anestetico locale senza epinefrina. Pazienti cardiopatici.', 'SEPT-MEP3', 'carpule', 10, 30, 0.60),
                    (v_clinic_id, v_c_farmaci, v_s_septodont, 'Gel anestetico topico', 'Anestesia di superficie pre-iniezione.', 'SEPT-GEL', 'flacone', 3, 6, 4.50),
                    (v_clinic_id, v_c_farmaci, NULL, 'Amoxicillina 1g + Acido clavulanico (cpr)', 'Profilassi antibiotica post-chirurgica. CHIR-002/003, IMP-001/004.', 'FARM-AMX1G', 'conf', 5, 10, 8.20),
                    (v_clinic_id, v_c_farmaci, NULL, 'Ibuprofene 600mg (cpr)', 'Antidolorifico/antinfiammatorio post-intervento.', 'FARM-IBU600', 'conf', 5, 10, 4.80),
                    (v_clinic_id, v_c_farmaci, NULL, 'Idrossido di calcio pasta', 'Medicazione intracanalare tra sedute (ENDO-*).', 'FARM-CAOH', 'siringa', 5, 10, 3.20),
                    (v_clinic_id, v_c_farmaci, v_s_dentsply, 'Ipoclorito di sodio 5.25%', 'Irrigante canalare endodonzia (ENDO-*). Flacone 1L.', 'ENDO-NAOCL', 'flacone', 2, 4, 6.50);

                -- Materiali
                INSERT INTO dentalcare.products (clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost) VALUES
                    (v_clinic_id, v_c_materiali, v_s_voco, 'Composito nanoriempito A1 (Grandio)', 'Restauro diretto conservativa (CONS-001/002/003). Tonalita A1.', 'VOCO-GRA-A1', 'siringa 4g', 3, 8, 14.50),
                    (v_clinic_id, v_c_materiali, v_s_voco, 'Composito nanoriempito A2 (Grandio)', 'Restauro diretto conservativa (CONS-001/002/003). Tonalita A2.', 'VOCO-GRA-A2', 'siringa 4g', 3, 8, 14.50),
                    (v_clinic_id, v_c_materiali, v_s_voco, 'Composito nanoriempito A3 (Grandio)', 'Restauro diretto conservativa (CONS-001/002/003). Tonalita A3.', 'VOCO-GRA-A3', 'siringa 4g', 2, 6, 14.50),
                    (v_clinic_id, v_c_materiali, v_s_voco, 'Adesivo universale monocomponente (Futurabond U)', 'Bonding per restauri in composito. Total-etch e self-etch.', 'VOCO-FUT-U', 'flacone 5ml', 2, 4, 22.00),
                    (v_clinic_id, v_c_materiali, v_s_voco, 'Acido ortofosforico 37% (Vococid)', 'Mordenzatura smalto/dentina prima del bonding.', 'VOCO-ACID37', 'siringa', 3, 6, 6.80),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'Cemento vetroionomero fotopolimerizzabile', 'Otturazioni decidue (PED-002), base/liner sotto composito.', 'DENT-GIC', 'set', 2, 4, 18.00),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'Coni di gutaperca standardizzati (assortiti)', 'Otturazione canalare (ENDO-*). Box 120 coni.', 'ENDO-GUTTA', 'box', 3, 6, 9.50),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'File NiTi rotanti ProTaper Next (set completo)', 'Sagomatura canalare meccanica (ENDO-*).', 'ENDO-PTN', 'set/6 pz', 5, 12, 7.20),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'Cemento canalare AH Plus', 'Sigillante endodontico per otturazione canalare.', 'ENDO-AHPLUS', 'set basi A+B', 2, 4, 16.50),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'Materiale da impronta vinilpolisilossano', 'Impronte per protesi fissa e mobile (PROT-001/002/003/004).', 'PROT-VPS', 'kit 2 cartucce', 4, 8, 28.00),
                    (v_clinic_id, v_c_materiali, NULL, 'Alginato cromoforo (Hydrogum 5)', 'Impronta diagnostica, studio modelli, protesi mobile.', 'PROT-ALG', 'busta 450g', 3, 6, 12.00),
                    (v_clinic_id, v_c_materiali, NULL, 'Cemento provvisorio (Temp Bond NE)', 'Cementazione provvisoria corone e intarsi.', 'PROT-TMPBND', 'siringa', 2, 4, 9.80),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'Membrana riassorbibile in collagene (Bio-Gide)', 'Rigenerazione ossea guidata (IMP-004). 25x25mm.', 'IMP-BIOGIDE', 'pz', 3, 5, 95.00),
                    (v_clinic_id, v_c_materiali, v_s_dentsply, 'Granuli ossei sintetici bifasici (Bio-Oss)', 'Augmentazione ossea (IMP-004). Flacone 0.5g.', 'IMP-BIOOSS', 'flacone', 3, 5, 110.00),
                    (v_clinic_id, v_c_materiali, NULL, 'Gel fluoruro fosfato acidulato 1.23%', 'Fluoroprofilassi (IGI-003), sigillatura solchi (PED-001).', 'IGI-FLU', 'gel 250ml', 2, 4, 14.00),
                    (v_clinic_id, v_c_materiali, NULL, 'Gel sigillante per solchi (sealant)', 'Sigillatura preventiva solchi e fessure (PED-001).', 'PED-SEAL', 'siringa', 2, 4, 18.50),
                    (v_clinic_id, v_c_materiali, NULL, 'Gel sbiancante carbamide perossido 16%', 'Mascherine sbiancamento domiciliare (EST-002).', 'EST-BLEA16', 'kit 3 siringhe', 4, 8, 22.00),
                    (v_clinic_id, v_c_materiali, NULL, 'Resina acrilica termopolimerizzabile rosa', 'Base protesi totale e parziale (PROT-005/006).', 'PROT-ACRI', 'kit 250g', 2, 4, 28.00);

                -- DPI
                INSERT INTO dentalcare.products (clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost) VALUES
                    (v_clinic_id, v_c_dpi, NULL, 'Guanti in nitrile taglia S (box 100)', 'Guanti monouso senza polvere. Taglia S.', 'DPI-GLV-S', 'box', 2, 4, 8.50),
                    (v_clinic_id, v_c_dpi, NULL, 'Guanti in nitrile taglia M (box 100)', 'Guanti monouso senza polvere. Taglia M.', 'DPI-GLV-M', 'box', 3, 6, 8.50),
                    (v_clinic_id, v_c_dpi, NULL, 'Guanti in nitrile taglia L (box 100)', 'Guanti monouso senza polvere. Taglia L.', 'DPI-GLV-L', 'box', 2, 4, 8.50),
                    (v_clinic_id, v_c_dpi, NULL, 'Mascherine chirurgiche tipo IIR (box 50)', 'Protezione vie aeree operatore. Conformi EN 14683.', 'DPI-MASK-IIR', 'box', 3, 6, 12.00),
                    (v_clinic_id, v_c_dpi, NULL, 'Mascherine FFP2 (box 20)', 'Alta protezione per procedure aerosol-generanti.', 'DPI-FFP2', 'box', 2, 4, 18.00),
                    (v_clinic_id, v_c_dpi, NULL, 'Occhiali protettivi monouso', 'Protezione occhi operatore e paziente.', 'DPI-GOGG', 'pz', 10, 20, 0.90),
                    (v_clinic_id, v_c_dpi, NULL, 'Camici monouso TNT taglia unica (box 10)', 'Protezione abiti operatore.', 'DPI-CAMICE', 'box', 2, 4, 24.00),
                    (v_clinic_id, v_c_dpi, NULL, 'Cuffie monouso (box 100)', 'Protezione capelli.', 'DPI-CUFFIA', 'box', 2, 4, 5.00);

                -- Chirurgia
                INSERT INTO dentalcare.products (clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost) VALUES
                    (v_clinic_id, v_c_chirurgia, NULL, 'Bisturi monouso lama n.15 (box 10)', 'Incisione tessuti molli. CHIR-002/003/004, IMP-001/004.', 'CHIR-BIST15', 'box', 3, 6, 12.00),
                    (v_clinic_id, v_c_chirurgia, NULL, 'Filo di sutura 4/0 non riassorbibile (seta)', 'Chiusura ferita post-chirurgica. CHIR-002/003/004, IMP-001.', 'CHIR-SUT4S', 'busta', 10, 20, 2.80),
                    (v_clinic_id, v_c_chirurgia, NULL, 'Filo di sutura 4/0 riassorbibile (Vicryl)', 'Chiusura piani profondi. IMP-001/004.', 'CHIR-SUT4V', 'busta', 5, 10, 4.20),
                    (v_clinic_id, v_c_chirurgia, v_s_septodont, 'Spugna emostatica in gelatina (Gelaspon)', 'Emostasi alveolare post-estrazione (CHIR-001/002/003).', 'CHIR-GEL', 'box 14 pz', 3, 5, 18.00),
                    (v_clinic_id, v_c_chirurgia, v_s_dentsply, 'Viti di copertura impianto (assortite)', 'Copertura fixture tra prima e seconda fase (IMP-001).', 'IMP-VITE', 'pz', 5, 10, 8.50),
                    (v_clinic_id, v_c_chirurgia, NULL, 'Aghi per siringhe carpule 27G short (box 100)', 'Somministrazione anestetico locale. Monouso.', 'CHIR-AGHI27S', 'box', 2, 4, 14.00),
                    (v_clinic_id, v_c_chirurgia, NULL, 'Aghi per siringhe carpule 27G long (box 100)', 'Anestesia tronculare. Monouso.', 'CHIR-AGHI27L', 'box', 2, 4, 14.00);

                -- Medicazione
                INSERT INTO dentalcare.products (clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost) VALUES
                    (v_clinic_id, v_c_medicazione, NULL, 'Garze sterili 10x10cm (conf 25 pz)', 'Medicazione ferite, tamponamento emorragie.', 'MED-GARZE', 'conf', 5, 10, 2.50),
                    (v_clinic_id, v_c_medicazione, NULL, 'Cotone in rotoli (500g)', 'Isolamento, tamponamento, assorbimento.', 'MED-COTONE', 'rotolo', 3, 6, 4.80),
                    (v_clinic_id, v_c_medicazione, NULL, 'Bavaglini monouso plastificati (box 500)', 'Protezione paziente durante le prestazioni.', 'MED-BAVAG', 'box', 2, 4, 18.00),
                    (v_clinic_id, v_c_medicazione, NULL, 'Pellicole barriera (box 300)', 'Copertura superfici riunito tra pazienti.', 'MED-BARRIER', 'box', 2, 4, 12.00),
                    (v_clinic_id, v_c_medicazione, NULL, 'Salviette disinfettanti riunito (wipes, box 150)', 'Disinfezione superfici tra pazienti.', 'MED-WIPES', 'box', 3, 6, 9.50),
                    (v_clinic_id, v_c_medicazione, NULL, 'Pasta profilattica fluorurata (coppetta monouso)', 'Lucidatura e profilassi (IGI-001/002). Gusto menta.', 'IGI-PASTA', 'coppetta', 20, 50, 0.60),
                    (v_clinic_id, v_c_medicazione, NULL, 'Strisce di cellulosa Cottonoid (box 250)', 'Isolamento in conservativa e endodonzia.', 'MED-COTTON', 'box', 3, 6, 8.00);

                -- Strumentario
                INSERT INTO dentalcare.products (clinic_id, category_id, supplier_id, name, description, sku, unit, min_stock_quantity, reorder_quantity, unit_cost) VALUES
                    (v_clinic_id, v_c_strumentario, NULL, 'Frese diamantate cilindriche assortite (set 12)', 'Preparazione cavita, rifinitura margini (CONS-*, PROT-*).', 'STRUM-FRD-CIL', 'set', 3, 6, 28.00),
                    (v_clinic_id, v_c_strumentario, NULL, 'Frese diamantate a fiamma assortite (set 6)', 'Preparazione conicita per corone (PROT-001/002).', 'STRUM-FRD-FIA', 'set', 3, 6, 22.00),
                    (v_clinic_id, v_c_strumentario, NULL, 'Frese al carburo tungsteno turbina (set 10)', 'Rimozione carie, preparazioni conservative.', 'STRUM-FRC-TRB', 'set', 3, 6, 18.00),
                    (v_clinic_id, v_c_strumentario, v_s_dentsply, 'Punte ultrasuoni per detartrasi (set 5)', 'Ablazione tartaro (IGI-001/002), levigatura radicolare (PAR-001).', 'STRUM-ULTRA', 'set', 2, 4, 45.00),
                    (v_clinic_id, v_c_strumentario, NULL, 'Specchietti monouso (box 25)', 'Esame clinico e retroilluminazione. Monouso sterili.', 'STRUM-SPEC', 'box', 3, 6, 18.00),
                    (v_clinic_id, v_c_strumentario, NULL, 'Sonde parodontali monouso (box 25)', 'Rilevazione profondita tasche (PAR-*). Box 25 pz.', 'STRUM-SONDA', 'box', 2, 4, 22.00);

                -- Stock iniziale
                INSERT INTO dentalcare.stock_movements (clinic_id, product_id, movement_type, quantity, notes)
                SELECT clinic_id, id,
                       'carico'::dentalcare.stock_movement_type,
                       CASE WHEN unit IN ('carpule','pz','busta','coppetta') THEN reorder_quantity * 2
                            ELSE reorder_quantity END,
                       'Stock iniziale'
                FROM dentalcare.products
                WHERE clinic_id = v_clinic_id;

                END LOOP;
            END $$
            """);
    }

    private void applyRecallSchema() {
        // ENUMs
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.recall_status AS ENUM
                    ('da_contattare','contattato','in_attesa','confermato','chiuso','annullato');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.recall_priority AS ENUM ('alta','media','bassa');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.recall_contact_type AS ENUM
                    ('telefono','sms','email','whatsapp');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);
        jdbc.execute("""
            DO $$ BEGIN
                CREATE TYPE dentalcare.recall_outcome AS ENUM
                    ('risposto','non_risposto','messaggio_lasciato','confermato','rifiutato');
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // patient_recalls table
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.patient_recalls (
                id                      uuid                        PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id               uuid                        NOT NULL REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                patient_id              uuid                        NOT NULL,
                recall_type             text                        NOT NULL DEFAULT 'Controllo periodico',
                due_date                date                        NOT NULL,
                status                  dentalcare.recall_status    NOT NULL DEFAULT 'da_contattare',
                priority                dentalcare.recall_priority  NOT NULL DEFAULT 'media',
                notes                   text,
                source_appointment_id   uuid,
                booked_appointment_id   uuid,
                last_contact_at         date,
                contact_count           integer                     NOT NULL DEFAULT 0,
                created_at              timestamptz                 NOT NULL DEFAULT now(),
                updated_at              timestamptz                 NOT NULL DEFAULT now(),
                CONSTRAINT patient_recalls_unique_per_clinic UNIQUE (id, clinic_id)
            )
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.patient_recalls ADD CONSTRAINT fk_recalls_patient
                    FOREIGN KEY (patient_id, clinic_id)
                    REFERENCES dentalcare.patients(id, clinic_id)
                    ON DELETE CASCADE;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.patient_recalls ADD CONSTRAINT fk_recalls_source_apt
                    FOREIGN KEY (source_appointment_id)
                    REFERENCES dentalcare.appointments(id)
                    ON DELETE SET NULL;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.patient_recalls ADD CONSTRAINT fk_recalls_booked_apt
                    FOREIGN KEY (booked_appointment_id)
                    REFERENCES dentalcare.appointments(id)
                    ON DELETE SET NULL;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // recall_contacts table
        jdbc.execute("""
            CREATE TABLE IF NOT EXISTS dentalcare.recall_contacts (
                id                      uuid                            PRIMARY KEY DEFAULT gen_random_uuid(),
                clinic_id               uuid                            NOT NULL REFERENCES dentalcare.clinics(id) ON DELETE RESTRICT,
                recall_id               uuid                            NOT NULL,
                contact_type            dentalcare.recall_contact_type  NOT NULL DEFAULT 'telefono',
                contact_at              timestamptz                     NOT NULL DEFAULT now(),
                outcome                 dentalcare.recall_outcome       NOT NULL,
                notes                   text,
                created_by_provider_id  uuid,
                created_at              timestamptz                     NOT NULL DEFAULT now(),
                CONSTRAINT recall_contacts_unique_per_clinic UNIQUE (id, clinic_id)
            )
            """);

        jdbc.execute("""
            DO $$ BEGIN
                ALTER TABLE dentalcare.recall_contacts ADD CONSTRAINT fk_recall_contacts_recall
                    FOREIGN KEY (recall_id, clinic_id)
                    REFERENCES dentalcare.patient_recalls(id, clinic_id)
                    ON DELETE CASCADE;
            EXCEPTION WHEN duplicate_object THEN NULL; END $$
            """);

        // indexes
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_recalls_clinic_status ON dentalcare.patient_recalls(clinic_id, status, due_date)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_recalls_patient ON dentalcare.patient_recalls(clinic_id, patient_id)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_recalls_due_date ON dentalcare.patient_recalls(clinic_id, due_date)");
        jdbc.execute("CREATE INDEX IF NOT EXISTS ix_recall_contacts_recall ON dentalcare.recall_contacts(recall_id, contact_at DESC)");

        // compute_recall_priority function (STABLE — uses current_date)
        jdbc.execute("""
            CREATE OR REPLACE FUNCTION dentalcare.compute_recall_priority(p_due_date date)
            RETURNS dentalcare.recall_priority
            LANGUAGE plpgsql STABLE
            AS $$
            BEGIN
                IF p_due_date < current_date THEN
                    RETURN 'alta'::dentalcare.recall_priority;
                ELSIF p_due_date <= current_date + interval '30 days' THEN
                    RETURN 'media'::dentalcare.recall_priority;
                ELSE
                    RETURN 'bassa'::dentalcare.recall_priority;
                END IF;
            END;
            $$
            """);

        // update_recall_on_contact trigger function
        jdbc.execute("""
            CREATE OR REPLACE FUNCTION dentalcare.update_recall_on_contact()
            RETURNS trigger
            LANGUAGE plpgsql
            AS $$
            BEGIN
                UPDATE dentalcare.patient_recalls
                SET contact_count   = contact_count + 1,
                    last_contact_at = NEW.contact_at::date,
                    status          = CASE
                                        WHEN NEW.outcome::text = 'confermato' THEN 'confermato'::dentalcare.recall_status
                                        WHEN status::text = 'da_contattare'   THEN 'contattato'::dentalcare.recall_status
                                        ELSE status
                                      END,
                    updated_at      = now()
                WHERE id = NEW.recall_id;
                RETURN NEW;
            END;
            $$
            """);

        jdbc.execute("DROP TRIGGER IF EXISTS trg_recall_contact_update ON dentalcare.recall_contacts");
        jdbc.execute("""
            CREATE TRIGGER trg_recall_contact_update
            AFTER INSERT ON dentalcare.recall_contacts
            FOR EACH ROW EXECUTE FUNCTION dentalcare.update_recall_on_contact()
            """);

        // updated_at trigger on patient_recalls
        jdbc.execute("DROP TRIGGER IF EXISTS trg_recalls_updated_at ON dentalcare.patient_recalls");
        jdbc.execute("""
            CREATE TRIGGER trg_recalls_updated_at
            BEFORE UPDATE ON dentalcare.patient_recalls
            FOR EACH ROW EXECUTE FUNCTION set_updated_at()
            """);
    }
}
