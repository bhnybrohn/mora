"""Event ("film") endpoints — host-side.

Endpoints:
    POST   /events                — create a film
    GET    /events                — my films (active + archived, newest first)
    GET    /events/:id            — film detail (host-only for now)
    PATCH  /events/:id            — update mutable fields
    POST   /events/:id/reveal     — flip status -> revealed
    DELETE /events/:id            — archive (soft)

All routes here require a logged-in user. Guest-side join endpoints live in
``guests.py``.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Event, Guest, Photo, User
from app.schemas import EventCreate, EventOut, EventPrivacy, EventStatus, EventTier
from app.services.auth import get_current_user, issue_guest_token
from app.services.storage import get_storage, request_base_url

router = APIRouter()


# ─── Schemas ────────────────────────────────────────────────────────────────


class EventListItem(EventOut):
    """List-view variant — includes derived guest/photo counts."""


class EventUpdate(BaseModel):
    """Whitelist of mutable fields. The route only writes these — anything
    else in the payload is silently ignored, so a malicious client can't
    flip ``owner_user_id``."""

    name: str | None = None
    location: str | None = None
    privacy: EventPrivacy | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    reveal_at: datetime | None = None
    tier: EventTier | None = None


# ─── Helpers ────────────────────────────────────────────────────────────────


async def _load_event_for_owner(db: AsyncSession, event_id: str, user: User) -> Event:
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if event is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    if event.owner_user_id != user.id:
        # Don't leak existence to non-owners.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    return event


async def _serialize(db: AsyncSession, event: Event) -> dict:
    """Pull counts in one round-trip alongside the event payload."""
    guest_count = (await db.scalar(select(func.count(Guest.id)).where(Guest.event_id == event.id))) or 0
    photo_count = (await db.scalar(select(func.count(Photo.id)).where(Photo.event_id == event.id))) or 0
    return {
        "id": event.id,
        "owner_user_id": event.owner_user_id,
        "name": event.name,
        "location": event.location or "",
        "event_type": event.event_type,
        "privacy": event.privacy,
        "starts_at": event.starts_at,
        "ends_at": event.ends_at,
        "reveal_at": event.reveal_at,
        "tier": event.tier,
        "status": event.status,
        "guest_count": guest_count,
        "photo_count": photo_count,
        "created_at": event.created_at,
    }


# ─── Routes ─────────────────────────────────────────────────────────────────


@router.post("", response_model=EventOut, status_code=status.HTTP_201_CREATED)
async def create_event(
    body: EventCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.ends_at <= body.starts_at:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "ends_at must be after starts_at")
    if body.reveal_at < body.starts_at:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "reveal_at cannot precede starts_at")

    event = Event(
        owner_user_id=user.id,
        name=body.name,
        location=body.location or "",
        event_type=body.event_type,
        privacy=body.privacy,
        starts_at=body.starts_at,
        ends_at=body.ends_at,
        reveal_at=body.reveal_at,
        tier=body.tier,
        status=EventStatus.active,
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return await _serialize(db, event)


@router.get("", response_model=list[EventListItem])
async def list_my_events(
    include_archived: bool = False,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Event).where(Event.owner_user_id == user.id).order_by(Event.created_at.desc())
    if not include_archived:
        stmt = stmt.where(Event.status != EventStatus.archived)
    rows = (await db.execute(stmt)).scalars().all()
    return [await _serialize(db, e) for e in rows]


@router.get("/{event_id}", response_model=EventOut)
async def get_event(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event = await _load_event_for_owner(db, event_id, user)
    return await _serialize(db, event)


@router.patch("/{event_id}", response_model=EventOut)
async def update_event(
    event_id: str,
    body: EventUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event = await _load_event_for_owner(db, event_id, user)

    patch = body.model_dump(exclude_unset=True, exclude_none=True)
    for key, value in patch.items():
        setattr(event, key, value)

    # Re-validate time invariants if any of them moved.
    if event.ends_at <= event.starts_at:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "ends_at must be after starts_at")
    if event.reveal_at < event.starts_at:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "reveal_at cannot precede starts_at")

    await db.commit()
    await db.refresh(event)
    return await _serialize(db, event)


class RevealOut(BaseModel):
    id: str
    status: EventStatus
    revealed_at: datetime


@router.post("/{event_id}/reveal", response_model=RevealOut)
async def reveal_event(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Manual reveal — the host can flip the film early instead of waiting for
    ``reveal_at``. We just move the status and stamp the new reveal time;
    notification fan-out is the background-job side's job (Celery, later).
    """
    event = await _load_event_for_owner(db, event_id, user)
    if event.status == EventStatus.revealed:
        # Idempotent — same response if already revealed.
        return RevealOut(id=event.id, status=event.status, revealed_at=event.reveal_at)

    now = datetime.utcnow()
    event.status = EventStatus.revealed
    event.reveal_at = now
    await db.commit()
    await db.refresh(event)
    return RevealOut(id=event.id, status=event.status, revealed_at=event.reveal_at)


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def archive_event(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Soft archive — flips status. Real deletion (storage purge + DB rows) is
    a tail job we'll wire when the retention window expires."""
    event = await _load_event_for_owner(db, event_id, user)
    event.status = EventStatus.archived
    await db.commit()
    return None


# ─── Host-side album view ──────────────────────────────────────────────────


class AlbumPhoto(BaseModel):
    id: str
    guest_id: str | None
    guest_name: str | None
    width: int
    height: int
    taken_at: datetime
    url: str
    preview_url: str


# ─── Host-camera — let the host upload photos to their own event ──────────


class HostCameraOut(BaseModel):
    guest_id: str
    event_id: str
    token: str
    display_name: str
    is_host: bool


@router.post("/{event_id}/host-camera", response_model=HostCameraOut)
async def host_camera_token(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mint a guest token so the host can shoot their own event.

    Internally we materialize a Guest row tied to the host's user_id and
    flagged `is_host=True`. Idempotent — subsequent calls return a fresh
    token for the same row, so the host's photos always attribute back to
    the same identity in the album."""
    event = await _load_event_for_owner(db, event_id, user)

    existing = (
        await db.execute(
            select(Guest).where(
                Guest.event_id == event.id,
                Guest.user_id == user.id,
                Guest.is_host.is_(True),
            )
        )
    ).scalar_one_or_none()

    if existing is None:
        existing = Guest(
            event_id=event.id,
            display_name=(user.display_name or "Host").strip() or "Host",
            phone=user.phone,
            is_host=True,
            user_id=user.id,
        )
        db.add(existing)
        await db.commit()
        await db.refresh(existing)
    elif existing.kicked_at is not None:
        # The host's own row can't be in a kicked state — clear it if somehow
        # left over from a prior reset so the upload flow doesn't 401.
        existing.kicked_at = None
        await db.commit()

    token = issue_guest_token(existing.id, event.id, ttl_hours=24)
    return HostCameraOut(
        guest_id=existing.id,
        event_id=event.id,
        token=token,
        display_name=existing.display_name,
        is_host=True,
    )


@router.get("/{event_id}/album", response_model=list[AlbumPhoto])
async def get_album(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    """Owner-side album. Returns every active photo regardless of reveal
    state — the host is the one who owns the event, they can always see it.
    Guest-side album lives at /events/:id/photos and is reveal-aware."""
    await _load_event_for_owner(db, event_id, user)

    rows = (
        await db.execute(
            select(Photo, Guest.display_name)
            .join(Guest, Guest.id == Photo.guest_id, isouter=True)
            .where(
                Photo.event_id == event_id,
                Photo.status == "active",
                Photo.deleted_at.is_(None),
            )
            .order_by(Photo.taken_at.asc())
        )
    ).all()

    storage = get_storage()
    return [
        AlbumPhoto(
            id=p.id,
            guest_id=p.guest_id,
            guest_name=guest_name,
            width=p.width,
            height=p.height,
            taken_at=p.taken_at,
            url=storage.public_url(p.storage_key, base_url=base_url),
            preview_url=storage.public_url(p.preview_key, base_url=base_url),
        )
        for p, guest_name in rows
    ]
