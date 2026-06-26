from fastapi import APIRouter, Depends

from app.minio_client import get_minio
from app.schemas import AnnotationRequest
from app.security import require_jwt

router = APIRouter()


@router.post("/annotations")
def save_annotations(req: AnnotationRequest, _claims: dict = Depends(require_jwt)) -> dict:
    minio = get_minio()
    minio.upload_json(req.annotation_bucket, req.annotation_object_key, req.model_dump())

    study = req.study_id or "unknown"
    training_key = f"ai/training/pending/{study}.json"
    minio.upload_json(req.annotation_bucket, training_key, {
        "image": {"bucket": req.image_bucket, "object_key": req.image_object_key},
        "annotations": req.annotations,
        "reviewer": req.reviewer,
    })
    return {"status": "saved",
            "annotation_object_key": req.annotation_object_key,
            "training_sample_object_key": training_key}
