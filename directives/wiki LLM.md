# Technical Specification: OCR & Wiki RAG Pipeline for DentalCare

## 1. Objective
Implement a pipeline that monitors a MinIO bucket for new documents (PDF/DOCX), converts them to structured Markdown (Wiki-ready), and uses GPT-4o to extract patient data for the SQL database.

## 2. Architecture Constraints
- **Environment:** CPU-only Proxmox CT.
- **Object Storage:** MinIO (S3 compatible).
- **Primary Logic:** Python scripts triggered by file events.
- **Storage Strategy:** - Raw binary files reside in MinIO.
  - Derived Wiki files (Markdown) reside on the local file system (Path: `/data/wiki/{patient_id}/`).

## 3. Workflow Specification
1. **Trigger:** The system must listen for new object creation in the `dental-records` bucket.
2. **Download:** Fetch object from MinIO via `boto3`.
3. **Extraction Engine:**
   - For PDF (native): Use `PyMuPDF`.
   - For Scanned/DOCX: Use `Docling` (fallback to `Tesseract` if Docling fails).
4. **AI Processing:** - Send extracted text to `GPT-4o` API.
   - **Task A (Database):** Extract structured JSON for SQL sync (fields: `patient_id`, `date`, `exam_type`, `summary`).
   - **Task B (Wiki):** Format content into standard Markdown headers for the patient's Wiki.
5. **Storage:**
   - Save Markdown to `/data/wiki/{patient_id}/`.
   - Commit changes to the local Git repository for versioning.
   - Update SQL `DentalCare` database with extracted JSON.

## 4. Markdown Template (Wiki standard)
Every patient wiki file must follow this structure:
```markdown
# {Patient_Name} - {Date}
## Summary
{AI_Generated_Summary}
## Clinical Findings
- ...
## Actions/Treatment Plan
- ...
## Raw Data
[Link to MinIO S3 Object]