-- seed_demo_superuser.sql
-- Creates (or updates) a demo "superuser" provider in the dev tenant.
--
-- Target tenant schema: t_9d754153
-- New provider:
--   email:    demo@demo.dentalcare.it
--   role:     'admin'
--   name:     Demo Tutto
--   active:   true, password_temporary: false
--   password_hash: copied from existing admin@demo.dentalcare.it provider
--                  (same BCrypt hash -> password 'DemoAdmin1!' verifies)
--   clinic_id:     same as admin@demo's clinic_id
--
-- Idempotent: email has no unique constraint, so we guard with NOT EXISTS on
-- insert and UPDATE on the already-present case. Safe to re-run.

SET search_path TO dentalcare, public;

-- 1. Ensure 'admin' exists in the enum (no-op if already present; it is, per V20).
--    ALTER TYPE ... ADD VALUE cannot run inside the same tx as its later use,
--    so it lives in its own statement-level DO block before the DML.
DO $$ BEGIN
    ALTER TYPE dentalcare.provider_role ADD VALUE IF NOT EXISTS 'admin';
EXCEPTION WHEN others THEN NULL;
END $$;

-- 2. Insert the demo provider only if it does not already exist in this tenant.
INSERT INTO t_9d754153.providers (
    id, clinic_id, first_name, last_name, role,
    active, email, password_hash, password_temporary
)
SELECT
    gen_random_uuid(),
    src.clinic_id,
    'Demo',
    'Tutto',
    'admin'::dentalcare.provider_role,
    true,
    'demo@demo.dentalcare.it',
    src.password_hash,
    false
FROM t_9d754153.providers src
WHERE src.email = 'admin@demo.dentalcare.it'
  AND NOT EXISTS (
        SELECT 1 FROM t_9d754153.providers p
        WHERE p.email = 'demo@demo.dentalcare.it'
    );

-- 3. If the demo provider already existed, refresh role/active/password/clinic
--    from the current admin@demo source so re-runs converge to the same state.
UPDATE t_9d754153.providers d
SET role               = 'admin'::dentalcare.provider_role,
    active             = true,
    password_temporary = false,
    first_name         = 'Demo',
    last_name          = 'Tutto',
    clinic_id          = src.clinic_id,
    password_hash      = src.password_hash,
    updated_at         = now()
FROM t_9d754153.providers src
WHERE d.email   = 'demo@demo.dentalcare.it'
  AND src.email = 'admin@demo.dentalcare.it';

-- 4. Verification.
SELECT id, email, role, active, password_temporary, clinic_id
FROM t_9d754153.providers
WHERE email = 'demo@demo.dentalcare.it';
