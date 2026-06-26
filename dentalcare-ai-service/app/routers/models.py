from fastapi import APIRouter, Depends

from app.config import get_settings
from app.security import require_jwt
from app.services.registry import get_disease_detector, get_fdi_detector

router = APIRouter()


@router.get("/models/status")
def models_status(_claims: dict = Depends(require_jwt)) -> dict:
    s = get_settings()
    fdi, disease = get_fdi_detector(), get_disease_detector()
    return {
        "runtime": "onnxruntime",
        "providers": ["CPUExecutionProvider"],
        "models": {
            "fdi": {"name": "dentex_fdi_v1", "path": s.fdi_model_path, "loaded": fdi.is_loaded()},
            "disease": {"name": "dentex_disease_v1", "path": s.disease_model_path, "loaded": disease.is_loaded()},
        },
    }
