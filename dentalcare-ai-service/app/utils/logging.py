import json
import logging
import sys

from app.config import get_settings


def setup_logging() -> None:
    settings = get_settings()
    logging.basicConfig(
        level=settings.log_level,
        stream=sys.stdout,
        format="%(message)s",
    )


def log_event(event: str, **fields) -> None:
    payload = {"event": event, **fields}
    logging.getLogger("ai-service").info(json.dumps(payload, default=str))
