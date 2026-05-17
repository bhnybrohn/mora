"""Auth primitives: phone normalization, OTP generation, JWT signing, and the
FastAPI dependency that resolves the current user from a bearer token.

The OTP delivery layer is intentionally pluggable. In development, codes are
logged to stdout so the Flutter app can read them off the terminal. In
production, swap `SmsSender.send` for Termii or AfricasTalking.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models import Guest, User

log = logging.getLogger("mora.auth")

_bearer = HTTPBearer(auto_error=False)

JWT_ALG = "HS256"

# A keypad-style code that's still ergonomic to type on phones. We exclude
# leading-zero codes by clamping the range so the SMS message is unambiguous.
OTP_LENGTH = 6
OTP_TTL_MINUTES = 10
OTP_MAX_ATTEMPTS = 5

# ─── Phone helpers ───

def normalize_phone(raw: str) -> str:
    """Coarse E.164 normalization. Strips spaces, dashes, and parens; requires
    a leading `+` followed by 7-15 digits.

    We deliberately avoid a heavyweight phonenumbers lib for v0; this catches
    the format we care about (the Flutter client always sends `+<dial><digits>`).
    """
    if not raw:
        raise ValueError("phone is required")
    cleaned = "".join(ch for ch in raw if ch.isdigit() or ch == "+")
    if not cleaned.startswith("+"):
        raise ValueError("phone must be E.164 (start with +)")
    digits = cleaned[1:]
    if not digits.isdigit() or not (7 <= len(digits) <= 15):
        raise ValueError("phone must have 7-15 digits")
    return cleaned


# ─── OTP helpers ───

def generate_otp() -> str:
    """A six-digit code as a zero-padded string. Uses `secrets` so the codes
    aren't predictable from PRNG output."""
    n = secrets.randbelow(10 ** OTP_LENGTH)
    return str(n).zfill(OTP_LENGTH)


def hash_otp(code: str) -> str:
    """HMAC-SHA256 the code with the server secret. Deterministic so we can
    look up by `phone` then compare hashes in constant time. Bcrypt would be
    overkill for a 6-digit, 10-minute, rate-limited code."""
    mac = hmac.new(settings.secret_key.encode("utf-8"), code.encode("utf-8"), hashlib.sha256)
    return mac.hexdigest()


def verify_otp(code: str, code_hash: str) -> bool:
    return hmac.compare_digest(hash_otp(code), code_hash)


def otp_expiry() -> datetime:
    return datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)


# ─── SMS delivery ───

class SmsSender:
    """Pluggable SMS sender. Default backend logs to stdout; swap for Termii
    or AfricasTalking by replacing the singleton at app startup."""

    async def send(self, phone: str, message: str) -> None:
        log.warning("DEV SMS to %s — %s", phone, message)


sms = SmsSender()


# ─── JWT ───

# Three token shapes share the same JWT signing secret. The `typ` claim is
# what every dependency checks first — a refresh token can never be used as
# an access token, and vice versa.
#
#   - "access"  → short-lived host login (1h). `sub` is User.id.
#   - "refresh" → long-lived (30d) token exchanged at /auth/refresh for a
#                 fresh access token. `sub` is User.id.
#   - "guest"   → event-scoped guest (24h). `sub` is Guest.id, `event_id`
#                 claim carries the scope.
TOKEN_TYPE_ACCESS = "access"
TOKEN_TYPE_REFRESH = "refresh"
TOKEN_TYPE_GUEST = "guest"

# Legacy alias — older code paths called the access token a "user" token.
# Tokens with `typ=user` are rejected (the schema changed) and treated as
# expired so the client refreshes.
TOKEN_TYPE_USER_LEGACY = "user"

ACCESS_TTL_MINUTES = 60
REFRESH_TTL_DAYS = 30


def issue_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TTL_MINUTES)
    payload = {
        "sub": user_id,
        "typ": TOKEN_TYPE_ACCESS,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=JWT_ALG)


def issue_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TTL_DAYS)
    payload = {
        "sub": user_id,
        "typ": TOKEN_TYPE_REFRESH,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=JWT_ALG)


# Backward-compat shim — existing callers expect `issue_token`. We map it to
# the new access-token issuer so older code keeps working until we sweep.
def issue_token(user_id: str) -> str:
    return issue_access_token(user_id)


def issue_guest_token(guest_id: str, event_id: str, *, ttl_hours: int = 24) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=ttl_hours)
    payload = {
        "sub": guest_id,
        "typ": TOKEN_TYPE_GUEST,
        "event_id": event_id,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=JWT_ALG)


def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.secret_key, algorithms=[JWT_ALG])


# ─── Current-user dependency ───

async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    payload = _decode_bearer(creds, expected_type=TOKEN_TYPE_ACCESS)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Malformed token")
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")
    return user


async def get_current_guest(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> Guest:
    """Resolve a guest from a guest-scoped JWT. Used by the camera/upload
    endpoints — those don't need a full user account."""
    payload = _decode_bearer(creds, expected_type=TOKEN_TYPE_GUEST)
    guest_id = payload.get("sub")
    if not guest_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Malformed token")
    guest = (await db.execute(select(Guest).where(Guest.id == guest_id))).scalar_one_or_none()
    if guest is None or guest.kicked_at is not None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Guest not found or removed")
    # Belt and braces: token's event_id must match what the DB says.
    if payload.get("event_id") != guest.event_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token doesn't match guest")
    return guest


def _decode_bearer(
    creds: HTTPAuthorizationCredentials | None,
    *,
    expected_type: str,
) -> dict:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    try:
        payload = decode_token(creds.credentials)
    except JWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    # Tokens minted before we added `typ` (or for the other scope) shouldn't
    # work here. Reject early so a guest token can never be used host-side.
    if payload.get("typ") != expected_type:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong token type")
    return payload
