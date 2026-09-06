# The HapticSync — Backend API

> **Clinical stroke rehabilitation platform backend**  
> Built with **FastAPI**, **SQLAlchemy 2.0**, **PostgreSQL** (Supabase), and **Alembic**.

---

## Overview

The HapticSync backend provides a secure, decoupled API for post-stroke hand and finger rehabilitation. The system bridges hardware sensors (3 flex sensors + 1 MPU6050 6-axis IMU on an ESP32 glove communicating via BLE to Flutter) with cloud data storage, doctor monitoring dashboards, calibration profiles, and future AI analytics.

### Key Architectural Highlights
- **Direct Backend Security Model**: The Flutter app communicates exclusively with FastAPI; Flutter has **no direct database access**.
- **Role Separation & Privacy**: Separate identity models for Doctors and Patients with strict doctor-patient relationship authorization.
- **PIN-Based Patient Onboarding**: Doctors generate a 6-digit one-time PIN (hashed with bcrypt, expiring in 24h, 5-attempt brute-force protection) for patients to complete account setup without complex manual credentials.
- **Offline-First Idempotency**: All session, game result, and metric submissions accept client-generated UUIDs (UUID v4) and are strictly idempotent with retry support (`X-Idempotent-Replayed` headers).
- **Extensible Game Registry**: Database-driven game registry with seeded initial games (*Piano* and *Pick and Place*). Adding new games requires zero schema migrations.
- **Clinical Terminology Safety**: System telemetry is explicitly labeled as **sensor-derived rehabilitation indicators** (e.g. Range of Motion, velocity, tremor power), never clinical diagnoses.

---

## Tech Stack

| Component | Technology | Description |
|-----------|------------|-------------|
| Framework | **FastAPI 0.141+** | High-performance async/sync web framework |
| Database ORM | **SQLAlchemy 2.0** | Type-safe declarative models with PostgreSQL UUID & JSONB |
| Migrations | **Alembic 1.19+** | Fully version-controlled relational schema migrations |
| Database | **PostgreSQL (Supabase)** | Hosted relational database with SSL-enforced connections |
| Auth & Crypto | **PyJWT + bcrypt** | Supabase JWT token verification + bcrypt PIN hashing |
| Validation | **Pydantic v2** | Strict request/response serialization and schemas |
| Testing | **pytest + pytest-asyncio** | Automated test suite with transactional rollback |

---

## Repository Structure

```
backend/
├── alembic/                 # Database migrations
│   ├── versions/            # Version migration scripts (initial_schema with game seeds)
│   └── env.py               # Alembic configuration & migration engine
├── app/
│   ├── api/
│   │   └── routes/          # FastAPI route controllers
│   │       ├── auth.py              # PIN verification & doctor registration
│   │       ├── devices.py           # Device registration & calibration curves
│   │       ├── doctors.py           # Doctor profiles & patient rosters
│   │       ├── game_sessions.py     # Game sessions, results & metrics
│   │       ├── games.py             # Game registry
│   │       ├── health.py            # API & DB health checks
│   │       ├── patients.py          # Doctor patient onboarding & invitations
│   │       └── ai.py                # AI clinical overview & parameter updates
│   ├── core/
│   │   ├── config.py        # Pydantic Settings & environment validation
│   │   ├── deps.py          # Dependency injection (get_db, auth & roles)
│   │   └── security.py      # JWT verification, bcrypt hashing, Supabase admin
│   ├── db/
│   │   ├── models/          # SQLAlchemy 2.0 ORM models
│   │   │   ├── ai.py                # AI analysis & clinical reports
│   │   │   ├── device.py            # Glove devices & calibrations
│   │   │   ├── game.py              # Game registry
│   │   │   ├── profile.py           # Profiles, Doctors, Patients & Invitations
│   │   │   └── session.py           # Therapy & game sessions, results, metrics
│   │   ├── base.py          # Declarative Base
│   │   └── database.py      # Engine & sessionmaker
│   ├── schemas/             # Pydantic v2 request/response models
│   └── main.py              # FastAPI app instance, CORS & router assembly
├── tests/                   # Automated pytest suite
├── .env.example             # Documented environment template
├── alembic.ini              # Alembic settings
├── pytest.ini               # Test configuration
└── requirements.txt         # Pinned Python dependencies
```

---

## Setup & Installation

### 1. Prerequisites
- Python 3.10+ (tested on Python 3.12)
- Supabase PostgreSQL instance (or local PostgreSQL)

### 2. Virtual Environment
```bash
cd backend
python -m venv .venv

# On Windows:
.\.venv\Scripts\activate

# On Linux/macOS:
source .venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables
Copy `.env.example` to `.env` and configure your credentials:
```bash
cp .env.example .env
```

Required variables:
- `user`, `password`, `host`, `port`, `dbname` (PostgreSQL connection parameters)
- `SUPABASE_URL`, `SUPABASE_JWT_SECRET` (Supabase project authentication)
- `SUPABASE_SERVICE_ROLE_KEY` (Server-side admin key for creating auth accounts & magic links)

---

## Database Migrations

Apply database migrations:
```bash
alembic upgrade head
```

Create a new migration after model changes:
```bash
alembic revision --autogenerate -m "describe_change"
```

Check migration status:
```bash
alembic current
```

---

## Running the API

Start the development server with auto-reload:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

- **Interactive API Documentation (Swagger)**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **Alternative Documentation (ReDoc)**: [http://localhost:8000/redoc](http://localhost:8000/redoc)
- **Health Check**: [http://localhost:8000/health](http://localhost:8000/health)

---

## Running Tests

Run the test suite with pytest:
```bash
pytest -v
```

Tests execute against transactional database sessions with automatic savepoint rollback (`join_transaction_mode="create_savepoint"`), leaving live data intact.

---

## API Endpoints Summary

### Authentication (`/auth`)
- `POST /auth/verify-pin` — Validates patient 6-digit PIN and returns sign-in magic link.
- `POST /auth/register-doctor` — Registers doctor profile and metadata after Supabase Auth sign-up.

### Health (`/health`)
- `GET /health` — Verifies API running and active PostgreSQL connection.

### Patients & Rosters (`/patients`)
- `POST /patients/onboard` — Doctor onboards a new patient; generates 6-digit PIN and invitation.
- `GET /patients` — Doctor views active patient roster.
- `GET /patients/{id}` — Doctor retrieves specific patient details.
- `GET /patients/{id}/sessions` — Doctor views patient therapy session history.

### Sessions & Telemetry (`/therapy-sessions`, `/game-sessions`)
- `POST /therapy-sessions` — Flutter uploads top-level therapy session (idempotent with client UUID).
- `GET /therapy-sessions/{id}` — Retrieve therapy session.
- `POST /game-sessions` — Upload game session played under a therapy session.
- `POST /game-sessions/{id}/results` — Upload scores, accuracy, and game-specific metrics.
- `POST /game-sessions/{id}/metrics` — Upload sensor-derived rehabilitation indicators (ROM, velocity, smoothness, tremor).

### Hardware & Calibration (`/devices`)
- `POST /devices` — Register glove hardware.
- `POST /devices/{id}/calibrations` — Upload calibration curves (min/max flex, neutral orientation).
- `GET /devices/{id}/calibrations/latest` — Fetch active calibration for gameplay normalization.

### Game Registry (`/games`)
- `GET /games` — List active games (*Piano*, *Pick and Place*).
