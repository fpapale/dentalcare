from functools import lru_cache

from app.config import get_settings
from app.inference.onnx_yolo import OnnxYoloDetector
from app.inference.pipeline import DISEASE_CLASS_NAMES, FDI_CLASS_NAMES
from app.minio_client import get_minio
from app.services.job_service import JobService


@lru_cache
def get_fdi_detector() -> OnnxYoloDetector:
    s = get_settings()
    return OnnxYoloDetector(s.fdi_model_path, FDI_CLASS_NAMES, s.fdi_input_size,
                            s.fdi_conf_threshold, s.model_iou_threshold, s.model_input_scale)


@lru_cache
def get_disease_detector() -> OnnxYoloDetector:
    s = get_settings()
    return OnnxYoloDetector(s.disease_model_path, DISEASE_CLASS_NAMES, s.disease_input_size,
                            s.disease_conf_threshold, s.model_iou_threshold, s.model_input_scale)


@lru_cache
def get_job_service() -> JobService:
    return JobService(get_minio(), get_fdi_detector(), get_disease_detector(), get_settings())
