import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import JSON

from app.database import Base


class Sponsor(Base):
    """A vendor the host credits on their film.

    Rendered three ways in the album:
      - MadePossibleBy grid (every sponsor, with role + swatch/logo)
      - Inline IssueInsert (sponsors with tagline + link become eligible)
      - SponsoredFrame (one tile in the photo grid)

    Palette is a 3-color list stored as JSON for portability across SQLite
    (dev) and Postgres (prod). The asoebi swatch renderer takes [base, glow,
    lift] in that order.
    """

    __tablename__ = "sponsors"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    event_id: Mapped[str] = mapped_column(String, ForeignKey("events.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    role: Mapped[str] = mapped_column(String(60))
    palette: Mapped[list[str]] = mapped_column(JSON, default=list)
    link: Mapped[str | None] = mapped_column(String(500), nullable=True)
    tagline: Mapped[str | None] = mapped_column(String(200), nullable=True)
    logo_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event")
