ALTER TABLE dentalcare.service_catalog
    ADD COLUMN IF NOT EXISTS duration_minutes INTEGER;

-- Default durations by category for existing services
UPDATE dentalcare.service_catalog SET duration_minutes = CASE
    WHEN lower(name) LIKE '%igiene%'                           THEN 60
    WHEN lower(name) LIKE '%sbiancament%'                      THEN 90
    WHEN lower(name) LIKE '%otturazion%'                       THEN 45
    WHEN lower(name) LIKE '%devitalizzazion%' OR lower(name) LIKE '%canalare%' OR lower(name) LIKE '%endodonz%' THEN 90
    WHEN lower(name) LIKE '%estrazion%' OR lower(name) LIKE '%estrat%'         THEN 45
    WHEN lower(name) LIKE '%impianto%' OR lower(name) LIKE '%implantolog%'     THEN 120
    WHEN lower(name) LIKE '%corona%' OR lower(name) LIKE '%protesi%'           THEN 60
    WHEN lower(name) LIKE '%visita%' OR lower(name) LIKE '%consult%'           THEN 30
    WHEN lower(name) LIKE '%rx%' OR lower(name) LIKE '%radiograf%'             THEN 15
    ELSE 30
END
WHERE duration_minutes IS NULL;
