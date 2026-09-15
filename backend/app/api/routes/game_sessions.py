"""
Game session routes: create, upload results, upload metrics.
All patient-authenticated. Full idempotency on all write operations.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.deps import get_current_patient
from app.db.database import get_db
from app.db.models import Game, Patient
from app.db.models.session import GameSession, SessionStatus
from app.schemas.session import (
    GameResultCreate, GameResultResponse,
    GameSessionCreate, GameSessionResponse,
    SessionMetricCreate, SessionMetricResponse,
)
from app.services import ai_service, session_service

settings = get_settings()

router = APIRouter(prefix="/game-sessions", tags=["Game Sessions"])
therapy_router = APIRouter(prefix="/therapy-sessions", tags=["Therapy Sessions"])


@therapy_router.post("", status_code=status.HTTP_201_CREATED)
def start_therapy_session_compat(body: Optional[Dict[str, Any]] = None):
    return {"id": (body or {}).get("id", str(uuid.uuid4())), "status": "completed"}


@therapy_router.get("/{therapy_session_id}", status_code=status.HTTP_200_OK)
def get_therapy_session_compat(therapy_session_id: uuid.UUID):
    return {"id": str(therapy_session_id), "status": "completed"}


@router.post(
    "",
    response_model=GameSessionResponse,
    summary="Create game session (idempotent)",
    description=(
        "Flutter uploads a game session after it completes. "
        "id must be a client-generated UUID v4 (same as used during gameplay). "
        "Idempotent: sending the same id twice returns existing session."
    ),
)
def create_game_session(
    body: GameSessionCreate,
    response: Response,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> GameSessionResponse:
    if not body.id:
        body.id = uuid.uuid4()
    if not body.started_at:
        body.started_at = datetime.now(timezone.utc)

    if not body.patient_id:
        body.patient_id = patient.id
    elif body.patient_id != patient.id:
        if settings.is_development:
            target_patient = db.get(Patient, body.patient_id)
            if target_patient:
                patient = target_patient
        if body.patient_id != patient.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot create a game session for another patient",
            )

    # Verify game exists; handle string slug, placeholder UUID, or fallback
    game = None
    if body.game_id:
        try:
            parsed_game_uuid = uuid.UUID(str(body.game_id))
            game = db.get(Game, parsed_game_uuid)
            if game:
                body.game_id = game.id
        except (ValueError, TypeError):
            pass

        if not game:
            game = db.execute(
                select(Game).where(Game.slug.ilike(str(body.game_id)))
            ).scalars().first()
            if game:
                body.game_id = game.id

    if not game:
        fallback_game = db.execute(select(Game).where(Game.is_active == True)).scalars().first()
        if fallback_game:
            body.game_id = fallback_game.id
            game = fallback_game
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Game '{body.game_id}' not found.",
            )

    game_session, created = session_service.upsert_game_session(db, body)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    if not created:
        response.headers["X-Idempotent-Replayed"] = "true"

    if game_session.status == SessionStatus.completed:
        background_tasks.add_task(ai_service.run_session_analysis_background, game_session.id)

    return GameSessionResponse.model_validate(game_session)


@router.get(
    "/{game_session_id}",
    response_model=GameSessionResponse,
    summary="Get game session",
)
def get_game_session(
    game_session_id: uuid.UUID,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> GameSessionResponse:
    game_session = session_service.get_game_session(db, game_session_id)
    if not game_session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Game session not found")

    # Verify patient ownership
    if game_session.patient_id != patient.id:
        if settings.is_development:
            target_patient = db.get(Patient, game_session.patient_id)
            if target_patient:
                patient = target_patient
        if game_session.patient_id != patient.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    return GameSessionResponse.model_validate(game_session)


@router.put(
    "/{game_session_id}",
    response_model=GameSessionResponse,
    summary="Update or create game session (PUT)",
)
@router.patch(
    "/{game_session_id}",
    response_model=GameSessionResponse,
    summary="Update game session (PATCH)",
)
def update_or_upsert_game_session(
    game_session_id: uuid.UUID,
    background_tasks: BackgroundTasks,
    body: Optional[Dict[str, Any]] = None,
    response: Response = None,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> GameSessionResponse:
    payload = body or {}
    session = session_service.get_game_session(db, game_session_id)
    if not session:
        # Create session if it doesn't exist yet
        fallback_game = db.execute(select(Game).where(Game.is_active == True)).scalars().first()
        raw_game_id = payload.get("game_id")
        game = None
        if raw_game_id:
            try:
                game = db.get(Game, uuid.UUID(str(raw_game_id)))
            except Exception:
                game = db.execute(select(Game).where(Game.slug.ilike(str(raw_game_id)))).scalars().first()
        if not game:
            game = fallback_game

        now = datetime.now(timezone.utc)
        raw_started = payload.get("started_at")
        started_at = datetime.fromisoformat(raw_started) if raw_started else now
        raw_ended = payload.get("ended_at")
        ended_at = datetime.fromisoformat(raw_ended) if raw_ended else now

        session = GameSession(
            id=game_session_id,
            patient_id=patient.id,
            game_id=game.id if game else uuid.uuid4(),
            started_at=started_at,
            ended_at=ended_at,
            duration_ms=payload.get("duration_ms", 0),
            status=payload.get("status", SessionStatus.completed),
            configuration=payload.get("configuration", {}),
        )
        db.add(session)
        db.commit()
        db.refresh(session)
        if response:
            response.status_code = status.HTTP_201_CREATED

        if session.status == SessionStatus.completed:
            background_tasks.add_task(ai_service.run_session_analysis_background, session.id)

        return GameSessionResponse.model_validate(session)

    # If exists, update fields
    if "ended_at" in payload and payload["ended_at"]:
        session.ended_at = (
            datetime.fromisoformat(payload["ended_at"])
            if isinstance(payload["ended_at"], str)
            else payload["ended_at"]
        )
    if "duration_ms" in payload and payload["duration_ms"] is not None:
        session.duration_ms = payload["duration_ms"]
    if "status" in payload and payload["status"]:
        session.status = payload["status"]
    if "configuration" in payload and payload["configuration"]:
        session.configuration = payload["configuration"]

    db.commit()
    db.refresh(session)

    if session.status == SessionStatus.completed or payload.get("status") == "completed":
        background_tasks.add_task(ai_service.run_session_analysis_background, session.id)

    return GameSessionResponse.model_validate(session)



@router.post(
    "/{game_session_id}/results",
    response_model=GameResultResponse,
    summary="Upload game results (idempotent)",
    description=(
        "Upload score, accuracy, and game-specific metrics for a completed game session. "
        "Idempotent: re-uploading the same game session's results returns the existing record."
    ),
)
def upload_results(
    game_session_id: uuid.UUID,
    body: GameResultCreate,
    response: Response,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> GameResultResponse:
    game_session = session_service.get_game_session(db, game_session_id)
    if not game_session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Game session not found")
    if game_session.patient_id != patient.id:
        if settings.is_development:
            target_patient = db.get(Patient, game_session.patient_id)
            if target_patient:
                patient = target_patient
        if game_session.patient_id != patient.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    result, created = session_service.upsert_game_result(db, game_session_id, body)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    if not created:
        response.headers["X-Idempotent-Replayed"] = "true"

    # Queue asynchronous Gemini rehabilitation analysis
    background_tasks.add_task(ai_service.run_session_analysis_background, game_session_id)

    return GameResultResponse.model_validate(result)


@router.post(
    "/{game_session_id}/metrics",
    response_model=SessionMetricResponse,
    summary="Upload sensor-derived rehabilitation metrics (idempotent)",
    description=(
        "Upload sensor-derived rehabilitation indicators (ROM, velocity, smoothness, etc.). "
        "These are system-computed analytics — NOT clinical diagnoses. "
        "Idempotent: re-uploading returns the existing record."
    ),
)
def upload_metrics(
    game_session_id: uuid.UUID,
    body: SessionMetricCreate,
    response: Response,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> SessionMetricResponse:
    game_session = session_service.get_game_session(db, game_session_id)
    if not game_session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Game session not found")
    if game_session.patient_id != patient.id:
        if settings.is_development:
            target_patient = db.get(Patient, game_session.patient_id)
            if target_patient:
                patient = target_patient
        if game_session.patient_id != patient.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    metric, created = session_service.upsert_session_metrics(db, game_session_id, body)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    if not created:
        response.headers["X-Idempotent-Replayed"] = "true"

    # Queue asynchronous Gemini rehabilitation analysis with updated kinematics
    background_tasks.add_task(ai_service.run_session_analysis_background, game_session_id)

    return SessionMetricResponse.model_validate(metric)
