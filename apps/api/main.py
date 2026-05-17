import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import settings
from app.database import Base, engine
from app.routes import auth, dev_uploads, events, guests, payments, photos, sponsors


log = logging.getLogger("mora.errors")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # In dev, create_all is enough. Once we have prod data, swap to Alembic.
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(title="Mora API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(events.router, prefix="/events", tags=["events"])
app.include_router(guests.router, prefix="/events", tags=["guests"])
app.include_router(photos.router, prefix="/events", tags=["photos"])
app.include_router(sponsors.router, prefix="/events", tags=["sponsors"])
app.include_router(payments.router, prefix="/payments", tags=["payments"])

# /dev-uploads only useful with the local-filesystem storage backend.
if settings.storage_backend == "local":
    app.include_router(dev_uploads.router, tags=["dev"])


# ─── Error logging ─────────────────────────────────────────────────────────
#
# By default uvicorn's access log shows only `<METHOD> <PATH> <STATUS>` for
# every request. When a request fails with an HTTPException, the actual
# reason (the `detail` field) doesn't appear anywhere, which is why a 409
# in the logs looks like "uploads broken" instead of "film already developed".
#
# These handlers wrap FastAPI's defaults to log the status, path, and detail
# message before returning the same JSON the client would have got. They
# don't change the response shape — just the operator's visibility.


@app.exception_handler(StarletteHTTPException)
async def _http_exception_handler(request: Request, exc: StarletteHTTPException):
    log.warning(
        "HTTP %s %s %s — %s",
        exc.status_code,
        request.method,
        request.url.path,
        exc.detail,
    )
    return JSONResponse({"detail": exc.detail}, status_code=exc.status_code)


@app.exception_handler(RequestValidationError)
async def _validation_exception_handler(request: Request, exc: RequestValidationError):
    # FastAPI's default 422 doesn't pull the field names into the log line.
    # Flatten the validator output to "field: msg" so the cause is visible
    # without opening the response body.
    flat = "; ".join(
        f"{'.'.join(str(p) for p in (e.get('loc') or []))}: {e.get('msg')}"
        for e in exc.errors()
    )
    log.warning("HTTP 422 %s %s — %s", request.method, request.url.path, flat)
    return JSONResponse({"detail": exc.errors()}, status_code=422)


@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception):
    # Unexpected errors get a stack trace so we can diagnose; the response
    # itself stays generic so we don't leak internals.
    log.exception("HTTP 500 %s %s — %r", request.method, request.url.path, exc)
    return JSONResponse({"detail": "Internal server error"}, status_code=500)


@app.get("/health")
async def health():
    return {"status": "ok"}
