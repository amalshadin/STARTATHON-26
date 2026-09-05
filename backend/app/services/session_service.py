"""
Session service: idempotent creation of therapy sessions, game sessions,
game results, and session metrics.

Idempotency strategy:
  - Client generates UUID before the session starts.
  - On upload: SELECT first. If found → return existing (idempotent replay).
  - If not found → INSERT.
  - Route returns HTTP 200 for replays, 201 for new records.
  - UNIQUE constraint on id (PK) provides database-level protection against races.
"""
from __future__ import annotations

import logging
import uuid
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.db.models import Game, GameResult, GameSession, SessionMetric, TherapySession
from app.schemas.session import (
    GameResultCreate,
    GameSessionCreate,
    SessionMetricCreate,
    TherapySessionCreate,
)

logger = logging.getLogger(__name__)


# ── Therapy Sessions ──────────────────────────────────────────────────────────

def upsert_therapy_session(
    db: Session, data: TherapySessionCreate
) -> tuple[TherapySession, bool]:
    """
    Idempotent therapy session creation.
    Returns (session, was_created). was_created=False means the session
    already existed (retry scenario).
    """
    existing = db.get(TherapySession, data.id)
    if existing:
        logger.debug("Idempotent replay: therapy_session %s already exists", data.id)
        return existing, False

    session = TherapySession(
        id=data.id,
        patient_id=data.patient_id,
        device_id=data.device_id,
        started_at=data.started_at,
        ended_at=data.ended_at,
        duration_s=data.duration_s,
        status=data.status,
        notes=data.notes,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session, True


def get_therapy_session(
    db: Session, session_id: uuid.UUID
) -> Optional[TherapySession]:
    return db.get(TherapySession, session_id)


def get_patient_therapy_sessions(
    db: Session, patient_id: uuid.UUID, limit: int = 50
) -> List[TherapySession]:
    """Return recent therapy sessions for a patient, newest first."""
    stmt = (
        select(TherapySession)
        .where(TherapySession.patient_id == patient_id)
        .order_by(TherapySession.started_at.desc())
        .limit(limit)
    )
    return list(db.execute(stmt).scalars().all())


# ── Game Sessions ─────────────────────────────────────────────────────────────

def upsert_game_session(
    db: Session, data: GameSessionCreate
) -> tuple[GameSession, bool]:
    """Idempotent game session creation."""
    existing = db.get(GameSession, data.id)
    if existing:
        logger.debug("Idempotent replay: game_session %s already exists", data.id)
        return existing, False

    session = GameSession(
        id=data.id,
        therapy_session_id=data.therapy_session_id,
        game_id=data.game_id,
        device_id=data.device_id,
        calibration_id=data.calibration_id,
        started_at=data.started_at,
        ended_at=data.ended_at,
        duration_ms=data.duration_ms,
        status=data.status,
        configuration=data.configuration,
        game_version=data.game_version,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session, True


def get_game_session(
    db: Session, game_session_id: uuid.UUID
) -> Optional[GameSession]:
    return db.get(GameSession, game_session_id)


# ── Game Results ──────────────────────────────────────────────────────────────

def upsert_game_result(
    db: Session, game_session_id: uuid.UUID, data: GameResultCreate
) -> tuple[GameResult, bool]:
    """
    Idempotent game result upload.
    UNIQUE constraint on game_session_id handles concurrent retries.
    """
    stmt = select(GameResult).where(GameResult.game_session_id == game_session_id)
    existing = db.execute(stmt).scalar_one_or_none()
    if existing:
        logger.debug("Idempotent replay: game_result for session %s already exists", game_session_id)
        return existing, False

    result = GameResult(
        game_session_id=game_session_id,
        score=data.score,
        accuracy=data.accuracy,
        completion_rate=data.completion_rate,
        repetitions=data.repetitions,
        metrics=data.metrics,
    )
    db.add(result)
    db.commit()
    db.refresh(result)
    return result, True


# ── Session Metrics ───────────────────────────────────────────────────────────

def upsert_session_metrics(
    db: Session, game_session_id: uuid.UUID, data: SessionMetricCreate
) -> tuple[SessionMetric, bool]:
    """
    Idempotent session metric upload.
    UNIQUE constraint on game_session_id.
    """
    stmt = select(SessionMetric).where(SessionMetric.game_session_id == game_session_id)
    existing = db.execute(stmt).scalar_one_or_none()
    if existing:
        logger.debug("Idempotent replay: session_metric for %s already exists", game_session_id)
        return existing, False

    metric = SessionMetric(
        game_session_id=game_session_id,
        algorithm_version=data.algorithm_version,
        metrics=data.metrics,
    )
    db.add(metric)
    db.commit()
    db.refresh(metric)
    return metric, True


# ── Games Registry ────────────────────────────────────────────────────────────

def get_all_games(db: Session) -> List[Game]:
    stmt = select(Game).where(Game.is_active == True).order_by(Game.name)
    return list(db.execute(stmt).scalars().all())


def get_game_by_slug(db: Session, slug: str) -> Optional[Game]:
    stmt = select(Game).where(Game.slug == slug, Game.is_active == True)
    return db.execute(stmt).scalar_one_or_none()
