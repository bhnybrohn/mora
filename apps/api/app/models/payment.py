import uuid
from enum import Enum
from datetime import datetime

from sqlalchemy import String, DateTime, Integer, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PaymentProvider(str, Enum):
    paystack = "paystack"
    flutterwave = "flutterwave"
    stripe = "stripe"


class PaymentStatus(str, Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: uuid.uuid4().hex[:12])
    event_id: Mapped[str] = mapped_column(String)
    user_id: Mapped[str] = mapped_column(String)
    provider: Mapped[PaymentProvider] = mapped_column(SAEnum(PaymentProvider))
    provider_ref: Mapped[str] = mapped_column(String(255))
    amount: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(10))
    status: Mapped[PaymentStatus] = mapped_column(SAEnum(PaymentStatus), default=PaymentStatus.pending)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
