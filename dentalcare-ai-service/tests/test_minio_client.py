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
