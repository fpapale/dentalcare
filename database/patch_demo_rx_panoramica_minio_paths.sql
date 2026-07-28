-- Patch: corregge file_path e mime_type per i 4 documenti rx_panoramica del tenant demo.
--
-- I path originali erano filesystem (/uploads/demo/...) incompatibili con MinIO.
-- Dopo la migrazione al bucket per-tenant (dc-t-9d754153) il formato corretto è:
--   patients/{patient_id}/{doc_id}/{file_name}
--
-- PREREQUISITO: eseguire demo_minio_upload.py dopo questo script per caricare
--               le immagini effettive in MinIO al path corretto.
--
-- Esecuzione:
--   psql -U postgres dentalcarepro < patch_demo_rx_panoramica_minio_paths.sql

UPDATE t_9d754153.patient_documents
SET
    file_path = 'patients/c1000001-0000-0000-0000-000000000003/a09fd284-3288-4bd9-91b4-56b17cea1d7c/ortopan_romano_2024.jpg',
    mime_type = 'image/jpeg'
WHERE id = 'a09fd284-3288-4bd9-91b4-56b17cea1d7c';

UPDATE t_9d754153.patient_documents
SET
    file_path = 'patients/c1000001-0000-0000-0000-000000000005/bef29ec9-5c6b-484c-9996-dd56a13e89b3/ortopan_ricci_2024.jpg',
    mime_type = 'image/jpeg'
WHERE id = 'bef29ec9-5c6b-484c-9996-dd56a13e89b3';

UPDATE t_9d754153.patient_documents
SET
    file_path = 'patients/c1000001-0000-0000-0000-000000000007/10dd504a-44ee-4263-b341-4e113b9040c3/ortopan_greco_pre_orto.jpg',
    mime_type = 'image/jpeg'
WHERE id = '10dd504a-44ee-4263-b341-4e113b9040c3';

UPDATE t_9d754153.patient_documents
SET
    file_path = 'patients/c1000001-0000-0000-0000-000000000011/88c87090-b0d9-4fd3-94bf-80fb36bb66ea/ortopan_deluca_paro.jpg',
    mime_type = 'image/jpeg'
WHERE id = '88c87090-b0d9-4fd3-94bf-80fb36bb66ea';
