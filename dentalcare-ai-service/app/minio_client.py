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
