"""Dev-only `/dev-uploads/{key}` endpoint.

Backs the ``LocalStorageBackend`` "presigned" upload URLs:

  - PUT writes the body to disk, gated by an HMAC token + expiry the
    backend stamped onto the URL it handed the client. Without that check
    any caller could POST arbitrary keys.
  - GET reads it back. Unsigned so the album view can <img src> the URL
    without ceremony; fine for dev.

This route module is only mounted when ``STORAGE_BACKEND=local``.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request, Response, status

from app.services.storage import LocalStorageBackend, get_storage

router = APIRouter()


@router.put("/dev-uploads/{key:path}")
async def upload_object(key: str, request: Request, exp: int = 0, sig: str = ""):
    backend = get_storage()
    if not isinstance(backend, LocalStorageBackend):
        raise HTTPException(status.HTTP_404_NOT_FOUND)

    if not exp or not sig or not backend.verify(key, exp, sig):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Invalid or expired upload URL")

    # Cap dev uploads so a runaway client can't fill the disk.
    body = await request.body()
    if len(body) > 25 * 1024 * 1024:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Max 25 MiB per object in dev")

    backend.write(key, body)
    return {"key": key, "bytes": len(body)}


@router.get("/dev-uploads/{key:path}")
async def download_object(key: str):
    backend = get_storage()
    if not isinstance(backend, LocalStorageBackend):
        raise HTTPException(status.HTTP_404_NOT_FOUND)

    data = backend.read(key)
    if data is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND)

    # We don't track content-type on disk; guess from extension. Good enough
    # for dev — production R2 sets it from the upload's Content-Type header.
    ct = "application/octet-stream"
    lk = key.lower()
    if lk.endswith(".webp"):
        ct = "image/webp"
    elif lk.endswith(".jpg") or lk.endswith(".jpeg"):
        ct = "image/jpeg"
    elif lk.endswith(".png"):
        ct = "image/png"
    return Response(content=data, media_type=ct)
