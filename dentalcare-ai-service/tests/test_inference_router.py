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


def test_get_job_requires_jwt():
    resp = client.get("/api/v1/inference/jobs/ai-job-1?result_bucket=dc-t-x")
    assert resp.status_code == 401


def test_get_job_missing_result_bucket_422():
    resp = client.get("/api/v1/inference/jobs/ai-job-1", headers=_auth())
    assert resp.status_code == 422


def test_get_job_returns_status(monkeypatch):
    import app.routers.inference as inf
    fake = type("S", (), {"read_job": lambda self, b, j: {"job_id": j, "status": "completed", "detections": []}})()
    monkeypatch.setattr(inf, "get_job_service", lambda: fake)
    resp = client.get("/api/v1/inference/jobs/ai-job-1?result_bucket=dc-t-x", headers=_auth())
    assert resp.status_code == 200
    assert resp.json()["status"] == "completed"


def test_get_job_404_on_missing_object(monkeypatch):
    import app.routers.inference as inf
    from minio.error import S3Error
    def boom(self, b, j):
        raise S3Error("NoSuchKey", "Object not found", "ai-job-1", "req-id", "host-id", response=None)
    fake = type("S", (), {"read_job": boom})()
    monkeypatch.setattr(inf, "get_job_service", lambda: fake)
    resp = client.get("/api/v1/inference/jobs/ai-job-1?result_bucket=dc-t-x", headers=_auth())
    assert resp.status_code == 404
