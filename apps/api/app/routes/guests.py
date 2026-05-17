"""Event-side guest endpoints.

Public-facing (no auth needed, called from the QR-scan PWA):
    POST   /events/:id/join              — join a public event, get guest token
    POST   /events/:id/join/request      — request to join a private event

Host-only (require the event-owner's JWT):
    GET    /events/:id/join/requests             — pending requests
    POST   /events/:id/join/requests/:rid/approve
    POST   /events/:id/join/requests/:rid/reject
    DELETE /events/:id/guests/:gid               — kick a guest

The guest-token returned by /join is scoped to a single event for 24 hours,
and is what the camera page sends with photo uploads.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Event, Guest, JoinRequest, Photo, User
from app.schemas import EventPrivacy, GuestJoin, JoinRequestOut, JoinRequestStatus
from app.services.auth import get_current_user, issue_guest_token

router = APIRouter()


# ─── Schemas ────────────────────────────────────────────────────────────────


class GuestJoinOut(BaseModel):
    guest_id: str
    event_id: str
    token: str
    display_name: str
    frames_per_guest: int = 24  # TODO: derive from event.tier once it lives on Event


class JoinRequestSubmitted(BaseModel):
    request_id: str
    status: JoinRequestStatus


class ApproveOut(BaseModel):
    guest_id: str
    event_id: str
    request_id: str


# ─── Public — join ──────────────────────────────────────────────────────────


@router.post("/{event_id}/join", response_model=GuestJoinOut)
async def join_public_event(
    event_id: str,
    body: GuestJoin,
    db: AsyncSession = Depends(get_db),
):
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    if event.privacy != EventPrivacy.public:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "This event is private. Use /join/request to ask the host.",
        )

    guest = Guest(event_id=event_id, display_name=body.display_name, phone=body.phone)
    db.add(guest)
    await db.commit()
    await db.refresh(guest)

    return GuestJoinOut(
        guest_id=guest.id,
        event_id=event_id,
        token=issue_guest_token(guest.id, event_id),
        display_name=guest.display_name,
    )


@router.post("/{event_id}/join/request", response_model=JoinRequestSubmitted)
async def request_join_private_event(
    event_id: str,
    body: GuestJoin,
    db: AsyncSession = Depends(get_db),
):
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    if event.privacy == EventPrivacy.public:
        # No reason to queue a request on a public event; redirect.
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Public events accept /join directly")

    req = JoinRequest(event_id=event_id, display_name=body.display_name, phone=body.phone)
    db.add(req)
    await db.commit()
    await db.refresh(req)
    return JoinRequestSubmitted(request_id=req.id, status=req.status)


# ─── Host-only helpers ──────────────────────────────────────────────────────


async def _load_event_for_owner(db: AsyncSession, event_id: str, user: User) -> Event:
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if event is None or event.owner_user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    return event


# ─── Host-only routes ───────────────────────────────────────────────────────


class GuestSummaryOut(BaseModel):
    id: str
    display_name: str
    phone: str | None
    is_host: bool
    photo_count: int
    joined_at: datetime
    kicked_at: datetime | None

    model_config = {"from_attributes": True}


@router.get("/{event_id}/guests", response_model=list[GuestSummaryOut])
async def list_guests(
    event_id: str,
    include_kicked: bool = False,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Host-side guest list with photo counts. Hosts appear here too (their
    own `is_host=True` row), so the UI can render them with a HOST badge."""
    await _load_event_for_owner(db, event_id, user)

    photo_count_subq = (
        select(Photo.guest_id, func.count(Photo.id).label("c"))
        .where(
            Photo.event_id == event_id,
            Photo.status == "active",
            Photo.deleted_at.is_(None),
        )
        .group_by(Photo.guest_id)
        .subquery()
    )

    stmt = (
        select(Guest, photo_count_subq.c.c)
        .where(Guest.event_id == event_id)
        .join(photo_count_subq, photo_count_subq.c.guest_id == Guest.id, isouter=True)
        .order_by(Guest.is_host.desc(), Guest.joined_at.asc())
    )
    if not include_kicked:
        stmt = stmt.where(Guest.kicked_at.is_(None))

    rows = (await db.execute(stmt)).all()
    return [
        GuestSummaryOut(
            id=g.id,
            display_name=g.display_name,
            phone=g.phone,
            is_host=g.is_host,
            photo_count=int(count or 0),
            joined_at=g.joined_at,
            kicked_at=g.kicked_at,
        )
        for g, count in rows
    ]


@router.get("/{event_id}/join/requests", response_model=list[JoinRequestOut])
async def list_join_requests(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_event_for_owner(db, event_id, user)
    rows = (
        await db.execute(
            select(JoinRequest)
            .where(
                JoinRequest.event_id == event_id,
                JoinRequest.status == JoinRequestStatus.pending,
            )
            .order_by(JoinRequest.requested_at.asc())
        )
    ).scalars().all()
    return rows


@router.post("/{event_id}/join/requests/{request_id}/approve", response_model=ApproveOut)
async def approve_join_request(
    event_id: str,
    request_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_event_for_owner(db, event_id, user)
    req = (
        await db.execute(
            select(JoinRequest).where(
                JoinRequest.id == request_id,
                JoinRequest.event_id == event_id,
            )
        )
    ).scalar_one_or_none()
    if req is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Request not found")
    if req.status != JoinRequestStatus.pending:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Request already {req.status.value}")

    req.status = JoinRequestStatus.approved
    guest = Guest(event_id=event_id, display_name=req.display_name, phone=req.phone)
    db.add(guest)
    await db.commit()
    await db.refresh(guest)
    return ApproveOut(guest_id=guest.id, event_id=event_id, request_id=req.id)


@router.post("/{event_id}/join/requests/{request_id}/reject", status_code=status.HTTP_204_NO_CONTENT)
async def reject_join_request(
    event_id: str,
    request_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_event_for_owner(db, event_id, user)
    req = (
        await db.execute(
            select(JoinRequest).where(
                JoinRequest.id == request_id,
                JoinRequest.event_id == event_id,
            )
        )
    ).scalar_one_or_none()
    if req is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Request not found")

    req.status = JoinRequestStatus.rejected
    await db.commit()
    return None


@router.delete("/{event_id}/guests/{guest_id}", status_code=status.HTTP_204_NO_CONTENT)
async def kick_guest(
    event_id: str,
    guest_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_event_for_owner(db, event_id, user)
    guest = (
        await db.execute(
            select(Guest).where(Guest.id == guest_id, Guest.event_id == event_id)
        )
    ).scalar_one_or_none()
    if guest is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Guest not found")
    if guest.kicked_at is None:
        guest.kicked_at = datetime.utcnow()
        await db.commit()
    return None
