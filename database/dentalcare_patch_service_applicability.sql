-- Patch: service applicability by tooth position
-- min/max_tooth_digit = second digit of FDI (1=incisor .. 8=wisdom)
-- NULL = no restriction on that bound
-- applicable_to_deciduous = false for permanent-only procedures

SET search_path TO dentalcare, public;

ALTER TABLE service_catalog
  ADD COLUMN IF NOT EXISTS min_tooth_digit      integer,
  ADD COLUMN IF NOT EXISTS max_tooth_digit      integer,
  ADD COLUMN IF NOT EXISTS applicable_to_deciduous boolean NOT NULL DEFAULT true;

-- ── Chirurgia ──────────────────────────────────────────────────────────────
-- Estrazione semplice / complessa / rimozione punti / frenulectomia → all teeth
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Chirurgia'
    AND name NOT ILIKE '%ottavo%';

-- Estrazione ottavo incluso → wisdom tooth only (digit 8)
UPDATE service_catalog SET min_tooth_digit = 8, max_tooth_digit = 8, applicable_to_deciduous = false
  WHERE category = 'Chirurgia' AND name ILIKE '%ottavo%';

-- ── Conservativa ───────────────────────────────────────────────────────────
-- Otturazione composito (mono/bi/tri) → all teeth
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Conservativa'
    AND name ILIKE '%otturazione%';

-- Ricostruzione estetica anteriore → anterior only (digits 1-3)
UPDATE service_catalog SET min_tooth_digit = 1, max_tooth_digit = 3, applicable_to_deciduous = false
  WHERE category = 'Conservativa' AND name ILIKE '%anteriore%';

-- ── Diagnostica ────────────────────────────────────────────────────────────
-- All diagnostics → no tooth restriction (arch/patient level)
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Diagnostica';

-- ── Endodonzia ─────────────────────────────────────────────────────────────
-- Monoradicolare → anterior + premolars (digits 1-5)
UPDATE service_catalog SET min_tooth_digit = 1, max_tooth_digit = 5, applicable_to_deciduous = true
  WHERE category = 'Endodonzia' AND name ILIKE '%mono%';

-- Biradicolare → premolars + first molar (digits 4-6)
UPDATE service_catalog SET min_tooth_digit = 4, max_tooth_digit = 6, applicable_to_deciduous = false
  WHERE category = 'Endodonzia' AND name ILIKE '%bi%';

-- Pluriradicolare → molars (digits 6-8)
UPDATE service_catalog SET min_tooth_digit = 6, max_tooth_digit = 8, applicable_to_deciduous = false
  WHERE category = 'Endodonzia' AND name ILIKE '%pluri%';

-- Ritrattamento canalare → all permanent teeth
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Endodonzia' AND name ILIKE '%ritrattamento%';

-- ── Estetica ───────────────────────────────────────────────────────────────
-- Sbiancamento → anterior preferred but applied to all present visible teeth
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Estetica';

-- ── Gnatologia ─────────────────────────────────────────────────────────────
-- Bite → arch-level, no tooth restriction
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Gnatologia';

-- ── Igiene ─────────────────────────────────────────────────────────────────
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Igiene';

-- ── Implantologia ──────────────────────────────────────────────────────────
-- All implant procedures → permanent only, no deciduous
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Implantologia';

-- ── Ortodontia ─────────────────────────────────────────────────────────────
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Ortodontia';

-- ── Parodontologia ─────────────────────────────────────────────────────────
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Parodontologia';

-- ── Pedodonzia ─────────────────────────────────────────────────────────────
-- Otturazione deciduo → deciduous only (no digit restriction within deciduous)
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Pedodonzia' AND name ILIKE '%deciduo%';

-- Sigillatura solchi → posterior only (digits 4-8), permanent + deciduous molars
UPDATE service_catalog SET min_tooth_digit = 4, max_tooth_digit = 8, applicable_to_deciduous = true
  WHERE category = 'Pedodonzia' AND name ILIKE '%sigillatura%';

-- ── Protesi ────────────────────────────────────────────────────────────────
-- Faccetta → anterior only (digits 1-3), permanent
UPDATE service_catalog SET min_tooth_digit = 1, max_tooth_digit = 3, applicable_to_deciduous = false
  WHERE category = 'Protesi' AND name ILIKE '%faccetta%';

-- Intarsio → posterior (digits 4-8), permanent
UPDATE service_catalog SET min_tooth_digit = 4, max_tooth_digit = 8, applicable_to_deciduous = false
  WHERE category = 'Protesi' AND name ILIKE '%intarsio%';

-- Corone → all permanent teeth
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Protesi' AND name ILIKE '%corona%';

-- Protesi mobile / totale → arch-level, permanent
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = false
  WHERE category = 'Protesi' AND name ILIKE '%protesi%';

-- ── Urgenza ────────────────────────────────────────────────────────────────
UPDATE service_catalog SET min_tooth_digit = NULL, max_tooth_digit = NULL, applicable_to_deciduous = true
  WHERE category = 'Urgenza';

-- Verify
SELECT category, name, min_tooth_digit, max_tooth_digit, applicable_to_deciduous
FROM service_catalog
WHERE clinic_id = (SELECT id FROM clinics LIMIT 1)
ORDER BY category, name;
