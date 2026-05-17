import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    # Stored in E.164 form, e.g. "+2348012345678". Indexed and unique so we can
    # find-or-create on every OTP verify without scanning the table.
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    locale: Mapped[str] = mapped_column(String(10), default="en")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class OtpCode(Base):
    """A pending one-time code for a phone number.

    The plaintext code is never stored — only a bcrypt hash. We keep at most
    one active row per phone (older rows are deleted on a new request) so
    rate-limiting can rely on `attempts` and `created_at` cleanly.
    """

    __tablename__ = "otp_codes"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    phone: Mapped[str] = mapped_column(String(20), index=True)
    code_hash: Mapped[str] = mapped_column(String(128))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
