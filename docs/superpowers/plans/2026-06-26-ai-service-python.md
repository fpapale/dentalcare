# dentalcare-ai-service (Python) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the standalone Python/FastAPI microservice `dentalcare-ai-service` that runs two cascaded ONNX YOLO models (FDI teeth + dental disease) on panoramic X-rays, stores results on MinIO, and notifies DentalCare via an HMAC webhook.

**Architecture:** FastAPI app, JWT-protected (shared secret with DentalCare). A job endpoint runs inference asynchronously via `BackgroundTasks`: downloads the image from MinIO, runs the FDI detector then the disease detector, matches diseases to teeth by IoU (with bounding-box-center fallback), writes `result.json` + `annotated.png` to MinIO, then POSTs an HMAC-signed callback to the backend. The service is stateless with respect to DentalCare's DB.

**Tech Stack:** Python 3.11, FastAPI, Uvicorn, onnxruntime (CPU), OpenCV (headless), NumPy, Pillow, minio, PyJWT, Pydantic v2 + pydantic-settings, pytest.

**Spec:** `docs/superpowers/specs/2026-06-26-ai-yolo-service-design.md` (sections 4, 9, 10, 11, 16).

**Working directory:** all paths below are relative to `dentalcare-ai-service/` (new subfolder of repo root `d:\dentalcare`).

## Global Constraints

- Python 3.11. Do not install `onnxruntime-gpu` (CPU only for this plan).
- All `/api/v1/*` endpoints require a valid JWT; `/health` does not.
- JWT: HMAC, `algorithms=["HS256","HS384","HS512"]` (DentalCare's jjwt picks the algorithm from secret length). Validate signature + `exp`. Validate `iss`/`aud` ONLY if `JWT_ISSUER`/`JWT_AUDIENCE` are set (default: unset — DentalCare tokens have no `iss`/`aud`).
- MinIO bucket is always taken from the request/job payload (`image_bucket`, `output_bucket`) — never hardcoded. Endpoint default `http://host.docker.internal:9000`.
- FDI class map (32 classes), index → FDI tooth number string: `0→11,1→12,2→13,3→14,4→15,5→16,6→17,7→18,8→21,9→22,10→23,11→24,12→25,13→26,14→27,15→28,16→31,17→32,18→33,19→34,20→35,21→36,22→37,23→38,24→41,25→42,26→43,27→44,28→45,29→46,30→47,31→48`.
- Disease class map (4 classes): `0→Impacted,1→Caries,2→Periapical_Lesion,3→Deep_Caries`.
- Default thresholds: `FDI_CONF_THRESHOLD=0.25`, `DISEASE_CONF_THRESHOLD=0.25`, `MODEL_IOU_THRESHOLD=0.45`, `MATCH_IOU_THRESHOLD=0.10`, `MATCH_CENTER_FALLBACK=true`, `FDI_INPUT_SIZE=1024`, `DISEASE_INPUT_SIZE=1024`.
- Bounding box color by FDI quadrant (first digit): Q1(11-18)=`#57C84D` green, Q2(21-28)=`#E84D4D` red, Q3(31-38)=`#4DC8E8` cyan, Q4(41-48)=`#E8C84D` yellow, null=`#9E9E9E` grey. Box label text: `{FDI} {disease}` (e.g. `36 Caries`); null tooth → `? {disease}`.
- Callback signature: `X-AI-Signature: <hex(HMAC_SHA256(AI_CALLBACK_SECRET, raw_request_body))>`.
- Bbox format everywhere is `bbox_xyxy = [x1, y1, x2, y2]` integers in original-image pixel coordinates.
- Temp files under `/tmp/dentalcare-ai/{job_id}/`, deleted at job end unless `SAVE_DEBUG_FILES=true`.
- Logging: one JSON object per line; never log raw image bytes or full tokens.

---

### Task 1: Project scaffold, config, health endpoint

**Files:**
- Create: `requirements.txt`
- Create: `.env.example`
- Create: `app/__init__.py` (empty)
- Create: `app/config.py`
- Create: `app/utils/__init__.py` (empty)
- Create: `app/utils/logging.py`
- Create: `app/routers/__init__.py` (empty)
- Create: `app/routers/health.py`
- Create: `app/main.py`
- Create: `tests/__init__.py` (empty)
- Create: `tests/test_health.py`
- Create: `pytest.ini`
- Create: `.gitignore`
- Create: `models/.gitkeep`, `data/.gitkeep`

**Interfaces:**
- Produces: `app.config.get_settings() -> Settings` (cached); `Settings` fields used by all later tasks. `app.main.app` (FastAPI instance). `app.utils.logging.setup_logging()` and `app.utils.logging.log_event(event: str, **fields)`.

- [ ] **Step 1: requirements.txt**

```text
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.8.2
pydantic-settings==2.4.0
python-multipart==0.0.9
minio==7.2.8
PyJWT==2.9.0
onnxruntime==1.19.2
opencv-python-headless==4.10.0.84
numpy==1.26.4
pillow==10.4.0
python-dotenv==1.0.1
httpx==0.27.2
pytest==8.3.2
```

- [ ] **Step 2: .gitignore**

```text
__pycache__/
*.pyc
.env
.venv/
venv/
models/*.onnx
tmp/
data/*
!data/.gitkeep
!models/.gitkeep
```

- [ ] **Step 3: .env.example**

```env
APP_NAME=dentalcare-ai-service
APP_VERSION=0.1.0
APP_ENV=development
LOG_LEVEL=INFO
API_PREFIX=/api/v1

JWT_SECRET=change-me-must-match-dentalcare-app-jwt-secret
JWT_ISSUER=
JWT_AUDIENCE=

MINIO_ENDPOINT=host.docker.internal:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false

FDI_MODEL_PATH=/app/models/dentex_fdi_v1.onnx
DISEASE_MODEL_PATH=/app/models/dentex_disease_v1.onnx
FDI_INPUT_SIZE=1024
DISEASE_INPUT_SIZE=1024
FDI_CONF_THRESHOLD=0.25
DISEASE_CONF_THRESHOLD=0.25
MODEL_IOU_THRESHOLD=0.45
MATCH_IOU_THRESHOLD=0.10
MATCH_CENTER_FALLBACK=true

AI_CALLBACK_URL=http://dentalcarepro-backend:8080/api/internal/ai/callback
AI_CALLBACK_SECRET=change-me-must-match-backend-app-ai-hmac-secret
CALLBACK_RETRIES=3

SAVE_DEBUG_FILES=false
TMP_DIR=/tmp/dentalcare-ai
```

- [ ] **Step 4: app/config.py**

```python
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
```

- [ ] **Step 5: app/utils/logging.py**

```python
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
```

- [ ] **Step 6: app/routers/health.py**

```python
from fastapi import APIRouter

from app.config import get_settings

router = APIRouter()


@router.get("/health")
def health() -> dict:
    settings = get_settings()
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
    }
```

- [ ] **Step 7: app/main.py**

```python
from fastapi import FastAPI

from app.config import get_settings
from app.routers import health
from app.utils.logging import setup_logging

setup_logging()
settings = get_settings()

app = FastAPI(title=settings.app_name, version=settings.app_version)
app.include_router(health.router)
```

- [ ] **Step 8: pytest.ini**

```ini
[pytest]
pythonpath = .
testpaths = tests
```

- [ ] **Step 9: Write the failing test — tests/test_health.py**

```python
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "dentalcare-ai-service"
    assert "version" in body
```

- [ ] **Step 10: Create empty `__init__.py` files and `.gitkeep`**

Run: `mkdir -p app/utils app/routers app/inference app/services tests models data && touch app/__init__.py app/utils/__init__.py app/routers/__init__.py app/inference/__init__.py app/services/__init__.py tests/__init__.py models/.gitkeep data/.gitkeep`

- [ ] **Step 11: Run test**

Run: `cd dentalcare-ai-service && pip install -r requirements.txt && pytest tests/test_health.py -v`
Expected: PASS (1 passed)

- [ ] **Step 12: Commit**

```bash
git add dentalcare-ai-service
git commit -m "feat(ai-service): scaffold FastAPI app, config, health endpoint"
```

---

### Task 2: JWT security dependency

**Files:**
- Create: `app/security.py`
- Create: `tests/test_security.py`

**Interfaces:**
- Consumes: `app.config.get_settings`.
- Produces: `require_jwt(authorization: str = Header(None)) -> dict` FastAPI dependency returning the token claims dict; raises `HTTPException(401)` on missing/invalid/expired token. `decode_token(token: str) -> dict`.

- [ ] **Step 1: Write failing test — tests/test_security.py**

```python
import time

import jwt
import pytest
from fastapi import HTTPException

from app.config import get_settings
from app.security import decode_token

SECRET = get_settings().jwt_secret


def _token(claims: dict, secret: str = SECRET) -> str:
    return jwt.encode(claims, secret, algorithm="HS256")


def test_decode_valid_token_returns_claims():
    token = _token({"sub": "u1", "schemaName": "t_9d754153", "exp": int(time.time()) + 60})
    claims = decode_token(token)
    assert claims["sub"] == "u1"
    assert claims["schemaName"] == "t_9d754153"


def test_decode_expired_token_raises_401():
    token = _token({"sub": "u1", "exp": int(time.time()) - 10})
    with pytest.raises(HTTPException) as exc:
        decode_token(token)
    assert exc.value.status_code == 401


def test_decode_wrong_secret_raises_401():
    token = _token({"sub": "u1", "exp": int(time.time()) + 60}, secret="wrong-secret-value")
    with pytest.raises(HTTPException) as exc:
        decode_token(token)
    assert exc.value.status_code == 401
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_security.py -v`
Expected: FAIL (cannot import `decode_token`)

- [ ] **Step 3: Implement app/security.py**

```python
import jwt
from fastapi import Header, HTTPException

from app.config import get_settings

_ALGORITHMS = ["HS256", "HS384", "HS512"]


def decode_token(token: str) -> dict:
    settings = get_settings()
    options = {"verify_aud": bool(settings.jwt_audience)}
    kwargs = {}
    if settings.jwt_audience:
        kwargs["audience"] = settings.jwt_audience
    if settings.jwt_issuer:
        kwargs["issuer"] = settings.jwt_issuer
    try:
        return jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=_ALGORITHMS,
            options=options,
            **kwargs,
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired token") from exc


def require_jwt(authorization: str = Header(default=None)) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    return decode_token(token)
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_security.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/security.py dentalcare-ai-service/tests/test_security.py
git commit -m "feat(ai-service): JWT validation (shared secret, optional iss/aud)"
```

---

### Task 3: MinIO client wrapper

**Files:**
- Create: `app/minio_client.py`
- Create: `tests/test_minio_client.py`

**Interfaces:**
- Consumes: `app.config.get_settings`.
- Produces: `MinioClient` with `download_object(bucket, object_key, local_path) -> str`, `upload_file(bucket, object_key, local_path, content_type=None) -> None`, `upload_json(bucket, object_key, data: dict) -> None`, `object_exists(bucket, object_key) -> bool`, `ensure_bucket(bucket) -> None`. Module-level `get_minio() -> MinioClient` (cached).

- [ ] **Step 1: Write failing test — tests/test_minio_client.py**

```python
import json
from unittest.mock import MagicMock

from app.minio_client import MinioClient


def _client_with_mock():
    raw = MagicMock()
    c = MinioClient(client=raw)
    return c, raw


def test_upload_json_puts_object_with_json_content_type():
    c, raw = _client_with_mock()
    c.upload_json("dc-t-1", "ai/jobs/j1.json", {"status": "queued"})
    assert raw.put_object.called
    args, kwargs = raw.put_object.call_args
    assert args[0] == "dc-t-1"
    assert args[1] == "ai/jobs/j1.json"
    assert kwargs["content_type"] == "application/json"


def test_object_exists_true_when_stat_succeeds():
    c, raw = _client_with_mock()
    raw.stat_object.return_value = object()
    assert c.object_exists("dc-t-1", "x") is True


def test_object_exists_false_when_stat_raises():
    from minio.error import S3Error
    c, raw = _client_with_mock()
    raw.stat_object.side_effect = S3Error("NoSuchKey", "m", "r", "h", "rid", response=None)
    assert c.object_exists("dc-t-1", "x") is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_minio_client.py -v`
Expected: FAIL (cannot import `MinioClient`)

- [ ] **Step 3: Implement app/minio_client.py**

```python
import io
import json
from functools import lru_cache

from minio import Minio
from minio.error import S3Error

from app.config import get_settings


class MinioClient:
    def __init__(self, client: Minio):
        self._client = client

    def ensure_bucket(self, bucket: str) -> None:
        if not self._client.bucket_exists(bucket):
            self._client.make_bucket(bucket)

    def download_object(self, bucket: str, object_key: str, local_path: str) -> str:
        self._client.fget_object(bucket, object_key, local_path)
        return local_path

    def upload_file(self, bucket: str, object_key: str, local_path: str, content_type: str | None = None) -> None:
        self.ensure_bucket(bucket)
        self._client.fput_object(
            bucket, object_key, local_path,
            content_type=content_type or "application/octet-stream",
        )

    def upload_json(self, bucket: str, object_key: str, data: dict) -> None:
        self.ensure_bucket(bucket)
        payload = json.dumps(data, default=str).encode("utf-8")
        self._client.put_object(
            bucket, object_key, io.BytesIO(payload), length=len(payload),
            content_type="application/json",
        )

    def object_exists(self, bucket: str, object_key: str) -> bool:
        try:
            self._client.stat_object(bucket, object_key)
            return True
        except S3Error:
            return False


@lru_cache
def get_minio() -> MinioClient:
    s = get_settings()
    raw = Minio(
        s.minio_endpoint,
        access_key=s.minio_access_key,
        secret_key=s.minio_secret_key,
        secure=s.minio_secure,
    )
    return MinioClient(client=raw)
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_minio_client.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/minio_client.py dentalcare-ai-service/tests/test_minio_client.py
git commit -m "feat(ai-service): MinIO client wrapper"
```

---

### Task 4: YOLO letterbox preprocessing

**Files:**
- Create: `app/inference/preprocessing.py`
- Create: `tests/test_preprocessing.py`

**Interfaces:**
- Produces: `letterbox(image_bgr: np.ndarray, new_size: int) -> tuple[np.ndarray, float, tuple[int,int]]` returning padded square image (new_size×new_size, BGR), the scale ratio, and `(pad_x, pad_y)`. `to_model_input(padded_bgr: np.ndarray) -> np.ndarray` returning NCHW float32 RGB normalized 0-1.

- [ ] **Step 1: Write failing test — tests/test_preprocessing.py**

```python
import numpy as np

from app.inference.preprocessing import letterbox, to_model_input


def test_letterbox_outputs_square_target_size():
    img = np.zeros((900, 1800, 3), dtype=np.uint8)
    padded, ratio, (pad_x, pad_y) = letterbox(img, 1024)
    assert padded.shape == (1024, 1024, 3)
    # wider image -> scaled by width, vertical padding
    assert ratio == 1024 / 1800
    assert pad_y > 0
    assert pad_x == 0


def test_to_model_input_shape_and_range():
    padded = np.full((1024, 1024, 3), 255, dtype=np.uint8)
    tensor = to_model_input(padded)
    assert tensor.shape == (1, 3, 1024, 1024)
    assert tensor.dtype == np.float32
    assert tensor.max() <= 1.0 and tensor.min() >= 0.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_preprocessing.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/inference/preprocessing.py**

```python
import cv2
import numpy as np


def letterbox(image_bgr: np.ndarray, new_size: int) -> tuple[np.ndarray, float, tuple[int, int]]:
    h, w = image_bgr.shape[:2]
    ratio = new_size / max(h, w)
    new_w, new_h = int(round(w * ratio)), int(round(h * ratio))
    resized = cv2.resize(image_bgr, (new_w, new_h), interpolation=cv2.INTER_LINEAR)

    pad_x = (new_size - new_w) // 2
    pad_y = (new_size - new_h) // 2
    padded = np.full((new_size, new_size, 3), 114, dtype=np.uint8)
    padded[pad_y:pad_y + new_h, pad_x:pad_x + new_w] = resized
    return padded, ratio, (pad_x, pad_y)


def to_model_input(padded_bgr: np.ndarray) -> np.ndarray:
    rgb = cv2.cvtColor(padded_bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    chw = np.transpose(rgb, (2, 0, 1))
    return np.expand_dims(chw, axis=0).astype(np.float32)
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_preprocessing.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/inference/preprocessing.py dentalcare-ai-service/tests/test_preprocessing.py
git commit -m "feat(ai-service): YOLO letterbox preprocessing"
```

---

### Task 5: YOLO postprocessing (NMS + rescale to original)

**Files:**
- Create: `app/inference/postprocessing.py`
- Create: `tests/test_postprocessing.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `iou_xyxy(a: list[float], b: list[float]) -> float`. `nms(boxes: list[list[float]], scores: list[float], iou_threshold: float) -> list[int]` returning kept indices. `parse_yolo_output(output: np.ndarray, num_classes: int, conf_threshold: float, iou_threshold: float, ratio: float, pad: tuple[int,int]) -> list[dict]` returning detections `{class_id, confidence, bbox_xyxy}` in original-image coords. Output tensor convention: Ultralytics YOLOv8 ONNX shape `(1, 4+num_classes, N)`; box is `cx,cy,w,h` in letterboxed pixel space.

- [ ] **Step 1: Write failing test — tests/test_postprocessing.py**

```python
import numpy as np

from app.inference.postprocessing import iou_xyxy, nms, parse_yolo_output


def test_iou_identical_boxes_is_one():
    assert iou_xyxy([0, 0, 10, 10], [0, 0, 10, 10]) == 1.0


def test_iou_disjoint_boxes_is_zero():
    assert iou_xyxy([0, 0, 10, 10], [20, 20, 30, 30]) == 0.0


def test_nms_drops_overlapping_lower_score():
    boxes = [[0, 0, 10, 10], [1, 1, 11, 11], [100, 100, 110, 110]]
    scores = [0.9, 0.8, 0.7]
    kept = nms(boxes, scores, iou_threshold=0.5)
    assert 0 in kept and 2 in kept and 1 not in kept


def test_parse_yolo_output_rescales_to_original():
    # one detection, class 1, high conf, centered box in 1024 letterbox space
    num_classes = 4
    out = np.zeros((1, 4 + num_classes, 1), dtype=np.float32)
    out[0, 0, 0] = 512  # cx
    out[0, 1, 0] = 512  # cy
    out[0, 2, 0] = 100  # w
    out[0, 3, 0] = 100  # h
    out[0, 4 + 1, 0] = 0.9  # class 1 score
    # ratio 0.5, no padding -> original coords doubled
    dets = parse_yolo_output(out, num_classes, conf_threshold=0.25,
                             iou_threshold=0.45, ratio=0.5, pad=(0, 0))
    assert len(dets) == 1
    d = dets[0]
    assert d["class_id"] == 1
    assert d["confidence"] == 0.9
    # cx-w/2=462 -> /0.5 = 924
    assert d["bbox_xyxy"] == [924, 924, 1124, 1124]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_postprocessing.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/inference/postprocessing.py**

```python
import numpy as np


def iou_xyxy(a: list[float], b: list[float]) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter == 0:
        return 0.0
    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


def nms(boxes: list[list[float]], scores: list[float], iou_threshold: float) -> list[int]:
    order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
    kept: list[int] = []
    while order:
        i = order.pop(0)
        kept.append(i)
        order = [j for j in order if iou_xyxy(boxes[i], boxes[j]) < iou_threshold]
    return kept


def parse_yolo_output(output: np.ndarray, num_classes: int, conf_threshold: float,
                      iou_threshold: float, ratio: float, pad: tuple[int, int]) -> list[dict]:
    # output: (1, 4+num_classes, N) -> (N, 4+num_classes)
    preds = np.squeeze(output, axis=0).transpose(1, 0)
    pad_x, pad_y = pad

    boxes: list[list[float]] = []
    scores: list[float] = []
    class_ids: list[int] = []
    for row in preds:
        cls_scores = row[4:4 + num_classes]
        class_id = int(np.argmax(cls_scores))
        conf = float(cls_scores[class_id])
        if conf < conf_threshold:
            continue
        cx, cy, w, h = row[0], row[1], row[2], row[3]
        x1 = (cx - w / 2 - pad_x) / ratio
        y1 = (cy - h / 2 - pad_y) / ratio
        x2 = (cx + w / 2 - pad_x) / ratio
        y2 = (cy + h / 2 - pad_y) / ratio
        boxes.append([x1, y1, x2, y2])
        scores.append(conf)
        class_ids.append(class_id)

    kept = nms(boxes, scores, iou_threshold)
    detections: list[dict] = []
    for i in kept:
        x1, y1, x2, y2 = boxes[i]
        detections.append({
            "class_id": class_ids[i],
            "confidence": round(scores[i], 4),
            "bbox_xyxy": [int(round(x1)), int(round(y1)), int(round(x2)), int(round(y2))],
        })
    return detections
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_postprocessing.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/inference/postprocessing.py dentalcare-ai-service/tests/test_postprocessing.py
git commit -m "feat(ai-service): YOLO postprocessing (IoU, NMS, rescale)"
```

---

### Task 6: OnnxYoloDetector

**Files:**
- Create: `app/inference/onnx_yolo.py`
- Create: `tests/test_onnx_yolo.py`

**Interfaces:**
- Consumes: `letterbox`, `to_model_input` (Task 4); `parse_yolo_output` (Task 5).
- Produces: `OnnxYoloDetector(model_path, class_names: dict[int,str], input_size, conf_threshold, iou_threshold)` with `predict(image_bgr) -> list[dict]` where each dict is `{class_id, class_name, confidence, bbox_xyxy}`. The detector lazily creates its `onnxruntime.InferenceSession` and logs the output shape on first inference.

- [ ] **Step 1: Write failing test — tests/test_onnx_yolo.py**

```python
from unittest.mock import MagicMock

import numpy as np

from app.inference import onnx_yolo
from app.inference.onnx_yolo import OnnxYoloDetector


def test_predict_maps_class_names(monkeypatch):
    fake_session = MagicMock()
    fake_session.get_inputs.return_value = [MagicMock(name="images")]
    fake_session.get_inputs.return_value[0].name = "images"
    # one detection class 1
    out = np.zeros((1, 4 + 2, 1), dtype=np.float32)
    out[0, 0, 0] = 100; out[0, 1, 0] = 100; out[0, 2, 0] = 20; out[0, 3, 0] = 20
    out[0, 4 + 1, 0] = 0.9
    fake_session.run.return_value = [out]

    monkeypatch.setattr(onnx_yolo.ort, "InferenceSession", lambda *a, **k: fake_session)

    det = OnnxYoloDetector("x.onnx", {0: "A", 1: "B"}, input_size=1024,
                           conf_threshold=0.25, iou_threshold=0.45)
    image = np.zeros((512, 512, 3), dtype=np.uint8)
    results = det.predict(image)
    assert len(results) == 1
    assert results[0]["class_name"] == "B"
    assert results[0]["class_id"] == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_onnx_yolo.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/inference/onnx_yolo.py**

```python
import numpy as np
import onnxruntime as ort

from app.inference.postprocessing import parse_yolo_output
from app.inference.preprocessing import letterbox, to_model_input
from app.utils.logging import log_event


class OnnxYoloDetector:
    def __init__(self, model_path: str, class_names: dict[int, str], input_size: int,
                 conf_threshold: float, iou_threshold: float):
        self.model_path = model_path
        self.class_names = class_names
        self.input_size = input_size
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self._session: ort.InferenceSession | None = None
        self._logged_shape = False

    def _ensure_session(self) -> ort.InferenceSession:
        if self._session is None:
            self._session = ort.InferenceSession(
                self.model_path, providers=["CPUExecutionProvider"]
            )
        return self._session

    def is_loaded(self) -> bool:
        import os
        return os.path.exists(self.model_path)

    def predict(self, image_bgr: np.ndarray) -> list[dict]:
        session = self._ensure_session()
        padded, ratio, pad = letterbox(image_bgr, self.input_size)
        tensor = to_model_input(padded)
        input_name = session.get_inputs()[0].name
        outputs = session.run(None, {input_name: tensor})
        output = outputs[0]
        if not self._logged_shape:
            log_event("onnx_output_shape", model=self.model_path, shape=list(output.shape))
            self._logged_shape = True
        dets = parse_yolo_output(
            output, num_classes=len(self.class_names),
            conf_threshold=self.conf_threshold, iou_threshold=self.iou_threshold,
            ratio=ratio, pad=pad,
        )
        for d in dets:
            d["class_name"] = self.class_names[d["class_id"]]
        return dets
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_onnx_yolo.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/inference/onnx_yolo.py dentalcare-ai-service/tests/test_onnx_yolo.py
git commit -m "feat(ai-service): OnnxYoloDetector with lazy session + shape logging"
```

---

### Task 7: Matching pipeline (FDI ↔ disease)

**Files:**
- Create: `app/inference/pipeline.py`
- Create: `tests/test_matching.py`

**Interfaces:**
- Consumes: `iou_xyxy` (Task 5). Class maps from Global Constraints.
- Produces: `FDI_CLASS_NAMES: dict[int,str]`, `DISEASE_CLASS_NAMES: dict[int,str]`. `match_detections(fdi_dets: list[dict], disease_dets: list[dict], iou_threshold: float, center_fallback: bool) -> list[dict]` where each result dict is `{tooth: str|None, disease: str, disease_confidence: float, fdi_confidence: float|None, bbox_xyxy: list[int], matching_method: str, matching_score: float|None, needs_review: bool}`. `tooth` is the FDI string (e.g. `"16"`); `matching_method` ∈ `{"iou","center","none"}`.

- [ ] **Step 1: Write failing test — tests/test_matching.py**

```python
from app.inference.pipeline import match_detections


def _fdi(tooth_box, name="16", conf=0.8):
    return {"class_name": name, "confidence": conf, "bbox_xyxy": tooth_box}


def _dis(box, name="Caries", conf=0.7):
    return {"class_name": name, "confidence": conf, "bbox_xyxy": box}


def test_match_by_iou_assigns_tooth():
    fdi = [_fdi([100, 100, 200, 300], name="16")]
    disease = [_dis([110, 120, 190, 280])]
    out = match_detections(fdi, disease, iou_threshold=0.10, center_fallback=True)
    assert out[0]["tooth"] == "16"
    assert out[0]["matching_method"] == "iou"
    assert out[0]["needs_review"] is False


def test_match_by_center_fallback_when_iou_low():
    # tiny disease box fully inside large tooth box, low IoU
    fdi = [_fdi([0, 0, 1000, 1000], name="36")]
    disease = [_dis([500, 500, 510, 510])]
    out = match_detections(fdi, disease, iou_threshold=0.90, center_fallback=True)
    assert out[0]["tooth"] == "36"
    assert out[0]["matching_method"] == "center"


def test_no_match_sets_needs_review():
    fdi = [_fdi([0, 0, 100, 100], name="11")]
    disease = [_dis([500, 500, 520, 520])]
    out = match_detections(fdi, disease, iou_threshold=0.10, center_fallback=True)
    assert out[0]["tooth"] is None
    assert out[0]["matching_method"] == "none"
    assert out[0]["needs_review"] is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_matching.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/inference/pipeline.py**

```python
from app.inference.postprocessing import iou_xyxy

FDI_CLASS_NAMES: dict[int, str] = {
    0: "11", 1: "12", 2: "13", 3: "14", 4: "15", 5: "16", 6: "17", 7: "18",
    8: "21", 9: "22", 10: "23", 11: "24", 12: "25", 13: "26", 14: "27", 15: "28",
    16: "31", 17: "32", 18: "33", 19: "34", 20: "35", 21: "36", 22: "37", 23: "38",
    24: "41", 25: "42", 26: "43", 27: "44", 28: "45", 29: "46", 30: "47", 31: "48",
}

DISEASE_CLASS_NAMES: dict[int, str] = {
    0: "Impacted", 1: "Caries", 2: "Periapical_Lesion", 3: "Deep_Caries",
}


def _center_inside(box: list[float], container: list[float]) -> bool:
    cx = (box[0] + box[2]) / 2
    cy = (box[1] + box[3]) / 2
    return container[0] <= cx <= container[2] and container[1] <= cy <= container[3]


def match_detections(fdi_dets: list[dict], disease_dets: list[dict],
                     iou_threshold: float, center_fallback: bool) -> list[dict]:
    results: list[dict] = []
    for dis in disease_dets:
        dbox = dis["bbox_xyxy"]
        best_iou, best_fdi = 0.0, None
        for fdi in fdi_dets:
            score = iou_xyxy(dbox, fdi["bbox_xyxy"])
            if score > best_iou:
                best_iou, best_fdi = score, fdi

        tooth, method, fdi_conf, match_score = None, "none", None, None
        if best_fdi is not None and best_iou >= iou_threshold:
            tooth = best_fdi["class_name"]
            method = "iou"
            fdi_conf = best_fdi["confidence"]
            match_score = round(best_iou, 4)
        elif center_fallback:
            for fdi in fdi_dets:
                if _center_inside(dbox, fdi["bbox_xyxy"]):
                    tooth = fdi["class_name"]
                    method = "center"
                    fdi_conf = fdi["confidence"]
                    match_score = round(iou_xyxy(dbox, fdi["bbox_xyxy"]), 4)
                    break

        results.append({
            "tooth": tooth,
            "disease": dis["class_name"],
            "disease_confidence": dis["confidence"],
            "fdi_confidence": fdi_conf,
            "bbox_xyxy": dbox,
            "matching_method": method,
            "matching_score": match_score,
            "needs_review": tooth is None,
        })
    return results
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_matching.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/inference/pipeline.py dentalcare-ai-service/tests/test_matching.py
git commit -m "feat(ai-service): FDI/disease matching (IoU + center fallback)"
```

---

### Task 8: Annotated image visualization (quadrant colors)

**Files:**
- Create: `app/inference/visualization.py`
- Create: `tests/test_visualization.py`

**Interfaces:**
- Consumes: detections from `match_detections` (Task 7).
- Produces: `quadrant_color(tooth: str | None) -> tuple[int,int,int]` returning BGR. `draw_detections(image_bgr: np.ndarray, detections: list[dict]) -> np.ndarray` returning annotated copy with colored boxes + `{FDI} {disease}` labels.

- [ ] **Step 1: Write failing test — tests/test_visualization.py**

```python
import numpy as np

from app.inference.visualization import draw_detections, quadrant_color


def test_quadrant_color_q1_green_bgr():
    # #57C84D -> RGB(87,200,77) -> BGR(77,200,87)
    assert quadrant_color("16") == (77, 200, 87)


def test_quadrant_color_null_is_grey():
    # #9E9E9E -> (158,158,158)
    assert quadrant_color(None) == (158, 158, 158)


def test_draw_detections_returns_same_shape_copy():
    img = np.zeros((400, 400, 3), dtype=np.uint8)
    dets = [{"tooth": "36", "disease": "Caries", "bbox_xyxy": [10, 10, 100, 100]}]
    out = draw_detections(img, dets)
    assert out.shape == img.shape
    # original untouched (a copy was drawn on)
    assert img.sum() == 0
    assert out.sum() > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_visualization.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/inference/visualization.py**

```python
import cv2
import numpy as np

# RGB hex per quadrant (first FDI digit)
_QUADRANT_RGB = {
    "1": (0x57, 0xC8, 0x4D),
    "2": (0xE8, 0x4D, 0x4D),
    "3": (0x4D, 0xC8, 0xE8),
    "4": (0xE8, 0xC8, 0x4D),
}
_NULL_RGB = (0x9E, 0x9E, 0x9E)


def quadrant_color(tooth: str | None) -> tuple[int, int, int]:
    rgb = _QUADRANT_RGB.get(tooth[0], _NULL_RGB) if tooth else _NULL_RGB
    r, g, b = rgb
    return (b, g, r)  # OpenCV uses BGR


def draw_detections(image_bgr: np.ndarray, detections: list[dict]) -> np.ndarray:
    out = image_bgr.copy()
    for d in detections:
        x1, y1, x2, y2 = d["bbox_xyxy"]
        color = quadrant_color(d.get("tooth"))
        label = f"{d['tooth']} {d['disease']}" if d.get("tooth") else f"? {d['disease']}"
        cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(out, (x1, y1 - th - 4), (x1 + tw, y1), color, -1)
        cv2.putText(out, label, (x1, y1 - 4), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                    (0, 0, 0), 1, cv2.LINE_AA)
    return out
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_visualization.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/inference/visualization.py dentalcare-ai-service/tests/test_visualization.py
git commit -m "feat(ai-service): annotated image with quadrant colors"
```

---

### Task 9: HMAC callback client

**Files:**
- Create: `app/callback.py`
- Create: `tests/test_callback.py`

**Interfaces:**
- Consumes: `app.config.get_settings`.
- Produces: `sign_body(body: bytes, secret: str) -> str` (hex HMAC-SHA256). `send_callback(payload: dict) -> bool` — serializes payload, signs raw bytes, POSTs to `AI_CALLBACK_URL` with header `X-AI-Signature`, retries `CALLBACK_RETRIES` times with exponential backoff, returns success bool (never raises).

- [ ] **Step 1: Write failing test — tests/test_callback.py**

```python
import hashlib
import hmac
from unittest.mock import MagicMock

from app import callback
from app.callback import send_callback, sign_body


def test_sign_body_matches_hmac_sha256():
    body = b'{"a":1}'
    expected = hmac.new(b"secret", body, hashlib.sha256).hexdigest()
    assert sign_body(body, "secret") == expected


def test_send_callback_posts_with_signature(monkeypatch):
    captured = {}

    def fake_post(url, content=None, headers=None, timeout=None):
        captured["url"] = url
        captured["headers"] = headers
        resp = MagicMock(); resp.status_code = 200
        return resp

    monkeypatch.setattr(callback.httpx, "post", fake_post)
    ok = send_callback({"job_id": "j1", "status": "completed"})
    assert ok is True
    assert "X-AI-Signature" in captured["headers"]


def test_send_callback_returns_false_after_retries(monkeypatch):
    def fake_post(*a, **k):
        raise callback.httpx.ConnectError("down")

    monkeypatch.setattr(callback.httpx, "post", fake_post)
    monkeypatch.setattr(callback.time, "sleep", lambda *_: None)
    assert send_callback({"job_id": "j1"}) is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_callback.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/callback.py**

```python
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
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_callback.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/callback.py dentalcare-ai-service/tests/test_callback.py
git commit -m "feat(ai-service): HMAC callback client with retries"
```

---

### Task 10: Pydantic schemas

**Files:**
- Create: `app/schemas.py`
- Create: `tests/test_schemas.py`

**Interfaces:**
- Produces: `InferenceJobRequest`, `JobCreatedResponse`, `DetectionOut`, `JobStatusResponse`, `ModelsStatusResponse`, `AnnotationRequest`. Field names match spec §6.3 / §16.

- [ ] **Step 1: Write failing test — tests/test_schemas.py**

```python
from app.schemas import InferenceJobRequest


def test_inference_request_defaults_and_metadata():
    req = InferenceJobRequest(
        patient_id="P1", document_id="D1", schema_name="t_9d754153",
        image_bucket="dc-t-9d754153",
        image_object_key="patients/P1/D1/panoramic.png",
        output_bucket="dc-t-9d754153",
        output_prefix="patients/P1/D1/ai/A1/",
        analysis_id="A1",
    )
    assert req.save_annotated_image is True
    assert req.metadata == {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_schemas.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/schemas.py**

```python
from pydantic import BaseModel, Field


class InferenceJobRequest(BaseModel):
    patient_id: str
    document_id: str
    analysis_id: str
    schema_name: str
    image_bucket: str
    image_object_key: str
    output_bucket: str
    output_prefix: str
    save_annotated_image: bool = True
    metadata: dict = Field(default_factory=dict)


class JobCreatedResponse(BaseModel):
    job_id: str
    status: str


class DetectionOut(BaseModel):
    tooth: str | None
    disease: str
    disease_confidence: float
    fdi_confidence: float | None
    bbox_xyxy: list[int]
    matching_method: str
    matching_score: float | None
    needs_review: bool


class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    result_object_key: str | None = None
    annotated_image_object_key: str | None = None
    detections: list[DetectionOut] = Field(default_factory=list)
    error: str | None = None


class ModelInfo(BaseModel):
    name: str
    path: str
    loaded: bool


class ModelsStatusResponse(BaseModel):
    runtime: str
    providers: list[str]
    models: dict[str, ModelInfo]


class AnnotationRequest(BaseModel):
    patient_id: str
    study_id: str | None = None
    image_bucket: str
    image_object_key: str
    annotation_bucket: str
    annotation_object_key: str
    reviewer: dict = Field(default_factory=dict)
    annotations: list[dict] = Field(default_factory=list)
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_schemas.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/schemas.py dentalcare-ai-service/tests/test_schemas.py
git commit -m "feat(ai-service): Pydantic request/response schemas"
```

---

### Task 11: Job service (run inference, persist to MinIO, callback)

**Files:**
- Create: `app/services/job_service.py`
- Create: `tests/test_job_service.py`

**Interfaces:**
- Consumes: `MinioClient` (Task 3), `OnnxYoloDetector` (Task 6), `match_detections` + class maps (Task 7), `draw_detections` (Task 8), `send_callback` (Task 9), `InferenceJobRequest` (Task 10).
- Produces: `JobService(minio, fdi_detector, disease_detector, settings)` with `run_job(job_id: str, req: InferenceJobRequest) -> None` (the BackgroundTask body) and `read_job(bucket: str, job_id: str) -> dict`. Writes index `ai/jobs/{job_id}.json`, `result.json`, `annotated.png` under `req.output_prefix`. Calls `send_callback` at the end.

- [ ] **Step 1: Write failing test — tests/test_job_service.py**

```python
from unittest.mock import MagicMock

import numpy as np

from app.config import get_settings
from app.schemas import InferenceJobRequest
from app.services.job_service import JobService


def _req():
    return InferenceJobRequest(
        patient_id="P1", document_id="D1", analysis_id="A1", schema_name="t_x",
        image_bucket="dc-t-x", image_object_key="patients/P1/D1/pano.png",
        output_bucket="dc-t-x", output_prefix="patients/P1/D1/ai/A1/",
    )


def test_run_job_writes_result_and_calls_callback(monkeypatch):
    minio = MagicMock()
    # download writes a fake image file; patch cv2.imread to return an array
    import app.services.job_service as js
    monkeypatch.setattr(js.cv2, "imread", lambda p: np.zeros((200, 200, 3), dtype=np.uint8))
    monkeypatch.setattr(js.cv2, "imwrite", lambda p, im: True)
    sent = {}
    monkeypatch.setattr(js, "send_callback", lambda payload: sent.update(payload) or True)

    fdi = MagicMock(); fdi.predict.return_value = [
        {"class_id": 5, "class_name": "16", "confidence": 0.8, "bbox_xyxy": [10, 10, 90, 90]}]
    disease = MagicMock(); disease.predict.return_value = [
        {"class_id": 1, "class_name": "Caries", "confidence": 0.7, "bbox_xyxy": [20, 20, 80, 80]}]

    svc = JobService(minio, fdi, disease, get_settings())
    svc.run_job("job-1", _req())

    # result.json + annotated.png + final index uploaded
    assert minio.upload_json.called
    assert sent["status"] == "completed"
    assert sent["job_id"] == "job-1"
    assert sent["detections"][0]["tooth"] == "16"


def test_run_job_failure_sets_failed_status(monkeypatch):
    minio = MagicMock()
    minio.download_object.side_effect = RuntimeError("minio down")
    import app.services.job_service as js
    sent = {}
    monkeypatch.setattr(js, "send_callback", lambda payload: sent.update(payload) or True)

    svc = JobService(minio, MagicMock(), MagicMock(), get_settings())
    svc.run_job("job-2", _req())
    assert sent["status"] == "failed"
    assert "error" in sent
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_job_service.py -v`
Expected: FAIL (cannot import)

- [ ] **Step 3: Implement app/services/job_service.py**

```python
import os
import shutil
from datetime import datetime, timezone

import cv2

from app.callback import send_callback
from app.config import Settings
from app.inference.pipeline import match_detections
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
        import json
        tmp = os.path.join(self.settings.tmp_dir, f"{job_id}-index.json")
        os.makedirs(os.path.dirname(tmp), exist_ok=True)
        self.minio.download_object(bucket, self._index_key(job_id), tmp)
        with open(tmp) as fh:
            return json.load(fh)

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
                from app.inference.visualization import draw_detections
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
            send_callback({
                "job_id": job_id, "status": "failed",
                "schema_name": req.schema_name, "patient_id": req.patient_id,
                "document_id": req.document_id, "analysis_id": req.analysis_id,
                "error": str(exc),
            })
        finally:
            if not self.settings.save_debug_files:
                shutil.rmtree(work_dir, ignore_errors=True)
```

- [ ] **Step 4: Run test**

Run: `pytest tests/test_job_service.py -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/app/services/job_service.py dentalcare-ai-service/tests/test_job_service.py
git commit -m "feat(ai-service): job service (inference -> MinIO -> callback)"
```

---

### Task 12: Detector registry + inference/models routers wired into app

**Files:**
- Create: `app/services/registry.py`
- Create: `app/routers/models.py`
- Create: `app/routers/inference.py`
- Modify: `app/main.py` (include the two routers under `API_PREFIX`)
- Create: `tests/test_inference_router.py`

**Interfaces:**
- Consumes: `OnnxYoloDetector` (Task 6), `JobService` (Task 11), `require_jwt` (Task 2), schemas (Task 10), class maps (Task 7).
- Produces: `app.services.registry.get_fdi_detector()`, `get_disease_detector()`, `get_job_service()` (cached). Endpoints: `GET {API_PREFIX}/models/status`; `POST {API_PREFIX}/inference/jobs` → 200 `JobCreatedResponse` (schedules BackgroundTask); `GET {API_PREFIX}/inference/jobs/{job_id}?result_bucket=...` → `JobStatusResponse`.

- [ ] **Step 1: Implement app/services/registry.py**

```python
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
                            s.fdi_conf_threshold, s.model_iou_threshold)


@lru_cache
def get_disease_detector() -> OnnxYoloDetector:
    s = get_settings()
    return OnnxYoloDetector(s.disease_model_path, DISEASE_CLASS_NAMES, s.disease_input_size,
                            s.disease_conf_threshold, s.model_iou_threshold)


@lru_cache
def get_job_service() -> JobService:
    return JobService(get_minio(), get_fdi_detector(), get_disease_detector(), get_settings())
```

- [ ] **Step 2: Implement app/routers/models.py**

```python
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
```

- [ ] **Step 3: Implement app/routers/inference.py**

```python
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
```

- [ ] **Step 4: Modify app/main.py to include routers**

Replace the body of `app/main.py` with:

```python
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
```

- [ ] **Step 5: Write test — tests/test_inference_router.py**

```python
import time

import jwt
from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app

client = TestClient(app)
SECRET = get_settings().jwt_secret


def _auth():
    token = jwt.encode({"sub": "u1", "schemaName": "t_x", "exp": int(time.time()) + 60},
                       SECRET, algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}


def test_create_job_requires_jwt():
    resp = client.post("/api/v1/inference/jobs", json={})
    assert resp.status_code == 401


def test_create_job_returns_queued(monkeypatch):
    import app.routers.inference as inf
    monkeypatch.setattr(inf, "get_job_service", lambda: type("S", (), {"run_job": lambda *a: None})())
    payload = {
        "patient_id": "P1", "document_id": "D1", "analysis_id": "A1", "schema_name": "t_x",
        "image_bucket": "dc-t-x", "image_object_key": "patients/P1/D1/p.png",
        "output_bucket": "dc-t-x", "output_prefix": "patients/P1/D1/ai/A1/",
    }
    resp = client.post("/api/v1/inference/jobs", json=payload, headers=_auth())
    assert resp.status_code == 200
    assert resp.json()["status"] == "queued"
    assert resp.json()["job_id"].startswith("ai-job-")
```

- [ ] **Step 6: Run tests**

Run: `pytest tests/test_inference_router.py tests/test_health.py -v`
Expected: PASS (3 passed)

- [ ] **Step 7: Commit**

```bash
git add dentalcare-ai-service/app/services/registry.py dentalcare-ai-service/app/routers/models.py dentalcare-ai-service/app/routers/inference.py dentalcare-ai-service/app/main.py dentalcare-ai-service/tests/test_inference_router.py
git commit -m "feat(ai-service): models/status + inference job endpoints"
```

---

### Task 13: Annotations + retraining stub routers

**Files:**
- Create: `app/routers/annotations.py`
- Create: `app/routers/retraining.py`
- Modify: `app/main.py` (include both routers)
- Create: `tests/test_annotations_router.py`

**Interfaces:**
- Consumes: `require_jwt` (Task 2), `MinioClient` via `get_minio` (Task 3), `AnnotationRequest` (Task 10).
- Produces: `POST {API_PREFIX}/annotations` → saves reviewed annotations JSON to MinIO + writes a training sample pointer under `ai/training/pending/`. `POST {API_PREFIX}/retraining/export-dataset` → `501 Not Implemented`.

- [ ] **Step 1: Implement app/routers/annotations.py**

```python
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
```

- [ ] **Step 2: Implement app/routers/retraining.py**

```python
from fastapi import APIRouter, Depends, HTTPException

from app.security import require_jwt

router = APIRouter()


@router.post("/retraining/export-dataset")
def export_dataset(_claims: dict = Depends(require_jwt)) -> dict:
    raise HTTPException(status_code=501, detail="Retraining export not implemented yet")
```

- [ ] **Step 3: Modify app/main.py — add the two includes**

Append after the existing `app.include_router(inference.router, ...)` line, and extend the import:

```python
from app.routers import annotations, health, inference, models, retraining
```

```python
app.include_router(annotations.router, prefix=settings.api_prefix)
app.include_router(retraining.router, prefix=settings.api_prefix)
```

- [ ] **Step 4: Write test — tests/test_annotations_router.py**

```python
import time

import jwt
from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app

client = TestClient(app)
SECRET = get_settings().jwt_secret


def _auth():
    token = jwt.encode({"sub": "u1", "exp": int(time.time()) + 60}, SECRET, algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}


def test_retraining_stub_returns_501():
    resp = client.post("/api/v1/retraining/export-dataset", headers=_auth(), json={})
    assert resp.status_code == 501


def test_annotations_saves_and_returns_keys(monkeypatch):
    import app.routers.annotations as ann
    fake = type("M", (), {"upload_json": lambda *a, **k: None})()
    monkeypatch.setattr(ann, "get_minio", lambda: fake)
    payload = {
        "patient_id": "P1", "study_id": "S1",
        "image_bucket": "dc-t-x", "image_object_key": "patients/P1/D1/p.png",
        "annotation_bucket": "dc-t-x",
        "annotation_object_key": "patients/P1/D1/ai/A1/reviewed.json",
        "reviewer": {"user_id": "DENTIST-1"}, "annotations": [],
    }
    resp = client.post("/api/v1/annotations", json=payload, headers=_auth())
    assert resp.status_code == 200
    assert resp.json()["status"] == "saved"
    assert resp.json()["training_sample_object_key"] == "ai/training/pending/S1.json"
```

- [ ] **Step 5: Run tests**

Run: `pytest tests/test_annotations_router.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: Run full suite**

Run: `pytest -v`
Expected: PASS (all tests green)

- [ ] **Step 7: Commit**

```bash
git add dentalcare-ai-service/app/routers/annotations.py dentalcare-ai-service/app/routers/retraining.py dentalcare-ai-service/app/main.py dentalcare-ai-service/tests/test_annotations_router.py
git commit -m "feat(ai-service): annotations endpoint + retraining stub"
```

---

### Task 14: Dockerfile, docker-compose wiring, README

**Files:**
- Create: `Dockerfile`
- Create: `README.md`
- Modify: `../docker-compose.yml` (add `dentalcare-ai-service` service)

**Interfaces:**
- Consumes: nothing (packaging task).
- Produces: runnable container `dentalcare-ai-service` on the `dentalcarepro` network, reachable by the backend at `http://dentalcare-ai-service:8000`.

- [ ] **Step 1: Dockerfile**

```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app /app/app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

> Models are NOT copied into the image — they are mounted read-only at `/app/models` via docker-compose so they can be swapped without rebuild.

- [ ] **Step 2: Add service to ../docker-compose.yml**

Add this service under `services:` in the repo-root `docker-compose.yml` (alongside `backend` and `frontend`):

```yaml
  dentalcare-ai-service:
    build:
      context: ./dentalcare-ai-service
      dockerfile: Dockerfile
    image: dentalcare-ai-service:${VERSION:-latest}
    container_name: dentalcare-ai-service
    restart: unless-stopped
    env_file:
      - ./dentalcare-ai-service/.env
    volumes:
      - ./dentalcare-ai-service/models:/app/models:ro
      - ./dentalcare-ai-service/tmp:/tmp/dentalcare-ai
    extra_hosts:
      - "host.docker.internal:host-gateway"
    deploy:
      resources:
        limits:
          memory: 2g
    networks:
      - dentalcarepro
```

> Do not expose a host port: only the backend (same network) calls it via `http://dentalcare-ai-service:8000`. Add a port mapping only for local debugging.

- [ ] **Step 3: README.md**

```markdown
# dentalcare-ai-service

AI inference microservice for DentalCare: two cascaded ONNX YOLO models
(FDI teeth + dental disease) on panoramic X-rays.

## Prerequisites
Place the exported ONNX models in `./models/`:
- `dentex_fdi_v1.onnx`
- `dentex_disease_v1.onnx`

Export from Ultralytics:
```python
from ultralytics import YOLO
YOLO('runs/dentex_fdi_v1/weights/best.pt').export(format='onnx', imgsz=1024, simplify=True)
YOLO('runs/dentex_disease_v1/weights/best.pt').export(format='onnx', imgsz=1024, simplify=True)
```

## Config
Copy `.env.example` to `.env`. `JWT_SECRET` MUST equal the backend's
`app.jwt.secret`; `AI_CALLBACK_SECRET` MUST equal the backend's `app.ai.hmac-secret`.

## Run (standalone, local)
```bash
cp .env.example .env
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
curl http://localhost:8000/health
```

## Run (Docker, with DentalCare)
From repo root: `docker compose up -d --build dentalcare-ai-service`

## Tests
`pytest -v`

## Notes
- CPU-only (onnxruntime). GPU is out of scope for this version.
- The service is stateless w.r.t. DentalCare's DB; results live on MinIO and
  are reported to the backend via an HMAC-signed callback.
- AI output is decision support: `AI-generated, requires clinician review`.
```

- [ ] **Step 4: Build the image to verify it compiles**

Run: `cd dentalcare-ai-service && docker build -t dentalcare-ai-service:test .`
Expected: build succeeds (image built).

- [ ] **Step 5: Commit**

```bash
git add dentalcare-ai-service/Dockerfile dentalcare-ai-service/README.md docker-compose.yml
git commit -m "feat(ai-service): Dockerfile, compose wiring, README"
```

---

## Notes for the executor

- Run every `pytest` and `git` command from inside `dentalcare-ai-service/` except the compose edit in Task 14 (repo root).
- The two ONNX model files are a manual prerequisite (P0) and are gitignored; tests mock inference, so the suite passes without them. `models/status` reports `loaded:false` until they are present.
- This plan delivers the standalone service. The DentalCare side (bucket-per-tenant, DB tables, Spring proxy, SSE, odontogram sync, Angular overlay) is Plan B — it consumes this service's `POST /api/v1/inference/jobs` contract and the HMAC callback payload defined in Task 9/11.
```

