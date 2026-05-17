"""Photo endpoints.

Guest-side (require a guest token scoped to the event):
    POST   /events/:id/photos/init             — get presigned upload URLs + photo_id
    POST   /events/:id/photos/commit           — finalize after upload
    GET    /events/:id/photos                  — list (reveal-aware)
    DELETE /events/:id/photos/:pid/by-guest    — delete own photo (pre-reveal)

Host-side (require the event-owner's JWT):
    DELETE /events/:id/photos/:pid/by-host     — host can delete any photo, any time

The Init/Commit split:
    init creates a Photo row with status="pending" + a storage key, then
    returns presigned PUTs the client uses to upload the full-res and
    preview binaries. commit flips status to "active" once the client
    confirms the uploads landed. A pending row that's never committed is
    cleanup fodder for a tail job (not in scope here).
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Event, Guest, Photo, User
from app.schemas import EventStatus, PhotoOut
from app.services.auth import get_current_guest, get_current_user
from app.services.storage import (
    PresignedUpload,
    get_storage,
    make_photo_key,
    make_preview_key,
    request_base_url,
)

router = APIRouter()


# ─── Schemas ────────────────────────────────────────────────────────────────


class PhotoInitBody(BaseModel):
    mime: str = Field("image/webp", examples=["image/webp", "image/jpeg"])
    ext: str = Field("webp", examples=["webp", "jpg"])


class PresignedUploadOut(BaseModel):
    url: str
    method: str
    headers: dict[str, str]
    key: str
    expires_in: int

    @classmethod
    def of(cls, p: PresignedUpload) -> "PresignedUploadOut":
        return cls(url=p.url, method=p.method, headers=p.headers, key=p.key, expires_in=p.expires_in)


class PhotoInitOut(BaseModel):
    photo_id: str
    full: PresignedUploadOut
    preview: PresignedUploadOut


class PhotoCommit(BaseModel):
    photo_id: str
    mime: str = "image/webp"
    width: int = Field(..., gt=0)
    height: int = Field(..., gt=0)
    taken_at: datetime | None = None  # client local-time of shutter; defaults to upload time


class PhotoView(BaseModel):
    """Album payload — adds a derived public URL on top of PhotoOut."""

    id: str
    event_id: str
    guest_id: str | None
    guest_name: str | None
    storage_key: str
    preview_key: str
    width: int
    height: int
    taken_at: datetime
    url: str
    preview_url: str
    is_own: bool


# ─── Helpers ────────────────────────────────────────────────────────────────


async def _load_active_event(db: AsyncSession, event_id: str) -> Event:
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if event is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    if event.status == EventStatus.archived:
        raise HTTPException(status.HTTP_410_GONE, "Event archived")
    return event


def _try_delete_storage(photo: Photo) -> None:
    """Best-effort blob delete. Tombstone the DB row regardless so the photo
    disappears from listings even if the storage backend is slow."""
    storage = get_storage()
    for key in (photo.storage_key, photo.preview_key):
        if not key:
            continue
        try:
            storage.delete(key)
        except Exception:
            # Background reaper will retry; never block the API on this.
            pass


# ─── Guest-side ─────────────────────────────────────────────────────────────


@router.post("/{event_id}/photos/init", response_model=PhotoInitOut)
async def init_upload(
    event_id: str,
    body: PhotoInitBody,
    guest: Guest = Depends(get_current_guest),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    if guest.event_id != event_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token doesn't match this event")

    event = await _load_active_event(db, event_id)
    if event.status == EventStatus.revealed:
        # Once revealed, no new contributions.
        raise HTTPException(status.HTTP_409_CONFLICT, "Film already developed, uploads are closed")

    # Mint the storage key up-front so we can stash it on the Photo row before
    # the upload actually happens. Lets us correlate the eventual upload back
    # to a Photo by id without a second lookup.
    full_key = make_photo_key(event_id, suffix=body.ext)
    photo = Photo(
        event_id=event_id,
        guest_id=guest.id,
        storage_key=full_key,
        preview_key="",
        mime=body.mime,
        width=0,
        height=0,
        taken_at=datetime.utcnow(),
        status="pending",
    )
    db.add(photo)
    await db.commit()
    await db.refresh(photo)

    preview_key = make_preview_key(event_id, photo.id)
    photo.preview_key = preview_key
    await db.commit()

    storage = get_storage()
    full = storage.init_upload(full_key, body.mime, base_url=base_url)
    preview = storage.init_upload(preview_key, "image/webp", base_url=base_url)

    return PhotoInitOut(
        photo_id=photo.id,
        full=PresignedUploadOut.of(full),
        preview=PresignedUploadOut.of(preview),
    )


@router.post("/{event_id}/photos/commit", response_model=PhotoOut)
async def commit_upload(
    event_id: str,
    body: PhotoCommit,
    guest: Guest = Depends(get_current_guest),
    db: AsyncSession = Depends(get_db),
):
    if guest.event_id != event_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token doesn't match this event")

    photo = (await db.execute(select(Photo).where(Photo.id == body.photo_id))).scalar_one_or_none()
    if photo is None or photo.event_id != event_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Photo not found")
    if photo.guest_id != guest.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your photo")
    if photo.status not in ("pending", "active"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Photo state {photo.status!r} can't be committed")

    photo.mime = body.mime
    photo.width = body.width
    photo.height = body.height
    if body.taken_at:
        photo.taken_at = body.taken_at
    photo.status = "active"
    await db.commit()
    await db.refresh(photo)
    return photo


# ─── Listing — reveal-aware ─────────────────────────────────────────────────


@router.get("/{event_id}/photos", response_model=list[PhotoView])
async def list_photos(
    event_id: str,
    guest: Guest = Depends(get_current_guest),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    """Pre-reveal: only your own photos.
    Post-reveal: every active photo in the event.
    Always excludes deleted/pending."""
    if guest.event_id != event_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token doesn't match this event")

    event = await _load_active_event(db, event_id)

    stmt = (
        select(Photo, Guest.display_name)
        .join(Guest, Guest.id == Photo.guest_id, isouter=True)
        .where(
            Photo.event_id == event_id,
            Photo.status == "active",
            Photo.deleted_at.is_(None),
        )
        .order_by(Photo.taken_at.asc())
    )
    if event.status != EventStatus.revealed:
        stmt = stmt.where(Photo.guest_id == guest.id)

    rows = (await db.execute(stmt)).all()

    storage = get_storage()
    return [
        PhotoView(
            id=photo.id,
            event_id=photo.event_id,
            guest_id=photo.guest_id,
            guest_name=guest_name,
            storage_key=photo.storage_key,
            preview_key=photo.preview_key,
            width=photo.width,
            height=photo.height,
            taken_at=photo.taken_at,
            url=storage.public_url(photo.storage_key, base_url=base_url),
            preview_url=storage.public_url(photo.preview_key, base_url=base_url),
            is_own=photo.guest_id == guest.id,
        )
        for photo, guest_name in rows
    ]


# ─── Delete — separate routes for guest vs host to keep auth schemes clean ─


@router.delete("/{event_id}/photos/{photo_id}/by-guest", status_code=status.HTTP_204_NO_CONTENT)
async def delete_photo_by_guest(
    event_id: str,
    photo_id: str,
    guest: Guest = Depends(get_current_guest),
    db: AsyncSession = Depends(get_db),
):
    if guest.event_id != event_id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Token doesn't match this event")

    event = await _load_active_event(db, event_id)
    if event.status == EventStatus.revealed:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Film already developed — only the host can remove photos after reveal",
        )

    photo = (await db.execute(select(Photo).where(Photo.id == photo_id))).scalar_one_or_none()
    if photo is None or photo.event_id != event_id or photo.deleted_at is not None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Photo not found")
    if photo.guest_id != guest.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your photo")

    photo.deleted_at = datetime.utcnow()
    photo.status = "deleted"
    await db.commit()
    _try_delete_storage(photo)
    return None


@router.delete("/{event_id}/photos/{photo_id}/by-host", status_code=status.HTTP_204_NO_CONTENT)
async def delete_photo_by_host(
    event_id: str,
    photo_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if event is None or event.owner_user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")

    photo = (await db.execute(select(Photo).where(Photo.id == photo_id))).scalar_one_or_none()
    if photo is None or photo.event_id != event_id or photo.deleted_at is not None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Photo not found")

    photo.deleted_at = datetime.utcnow()
    photo.status = "deleted"
    await db.commit()
    _try_delete_storage(photo)
    return None
