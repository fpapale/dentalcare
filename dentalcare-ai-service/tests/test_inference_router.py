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
