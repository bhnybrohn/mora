"""Sponsor (vendor credit) endpoints. All host-only — only the event owner
can edit the vendor list on their film.

    GET    /events/:id/sponsors             — list, sort_order then created_at
    POST   /events/:id/sponsors             — create a sponsor
    POST   /events/:id/sponsors/logo-init   — presigned upload for a logo
    PATCH  /events/:id/sponsors/:sid        — edit
    DELETE /events/:id/sponsors/:sid        — remove

Listings are public-readable inside the album endpoints (so guests see vendor
credits at the foot). The CRUD here requires the host JWT.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Event, Sponsor, User
from app.services.auth import get_current_user
from app.services.storage import PresignedUpload, get_storage, request_base_url

router = APIRouter()


# ─── Schemas ────────────────────────────────────────────────────────────────


class SponsorIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=160)
    role: str = Field(..., min_length=1, max_length=60)
    # 3-color palette as hex strings, [base, glow, lift]. Empty list means
    # "use a sensible default for this role" (computed client-side or via
    # `_palette_for_role` below if the client doesn't pick one).
    palette: list[str] = Field(default_factory=list)
    link: str | None = None
    tagline: str | None = None
    logo_key: str | None = None
    is_featured: bool = False
    sort_order: int = 0


class SponsorUpdate(BaseModel):
    """Whitelist of mutable fields — never accept event_id or id from the
    client. Anything not set stays untouched."""
    name: str | None = None
    role: str | None = None
    palette: list[str] | None = None
    link: str | None = None
    tagline: str | None = None
    logo_key: str | None = None
    is_featured: bool | None = None
    sort_order: int | None = None


class SponsorOut(BaseModel):
    id: str
    event_id: str
    name: str
    role: str
    palette: list[str]
    link: str | None
    tagline: str | None
    logo_key: str | None
    logo_url: str | None
    is_featured: bool
    sort_order: int

    model_config = {"from_attributes": True}


class LogoUploadOut(BaseModel):
    key: str
    url: str
    method: str
    headers: dict[str, str]
    expires_in: int

    @classmethod
    def of(cls, p: PresignedUpload) -> "LogoUploadOut":
        return cls(
            key=p.key,
            url=p.url,
            method=p.method,
            headers=p.headers,
            expires_in=p.expires_in,
        )


# ─── Helpers ────────────────────────────────────────────────────────────────


async def _load_event_for_owner(db: AsyncSession, event_id: str, user: User) -> Event:
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if event is None or event.owner_user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Event not found")
    return event


def _serialize(s: Sponsor, base_url: str | None = None) -> SponsorOut:
    return SponsorOut(
        id=s.id,
        event_id=s.event_id,
        name=s.name,
        role=s.role,
        palette=list(s.palette or []),
        link=s.link,
        tagline=s.tagline,
        logo_key=s.logo_key,
        logo_url=get_storage().public_url(s.logo_key, base_url=base_url) if s.logo_key else None,
        is_featured=s.is_featured,
        sort_order=s.sort_order,
    )


# ─── Routes ─────────────────────────────────────────────────────────────────


@router.get("/{event_id}/sponsors", response_model=list[SponsorOut])
async def list_sponsors(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    await _load_event_for_owner(db, event_id, user)
    rows = (
        await db.execute(
            select(Sponsor)
            .where(Sponsor.event_id == event_id)
            .order_by(Sponsor.sort_order.asc(), Sponsor.created_at.asc())
        )
    ).scalars().all()
    return [_serialize(s, base_url=base_url) for s in rows]


@router.post("/{event_id}/sponsors", response_model=SponsorOut, status_code=status.HTTP_201_CREATED)
async def create_sponsor(
    event_id: str,
    body: SponsorIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    await _load_event_for_owner(db, event_id, user)

    sponsor = Sponsor(
        event_id=event_id,
        name=body.name.strip(),
        role=body.role.strip(),
        palette=body.palette or _palette_for_role(body.role),
        link=(body.link or '').strip() or None,
        tagline=(body.tagline or '').strip() or None,
        logo_key=body.logo_key,
        is_featured=body.is_featured,
        sort_order=body.sort_order,
    )
    db.add(sponsor)
    await db.commit()
    await db.refresh(sponsor)
    return _serialize(sponsor, base_url=base_url)


@router.patch("/{event_id}/sponsors/{sponsor_id}", response_model=SponsorOut)
async def update_sponsor(
    event_id: str,
    sponsor_id: str,
    body: SponsorUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    await _load_event_for_owner(db, event_id, user)

    sponsor = (
        await db.execute(
            select(Sponsor).where(Sponsor.id == sponsor_id, Sponsor.event_id == event_id)
        )
    ).scalar_one_or_none()
    if sponsor is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sponsor not found")

    patch = body.model_dump(exclude_unset=True)
    for key, value in patch.items():
        if value is None and key in {"name", "role"}:
            # Required fields can't be cleared, skip.
            continue
        setattr(sponsor, key, value)

    await db.commit()
    await db.refresh(sponsor)
    return _serialize(sponsor, base_url=base_url)


@router.delete("/{event_id}/sponsors/{sponsor_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_sponsor(
    event_id: str,
    sponsor_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_event_for_owner(db, event_id, user)

    sponsor = (
        await db.execute(
            select(Sponsor).where(Sponsor.id == sponsor_id, Sponsor.event_id == event_id)
        )
    ).scalar_one_or_none()
    if sponsor is None:
        # 404 → already gone; idempotent delete.
        return None

    # Best-effort logo cleanup. DB row drops regardless.
    if sponsor.logo_key:
        try:
            get_storage().delete(sponsor.logo_key)
        except Exception:
            pass

    await db.delete(sponsor)
    await db.commit()
    return None


@router.post("/{event_id}/sponsors/logo-init", response_model=LogoUploadOut)
async def init_logo_upload(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    base_url: str = Depends(request_base_url),
):
    """Hand back a presigned PUT so the host can upload a sponsor logo.

    The client then includes the returned `key` as `logo_key` on the next
    POST/PATCH /sponsors call. Logos live under `events/<eid>/sponsors/` so
    they share lifecycle rules with the rest of the event's assets."""
    await _load_event_for_owner(db, event_id, user)

    import uuid as _uuid
    key = f"events/{event_id}/sponsors/{_uuid.uuid4().hex}.png"
    presigned = get_storage().init_upload(key, "image/png", base_url=base_url)
    return LogoUploadOut.of(presigned)


# ─── Defaults ──────────────────────────────────────────────────────────────


# Role → asoebi-coded default palette. The host can override per-sponsor; this
# is the "we picked something nice for you" fallback so the form stays simple.
_ROLE_PALETTES: dict[str, list[str]] = {
    "aso oke":     ['#3A1418', '#D4A857', '#7A3025'],
    "catering":    ['#2A1F1A', '#E89C5C', '#4D2A20'],
    "photography": ['#1A1714', '#A88B5C', '#3D3530'],
    "venue":       ['#1F2A52', '#D4A857', '#3D3530'],
    "make-up":     ['#3A2A30', '#E8A55C', '#8B5530'],
    "mc":          ['#2A1A0D', '#F1C57E', '#5C2A14'],
    "dj":          ['#13110D', '#A47C40', '#3A2515'],
}


def _palette_for_role(role: str) -> list[str]:
    return _ROLE_PALETTES.get(role.strip().lower(), ['#1A130C', '#7A6E60', '#D9A85C'])
