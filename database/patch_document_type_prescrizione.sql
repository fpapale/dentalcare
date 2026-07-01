-- Patch: add 'prescrizione' to dentalcare.document_type enum (FIX #5 — prescription document upload).
-- Global enum in schema dentalcare, shared by all tenant patient_documents tables.
-- PG12+ supports ADD VALUE outside a transaction. Idempotent via IF NOT EXISTS.
-- Apply once per database (dev + prod).

ALTER TYPE dentalcare.document_type ADD VALUE IF NOT EXISTS 'prescrizione';
