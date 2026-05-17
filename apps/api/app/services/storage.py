"""Storage backend abstraction.

Two implementations live here:

  - ``LocalStorageBackend`` writes to a directory on disk and serves files via
    a `/dev-uploads/{key}` endpoint mounted on the FastAPI app. Its "presigned
    upload URL" is just a PUT to a dev endpoint, gated by a short-lived
    HMAC token. This keeps the *client* code identical between dev and
    production — same flow, same shape, just a different host.

  - ``R2StorageBackend`` talks to Cloudflare R2 via the S3-compatible API
    (boto3). Presigned PUTs and GETs are issued by the AWS SigV4 signer.

The factory `get_storage()` picks one based on ``STORAGE_BACKEND``.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import time
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote

from fastapi import Request

from app.config import settings


def request_base_url(request: Request) -> str:
    """FastAPI dependency that returns the trailing-slash-stripped base URL
    the client used to reach the API. Pass the result as ``base_url`` to
    storage calls so dev-uploads URLs come back on the same host the phone
    can reach (the LAN IP, not the server's ``localhost``)."""
    return str(request.base_url).rstrip("/")


@dataclass
class PresignedUpload:
    """What the API hands back to the client after `init_upload`.

    The client PUTs the binary to ``url`` with the listed ``headers``, and
    later POSTs back to /events/{id}/photos/commit with ``key`` so we know
    the object is in place.
    """

    key: str
    url: str
    method: str  # "PUT"
    headers: dict[str, str]
    expires_in: int


class StorageBackend(ABC):
    """Minimal surface every backend must implement.

    We keep this tiny on purpose — the call sites are ``init_upload`` (when
    the client wants to push a photo) and ``public_url`` (when we want to
    hand a viewer something to render). Anything richer (lifecycle rules,
    copy, multi-part) can be added per-backend once it's actually needed.

    Both methods accept an optional ``base_url`` override. The local-file
    backend uses it to issue PUT/GET URLs that point at whatever host the
    *client* used to call the API — so a phone reaching the API on its
    LAN IP gets back upload URLs on that same LAN IP, not on the server's
    configured ``localhost``. The R2 backend ignores it (R2 URLs are
    absolute on the bucket's domain).
    """

    @abstractmethod
    def init_upload(
        self,
        key: str,
        content_type: str,
        *,
        bucket: str | None = None,
        base_url: str | None = None,
    ) -> PresignedUpload:
        ...

    @abstractmethod
    def public_url(
        self,
        key: str,
        *,
        bucket: str | None = None,
        base_url: str | None = None,
    ) -> str:
        ...

    @abstractmethod
    def delete(self, key: str, *, bucket: str | None = None) -> None:
        ...


# ─── Local filesystem backend (dev) ─────────────────────────────────────────


class LocalStorageBackend(StorageBackend):
    """Writes objects to disk under ``STORAGE_LOCAL_DIR`` and serves them
    over HTTP via the `/dev-uploads/{key}` endpoint.

    The "presigned" upload URL is a PUT to that same endpoint, but the body
    must include an `X-Upload-Token` header whose value is HMAC-SHA256
    over ``key|expires_at`` keyed on the server secret. That gives us:

      - The same client flow as R2 (PUT with auth headers).
      - Cheap defense against a random caller writing to arbitrary keys.

    Not appropriate for production — multiple replicas would each see
    different files. Use R2 for anything real.
    """

    def __init__(self, root_dir: str, public_base_url: str, secret_key: str):
        self.root = Path(root_dir).resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        self.public_base = public_base_url.rstrip("/")
        self.secret = secret_key.encode("utf-8")

    # ─ Public-URL signing helpers (used by dev-uploads endpoint too) ─

    def sign(self, key: str, expires_at: int) -> str:
        payload = f"{key}|{expires_at}".encode("utf-8")
        return hmac.new(self.secret, payload, hashlib.sha256).hexdigest()

    def verify(self, key: str, expires_at: int, token: str) -> bool:
        if expires_at < int(time.time()):
            return False
        return hmac.compare_digest(self.sign(key, expires_at), token)

    # ─ StorageBackend surface ─

    def init_upload(
        self,
        key: str,
        content_type: str,
        *,
        bucket: str | None = None,
        base_url: str | None = None,
    ) -> PresignedUpload:
        # 15-minute upload window — generous enough for slow Lagos networks.
        expires_at = int(time.time()) + 15 * 60
        token = self.sign(key, expires_at)
        host = (base_url or self.public_base).rstrip("/")
        url = f"{host}/dev-uploads/{quote(key)}?exp={expires_at}&sig={token}"
        return PresignedUpload(
            key=key,
            url=url,
            method="PUT",
            headers={"Content-Type": content_type},
            expires_in=15 * 60,
        )

    def public_url(
        self,
        key: str,
        *,
        bucket: str | None = None,
        base_url: str | None = None,
    ) -> str:
        host = (base_url or self.public_base).rstrip("/")
        return f"{host}/dev-uploads/{quote(key)}"

    def delete(self, key: str, *, bucket: str | None = None) -> None:
        path = self._safe_path(key)
        if path.exists():
            path.unlink()

    # ─ Local filesystem helpers ─

    def _safe_path(self, key: str) -> Path:
        # Resolve and ensure the final path stays inside `self.root`. Prevents
        # path traversal via a key like `../../etc/passwd`.
        target = (self.root / key).resolve()
        if not str(target).startswith(str(self.root)):
            raise ValueError("invalid storage key")
        return target

    def write(self, key: str, data: bytes) -> None:
        """Called by the /dev-uploads PUT endpoint, not by general callers."""
        path = self._safe_path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def read(self, key: str) -> bytes | None:
        path = self._safe_path(key)
        if not path.exists():
            return None
        return path.read_bytes()

    def exists(self, key: str) -> bool:
        return self._safe_path(key).exists()


# ─── Cloudflare R2 backend ──────────────────────────────────────────────────


class R2StorageBackend(StorageBackend):
    """Boto3 over the R2 S3-compatible API.

    R2 doesn't charge for egress, so for v1 we serve photos directly from
    `public_url` (a permanent /<bucket>/<key> on the R2 dev-domain). When we
    add per-event encryption + signed URLs, swap `public_url` to issue
    presigned GETs with short TTLs.
    """

    def __init__(self):
        # Import boto3 lazily so dev-only users don't pay the import cost on
        # cold start when STORAGE_BACKEND=local.
        import boto3
        from botocore.client import Config

        if not (settings.r2_endpoint and settings.r2_access_key and settings.r2_secret_key):
            raise RuntimeError(
                "R2 storage backend selected but R2_ENDPOINT / R2_ACCESS_KEY / R2_SECRET_KEY are unset"
            )

        self._client = boto3.client(
            "s3",
            endpoint_url=settings.r2_endpoint,
            aws_access_key_id=settings.r2_access_key,
            aws_secret_access_key=settings.r2_secret_key,
            config=Config(signature_version="s3v4"),
            region_name="auto",  # R2 expects this
        )
        self._default_bucket = settings.r2_bucket_photos

    def _bucket(self, override: str | None) -> str:
        return override or self._default_bucket

    def init_upload(
        self,
        key: str,
        content_type: str,
        *,
        bucket: str | None = None,
        base_url: str | None = None,  # ignored: R2 URLs are absolute
    ) -> PresignedUpload:
        bkt = self._bucket(bucket)
        url = self._client.generate_presigned_url(
            "put_object",
            Params={"Bucket": bkt, "Key": key, "ContentType": content_type},
            ExpiresIn=15 * 60,
            HttpMethod="PUT",
        )
        return PresignedUpload(
            key=key,
            url=url,
            method="PUT",
            headers={"Content-Type": content_type},
            expires_in=15 * 60,
        )

    def public_url(
        self,
        key: str,
        *,
        bucket: str | None = None,
        base_url: str | None = None,  # ignored: R2 URLs are absolute
    ) -> str:
        bkt = self._bucket(bucket)
        # When the bucket is exposed via an R2 public dev domain, this works
        # directly. Once we put a CDN in front we'll set STORAGE_PUBLIC_BASE_URL
        # to the CDN host and reuse the same key.
        base = settings.storage_public_base_url.rstrip("/") if settings.storage_public_base_url else settings.r2_endpoint.rstrip("/")
        return f"{base}/{bkt}/{quote(key)}"

    def delete(self, key: str, *, bucket: str | None = None) -> None:
        self._client.delete_object(Bucket=self._bucket(bucket), Key=key)


# ─── Key helpers ────────────────────────────────────────────────────────────


def make_photo_key(event_id: str, *, suffix: str = "") -> str:
    """`events/<event_id>/photos/<uuid>[.ext]`.

    Keeping objects under the event prefix means we can issue per-event
    lifecycle rules later (archive after N days, etc.) without a metadata
    lookup.
    """
    ext = ""
    if suffix:
        ext = suffix if suffix.startswith(".") else f".{suffix}"
    return f"events/{event_id}/photos/{uuid.uuid4().hex}{ext}"


def make_preview_key(event_id: str, photo_id: str) -> str:
    return f"events/{event_id}/previews/{photo_id}.webp"


# ─── Factory ────────────────────────────────────────────────────────────────


_storage: StorageBackend | None = None


def get_storage() -> StorageBackend:
    """Memoized factory. Picks the backend named in ``STORAGE_BACKEND``."""
    global _storage
    if _storage is not None:
        return _storage

    backend = (os.getenv("STORAGE_BACKEND") or settings.storage_backend or "local").lower()
    if backend == "r2":
        _storage = R2StorageBackend()
    elif backend == "local":
        _storage = LocalStorageBackend(
            root_dir=settings.storage_local_dir,
            public_base_url=settings.storage_public_base_url,
            secret_key=settings.secret_key,
        )
    else:
        raise RuntimeError(f"unknown STORAGE_BACKEND={backend!r}")
    return _storage
