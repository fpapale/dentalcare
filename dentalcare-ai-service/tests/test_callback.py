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
