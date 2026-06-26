import json
import os
import shutil
from datetime import datetime, timezone

import cv2

from app.callback import send_callback
from app.config import Settings
from app.inference.pipeline import match_detections
from app.inference.visualization import draw_detections
from app.schemas import InferenceJobRequest
from app.utils.logging import log_event


class JobService:
    def __init__(self, minio, fdi_detector, disease_detector, settings: Settings):
        self.minio = minio
        self.fdi = fdi_detector
        self.disease = disease_detector
        self.settings = settings

    def _index_key(self, job_id: str) -> str:
        return f"ai/jobs/{job_id}.json"

    def _write_index(self, req: InferenceJobRequest, job_id: str, status: str, extra: dict | None = None) -> None:
        doc = {"job_id": job_id, "status": status,
               "analysis_id": req.analysis_id, **(extra or {})}
        self.minio.upload_json(req.output_bucket, self._index_key(job_id), doc)

    def read_job(self, bucket: str, job_id: str) -> dict:
        """Read the job index JSON. `bucket` must be the job's output_bucket."""
        tmp = os.path.join(self.settings.tmp_dir, f"{job_id}-index.json")
        os.makedirs(os.path.dirname(tmp), exist_ok=True)
        try:
            self.minio.download_object(bucket, self._index_key(job_id), tmp)
            with open(tmp) as fh:
                return json.load(fh)
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

    def run_job(self, job_id: str, req: InferenceJobRequest) -> None:
        work_dir = os.path.join(self.settings.tmp_dir, job_id)
        os.makedirs(work_dir, exist_ok=True)
        started = datetime.now(timezone.utc)
        try:
            self._write_index(req, job_id, "processing")

            local_img = os.path.join(work_dir, "source.img")
            self.minio.download_object(req.image_bucket, req.image_object_key, local_img)
            image = cv2.imread(local_img)
            if image is None:
                raise ValueError("Image could not be decoded")

            fdi_dets = self.fdi.predict(image)
            disease_dets = self.disease.predict(image)
            detections = match_detections(
                fdi_dets, disease_dets,
                iou_threshold=self.settings.match_iou_threshold,
                center_fallback=self.settings.match_center_fallback,
            )

            result_key = f"{req.output_prefix}result.json"
            result_doc = {
                "job_id": job_id,
                "patient_id": req.patient_id,
                "document_id": req.document_id,
                "analysis_id": req.analysis_id,
                "source_image": {"bucket": req.image_bucket, "object_key": req.image_object_key},
                "models": {"fdi": os.path.basename(self.settings.fdi_model_path),
                           "disease": os.path.basename(self.settings.disease_model_path)},
                "status": "completed",
                "created_at": started.isoformat(),
                "detections": detections,
                "raw": {"fdi_detections": fdi_dets, "disease_detections": disease_dets},
                "review": {"status": "pending", "reviewed_by": None, "reviewed_at": None},
            }
            self.minio.upload_json(req.output_bucket, result_key, result_doc)

            annotated_key = None
            if req.save_annotated_image:
                annotated = draw_detections(image, detections)
                annotated_path = os.path.join(work_dir, "annotated.png")
                cv2.imwrite(annotated_path, annotated)
                annotated_key = f"{req.output_prefix}annotated.png"
                self.minio.upload_file(req.output_bucket, annotated_key, annotated_path, "image/png")

            self._write_index(req, job_id, "completed",
                              {"result_object_key": result_key,
                               "annotated_image_object_key": annotated_key,
                               "detections": detections})

            send_callback({
                "job_id": job_id, "status": "completed",
                "schema_name": req.schema_name, "patient_id": req.patient_id,
                "document_id": req.document_id, "analysis_id": req.analysis_id,
                "result_bucket": req.output_bucket, "result_object_key": result_key,
                "annotated_object_key": annotated_key, "detections": detections,
            })
            log_event("job_completed", job_id=job_id, detections=len(detections))
        except Exception as exc:  # noqa: BLE001 - report all failures via callback
            log_event("job_failed", job_id=job_id, error=str(exc))
            try:
                self._write_index(req, job_id, "failed", {"error": str(exc)})
            except Exception:  # noqa: BLE001
                pass
            try:
                send_callback({
                    "job_id": job_id, "status": "failed",
                    "schema_name": req.schema_name, "patient_id": req.patient_id,
                    "document_id": req.document_id, "analysis_id": req.analysis_id,
                    "error": str(exc),
                })
            except Exception:  # noqa: BLE001
                pass
        finally:
            if not self.settings.save_debug_files:
                shutil.rmtree(work_dir, ignore_errors=True)
