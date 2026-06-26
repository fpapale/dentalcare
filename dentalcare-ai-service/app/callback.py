import hashlib
import hmac
import json
import time

import httpx

from app.config import get_settings
from app.utils.logging import log_event


def sign_body(body: bytes, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()


def send_callback(payload: dict) -> bool:
    settings = get_settings()
    body = json.dumps(payload, default=str).encode("utf-8")
    signature = sign_body(body, settings.ai_callback_secret)
    headers = {"Content-Type": "application/json", "X-AI-Signature": signature}

    for attempt in range(settings.callback_retries):
        try:
            resp = httpx.post(settings.ai_callback_url, content=body, headers=headers, timeout=10.0)
            if 200 <= resp.status_code < 300:
                return True
            log_event("callback_non_2xx", status=resp.status_code, attempt=attempt)
        except httpx.HTTPError as exc:
            log_event("callback_error", error=str(exc), attempt=attempt)
        time.sleep(2 ** attempt)
    return False
