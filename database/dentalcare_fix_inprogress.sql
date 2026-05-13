-- Imposta in_progress gli appuntamenti che stanno accadendo adesso
-- Eseguire con:
--   psql -h 192.168.0.173 -U postgres -d dentalcarepro -f dentalcare_fix_inprogress.sql

BEGIN;

SET search_path TO dentalcare, public;

UPDATE appointments
SET status = 'in_progress'
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'
  AND starts_at <= NOW()
  AND ends_at   >= NOW()
  AND status IN ('scheduled', 'confirmed');

SELECT COUNT(*) AS appuntamenti_in_corso
FROM appointments
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'
  AND status = 'in_progress';

COMMIT;
