-- V8: Inventory tables + patch v_patient_estimates_summary + missing indexes
-- Flyway migration — incremental, idempotent where possible

SET search_path TO dentalcare, public;

-- =========================================================
-- 1. PATCH v_patient_estimates_summary: add created_by_provider_id
-- =========================================================

CREATE OR REPLACE VIEW v_patient_estimates_summary AS
WITH line_agg AS (
    SELECT
        clinic_id,
        estimate_id,
        COUNT(*) AS estimate_lines_count
    FROM estimate_lines
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
FROM clinics c
JOIN patients p
  ON p.clinic_id = c.id
JOIN estimates e
  ON e.patient_id = p.id
 AND e.clinic_id = p.clinic_id
LEFT JOIN treatment_plans tp
  ON tp.id = e.treatment_plan_id
 AND tp.clinic_id = e.clinic_id
LEFT JOIN line_agg la
  ON la.estimate_id = e.id
 AND la.clinic_id = e.clinic_id;

-- =========================================================
-- 2. Missing indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS ix_invoices_provider
    ON invoices(clinic_id, provider_id)
    WHERE provider_id IS NOT NULL;

-- =========================================================
-- 3a. suppliers
-- =========================================================

CREATE TABLE IF NOT EXISTS suppliers (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id       uuid        NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    name            text        NOT NULL,
    contact_person  text,
    phone           text,
    email           text,
    notes           text,
    is_active       boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, clinic_id)
);

-- =========================================================
-- 3b. product_categories
-- =========================================================

CREATE TABLE IF NOT EXISTS product_categories (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id   uuid    NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    name        text    NOT NULL,
    UNIQUE (id, clinic_id),
    UNIQUE (clinic_id, name)
);

-- =========================================================
-- 3c. stock_movement_type ENUM
-- =========================================================

DO $$ BEGIN
    CREATE TYPE stock_movement_type AS ENUM ('carico', 'scarico', 'rettifica', 'rientro');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================
-- 3d. products
-- =========================================================

CREATE TABLE IF NOT EXISTS products (
    id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id           uuid          NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
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
);

-- FK: products -> product_categories (composite, nullable category_id)
-- PostgreSQL skips FK check when any part of the composite key is NULL — safe.
ALTER TABLE products
    DROP CONSTRAINT IF EXISTS fk_products_category;
ALTER TABLE products
    ADD CONSTRAINT fk_products_category
        FOREIGN KEY (category_id, clinic_id)
        REFERENCES product_categories(id, clinic_id)
        ON DELETE SET NULL;

-- FK: products -> suppliers (composite, nullable supplier_id)
ALTER TABLE products
    DROP CONSTRAINT IF EXISTS fk_products_supplier;
ALTER TABLE products
    ADD CONSTRAINT fk_products_supplier
        FOREIGN KEY (supplier_id, clinic_id)
        REFERENCES suppliers(id, clinic_id)
        ON DELETE SET NULL;

-- =========================================================
-- 3e. stock_movements
-- =========================================================

CREATE TABLE IF NOT EXISTS stock_movements (
    id                      uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id               uuid                  NOT NULL REFERENCES clinics(id) ON DELETE RESTRICT,
    product_id              uuid                  NOT NULL,
    movement_type           stock_movement_type   NOT NULL,
    quantity                numeric(10,2)         NOT NULL,
    unit_cost               numeric(12,2),
    notes                   text,
    reference_doc           text,
    created_by_provider_id  uuid,
    created_at              timestamptz           NOT NULL DEFAULT now(),
    UNIQUE (id, clinic_id)
);

-- FK: stock_movements -> products (composite)
ALTER TABLE stock_movements
    DROP CONSTRAINT IF EXISTS fk_stock_movements_product;
ALTER TABLE stock_movements
    ADD CONSTRAINT fk_stock_movements_product
        FOREIGN KEY (product_id, clinic_id)
        REFERENCES products(id, clinic_id)
        ON DELETE RESTRICT;

-- =========================================================
-- 3f. product_stock_v VIEW
-- =========================================================

CREATE OR REPLACE VIEW product_stock_v AS
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
FROM products p
LEFT JOIN product_categories pc ON pc.id = p.category_id AND pc.clinic_id = p.clinic_id
LEFT JOIN suppliers s ON s.id = p.supplier_id AND s.clinic_id = p.clinic_id
LEFT JOIN stock_movements m ON m.product_id = p.id AND m.clinic_id = p.clinic_id
GROUP BY p.id, p.clinic_id, p.name, p.sku, p.unit, p.min_stock_quantity,
         p.reorder_quantity, p.unit_cost, p.is_active, p.category_id, pc.name,
         p.supplier_id, s.name, p.description, p.created_at, p.updated_at;

-- =========================================================
-- 3g. Indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS ix_products_clinic
    ON products(clinic_id) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS ix_products_category
    ON products(clinic_id, category_id);

CREATE INDEX IF NOT EXISTS ix_stock_movements_product
    ON stock_movements(clinic_id, product_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_suppliers_clinic
    ON suppliers(clinic_id) WHERE is_active = true;

-- =========================================================
-- 3h. updated_at triggers
-- =========================================================

DROP TRIGGER IF EXISTS trg_suppliers_updated_at ON suppliers;
CREATE TRIGGER trg_suppliers_updated_at
BEFORE UPDATE ON suppliers FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =========================================================
-- 3i. Seed default product_categories for default clinic
-- =========================================================

DO $$
DECLARE v_clinic_id uuid;
BEGIN
    SELECT id INTO v_clinic_id FROM dentalcare.clinics LIMIT 1;
    IF v_clinic_id IS NOT NULL THEN
        INSERT INTO dentalcare.product_categories(clinic_id, name)
        VALUES
            (v_clinic_id, 'Farmaci'),
            (v_clinic_id, 'Materiali'),
            (v_clinic_id, 'DPI'),
            (v_clinic_id, 'Chirurgia'),
            (v_clinic_id, 'Medicazione'),
            (v_clinic_id, 'Strumentario')
        ON CONFLICT (clinic_id, name) DO NOTHING;
    END IF;
END $$;

-- =========================================================
-- Verify
-- =========================================================

SELECT
    (SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema = 'dentalcare'
       AND table_name IN ('suppliers', 'product_categories', 'products', 'stock_movements'))      AS inventory_tables,
    (SELECT COUNT(*) FROM information_schema.views
     WHERE table_schema = 'dentalcare'
       AND table_name IN ('v_patient_estimates_summary', 'product_stock_v'))                      AS views,
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = 'dentalcare'
       AND table_name = 'v_patient_estimates_summary'
       AND column_name = 'created_by_provider_id')                                                AS summary_has_provider_col,
    (SELECT COUNT(*) FROM dentalcare.product_categories)                                          AS seeded_categories;
