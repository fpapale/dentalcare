-- ─── 1. Delete weekend appointments (only if column exists — safe for fresh installs) ──
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'dentalcare'
      AND table_name   = 'appointments'
      AND column_name  = 'starts_at'
  ) THEN
    DELETE FROM dentalcare.appointments
    WHERE EXTRACT(DOW FROM starts_at AT TIME ZONE 'Europe/Rome') IN (0, 6);
  END IF;
END $$;

-- ─── 2. Geo tables ────────────────────────────────────────────────────────────

CREATE TABLE dentalcare.states (
    id   UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    code CHAR(2) NOT NULL,
    name TEXT    NOT NULL,
    CONSTRAINT uq_states_code UNIQUE (code)
);

CREATE TABLE dentalcare.regions (
    id       UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id UUID       NOT NULL REFERENCES dentalcare.states(id),
    code     VARCHAR(5) NOT NULL,
    name     TEXT       NOT NULL,
    CONSTRAINT uq_regions_state_code UNIQUE (state_id, code)
);
CREATE INDEX ix_regions_state ON dentalcare.regions(state_id);

CREATE TABLE dentalcare.cities (
    id            UUID   PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id     UUID   NOT NULL REFERENCES dentalcare.regions(id),
    name          TEXT   NOT NULL,
    province_code CHAR(2),
    CONSTRAINT uq_cities_region_name UNIQUE (region_id, name)
);
CREATE INDEX ix_cities_region ON dentalcare.cities(region_id);

-- Link clinic to city
ALTER TABLE dentalcare.clinics
    ADD COLUMN city_id UUID REFERENCES dentalcare.cities(id);

-- ─── 3. National holidays ─────────────────────────────────────────────────────

CREATE TABLE dentalcare.national_holidays (
    id           UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id     UUID     NOT NULL REFERENCES dentalcare.states(id),
    name         TEXT     NOT NULL,
    is_recurring BOOLEAN  NOT NULL DEFAULT TRUE,
    -- recurring: same month+day every year
    month        SMALLINT,
    day          SMALLINT,
    -- non-recurring: specific date (e.g. Easter)
    holiday_date DATE,
    CONSTRAINT chk_holiday_def CHECK (
        (is_recurring = TRUE  AND month IS NOT NULL AND day IS NOT NULL AND holiday_date IS NULL) OR
        (is_recurring = FALSE AND holiday_date IS NOT NULL AND month IS NULL AND day IS NULL)
    )
);
CREATE INDEX ix_holidays_recurring ON dentalcare.national_holidays(state_id, month, day)
    WHERE is_recurring = TRUE;
CREATE INDEX ix_holidays_date ON dentalcare.national_holidays(state_id, holiday_date)
    WHERE holiday_date IS NOT NULL;

-- ─── 4. Italy data ────────────────────────────────────────────────────────────

INSERT INTO dentalcare.states (id, code, name)
VALUES ('00000001-0000-0000-0000-000000000001', 'IT', 'Italia');

DO $$
DECLARE
  v_it  UUID := '00000001-0000-0000-0000-000000000001';
  -- region IDs
  r_abr UUID; r_bas UUID; r_cal UUID; r_cam UUID; r_emr UUID;
  r_fvg UUID; r_laz UUID; r_lig UUID; r_lom UUID; r_mar UUID;
  r_mol UUID; r_pie UUID; r_pug UUID; r_sar UUID; r_sic UUID;
  r_tos UUID; r_taa UUID; r_umb UUID; r_vao UUID; r_ven UUID;
  -- city IDs
  c_rom UUID; c_mil UUID;
BEGIN
  -- Regions
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'ABR', 'Abruzzo')         RETURNING id INTO r_abr;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'BAS', 'Basilicata')       RETURNING id INTO r_bas;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'CAL', 'Calabria')         RETURNING id INTO r_cal;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'CAM', 'Campania')         RETURNING id INTO r_cam;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'EMR', 'Emilia-Romagna')   RETURNING id INTO r_emr;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'FVG', 'Friuli-Venezia Giulia') RETURNING id INTO r_fvg;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'LAZ', 'Lazio')            RETURNING id INTO r_laz;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'LIG', 'Liguria')          RETURNING id INTO r_lig;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'LOM', 'Lombardia')        RETURNING id INTO r_lom;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'MAR', 'Marche')           RETURNING id INTO r_mar;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'MOL', 'Molise')           RETURNING id INTO r_mol;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'PIE', 'Piemonte')         RETURNING id INTO r_pie;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'PUG', 'Puglia')           RETURNING id INTO r_pug;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'SAR', 'Sardegna')         RETURNING id INTO r_sar;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'SIC', 'Sicilia')          RETURNING id INTO r_sic;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'TOS', 'Toscana')          RETURNING id INTO r_tos;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'TAA', 'Trentino-Alto Adige') RETURNING id INTO r_taa;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'UMB', 'Umbria')           RETURNING id INTO r_umb;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'VAO', 'Valle d''Aosta')   RETURNING id INTO r_vao;
  INSERT INTO dentalcare.regions (id, state_id, code, name) VALUES
    (gen_random_uuid(), v_it, 'VEN', 'Veneto')           RETURNING id INTO r_ven;

  -- Cities (capitals + major cities)
  INSERT INTO dentalcare.cities (region_id, name, province_code) VALUES
    (r_abr, 'L''Aquila', 'AQ'), (r_abr, 'Pescara', 'PE'), (r_abr, 'Chieti', 'CH'),
    (r_bas, 'Potenza', 'PZ'), (r_bas, 'Matera', 'MT'),
    (r_cal, 'Catanzaro', 'CZ'), (r_cal, 'Reggio Calabria', 'RC'), (r_cal, 'Cosenza', 'CS'),
    (r_cam, 'Napoli', 'NA'), (r_cam, 'Salerno', 'SA'), (r_cam, 'Caserta', 'CE'), (r_cam, 'Avellino', 'AV'),
    (r_emr, 'Bologna', 'BO'), (r_emr, 'Modena', 'MO'), (r_emr, 'Parma', 'PR'), (r_emr, 'Ferrara', 'FE'), (r_emr, 'Rimini', 'RN'),
    (r_fvg, 'Trieste', 'TS'), (r_fvg, 'Udine', 'UD'), (r_fvg, 'Pordenone', 'PN'),
    (r_lom, 'Bergamo', 'BG'), (r_lom, 'Brescia', 'BS'), (r_lom, 'Como', 'CO'), (r_lom, 'Monza', 'MB'), (r_lom, 'Varese', 'VA'), (r_lom, 'Pavia', 'PV'),
    (r_mar, 'Ancona', 'AN'), (r_mar, 'Pesaro', 'PU'), (r_mar, 'Macerata', 'MC'),
    (r_mol, 'Campobasso', 'CB'), (r_mol, 'Isernia', 'IS'),
    (r_pie, 'Torino', 'TO'), (r_pie, 'Novara', 'NO'), (r_pie, 'Alessandria', 'AL'), (r_pie, 'Asti', 'AT'), (r_pie, 'Cuneo', 'CN'),
    (r_pug, 'Bari', 'BA'), (r_pug, 'Taranto', 'TA'), (r_pug, 'Brindisi', 'BR'), (r_pug, 'Lecce', 'LE'), (r_pug, 'Foggia', 'FG'),
    (r_sar, 'Cagliari', 'CA'), (r_sar, 'Sassari', 'SS'), (r_sar, 'Nuoro', 'NU'), (r_sar, 'Oristano', 'OR'),
    (r_sic, 'Palermo', 'PA'), (r_sic, 'Catania', 'CT'), (r_sic, 'Messina', 'ME'), (r_sic, 'Agrigento', 'AG'), (r_sic, 'Trapani', 'TP'),
    (r_tos, 'Firenze', 'FI'), (r_tos, 'Pisa', 'PI'), (r_tos, 'Siena', 'SI'), (r_tos, 'Livorno', 'LI'), (r_tos, 'Arezzo', 'AR'),
    (r_taa, 'Trento', 'TN'), (r_taa, 'Bolzano', 'BZ'),
    (r_umb, 'Perugia', 'PG'), (r_umb, 'Terni', 'TR'),
    (r_vao, 'Aosta', 'AO'),
    (r_ven, 'Venezia', 'VE'), (r_ven, 'Verona', 'VR'), (r_ven, 'Padova', 'PD'), (r_ven, 'Vicenza', 'VI'), (r_ven, 'Treviso', 'TV');

  -- Lazio: Roma (need the city ID for the clinic update)
  INSERT INTO dentalcare.cities (id, region_id, name, province_code)
    VALUES (gen_random_uuid(), r_laz, 'Roma', 'RM')
    RETURNING id INTO c_rom;
  INSERT INTO dentalcare.cities (region_id, name, province_code) VALUES
    (r_laz, 'Latina', 'LT'), (r_laz, 'Frosinone', 'FR'), (r_laz, 'Viterbo', 'VT'), (r_laz, 'Rieti', 'RI');

  -- Liguria
  INSERT INTO dentalcare.cities (region_id, name, province_code) VALUES
    (r_lig, 'Genova', 'GE'), (r_lig, 'La Spezia', 'SP'), (r_lig, 'Savona', 'SV'), (r_lig, 'Imperia', 'IM');

  -- Lombardia: Milano (need city ID)
  INSERT INTO dentalcare.cities (id, region_id, name, province_code)
    VALUES (gen_random_uuid(), r_lom, 'Milano', 'MI')
    RETURNING id INTO c_mil;

  -- Link clinics to cities
  UPDATE dentalcare.clinics SET city_id = c_rom
    WHERE id = '9d754153-6579-4b7e-a56b-025f00299cd9';  -- Roma
  UPDATE dentalcare.clinics SET city_id = c_mil
    WHERE id = '352464ea-0b3f-47ba-a3dc-3511c6d1af4f';  -- Milano

END $$;

-- ─── 5. Italian national holidays ────────────────────────────────────────────

DO $$
DECLARE v_it UUID := '00000001-0000-0000-0000-000000000001';
BEGIN
  -- Fixed recurring holidays (month, day)
  INSERT INTO dentalcare.national_holidays (state_id, name, is_recurring, month, day) VALUES
    (v_it, 'Capodanno',                  TRUE,  1,  1),
    (v_it, 'Epifania',                   TRUE,  1,  6),
    (v_it, 'Festa della Liberazione',    TRUE,  4, 25),
    (v_it, 'Festa del Lavoro',           TRUE,  5,  1),
    (v_it, 'Festa della Repubblica',     TRUE,  6,  2),
    (v_it, 'Ferragosto',                 TRUE,  8, 15),
    (v_it, 'Tutti i Santi',              TRUE, 11,  1),
    (v_it, 'Immacolata Concezione',      TRUE, 12,  8),
    (v_it, 'Natale',                     TRUE, 12, 25),
    (v_it, 'Santo Stefano',              TRUE, 12, 26);

  -- Easter (Pasqua) and Easter Monday (Pasquetta) 2024–2035
  -- Dates computed via Gregorian algorithm
  INSERT INTO dentalcare.national_holidays (state_id, name, is_recurring, holiday_date) VALUES
    (v_it, 'Pasqua',      FALSE, '2024-03-31'),
    (v_it, 'Pasquetta',   FALSE, '2024-04-01'),
    (v_it, 'Pasqua',      FALSE, '2025-04-20'),
    (v_it, 'Pasquetta',   FALSE, '2025-04-21'),
    (v_it, 'Pasqua',      FALSE, '2026-04-05'),
    (v_it, 'Pasquetta',   FALSE, '2026-04-06'),
    (v_it, 'Pasqua',      FALSE, '2027-03-28'),
    (v_it, 'Pasquetta',   FALSE, '2027-03-29'),
    (v_it, 'Pasqua',      FALSE, '2028-04-16'),
    (v_it, 'Pasquetta',   FALSE, '2028-04-17'),
    (v_it, 'Pasqua',      FALSE, '2029-04-01'),
    (v_it, 'Pasquetta',   FALSE, '2029-04-02'),
    (v_it, 'Pasqua',      FALSE, '2030-04-21'),
    (v_it, 'Pasquetta',   FALSE, '2030-04-22'),
    (v_it, 'Pasqua',      FALSE, '2031-04-13'),
    (v_it, 'Pasquetta',   FALSE, '2031-04-14'),
    (v_it, 'Pasqua',      FALSE, '2032-03-28'),
    (v_it, 'Pasquetta',   FALSE, '2032-03-29'),
    (v_it, 'Pasqua',      FALSE, '2033-04-17'),
    (v_it, 'Pasquetta',   FALSE, '2033-04-18'),
    (v_it, 'Pasqua',      FALSE, '2034-04-09'),
    (v_it, 'Pasquetta',   FALSE, '2034-04-10'),
    (v_it, 'Pasqua',      FALSE, '2035-03-25'),
    (v_it, 'Pasquetta',   FALSE, '2035-03-26');

END $$;
