import hashlib
import hmac
import json
from unittest.mock import MagicMock

from app import callback
from app.callback import send_callback, sign_body
from app.config import get_settings


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

    # Assert signature value equals independent HMAC over exact serialized body
    expected_body = json.dumps({"job_id": "j1", "status": "completed"}, default=str).encode("utf-8")
    expected_sig = hmac.new(get_settings().ai_callback_secret.encode("utf-8"), expected_body, hashlib.sha256).hexdigest()
    assert captured["headers"]["X-AI-Signature"] == expected_sig


def test_send_callback_returns_false_after_retries(monkeypatch):
    def fake_post(*a, **k):
        raise callback.httpx.ConnectError("down")

    monkeypatch.setattr(callback.httpx, "post", fake_post)
    monkeypatch.setattr(callback.time, "sleep", lambda *_: None)
    assert send_callback({"job_id": "j1"}) is False


def test_send_callback_returns_false_on_persistent_500(monkeypatch):
    def fake_post(*a, **k):
        resp = MagicMock(); resp.status_code = 500
        return resp
    monkeypatch.setattr(callback.httpx, "post", fake_post)
    monkeypatch.setattr(callback.time, "sleep", lambda *_: None)
    assert send_callback({"job_id": "j1"}) is False
