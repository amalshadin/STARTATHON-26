"""
Game session routes: create, upload results, upload metrics.
All patient-authenticated. Full idempotency on all write operations.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.deps import get_current_patient
from app.db.database import get_db
from app.db.models import Game, Patient
from app.schemas.session import (
    GameResultCreate, GameResultResponse,
    GameSessionCreate, GameSessionResponse,
    SessionMetricCreate, SessionMetricResponse,
)
from app.services import ai_service, session_service

settings = get_settings()

router = APIRouter(prefix="/game-sessions", tags=["Game Sessions"])


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
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> GameSessionResponse:
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

    # Verify game exists; in development mode, fallback to an active game if placeholder passed
    game = db.get(Game, body.game_id)
    if not game:
        if settings.is_development:
            fallback_game = db.execute(select(Game).where(Game.is_active == True)).scalars().first()
            if fallback_game:
                body.game_id = fallback_game.id
            else:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Game '{body.game_id}' not found.",
                )
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Game '{body.game_id}' not found.",
            )

    game_session, created = session_service.upsert_game_session(db, body)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    if not created:
        response.headers["X-Idempotent-Replayed"] = "true"
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
