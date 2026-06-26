from fastapi import FastAPI

from app.config import get_settings
from app.routers import health, inference, models
from app.utils.logging import setup_logging

setup_logging()
settings = get_settings()

app = FastAPI(title=settings.app_name, version=settings.app_version)
app.include_router(health.router)
app.include_router(models.router, prefix=settings.api_prefix)
app.include_router(inference.router, prefix=settings.api_prefix)
