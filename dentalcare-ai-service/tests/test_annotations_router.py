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
    calls = []
    fake = type("M", (), {"upload_json": lambda self, *a, **k: calls.append(a)})()
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
    assert len(calls) == 2


def test_annotations_unknown_study_id(monkeypatch):
    import app.routers.annotations as ann
    fake = type("M", (), {"upload_json": lambda self, *a, **k: None})()
    monkeypatch.setattr(ann, "get_minio", lambda: fake)
    payload = {
        "patient_id": "P1",
        "image_bucket": "dc-t-x", "image_object_key": "img.png",
        "annotation_bucket": "dc-t-x",
        "annotation_object_key": "ann.json",
        "reviewer": {}, "annotations": [],
    }
    resp = client.post("/api/v1/annotations", json=payload, headers=_auth())
    assert resp.status_code == 200
    assert resp.json()["training_sample_object_key"] == "ai/training/pending/unknown.json"
