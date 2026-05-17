from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


class EventType(str, Enum):
    wedding = "wedding"
    owambe = "owambe"
    naming = "naming"
    funeral = "funeral"
    birthday = "birthday"
    other = "other"


class EventPrivacy(str, Enum):
    public = "public"
    private = "private"


class EventStatus(str, Enum):
    active = "active"
    revealed = "revealed"
    archived = "archived"


class EventTier(str, Enum):
    free = "free"
    standard = "standard"
    premium = "premium"


class JoinRequestStatus(str, Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class EventCreate(BaseModel):
    name: str
    location: str = ""
    event_type: EventType
    privacy: EventPrivacy = EventPrivacy.public
    starts_at: datetime
    ends_at: datetime
    reveal_at: datetime
    tier: EventTier = EventTier.free


class EventOut(BaseModel):
    id: str
    owner_user_id: str
    name: str
    location: str = ""
    event_type: EventType
    privacy: EventPrivacy
    starts_at: datetime
    ends_at: datetime
    reveal_at: datetime
    tier: EventTier
    status: EventStatus
    guest_count: int = 0
    photo_count: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class GuestJoin(BaseModel):
    display_name: str
    phone: str | None = None


class JoinRequestOut(BaseModel):
    id: str
    event_id: str
    display_name: str
    phone: str | None = None
    status: JoinRequestStatus
    requested_at: datetime

    model_config = {"from_attributes": True}


class PhotoOut(BaseModel):
    id: str
    event_id: str
    guest_id: str | None
    storage_key: str
    preview_key: str
    width: int
    height: int
    taken_at: datetime
    status: str

    model_config = {"from_attributes": True}


class PhotoInitOut(BaseModel):
    upload_url: str
    photo_id: str


class PaymentInit(BaseModel):
    provider: str
    tier: EventTier


class PaymentOut(BaseModel):
    checkout_url: str
    reference: str
