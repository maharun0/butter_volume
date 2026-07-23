# Butter Volume — FastAPI Backend Documentation

**Version:** 1.0
**Date:** 2026-07-23
**Status:** Approved for development
**Base URL:** `https://api.buttervolume.app/v1` (prod) · `https://api.dev.buttervolume.app/v1` (dev)
**Companion document:** `flutter-app-documentation.md`

---

## Table of Contents

1. [Purpose & Scope](#1-purpose--scope)
2. [Architecture](#2-architecture)
3. [Technology Decisions & Rationale](#3-technology-decisions--rationale)
4. [Project Structure](#4-project-structure)
5. [Authentication Model](#5-authentication-model)
6. [Data Model](#6-data-model)
7. [API Contract](#7-api-contract)
8. [Purchase Verification & Entitlements](#8-purchase-verification--entitlements)
9. [Security](#9-security)
10. [Operations & Deployment](#10-operations--deployment)
11. [Recommended Additional Features](#11-recommended-additional-features)
12. [Roadmap](#12-roadmap)

---

## 1. Purpose & Scope

The backend is the **trust and coordination layer** for the Butter Volume Android app. It is deliberately small: the app is fully usable offline, and the backend's job is to be authoritative where the client cannot be trusted, and helpful where the client cannot see.

**Responsibilities:**

| Area | Role |
|---|---|
| Device registration | Anonymous device identity; the default account model |
| User accounts | Optional Google Sign-In; links devices, enables sync & cross-device restore |
| Purchase verification | Server-side verification + acknowledgement of Play purchases; **single source of truth for premium** |
| Subscription lifecycle | Consume Play RTDN (Real-Time Developer Notifications) to track renewals, grace, hold, pause, cancel, refund |
| Premium entitlement | Issue entitlement state + **signed offline entitlement tokens** |
| Theme synchronization | Cloud storage of custom themes (premium + signed-in) |
| Remote configuration | Tunable values without app releases |
| Feature flags | Kill switches & experiments (e.g., `ads_enabled`) |
| App version checking | Min/latest version, forced-update messaging |
| Analytics | First-party ingestion of the event contract defined in the Flutter doc §17 |
| Crash reporting | Sentry (backend's own errors); aggregates client release-health via Sentry API for the ops dashboard |
| API auth & rate limiting | Device/user JWTs; Redis-backed limits |

**Non-goals:** no media handling, no push infrastructure in v1 (no FCM needed — the app's loops are local), no admin web UI in v1 (SQL + scripts; dashboard on roadmap).

**Design constraints:**
- **Client degrades gracefully:** every endpoint may be unreachable; the app relies on cached config and the signed offline token. Therefore no endpoint may be required for app startup.
- **Low cost:** must run comfortably on a $6–12/mo VPS at 100k MAU (this workload is tiny: mostly short reads + batched analytics writes).
- **PII minimization:** email only for signed-in users; analytics keyed by opaque ids.

---

## 2. Architecture

### 2.1 System diagram

```
                        ┌──────────────────────────────────────────────┐
   Android app          │                VPS (Docker Compose)          │
 (dio, JWT auth)        │                                              │
        │               │  ┌─────────┐   ┌──────────────────────────┐  │
        └── HTTPS ──────┼─►│  Caddy  │──►│  api  (FastAPI/uvicorn,  │  │
                        │  │  :443   │   │  2–4 workers)            │  │
 Google Play ── RTDN ───┼─►│  auto-  │   └─────┬────────────┬───────┘  │
 (Pub/Sub push)         │  │  TLS    │         │            │          │
                        │  └─────────┘   ┌─────▼─────┐ ┌────▼───────┐  │
                        │                │ postgres  │ │   redis    │  │
                        │                │   :5432   │ │   :6379    │  │
                        │                └───────────┘ └────────────┘  │
                        │  ┌────────────────────────────────────────┐  │
                        │  │ worker (arq): RTDN processing retries, │  │
                        │  │ analytics rollups, token re-verify,    │  │
                        │  │ stale-purchase reconciliation (cron)   │  │
                        │  └────────────────────────────────────────┘  │
                        └──────────────────────────────────────────────┘
                                     │ outbound HTTPS
        Google Play Developer API ◄──┘──► Google OAuth tokeninfo ──► Sentry
```

### 2.2 Request path layering

```
Router (FastAPI, thin)  →  Service (business logic)  →  Repository (SQLAlchemy)
        │                        │
        └── Pydantic schemas     └── external gateways (PlayStoreGateway,
            in/out                   GoogleAuthGateway) behind interfaces
```

Routers never touch the ORM; services never build HTTP responses. External APIs are wrapped in gateway classes with interfaces so tests fake them.

---

## 3. Technology Decisions & Rationale

| Concern | Choice | Why |
|---|---|---|
| Framework | **FastAPI** (Python 3.12) | Prescribed; async-first, Pydantic v2 validation, OpenAPI for free (the generated `/docs` is the internal API reference). |
| Server | **uvicorn** workers behind Caddy | Simple, standard. |
| ORM / DB | **SQLAlchemy 2 (async) + asyncpg + Alembic**, **PostgreSQL 16** | Boring, correct, migratable. JSONB fits theme payloads & config values without schema churn. |
| Cache / limits / queue | **Redis 7** | Rate limiting (sliding window), config cache, and the **arq** task queue broker — one dependency, three jobs. |
| Background jobs | **arq** | Async-native, tiny, Redis-based. Celery is overkill here. RTDN handling must be queue-backed (Pub/Sub push retries + our own retries). |
| Auth tokens | **JWT (ES256)** via `pyjwt` + `cryptography` | Asymmetric so future services can verify without the signing key; `kid` header for rotation. |
| Offline entitlement token | **Ed25519 signature** (compact custom payload) | Verified in the app with the embedded public key; small, fast, no JWT bloat on the hot path. |
| Google verification | **google-api-python-client** (Play Developer API: `purchases.subscriptionsv2`, `purchases.products`) + `google-auth` (ID-token verification) | Official; service account with least-privilege Play Console access. |
| Settings/config | **pydantic-settings** + `.env` (dev) / Docker secrets (prod) | Typed config. |
| Observability | **Sentry** (errors + performance), **structlog** JSON logs, `/health` + Uptime Kuma | Matches the client's Sentry; one pane of glass. |
| Rate limiting | Custom Redis sliding-window dependency (not slowapi) | ~40 lines, async, per-route policies, testable. |
| Tests | **pytest + pytest-asyncio + httpx.AsyncClient**, testcontainers for Postgres | Full-stack endpoint tests against a real Postgres. |
| Lint/type | **ruff + mypy (strict)** | Non-negotiable hygiene. |

---

## 4. Project Structure

```
butter-volume-api/
├── app/
│   ├── main.py                     # app factory, middleware, router mounting
│   ├── core/
│   │   ├── config.py               # pydantic-settings
│   │   ├── security.py             # JWT issue/verify, key rotation (kid), password-less
│   │   ├── entitlement_token.py    # Ed25519 offline-token signer
│   │   ├── ratelimit.py            # Redis sliding-window dependency
│   │   ├── deps.py                 # get_db, get_redis, current_device, current_user
│   │   └── errors.py               # error envelope, exception handlers
│   ├── db/
│   │   ├── base.py  session.py     # async engine/session
│   │   └── migrations/             # alembic
│   ├── models/                     # SQLAlchemy models (one file per table)
│   ├── schemas/                    # Pydantic request/response models
│   ├── routers/
│   │   ├── auth.py  devices.py  purchases.py  entitlements.py
│   │   ├── themes.py  config.py  flags.py  version.py
│   │   ├── analytics.py  feedback.py  account.py  webhooks.py  health.py
│   ├── services/
│   │   ├── auth_service.py  device_service.py
│   │   ├── purchase_service.py  entitlement_service.py  rtdn_service.py
│   │   ├── theme_service.py  config_service.py  analytics_service.py
│   ├── gateways/
│   │   ├── play_store.py           # Play Developer API wrapper (+ interface)
│   │   └── google_auth.py          # ID-token verification wrapper
│   └── workers/
│       ├── worker.py               # arq settings
│       └── tasks.py                # process_rtdn, reconcile_purchases, rollup_analytics
├── tests/
│   ├── conftest.py                 # app + testcontainer fixtures, fake gateways
│   ├── test_auth.py  test_purchases.py  test_rtdn.py  test_themes.py  ...
├── alembic.ini
├── pyproject.toml
├── Dockerfile
├── docker-compose.yml              # prod: caddy, api, worker, postgres, redis
├── docker-compose.dev.yml
└── Caddyfile
```

---

## 5. Authentication Model

Two identities, one token format. **Anonymous device auth is the default**; Google Sign-In is optional and additive (per product decision).

### 5.1 Device auth (anonymous, default path)

```
App first run
  ► generates device_uuid (random v4, stored in app-private storage)
  ► POST /v1/devices/register {device_uuid, model, os_version, app_version, locale}
  ◄ 201 {device_id, access_token (30 min), refresh_token (90 d, rotating)}
  ► stores tokens in flutter_secure_storage
Subsequent calls: Authorization: Bearer <access_token>
Refresh: POST /v1/auth/refresh {refresh_token} ◄ new pair (old refresh revoked)
```

- `device_uuid` is app-generated, not a hardware ID (no `ANDROID_ID` — avoids privacy review issues). Reinstall ⇒ new device; entitlements re-attach via purchase restore (§8.5).
- Refresh tokens are **rotating + reuse-detected**: a re-used (already-rotated) refresh token revokes the whole chain (stolen-token defense).

### 5.2 Optional Google Sign-In (account linking)

```
App: google_sign_in ► obtains Google ID token (aud = our server client ID)
  ► POST /v1/auth/google {id_token}          (device-authenticated call)
Backend: verifies signature/aud/exp via google-auth
  ► finds-or-creates users row (google_sub unique; email stored)
  ► links current device to user (devices.user_id)
  ► merges entitlements: any active purchase on this device attaches to the user;
    any active user entitlement now applies to this device
  ◄ 200 {user, access_token, refresh_token}   (new tokens carry user_id claim)
```

Sign-out (`POST /v1/auth/logout`) revokes the refresh chain and re-issues device-only tokens; the device keeps working anonymously.

### 5.3 JWT claims

```json
{
  "iss": "buttervolume-api",
  "sub": "dev_9f6f2c1e",             // device_id (always present)
  "uid": "usr_5b2d...",              // only when signed in
  "ent": "premium_lifetime",          // entitlement snapshot (advisory; not the trust root)
  "iat": 1753257600, "exp": 1753259400,
  "kid": "2026-07-a"                  // in header; rotation §9.1
}
```

### 5.4 Auth matrix

| Endpoint group | Auth required |
|---|---|
| `/devices/register` | none (rate-limited hard) |
| `/auth/refresh` | refresh token |
| `/config`, `/flags`, `/version-check` | device token (work for everyone) |
| `/purchases/*`, `/entitlements/*`, `/analytics/*`, `/feedback` | device token |
| `/themes/*` (sync), `/account` | user token (signed in) — themes additionally require premium |
| `/webhooks/play-rtdn` | OIDC-authenticated Pub/Sub push (§9.3) — no JWT |
| `/health` | none |

---

## 6. Data Model

### 6.1 ERD

```
users 1───* devices                    users 1───* themes
  │                                      
  1                                    devices *───* analytics_events (by device_id)
  │
  *───* entitlements *───1 purchases 1───* subscription_events
              (owner = user_id OR device_id — exactly one set)

remote_config   feature_flags   app_versions   feedback      (standalone)
```

### 6.2 Tables (key columns)

**users** — `id (uuid pk)`, `google_sub (unique)`, `email`, `created_at`, `deleted_at (soft)`
**devices** — `id (uuid pk)`, `device_uuid (unique)`, `user_id (fk null)`, `model`, `os_version`, `app_version`, `locale`, `last_seen_at`, `created_at`
**refresh_tokens** — `id`, `device_id`, `family_id`, `token_hash`, `expires_at`, `rotated_at`, `revoked_at`
**purchases** — `id`, `product_id (bv_premium_monthly | bv_premium_lifetime)`, `purchase_token_hash (unique)`, `order_id`, `kind (subscription|one_time)`, `state (pending|verified|refunded|revoked)`, `raw_response (jsonb)`, `acknowledged_at`, `created_at`
**entitlements** — `id`, `user_id (null)`, `device_id (null)` *(check: exactly one non-null)*, `purchase_id (fk)`, `status` (see §8.2), `expires_at (null for lifetime)`, `updated_at`
**subscription_events** — `id`, `purchase_id`, `rtdn_type (int)`, `notification_id (unique — idempotency)`, `payload (jsonb)`, `processed_at`, `created_at` — the append-only RTDN audit log
**themes** — `id (uuid, client-generated)`, `user_id`, `name`, `payload (jsonb — the canonical theme schema, Flutter doc §7.1)`, `schema_version`, `updated_at`, `deleted (bool — tombstone)`
**remote_config** — `key (pk)`, `value (jsonb)`, `updated_at`
**feature_flags** — `key (pk)`, `enabled (bool)`, `rollout_pct (0–100)`, `conditions (jsonb: min_app_version, entitlement, locale…)`, `updated_at`
**app_versions** — `id`, `platform ('android')`, `latest_version`, `min_supported_version`, `changelog`, `force_update_message`, `created_at`
**analytics_events** — `id (bigserial)`, `device_id`, `user_id (null)`, `name`, `props (jsonb)`, `client_ts`, `received_at` — partitioned by month; raw kept 90 days, rollups forever
**analytics_daily** — `date`, `metric`, `dims (jsonb)`, `value` — worker-produced rollups (DAU, activations, conversion, retention cohorts)
**feedback** — `id`, `device_id`, `user_id (null)`, `category (bug|idea|praise|other)`, `message`, `diagnostics (jsonb null)`, `created_at`

### 6.3 Indexing notes
`analytics_events (name, received_at)`, `(device_id, received_at)`; `entitlements (device_id) / (user_id)` partial where status active; `themes (user_id, updated_at)`; `purchases (purchase_token_hash)` unique — this is also the replay guard (§9.4).

---

## 7. API Contract

### 7.0 Conventions

- JSON everywhere; `snake_case`; timestamps ISO-8601 UTC.
- **Error envelope** (all non-2xx):

```json
{ "error": { "code": "entitlement_required", "message": "Premium required for theme sync.", "details": {} } }
```

Common codes: `validation_error (422)`, `unauthorized (401)`, `forbidden (403)`, `not_found (404)`, `rate_limited (429, Retry-After header)`, `conflict (409)`, `play_verification_failed (400)`, `entitlement_required (403)`, `internal (500)`.

- Versioning: path prefix `/v1`; breaking changes ⇒ `/v2`, `/v1` maintained ≥ 6 months (clients update slowly).

### 7.1 Auth & devices

**POST `/v1/devices/register`** — anonymous. Rate limit 5/h/IP.
```json
// req
{ "device_uuid": "c1a2…", "model": "Pixel 8", "os_version": "15",
  "app_version": "1.0.0", "locale": "en_US" }
// 201
{ "device_id": "dev_9f6f2c1e",
  "access_token": "eyJ…", "refresh_token": "rt_…", "expires_in": 1800 }
```
Idempotent on `device_uuid` (returns 200 + fresh tokens if known).

**POST `/v1/auth/refresh`** → new token pair (rotation, §5.1).
**POST `/v1/auth/google`** — body `{ "id_token": "…" }` → `{ user, access_token, refresh_token }` (§5.2).
**POST `/v1/auth/logout`** → 204; revokes refresh family, unlinks session (device row keeps `user_id` unless `{"unlink": true}`).
**PATCH `/v1/devices/me`** — update `app_version/os_version/locale` (called on app update). → 200.

### 7.2 Purchases & entitlements

**POST `/v1/purchases/verify`** — the critical path (§8.1). Rate limit 10/h/device.
```json
// req
{ "product_id": "bv_premium_lifetime", "purchase_token": "opaque-play-token" }
// 200
{ "entitlement": {
    "status": "premium_lifetime", "expires_at": null,
    "products": ["bv_premium_lifetime"] },
  "offline_token": "bv1.eyJz…​.MEUCIQ…" }
// 400 play_verification_failed | 409 conflict (token owned by another user)
```

**POST `/v1/purchases/restore`** — body `{ "purchases": [{product_id, purchase_token}] }` (from `restorePurchases()`); each verified as above; response = merged entitlement + fresh offline token.

**GET `/v1/entitlements/me`** — current entitlement + a **fresh offline token** (the app calls this opportunistically on open; failure is fine — cached token rules).
```json
{ "entitlement": { "status": "grace_period", "expires_at": "2026-08-02T10:00:00Z",
                   "products": ["bv_premium_monthly"] },
  "offline_token": "bv1.…", "message": "payment_issue" }
```

### 7.3 Webhooks

**POST `/v1/webhooks/play-rtdn`** — Google Cloud Pub/Sub push endpoint (RTDN). Auth: OIDC token from Pub/Sub verified against Google certs + expected service-account email (§9.3). Handler: decode → insert `subscription_events` (idempotent on `notification_id`) → enqueue `process_rtdn` → **always 204 fast** (processing is async; Pub/Sub retries on non-2xx).

### 7.4 Theme sync *(user token + premium)*

Last-write-wins by `updated_at`, tombstones for deletes — matches the client model (Flutter doc §7.1).

**GET `/v1/themes?since=<iso>`** → `{ "themes": [ {id, name, payload, schema_version, updated_at, deleted} ], "server_time": "…" }`
**PUT `/v1/themes/{id}`** — upsert one theme (client-generated uuid). 409 only if `schema_version` newer than server supports.
**POST `/v1/themes/sync`** — batch: `{ "changes": [...], "since": "…" }` → `{ "applied": [...], "conflicts_resolved": [...], "themes": [...] }` (preferred call; single round trip).
**DELETE `/v1/themes/{id}`** → 204 (tombstone).
Limits: ≤ 50 themes/user, payload ≤ 8 KB (validated against the JSON schema server-side).

### 7.5 Remote config & feature flags

**GET `/v1/config`** — cached in Redis 60 s; ETag/If-None-Match supported (304 saves battery/bytes).
```json
{ "config": {
    "free_session_hours": 12,
    "expiry_warning_minutes": 30,
    "ad_min_interval_hours": 4, "ad_max_per_day": 2,
    "paywall_default_plan": "lifetime",
    "analytics_batch_max": 50, "analytics_flush_seconds": 30,
    "oem_guide_urls": { "xiaomi": "https://buttervolume.app/support/xiaomi", "...": "…" }
  }, "updated_at": "…" }
```

**GET `/v1/flags`** — evaluated per caller (rollout % by stable hash of device_id; conditions on app version/entitlement/locale):
```json
{ "flags": { "ads_enabled": true, "rewarded_extension_experiment": false,
             "theme_sync_enabled": true, "promo_banner": false } }
```

### 7.6 Version check

**GET `/v1/version-check?current=1.0.0`**
```json
{ "latest_version": "1.2.0", "min_supported_version": "1.0.0",
  "update_required": false, "update_recommended": true,
  "changelog": "New: Cyber theme; smoother radial.",
  "force_update_message": null }
```
`update_required: true` ⇒ app shows a blocking (but honest) update screen.

### 7.7 Analytics ingestion

**POST `/v1/analytics/events`** — batched (≤ 50), fire-and-forget from the client. Event names/props are exactly the contract in Flutter doc §17. Unknown names accepted (forward compatibility) but flagged in rollups. Rate limit 60 req/h/device.
```json
// req
{ "events": [
  { "name": "feature_activated", "client_ts": "2026-07-23T09:00:00Z",
    "props": { "feature": "floating_button", "entitlement": "free" } },
  { "name": "timer_expired", "client_ts": "2026-07-23T21:01:00Z",
    "props": { "feature": "floating_button", "session_hours": 12 } } ] }
// 202
{ "accepted": 2 }
```

### 7.8 Feedback & account

**POST `/v1/feedback`** — `{ category, message, diagnostics? }` → 201. Rate limit 5/day/device.
**DELETE `/v1/account`** *(user token)* — GDPR delete: soft-delete user, hard-delete themes & feedback, detach devices, anonymize analytics (`user_id → null`) — completes async ≤ 30 days, immediate token revocation. → 202.

### 7.9 Health

**GET `/health`** → `{ "status": "ok", "db": "ok", "redis": "ok", "version": "…" }` (DB/redis checks cached 10 s).

---

## 8. Purchase Verification & Entitlements

### 8.1 Verification flow (client-initiated)

```
POST /v1/purchases/verify
 1. hash(purchase_token) — if exists and owned by another user/device chain → 409
 2. Play Developer API:
      one-time  : purchases.products.get(package, product_id, token)
                  → require purchaseState == PURCHASED
      subs      : purchases.subscriptionsv2.get(package, token)
                  → map subscriptionState (§8.2)
 3. persist purchases row (raw_response jsonb kept for audit)
 4. acknowledge if unacknowledged (products.acknowledge / server-side)
 5. upsert entitlement (owner = user if signed in, else device)
 6. sign & return offline token (§8.4)
All Play calls behind PlayStoreGateway; transient Google errors → 503 retryable,
the app retries with backoff and keeps the Play purchase queued.
```

### 8.2 Entitlement state machine (canonical vocabulary — identical to Flutter doc §6.1)

```
                       verify OK (lifetime)
   free ─────────────────────────────────────────► premium_lifetime  (terminal
     │                                                          unless refunded)
     │ verify OK (subscription)
     ▼
   premium_monthly ──renewal──► premium_monthly
     │        │           │
     │        │           └─payment fails─► grace_period ──recovers──► premium_monthly
     │        │                                  │ grace ends
     │        └─user pauses─► paused             ▼
     │                          │             on_hold ──recovers──► premium_monthly
     │                          │resume          │ hold ends / cancel
     ▼                          ▼                ▼
   expired ◄────────────── (cancel at period end)─┘        refund/revoke → free (any state)
```

| Status | Client behavior (Flutter doc §11.2) |
|---|---|
| `premium_monthly`, `premium_lifetime` | Full premium |
| `grace_period` | Full premium + "payment issue" banner |
| `on_hold`, `paused` | Free behavior + fix/resume banner |
| `expired`, `free` | Free |

### 8.3 RTDN processing (worker task `process_rtdn`)

RTDN notification types mapped: `SUBSCRIPTION_PURCHASED/RENEWED/RECOVERED → premium_monthly`, `IN_GRACE_PERIOD → grace_period`, `ON_HOLD → on_hold`, `PAUSED → paused`, `CANCELED → (keep premium until expiry_time, then expired)`, `REVOKED/EXPIRED → expired`; `ONE_TIME_PRODUCT_* → verify/refund lifetime`. Every event: re-fetch authoritative state from Play (never trust the notification alone), update entitlement, append audit row. Idempotent by `notification_id`. A nightly `reconcile_purchases` cron re-checks all non-terminal subscriptions (belt-and-braces against missed RTDNs).

### 8.4 Signed offline entitlement token

The client's offline trust root (Flutter doc §11.2). Compact format `bv1.<base64url payload>.<base64url ed25519 sig>`:

```json
{ "v": 1, "sub": "dev_9f6f2c1e", "uid": "usr_5b2d…",
  "status": "premium_monthly", "products": ["bv_premium_monthly"],
  "iat": 1753257600,
  "exp": 1753862400 }        // subs: min(now+7d, sub_expiry+3d grace); lifetime: now+180d
```

- Public key ships in the app (with a `kid`-style version byte for rotation); verification is pure offline `ed25519.verify`.
- Refreshed opportunistically via `GET /v1/entitlements/me` on every app open — so a normally-online user always holds a fresh token, and even a fully offline lifetime user is covered for 180 days between refreshes.

### 8.5 Restoration & cross-device
- Same device reinstall / new device, not signed in: `restorePurchases()` returns Play tokens for the Google account → `/v1/purchases/restore` re-verifies → new entitlement chain. Purchase-token hash uniqueness prevents two *different* user accounts claiming one token (409 with a support hint).
- Signed in: entitlement is user-owned; any newly linked device inherits it instantly (`/v1/entitlements/me`).

---

## 9. Security

### 9.1 JWT & keys
- ES256; signing keys as PEM in Docker secrets; `kid` in header; rotation = add new key, issue with it, keep old for verify until max token age passes. Access 30 min / refresh 90 d rotating with family reuse-detection (§5.1).

### 9.2 Rate limiting (Redis sliding window)
| Route | Limit |
|---|---|
| `/devices/register` | 5/h/IP |
| `/auth/*` | 20/h/device |
| `/purchases/verify` | 10/h/device |
| `/analytics/events` | 60/h/device |
| `/feedback` | 5/day/device |
| default | 120/min/device |

429 + `Retry-After`. IP-based limits applied pre-auth at Caddy level too (basic flood guard).

### 9.3 Webhook authentication
Pub/Sub push configured **with OIDC token**: backend verifies the bearer JWT against Google's certs, checks `email == rtdn-push@<project>.iam.gserviceaccount.com` and `aud == webhook URL`. Additionally the endpoint path contains a random slug (`/v1/webhooks/play-rtdn-<32hex>`) as defense-in-depth. Payload is never trusted for state — Play is re-queried (§8.3).

### 9.4 Purchase replay & abuse
- `purchase_token_hash` unique constraint = replay guard across accounts.
- Verification always server→Google; client-supplied fields (product_id) cross-checked against Play's response.
- Entitlement downgrades only via RTDN/reconciliation — a client can never *upgrade* itself and never needs to downgrade itself.

### 9.5 Data protection & PII
- TLS 1.2+ only (Caddy default); HSTS.
- PII inventory: `users.email`, `feedback.message` (may contain anything), `devices.model/locale`. Analytics carry **no** PII by contract; the server validates events against the allow-list schema (Flutter doc §17) and log-and-drops noncompliant props rather than storing them.
- Backups encrypted at rest (age/restic, §10.3). GDPR delete path in §7.8.
- Secrets: Docker secrets + `.env` never committed; Play service-account JSON mounted read-only into `api` and `worker` only.
- Dependency & image scanning in CI (`pip-audit`, `trivy`).

---

## 10. Operations & Deployment

### 10.1 docker-compose (prod shape)

```yaml
services:
  caddy:
    image: caddy:2
    ports: ["80:80", "443:443"]
    volumes: [./Caddyfile:/etc/caddy/Caddyfile, caddy_data:/data]
  api:
    build: .
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 3
    env_file: .env.prod
    secrets: [jwt_signing_key, ent_signing_key, play_sa_json]
    depends_on: [postgres, redis]
    restart: unless-stopped
  worker:
    build: .
    command: arq app.workers.worker.WorkerSettings
    env_file: .env.prod
    secrets: [play_sa_json, ent_signing_key]
    depends_on: [postgres, redis]
    restart: unless-stopped
  postgres:
    image: postgres:16
    volumes: [pg_data:/var/lib/postgresql/data]
    environment: { POSTGRES_DB: buttervolume, ... }
    restart: unless-stopped
  redis:
    image: redis:7
    command: redis-server --appendonly yes
    volumes: [redis_data:/data]
    restart: unless-stopped
```

Caddyfile: `api.buttervolume.app { reverse_proxy api:8000 }` — automatic TLS. Also serves the static site (`buttervolume.app`: privacy policy, support/FAQ, OEM guides) from a `site/` directory — one VPS hosts everything the Play listing links to.

### 10.2 Environments & CI/CD
- `dev` (api.dev.buttervolume.app) and `prod`, separate compose projects on the same or separate VPS.
- GitHub Actions: `ruff + mypy + pytest (testcontainers)` on PR → build/push image (GHCR, tagged by sha) on main → deploy = SSH `docker compose pull && up -d` → alembic migrations run by an entrypoint gate (advisory-locked so only one container migrates).
- Migration policy: expand → migrate → contract; never destructive in the same release that stops writing a column.

### 10.3 Backups & DR
- Nightly `pg_dump` → restic → offsite object storage (e.g., Backblaze B2), 30 daily / 12 monthly retention; weekly automated restore-test into a scratch container (a backup that isn't restore-tested doesn't exist).
- Redis is reconstructible (limits/cache/queue) — AOF persistence is enough.
- RPO 24 h / RTO ~1 h (fresh VPS + compose + restore runbook in `docs/runbooks/`).

### 10.4 Monitoring
- Sentry (errors + tracing on the purchase path), structlog JSON → journald (loki optional later), Uptime Kuma on `/health` + external ping, disk/RAM alerts via node-exporter or hosting provider alarms.
- **Weekly ops digest** (cron → email): new devices, DAU, verify success rate, RTDN backlog, conversion, refunds — the "is the business alive" email.

### 10.5 Cost estimate
Hetzner CX22-class VPS (~€6) + backups storage (~€1) + domain ≈ **€8/mo** total at launch scale; headroom to ~100k MAU on a single node given the read-light workload; the scaling path (managed Postgres, second api node behind Caddy) requires no code changes.

---

## 11. Recommended Additional Features

Included in the schema/design above where cheap; flagged as post-v1 where not:

1. **Trending themes** *(post-v1)* — `theme_applied` rollups already capture popularity; expose `GET /v1/themes/trending` (anonymized, opt-in shared themes only) to feed a "Popular this week" shelf in the Theme Gallery. Strong retention/creation loop.
2. **Ads kill switch & experiment flags** *(v1)* — `ads_enabled`, `rewarded_extension_experiment` flags exist from day one; an ad-SDK outage or policy problem becomes a config change, not a release.
3. **Promo codes** *(post-v1)* — `POST /v1/promo/redeem` granting timed premium; useful for reviewers, support goodwill, launch campaigns. (Play promo codes cover some of this; own codes allow "1 month premium" grants.)
4. **Announcements/changelog endpoint** *(post-v1)* — `GET /v1/announcements` for an in-app "what's new" card without a release.
5. **Client release-health aggregation** *(v1-lite)* — worker pulls Sentry release-health API nightly into `analytics_daily` so crash-free % sits next to business metrics in one place.
6. **Refund-abuse telemetry** *(post-v1)* — correlate refunds with usage in rollups to spot patterns before they hurt.
7. **Admin CLI** *(v1)* — `python -m app.admin grant-premium <device> --days 30`, `flags set ads_enabled false`, `config set free_session_hours 12` — covers all v1 admin needs without a web UI.

---

## 12. Roadmap

| Milestone | Scope |
|---|---|
| **v1.0 (launch)** | Everything in §5–§10: device auth, Google link, verify + RTDN + reconciliation, offline tokens, theme sync, config/flags/version, analytics ingest + rollups, feedback, GDPR delete, admin CLI, full ops stack |
| **v1.1** | Trending themes, announcements, promo codes, weekly digest polish |
| **v1.2** | **Full settings backup/restore** — generalize theme sync to a `user_blobs` table (settings JSON, versioned, LWW) enabling "new phone, everything back" (pairs with Flutter roadmap item) |
| **v1.3** | Multi-device sync hardening: per-field merge for settings (LWW per key rather than per blob), device list management UI endpoints (`GET/DELETE /v1/devices`) |
| **v2.0** | Admin dashboard (small SvelteKit/React app behind Caddy basic-auth → metrics, flags, config, user lookup, entitlement grants); optional FCM for announcement pushes; `/v2` only if contract must break |

---

*End of FastAPI Backend Documentation. Client-side behavior referenced throughout lives in `flutter-app-documentation.md`.*
