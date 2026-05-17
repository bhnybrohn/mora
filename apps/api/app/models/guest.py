import uuid
from datetime import datetime

from sqlalchemy import Boolean, String, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.schemas import JoinRequestStatus


class Guest(Base):
    __tablename__ = "event_guests"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    event_id: Mapped[str] = mapped_column(String, ForeignKey("events.id"))
    display_name: Mapped[str] = mapped_column(String(100))
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    # Marks the host's own "camera row". The host can also contribute photos
    # to their own event — we model that as a Guest tied to their user_id so
    # the rest of the upload pipeline works unchanged. is_host is the UI hint
    # so the album can badge them differently.
    is_host: Mapped[bool] = mapped_column(Boolean, default=False)
    user_id: Mapped[str | None] = mapped_column(String, nullable=True, index=True)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    kicked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    event = relationship("Event", back_populates="guests")
    photos = relationship("Photo", back_populates="guest", lazy="dynamic")


class JoinRequest(Base):
    __tablename__ = "join_requests"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    event_id: Mapped[str] = mapped_column(String, ForeignKey("events.id"))
    display_name: Mapped[str] = mapped_column(String(100))
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    status: Mapped[JoinRequestStatus] = mapped_column(SAEnum(JoinRequestStatus), default=JoinRequestStatus.pending)
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
