-- Seed flyway_schema_history so Flyway treats V1–V11 as already applied.
-- Run ONCE on the live DB (dentalcarepro) from a psql session.
-- After this, flyway.repair() will update checksums; flyway.migrate() will be a no-op.

SET search_path TO dentalcare, public;

-- Create the Flyway history table if missing (Flyway normally creates it)
CREATE TABLE IF NOT EXISTS flyway_schema_history (
    installed_rank INTEGER NOT NULL,
    version        VARCHAR(50),
    description    VARCHAR(200) NOT NULL,
    type           VARCHAR(20)  NOT NULL,
    script         VARCHAR(1000) NOT NULL,
    checksum       INTEGER,
    installed_by   VARCHAR(100) NOT NULL,
    installed_on   TIMESTAMP    NOT NULL DEFAULT now(),
    execution_time INTEGER      NOT NULL,
    success        BOOLEAN      NOT NULL,
    CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank)
);

CREATE INDEX IF NOT EXISTS flyway_schema_history_s_idx
    ON flyway_schema_history (success);

-- Insert records for V1–V11 (checksum=0 — flyway.repair() will recompute)
INSERT INTO flyway_schema_history
    (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success)
VALUES
    (1,  '1',  'init schema',                 'SQL',      'V1__init_schema.sql',                      0, 'postgres', 100, true),
    (2,  '2',  'tooth conditions',             'SQL',      'V2__tooth_conditions.sql',                 0, 'postgres', 100, true),
    (3,  '3',  'geo holidays',                 'SQL',      'V3__geo_holidays.sql',                     0, 'postgres', 100, true),
    (4,  '4',  'service duration',             'BASELINE', 'V4__service_duration.sql',                 0, 'postgres', 0,   true),
    (5,  '5',  'estimates views and patch',    'SQL',      'V5__estimates_views_and_patch.sql',         0, 'postgres', 100, true),
    (6,  '6',  'estimates provider column',    'SQL',      'V6__estimates_provider_column.sql',         0, 'postgres', 100, true),
    (7,  '7',  'invoices',                     'SQL',      'V7__invoices.sql',                          0, 'postgres', 100, true),
    (8,  '8',  'inventory',                    'SQL',      'V8__inventory.sql',                         0, 'postgres', 100, true),
    (9,  '9',  'recalls',                      'SQL',      'V9__recalls.sql',                           0, 'postgres', 100, true),
    (10, '10', 'inventory seed',               'SQL',      'V10__inventory_seed.sql',                   0, 'postgres', 100, true),
    (11, '11', 'schema updates',               'SQL',      'V11__schema_updates.sql',                   0, 'postgres', 100, true)
ON CONFLICT (installed_rank) DO NOTHING;
