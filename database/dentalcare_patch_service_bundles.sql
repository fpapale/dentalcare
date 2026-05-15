-- Patch: service bundle items
-- Definisce le sotto-prestazioni suggerite automaticamente per ogni prestazione principale
SET search_path TO dentalcare, public;

CREATE TABLE IF NOT EXISTS service_bundle_items (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clinic_id         uuid NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    parent_service_id uuid NOT NULL,
    child_service_id  uuid NOT NULL,
    sort_order        integer NOT NULL DEFAULT 10,
    CONSTRAINT fk_bundle_parent  FOREIGN KEY (parent_service_id) REFERENCES service_catalog(id) ON DELETE CASCADE,
    CONSTRAINT fk_bundle_child   FOREIGN KEY (child_service_id)  REFERENCES service_catalog(id) ON DELETE CASCADE,
    CONSTRAINT uq_bundle_item    UNIQUE (clinic_id, parent_service_id, child_service_id)
);

CREATE INDEX IF NOT EXISTS ix_service_bundle_parent
    ON service_bundle_items (clinic_id, parent_service_id);

-- ── Seed bundle rules (per ogni clinica) ─────────────────────────────────────
INSERT INTO service_bundle_items (id, clinic_id, parent_service_id, child_service_id, sort_order)
SELECT
    gen_random_uuid(),
    p.clinic_id,
    p.id,
    c.id,
    b.sort_order
FROM (VALUES
    -- Chirurgia: estrazione → rimozione punti
    ('Estrazione semplice',               'Rimozione punti',                      10),
    ('Estrazione complessa',              'Rimozione punti',                      10),
    ('Estrazione ottavo incluso',         'Rimozione punti',                      10),
    -- Endodonzia: devitalizzazione → RX endorale + otturazione
    ('Devitalizzazione monoradicolare',   'Radiografia endorale',                 10),
    ('Devitalizzazione monoradicolare',   'Otturazione composito monofacciale',   20),
    ('Devitalizzazione biradicolare',     'Radiografia endorale',                 10),
    ('Devitalizzazione biradicolare',     'Otturazione composito bifacciale',     20),
    ('Devitalizzazione pluriradicolare',  'Radiografia endorale',                 10),
    ('Devitalizzazione pluriradicolare',  'Otturazione composito bifacciale',     20),
    ('Ritrattamento canalare',            'Radiografia endorale',                 10),
    -- Implantologia: impianto → CBCT + moncone + corona
    ('Impianto osteointegrato',           'CBCT arcata singola',                  10),
    ('Impianto osteointegrato',           'Moncone implantare',                   20),
    ('Impianto osteointegrato',           'Corona su impianto',                   30),
    -- Parodontologia: levigatura → mantenimento
    ('Levigatura radicolare per quadrante', 'Terapia parodontale di mantenimento', 10),
    -- Igiene profonda → fluoroprofilassi
    ('Igiene orale profonda',             'Fluoroprofilassi',                     10)
) AS b(parent_name, child_name, sort_order)
JOIN service_catalog p ON p.name = b.parent_name AND p.active = true
JOIN service_catalog c ON c.name = b.child_name  AND c.clinic_id = p.clinic_id AND c.active = true
ON CONFLICT (clinic_id, parent_service_id, child_service_id) DO NOTHING;

-- Verify
SELECT
    p.name  AS parent,
    c.name  AS child,
    sbi.sort_order
FROM service_bundle_items sbi
JOIN service_catalog p ON p.id = sbi.parent_service_id
JOIN service_catalog c ON c.id = sbi.child_service_id
WHERE sbi.clinic_id = (SELECT id FROM clinics LIMIT 1)
ORDER BY p.name, sbi.sort_order;
