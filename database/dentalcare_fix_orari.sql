-- Sposta gli appuntamenti delle 11:00 alle 09:30 (durata invariata)
BEGIN;
SET search_path TO dentalcare, public;

UPDATE appointments
SET starts_at = starts_at - INTERVAL '1.5 hours',
    ends_at   = ends_at   - INTERVAL '1.5 hours'
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'
  AND starts_at::date = CURRENT_DATE
  AND EXTRACT(HOUR FROM starts_at) = 11;

-- Aggiorna a in_progress quelli che ora ricadono nell'orario corrente
UPDATE appointments
SET status = 'in_progress'
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'
  AND starts_at <= NOW()
  AND ends_at   >= NOW()
  AND status IN ('scheduled', 'confirmed');

SELECT starts_at, ends_at, status
FROM appointments
WHERE clinic_id = '9d754153-6579-4b7e-a56b-025f00299cd9'
  AND starts_at::date = CURRENT_DATE
ORDER BY starts_at;

COMMIT;
