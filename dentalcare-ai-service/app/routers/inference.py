import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query

from app.schemas import InferenceJobRequest, JobCreatedResponse, JobStatusResponse
from app.security import require_jwt
from app.services.registry import get_job_service

router = APIRouter()


@router.post("/inference/jobs", response_model=JobCreatedResponse)
def create_job(req: InferenceJobRequest, background: BackgroundTasks,
               _claims: dict = Depends(require_jwt)) -> JobCreatedResponse:
    job_id = f"ai-job-{uuid.uuid4()}"
    svc = get_job_service()
    background.add_task(svc.run_job, job_id, req)
    return JobCreatedResponse(job_id=job_id, status="queued")


@router.get("/inference/jobs/{job_id}", response_model=JobStatusResponse)
def get_job(job_id: str, result_bucket: str = Query(...),
            _claims: dict = Depends(require_jwt)) -> JobStatusResponse:
    svc = get_job_service()
    try:
        doc = svc.read_job(result_bucket, job_id)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=404, detail="Job not found") from exc
    return JobStatusResponse(
        job_id=doc["job_id"], status=doc["status"],
        result_object_key=doc.get("result_object_key"),
        annotated_image_object_key=doc.get("annotated_image_object_key"),
        detections=doc.get("detections", []), error=doc.get("error"),
    )
