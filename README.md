# Mora

A shared camera roll for African events.

- **Flutter app** — iOS + Android (host + installed guest experience)
- **Guest PWA** — No-install guest camera (Next.js)
- **API** — FastAPI backend

```
apps/
├── flutter_app/   # dart/flutter
├── guest_pwa/     # next.js/typescript
└── api/           # fastapi/python
packages/
└── shared_types/  # type definitions
```

## Running locally

Three terminals: API stack, API server, Flutter (or PWA).

### 1. Backend stack (Postgres + Redis)

```bash
cd apps/api
cp .env.example .env       # edit STORAGE_PUBLIC_BASE_URL to your LAN IP
docker compose up -d        # postgres on :5434, redis on :6381
```

### 2. API server

```bash
cd apps/api
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Verify: `curl http://localhost:8000/health` → `{"status":"ok"}`.
Swagger UI: <http://localhost:8000/docs>.

In dev, OTP codes are logged to the uvicorn console:
`WARNING:mora.auth:DEV SMS to +234… — Your Mora code is 384210.`

### 3. Flutter (host app)

```bash
cd apps/flutter_app
flutter pub get
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
```

Find your Mac's LAN IP: `ipconfig getifaddr en0`. The phone and Mac need
to be on the same Wi-Fi.

### 4. Guest PWA (optional — Next.js)

```bash
cd apps/guest_pwa
npm install
npm run dev   # http://localhost:3000
```

## Resetting the dev DB

```bash
docker exec mora-postgres psql -U mora -d mora \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
rm -rf apps/api/uploads
```

Schema auto-recreates on the next API request.
