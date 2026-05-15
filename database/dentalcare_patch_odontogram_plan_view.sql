-- Patch: view e indice per sincronizzazione piano di cura ↔ odontogramma
SET search_path TO dentalcare, public;

-- Indice per velocizzare la JOIN treatment_plan_items ↔ tooth_conditions
CREATE INDEX IF NOT EXISTS ix_tooth_conditions_patient_fdi_surface
    ON tooth_conditions (clinic_id, patient_id, tooth_fdi, surface);

-- Vista: items del piano di cura arricchiti con condizione odontogramma
CREATE OR REPLACE VIEW v_treatment_items_odontogram AS
SELECT
    tpi.id                  AS item_id,
    tpi.treatment_plan_id,
    tpi.clinic_id,
    tp.patient_id,
    tpi.tooth_number,
    tpi.quadrant,
    tpi.status              AS item_status,
    tpi.service_id,
    tc.condition            AS odontogram_condition,
    tc.tooth_fdi
FROM treatment_plan_items tpi
JOIN treatment_plans tp
    ON tp.id = tpi.treatment_plan_id AND tp.clinic_id = tpi.clinic_id
LEFT JOIN tooth_conditions tc
    ON tpi.tooth_number ~ '^[0-9]+$'
   AND CAST(tpi.tooth_number AS integer) = tc.tooth_fdi
   AND tc.surface = 'WHOLE'
   AND tc.patient_id = tp.patient_id
   AND tc.clinic_id = tpi.clinic_id;

-- Verify
SELECT item_id, tooth_number, item_status, odontogram_condition
FROM v_treatment_items_odontogram
LIMIT 5;
