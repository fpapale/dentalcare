-- Multi-estimate per treatment plan support
-- Allows multiple estimates to reference the same treatment plan,
-- each covering a different subset of plan items (like Dentrix/Eaglesoft)

-- Drop unique constraint that blocked multiple estimates per plan
ALTER TABLE dentalcare.estimates
  DROP CONSTRAINT IF EXISTS ux_estimates_plan_version;

-- Index for efficient plan→estimates lookups
CREATE INDEX IF NOT EXISTS ix_estimates_treatment_plan
  ON dentalcare.estimates(clinic_id, treatment_plan_id)
  WHERE treatment_plan_id IS NOT NULL;

-- Index for finding which estimates cover a given plan item
CREATE INDEX IF NOT EXISTS ix_estimate_lines_plan_item
  ON dentalcare.estimate_lines(clinic_id, treatment_plan_item_id)
  WHERE treatment_plan_item_id IS NOT NULL;
