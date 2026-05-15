-- Patch: condition_service_defaults
-- Per ogni condizione odontogramma, definisce le prestazioni suggerite di default
-- quando si genera un piano di cura dall'odontogramma.
SET search_path TO dentalcare, public;

-- Aggiungi "Pontile in ceramica" se mancante (necessario per bridge_pontic)
INSERT INTO service_catalog (id, clinic_id, code, name, category, default_price, duration_minutes, active,
                              min_tooth_digit, max_tooth_digit, applicable_to_deciduous)
SELECT gen_random_uuid(), c.id, 'PROT-PONT', 'Pontile in ceramica', 'Protesi',
       750.00, 60, true, NULL, NULL, false
FROM clinics c
WHERE NOT EXISTS (
    SELECT 1 FROM service_catalog sc
    WHERE sc.clinic_id = c.id AND sc.name = 'Pontile in ceramica'
);

-- ── Tabella condition_service_defaults ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS condition_service_defaults (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id        uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    condition_name   text NOT NULL,
    service_id       uuid NOT NULL REFERENCES service_catalog(id) ON DELETE CASCADE,
    sort_order       integer NOT NULL DEFAULT 10,
    CONSTRAINT uq_condition_default UNIQUE (clinic_id, condition_name, service_id)
);

CREATE INDEX IF NOT EXISTS ix_condition_service_defaults_cond
    ON condition_service_defaults (clinic_id, condition_name);

-- ── Seed defaults per condizione ─────────────────────────────────────────────
INSERT INTO condition_service_defaults (id, clinic_id, condition_name, service_id, sort_order)
SELECT gen_random_uuid(), sc.clinic_id, d.condition_name, sc.id, d.sort_order
FROM (VALUES
    -- Carie → otturazione monofacciale (caso più comune)
    ('cavity',        'Otturazione composito monofacciale',    10),

    -- Da estrarre → estrazione semplice + rimozione punti
    ('to_extract',    'Estrazione semplice',                   10),
    ('to_extract',    'Rimozione punti',                       20),

    -- Devitalizzato (da ritrattare) → ritrattamento + RX
    ('root_canal',    'Ritrattamento canalare',                10),
    ('root_canal',    'Radiografia endorale',                  20),

    -- Mancante → impianto completo (CBCT + fixture + moncone + corona)
    ('missing',       'CBCT arcata singola',                   10),
    ('missing',       'Impianto osteointegrato',               20),
    ('missing',       'Moncone implantare',                    30),
    ('missing',       'Corona su impianto',                    40),

    -- Bridge pilastro → corona (pilastro di ponte)
    ('bridge_pillar', 'Corona in zirconia',                    10),

    -- Bridge pontile → pontile in ceramica
    ('bridge_pontic', 'Pontile in ceramica',                   10),

    -- Corona da rifare → corona in zirconia
    ('crown',         'Corona in zirconia',                    10),

    -- Impianto già presente, serve completamento → moncone + corona
    ('implant',       'Moncone implantare',                    10),
    ('implant',       'Corona su impianto',                    20)
) AS d(condition_name, service_name, sort_order)
JOIN service_catalog sc ON sc.name = d.service_name AND sc.active = true
ON CONFLICT (clinic_id, condition_name, service_id) DO NOTHING;

-- Verify
SELECT condition_name, sc.name AS service, csd.sort_order
FROM condition_service_defaults csd
JOIN service_catalog sc ON sc.id = csd.service_id
WHERE csd.clinic_id = (SELECT id FROM clinics LIMIT 1)
ORDER BY condition_name, csd.sort_order;
