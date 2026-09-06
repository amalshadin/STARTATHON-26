"""
HapticSync FastAPI Application

Entry point. Configures:
  - CORS (origins from .env CORS_ORIGINS)
  - All API routers
  - Global exception handling
  - OpenAPI metadata

Run with:
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

See backend/README.md for full setup instructions.
"""
from __future__ import annotations

import logging

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core.config import get_settings

# Import all models so SQLAlchemy's mapper registry is populated before first request.
# This is required for relationship resolution and Alembic autogenerate.
import app.db.models  # noqa: F401

from app.api.routes import (
    auth,
    devices,
    doctors,
    game_sessions,
    games,
    health,
    patients,
    ai,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)

settings = get_settings()

# ── Application ───────────────────────────────────────────────────────────────

app = FastAPI(
    title="HapticSync API",
    description=(
        "Backend API for The HapticSync stroke rehabilitation platform. "
        "Provides session management, patient/doctor relationships, "
        "device calibration tracking, and rehabilitation analytics. "
        "\n\n"
        "**Team:** Nihal, Bharath, Amal, Devanarayan  \n"
        "**Institution:** RIT Kottayam"
    ),
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_tags=[
        {"name": "Health", "description": "API and database health checks"},
        {"name": "Authentication", "description": "PIN verification and doctor registration"},
        {"name": "Patients", "description": "Patient management (doctor-side)"},
        {"name": "Doctors", "description": "Doctor profile"},
        {"name": "Devices", "description": "Glove device registration and calibration"},
        {"name": "Game Sessions", "description": "Individual game sessions, results, and metrics"},
        {"name": "Games", "description": "Game registry"},
        {"name": "AI Overview", "description": "Gemini-powered rehabilitation briefings and parameter suggestions"},
    ],
)

# ── CORS ──────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(patients.router)
app.include_router(doctors.router)
app.include_router(devices.router)
app.include_router(game_sessions.router)
app.include_router(games.router)
app.include_router(ai.router)


# ── Root ──────────────────────────────────────────────────────────────────────

@app.get("/", include_in_schema=False)
def root():
    return {
        "project": "HapticSync API",
        "version": "0.1.0",
        "docs": "/docs",
        "health": "/health",
        "environment": settings.environment,
    }


# ── Global Exception Handlers ─────────────────────────────────────────────────

@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": str(exc)},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "An internal server error occurred"},
    )