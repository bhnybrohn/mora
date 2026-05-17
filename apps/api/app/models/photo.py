import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Photo(Base):
    __tablename__ = "photos"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    event_id: Mapped[str] = mapped_column(String, ForeignKey("events.id"))
    guest_id: Mapped[str | None] = mapped_column(String, ForeignKey("event_guests.id"), nullable=True)
    storage_key: Mapped[str] = mapped_column(String(255))
    preview_key: Mapped[str] = mapped_column(String(255))
    mime: Mapped[str] = mapped_column(String(50))
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    taken_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    uploaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active")

    event = relationship("Event", back_populates="photos")
    guest = relationship("Guest", back_populates="photos")
