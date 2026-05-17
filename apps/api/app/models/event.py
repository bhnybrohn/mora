import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.schemas import EventType, EventPrivacy, EventStatus, EventTier


class Event(Base):
    __tablename__ = "events"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    owner_user_id: Mapped[str] = mapped_column(String, index=True)
    name: Mapped[str] = mapped_column(String(255))
    # Free-text venue/city — kept loose for v1. Once we add maps we'll add
    # `location_lat/lng` alongside; this stays as the human-readable label.
    location: Mapped[str] = mapped_column(String(255), default="")
    event_type: Mapped[EventType] = mapped_column(SAEnum(EventType))
    privacy: Mapped[EventPrivacy] = mapped_column(SAEnum(EventPrivacy), default=EventPrivacy.public)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    reveal_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    tier: Mapped[EventTier] = mapped_column(SAEnum(EventTier), default=EventTier.free)
    status: Mapped[EventStatus] = mapped_column(SAEnum(EventStatus), default=EventStatus.active)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    guests = relationship("Guest", back_populates="event", lazy="dynamic")
    photos = relationship("Photo", back_populates="event", lazy="dynamic")
