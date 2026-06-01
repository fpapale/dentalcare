-- seed_appointments_jun_jul_2026.sql
-- Seeds realistic, conflict-free appointments into t_9d754153.appointments
-- for the range 2026-06-02 .. 2026-07-31 (today is 2026-06-01).
--
-- Tenant schema: t_9d754153
-- clinic_id:     9d754153-6579-4b7e-a56b-025f00299cd9
--
-- CONFLICT-FREE DESIGN
--   Each medical provider is bound to ITS OWN chair and works a fixed list of
--   non-overlapping daily slots. Therefore:
--     * a provider never overlaps itself (slots are disjoint, one row per slot/day);
--     * a chair never has two appointments (each chair belongs to exactly one
--       provider, and that provider has one row per slot).
--   This trivially satisfies the app's chair/provider overlap checks.
--
--   Providers (active medical only) -> chair:
--     b1...001 dentist      -> Studio 1
--     b1...002 surgeon      -> Studio 2
--     b1...003 orthodontist -> Studio 3
--     b1...004 hygienist    -> Studio 4
--
--   Daily slots (Europe/Rome local, CEST = +02 in Jun/Jul), lunch 13-14 skipped:
--     09:00-10:00, 10:00-11:00, 11:00-12:00, 12:00-12:30,
--     14:00-15:00, 15:00-16:00, 16:00-17:00, 17:00-17:30
--   = 8 slots per provider per day, 4 providers => up to 32 rows/day.
--   To keep volume "realistic but not huge" (~4-8/day overall feel per the
--   request) we DROP some slots via a modulo rotation: each (provider, slot,
--   day) is kept only on a rotating subset, giving roughly a few hundred rows.
--
-- WEEKDAYS only (skip Sat/Sun). Holidays in range: 2026-06-02 Festa della
--   Repubblica is skipped explicitly (no other national holiday Jun3-Jul31).
--
-- Idempotent & coexisting: each candidate has a CORRELATED NOT EXISTS guard
--   mirroring the backend chair/provider half-open overlap check. A candidate
--   is inserted only if it does not clash with an existing (non-cancelled)
--   appointment on the same chair OR same provider. So new rows fill around
--   the pre-existing demo appointments, and re-runs skip exact/overlapping
--   duplicates (no all-or-nothing global guard).

SET search_path TO dentalcare, public;

-- Sanity: confirm appointment_status enum has 'scheduled' (informational).
-- SELECT enumlabel FROM pg_enum e
--   JOIN pg_type t ON t.oid = e.enumtypid
--   WHERE t.typname = 'appointment_status';

WITH
-- All candidate working days in range.
days AS (
    SELECT d::date AS day
    FROM generate_series(DATE '2026-06-02', DATE '2026-07-31', INTERVAL '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) < 6        -- Mon..Fri only
      AND d::date <> DATE '2026-06-02'      -- Festa della Repubblica
),
-- Provider bound to its own chair, with a rotation offset for thinning slots.
providers AS (
    SELECT * FROM (VALUES
        ('b1000001-0000-0000-0000-000000000001'::uuid, 'Studio 1', 0),
        ('b1000001-0000-0000-0000-000000000002'::uuid, 'Studio 2', 1),
        ('b1000001-0000-0000-0000-000000000003'::uuid, 'Studio 3', 2),
        ('b1000001-0000-0000-0000-000000000004'::uuid, 'Studio 4', 3)
    ) AS p(provider_id, chair_label, prov_off)
),
-- Daily slots: start time + duration in minutes, indexed for rotation.
slots AS (
    SELECT * FROM (VALUES
        (0, TIME '09:00', 60, 'Visita di controllo'),
        (1, TIME '10:00', 60, 'Igiene e pulizia'),
        (2, TIME '11:00', 60, 'Trattamento conservativo'),
        (3, TIME '12:00', 30, 'Consulto'),
        (4, TIME '14:00', 60, 'Trattamento'),
        (5, TIME '15:00', 60, 'Controllo periodico'),
        (6, TIME '16:00', 60, 'Visita'),
        (7, TIME '17:00', 30, 'Consulto rapido')
    ) AS s(slot_idx, start_t, dur_min, service_note)
),
-- Existing patients in this tenant, rotated deterministically.
pat AS (
    SELECT id AS patient_id,
           row_number() OVER (ORDER BY id) - 1 AS pat_idx,
           count(*) OVER ()                    AS pat_count
    FROM t_9d754153.patients
),
-- Cross-join days x providers x slots, then THIN with a modulo so each
-- provider keeps ~half its slots on a given day (rotating by day + offset).
-- day_num = days since range start, used to rotate which slots survive.
candidates AS (
    SELECT
        d.day,
        p.provider_id,
        p.chair_label,
        s.start_t,
        s.dur_min,
        s.service_note,
        (d.day - DATE '2026-06-02') AS day_num,
        s.slot_idx,
        p.prov_off,
        row_number() OVER (ORDER BY d.day, p.provider_id, s.slot_idx) - 1 AS seq
    FROM days d
    CROSS JOIN providers p
    CROSS JOIN slots s
    -- Keep a slot only when (slot_idx + day_num + prov_off) is even => ~4 slots
    -- per provider per day, ~16 rows/day, ~ a few hundred over the range.
    WHERE ((s.slot_idx + (d.day - DATE '2026-06-02') + p.prov_off) % 2) = 0
),
-- Attach a rotating patient and materialise the absolute starts_at/ends_at
-- instants as columns, so the correlated guard below can reference them.
-- AT TIME ZONE turns the Europe/Rome wall-clock into the right UTC instant
-- (handles +02 CEST in June/July).
final AS (
    SELECT
        c.day,
        c.provider_id,
        c.chair_label,
        c.service_note,
        pt.patient_id,
        ((c.day + c.start_t) AT TIME ZONE 'Europe/Rome')                                AS starts_at,
        ((c.day + c.start_t + make_interval(mins => c.dur_min)) AT TIME ZONE 'Europe/Rome') AS ends_at
    FROM candidates c
    CROSS JOIN LATERAL (
        SELECT patient_id
        FROM pat
        WHERE pat.pat_idx = c.seq % NULLIF(pat.pat_count, 0)
        LIMIT 1
    ) pt
)
INSERT INTO t_9d754153.appointments (
    id, clinic_id, patient_id, provider_id, treatment_plan_item_id,
    chair_label, starts_at, ends_at, status, notes,
    cancellation_reason, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid,
    f.patient_id,
    f.provider_id,
    NULL,                                   -- treatment_plan_item_id
    f.chair_label,
    f.starts_at,
    f.ends_at,
    'scheduled'::dentalcare.appointment_status,
    f.service_note,
    NULL,                                   -- cancellation_reason
    now(),
    now()
FROM final f
-- Correlated guard: skip a candidate only if it would clash with an existing
-- (non-cancelled) appointment on the SAME chair OR the SAME provider, using the
-- backend's half-open overlap test (starts_at < E AND ends_at > S). New rows
-- thus fill around pre-existing demo appointments, and re-runs skip dupes.
WHERE NOT EXISTS (
    SELECT 1
    FROM t_9d754153.appointments a
    WHERE a.clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
      AND a.status::text <> 'cancelled'
      AND (a.chair_label = f.chair_label OR a.provider_id = f.provider_id)
      AND a.starts_at < f.ends_at
      AND a.ends_at   > f.starts_at
);

-- Verification: total seeded + per-day sample.
SELECT count(*) AS total_seeded
FROM t_9d754153.appointments
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
  AND starts_at >= (DATE '2026-06-02' AT TIME ZONE 'Europe/Rome')
  AND starts_at <  (DATE '2026-08-01' AT TIME ZONE 'Europe/Rome');

SELECT (starts_at AT TIME ZONE 'Europe/Rome')::date AS day,
       count(*) AS appts,
       count(DISTINCT provider_id) AS providers,
       count(DISTINCT chair_label) AS chairs
FROM t_9d754153.appointments
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'::uuid
  AND starts_at >= (DATE '2026-06-02' AT TIME ZONE 'Europe/Rome')
  AND starts_at <  (DATE '2026-08-01' AT TIME ZONE 'Europe/Rome')
GROUP BY 1
ORDER BY 1
LIMIT 40;
