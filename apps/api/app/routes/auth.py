"""Phone-OTP authentication.

POST /auth/otp/request — generate a 6-digit code, persist its hash, "send" SMS.
POST /auth/otp/verify  — validate code, find-or-create user, return a JWT.

The plaintext code is never stored or returned by the API. In dev, the SMS
backend logs the code to stdout so the Flutter client can be exercised
end-to-end without a real SMS provider wired up.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import OtpCode, User
from app.services.auth import (
    ACCESS_TTL_MINUTES,
    OTP_MAX_ATTEMPTS,
    TOKEN_TYPE_REFRESH,
    decode_token,
    generate_otp,
    get_current_user,
    hash_otp,
    issue_access_token,
    issue_refresh_token,
    normalize_phone,
    otp_expiry,
    sms,
    verify_otp,
)
from jose import JWTError

ACCESS_TTL_SECONDS = ACCESS_TTL_MINUTES * 60

router = APIRouter()


class OtpRequestBody(BaseModel):
    phone: str = Field(..., examples=["+2348012345678"])


class OtpVerifyBody(BaseModel):
    phone: str = Field(..., examples=["+2348012345678"])
    code: str = Field(..., min_length=4, max_length=8)


class OtpRequestOut(BaseModel):
    message: str
    resend_in_seconds: int


class TokenOut(BaseModel):
    # Kept for back-compat with anything still reading `token`. New clients
    # should use `access_token` + `refresh_token`.
    token: str
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int  # seconds the access token is valid for
    user_id: str
    is_new_user: bool


class RefreshBody(BaseModel):
    refresh_token: str


class RefreshOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


@router.post("/otp/request", response_model=OtpRequestOut)
async def request_otp(body: OtpRequestBody, db: AsyncSession = Depends(get_db)):
    try:
        phone = normalize_phone(body.phone)
    except ValueError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(e))

    # Invalidate any prior pending codes for this phone so a fresh request
    # always wins and the user can recover from a typo without waiting.
    await db.execute(delete(OtpCode).where(OtpCode.phone == phone))

    code = generate_otp()
    row = OtpCode(phone=phone, code_hash=hash_otp(code), expires_at=otp_expiry())
    db.add(row)
    await db.commit()

    await sms.send(phone, f"Your Mora code is {code}. Expires in 10 minutes.")
    return OtpRequestOut(message="OTP sent", resend_in_seconds=30)


@router.post("/otp/verify", response_model=TokenOut)
async def verify_otp_route(body: OtpVerifyBody, db: AsyncSession = Depends(get_db)):
    try:
        phone = normalize_phone(body.phone)
    except ValueError as e:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(e))

    row = (
        await db.execute(
            select(OtpCode).where(OtpCode.phone == phone).order_by(OtpCode.created_at.desc())
        )
    ).scalars().first()

    if row is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No code requested for this number")

    if row.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        # Don't leak whether the code matched — just say it expired.
        await db.delete(row)
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Code expired, request a new one")

    if row.attempts >= OTP_MAX_ATTEMPTS:
        await db.delete(row)
        await db.commit()
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many attempts, request a new code")

    if not verify_otp(body.code.strip(), row.code_hash):
        row.attempts += 1
        await db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Code didn't match")

    # Single-use — consume the code immediately on success.
    await db.delete(row)

    # Find-or-create user. last_login_at is touched on every successful verify.
    user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    is_new = user is None
    now = datetime.now(timezone.utc)
    if user is None:
        user = User(phone=phone, last_login_at=now)
        db.add(user)
    else:
        user.last_login_at = now

    await db.commit()
    await db.refresh(user)

    access = issue_access_token(user.id)
    refresh = issue_refresh_token(user.id)
    return TokenOut(
        token=access,  # legacy alias
        access_token=access,
        refresh_token=refresh,
        expires_in=ACCESS_TTL_SECONDS,
        user_id=user.id,
        is_new_user=is_new,
    )


@router.post("/refresh", response_model=RefreshOut)
async def refresh_route(body: RefreshBody, db: AsyncSession = Depends(get_db)):
    """Exchange a refresh token for a new access (and rotated refresh) pair.

    The route deliberately returns 401 on every failure mode (bad sig, expired,
    wrong typ, user gone) — the client uses 401 from /auth/refresh as its
    "hard sign-out" trigger that wipes saved tokens. Any other status would
    encourage retry storms."""
    try:
        payload = decode_token(body.refresh_token)
    except JWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")

    if payload.get("typ") != TOKEN_TYPE_REFRESH:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong token type")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Malformed token")

    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None:
        # The user this token referred to no longer exists (deleted, or DB
        # reset in dev). Treat as a hard sign-out.
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")

    return RefreshOut(
        access_token=issue_access_token(user.id),
        refresh_token=issue_refresh_token(user.id),  # rotate on every use
        expires_in=ACCESS_TTL_SECONDS,
    )


class MeOut(BaseModel):
    id: str
    phone: str
    display_name: str | None
    locale: str

    model_config = {"from_attributes": True}




@router.get("/me", response_model=MeOut)
async def me(user: User = Depends(get_current_user)):
    return user
