from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "dentalcare-ai-service"
    app_version: str = "0.1.0"
    app_env: str = "development"
    log_level: str = "INFO"
    api_prefix: str = "/api/v1"

    jwt_secret: str = "change-me"
    jwt_issuer: str = ""
    jwt_audience: str = ""

    minio_endpoint: str = "host.docker.internal:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_secure: bool = False

    fdi_model_path: str = "/app/models/dentex_fdi_v1.onnx"
    disease_model_path: str = "/app/models/dentex_disease_v1.onnx"
    fdi_input_size: int = 1024
    disease_input_size: int = 1024
    fdi_conf_threshold: float = 0.25
    disease_conf_threshold: float = 0.25
    model_iou_threshold: float = 0.45
    match_iou_threshold: float = 0.10
    match_center_fallback: bool = True

    ai_callback_url: str = "http://dentalcarepro-backend:8080/api/internal/ai/callback"
    ai_callback_secret: str = "change-me"
    callback_retries: int = 3

    save_debug_files: bool = False
    tmp_dir: str = "/tmp/dentalcare-ai"


@lru_cache
def get_settings() -> Settings:
    return Settings()
