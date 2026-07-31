"""S3-compatible object storage (MinIO in dev, any S3 in prod).

RAG source files are stored under a **user-scoped key**:
    {user_id}/{document_id}/{filename}
so every object is tied to a UserID (and its document) — access is always
filtered by the owning user at the application layer. Extend the prefix if you
later scope by org/team as well.
"""

from __future__ import annotations

import uuid

import boto3
from botocore.client import Config

from ..config import Settings, get_settings


class ObjectStore:
    def __init__(self, settings: Settings) -> None:
        self._bucket = settings.object_store_bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=settings.object_store_endpoint,
            region_name=settings.object_store_region,
            aws_access_key_id=settings.object_store_access_key,
            aws_secret_access_key=settings.object_store_secret_key,
            config=Config(
                s3={"addressing_style": "path" if settings.object_store_force_path_style else "auto"}
            ),
        )

    def ensure_bucket(self) -> None:
        existing = {b["Name"] for b in self._client.list_buckets().get("Buckets", [])}
        if self._bucket not in existing:
            self._client.create_bucket(Bucket=self._bucket)

    @staticmethod
    def key_for(user_id: uuid.UUID, document_id: uuid.UUID, filename: str) -> str:
        return f"{user_id}/{document_id}/{filename}"

    def put(self, key: str, data: bytes, content_type: str) -> None:
        self._client.put_object(Bucket=self._bucket, Key=key, Body=data, ContentType=content_type)

    def get(self, key: str) -> bytes:
        return self._client.get_object(Bucket=self._bucket, Key=key)["Body"].read()

    def delete(self, key: str) -> None:
        self._client.delete_object(Bucket=self._bucket, Key=key)

    def presigned_get(self, key: str, expires: int = 3600) -> str:
        return self._client.generate_presigned_url(
            "get_object", Params={"Bucket": self._bucket, "Key": key}, ExpiresIn=expires
        )


_singleton: ObjectStore | None = None


def get_object_store(settings: Settings | None = None) -> ObjectStore:
    """Return the object-store client. Explicit settings bypass the singleton."""
    global _singleton
    if settings is not None:
        return ObjectStore(settings)
    if _singleton is None:
        _singleton = ObjectStore(get_settings())
    return _singleton
