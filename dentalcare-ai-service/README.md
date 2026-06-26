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
