"""
AI analysis and overview routes.
Provides clinical summaries, rehabilitation briefings, and game parameter suggestions
powered by Google Gemini. Accessible to both doctors and patients.
"""
from __future__ import annotations

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.deps import require_doctor_patient_access
from app.db.database import get_db
from app.db.models.ai import AIAnalysis, AIAnalysisStatus
from app.db.models.profile import Patient
from app.db.models.session import GameSession
from app.schemas.ai import AIGenerateRequest, AIOverviewResponse, ProgressSummaryResponse
from app.services import ai_service

router = APIRouter(tags=["AI Overview"])


@router.get(
    "/patients/{patient_id}/ai-overview",
    response_model=AIOverviewResponse,
    summary="Get latest AI overview and parameter suggestions for a patient",
    description=(
        "Returns the most recent Gemini-generated rehabilitation briefing and suggested "
        "game parameter updates for the patient. Cached in database for instant retrieval. "
        "Pass ?regenerate=true to trigger on-demand generation from latest session data."
    ),
)
async def get_patient_ai_overview(
    patient_id: uuid.UUID,
    regenerate: bool = Query(False, description="Force on-demand Gemini generation if true"),
    db: Session = Depends(get_db),
    patient: Patient = Depends(require_doctor_patient_access),
) -> AIOverviewResponse:
    if not regenerate:
        analysis = ai_service.get_latest_patient_overview(db, patient_id)
        if analysis:
            return ai_service.format_ai_response(analysis)

    # If no cached analysis or regenerate requested, locate the patient's latest game session
    stmt = (
        select(GameSession)
        .where(GameSession.patient_id == patient_id)
        .order_by(GameSession.started_at.desc())
        .limit(1)
    )
    latest_game_session = db.execute(stmt).scalar_one_or_none()

    if not latest_game_session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No game sessions found for this patient to generate an AI overview.",
        )

    analysis = await ai_service.process_and_save_ai_analysis(db, latest_game_session.id)
    if not analysis:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate AI overview.",
        )

    return ai_service.format_ai_response(analysis)


@router.post(
    "/patients/{patient_id}/ai-overview/generate",
    response_model=AIOverviewResponse,
    summary="Generate on-demand AI overview for patient",
    description=(
        "Explicitly triggers Gemini generation for the patient's specified session "
        "(or latest session if omitted) and updates the database."
    ),
)
async def generate_patient_ai_overview(
    patient_id: uuid.UUID,
    body: Optional[AIGenerateRequest] = None,
    db: Session = Depends(get_db),
    patient: Patient = Depends(require_doctor_patient_access),
) -> AIOverviewResponse:
    target_game_session_id = body.game_session_id if body else None

    if not target_game_session_id:
        stmt = (
            select(GameSession)
            .where(GameSession.patient_id == patient_id)
            .order_by(GameSession.started_at.desc())
            .limit(1)
        )
        latest = db.execute(stmt).scalar_one_or_none()
        if not latest:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No game sessions available to generate AI overview.",
            )
        target_game_session_id = latest.id

    analysis = await ai_service.process_and_save_ai_analysis(db, target_game_session_id)
    if not analysis:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate AI overview.",
        )

    return ai_service.format_ai_response(analysis)


@router.get(
    "/game-sessions/{game_session_id}/ai-overview",
    response_model=AIOverviewResponse,
    summary="Get AI overview for a specific game session",
)
def get_game_session_ai_overview(
    game_session_id: uuid.UUID,
    db: Session = Depends(get_db),
) -> AIOverviewResponse:
    stmt = (
        select(AIAnalysis)
        .where(
            AIAnalysis.game_session_id == game_session_id,
            AIAnalysis.status == AIAnalysisStatus.completed,
        )
        .order_by(AIAnalysis.created_at.desc())
        .limit(1)
    )
    analysis = db.execute(stmt).scalar_one_or_none()
    if not analysis:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No AI analysis found for this game session.",
        )
    return ai_service.format_ai_response(analysis)


@router.get(
    "/patients/{patient_id}/progress-summary",
    response_model=ProgressSummaryResponse,
    summary="Get multi-session AI progress summary across past 3 to 10 game sessions",
    description=(
        "Returns a longitudinal overview generated from the patient's past 3 to 10 game sessions. "
        "Requires a minimum of 3 game sessions. If fewer than 3 sessions exist, returns "
        "status 'insufficient_data'. Cached in database; pass ?regenerate=true to trigger fresh generation."
    ),
)
async def get_patient_progress_summary(
    patient_id: uuid.UUID,
    regenerate: bool = Query(False, description="Force on-demand Gemini generation if true"),
    db: Session = Depends(get_db),
    patient: Patient = Depends(require_doctor_patient_access),
) -> ProgressSummaryResponse:
    # 1. Check existing sessions count for this patient (up to 10)
    sessions = ai_service.get_patient_session_batch(db, patient_id, limit=10)
    session_count = len(sessions)

    if session_count < 3:
        return ProgressSummaryResponse(
            patient_id=patient_id,
            status="insufficient_data",
            session_count=session_count,
            min_sessions_required=3,
            summary=None,
            session_ids=[s.id for s in sessions],
            message=f"At least 3 completed game sessions are required to generate a progress summary (current: {session_count}).",
        )

    # 2. Check if a cached progress summary exists and regenerate is False
    if not regenerate:
        cached = ai_service.get_latest_progress_summary(db, patient_id)
        if cached:
            return ProgressSummaryResponse(
                id=cached.id,
                patient_id=cached.patient_id,
                status="completed",
                session_count=cached.session_count,
                min_sessions_required=3,
                summary=cached.summary,
                session_ids=[uuid.UUID(sid) if isinstance(sid, str) else sid for sid in cached.session_ids] if cached.session_ids else [],
                model_version=cached.model_version,
                created_at=cached.created_at,
            )

    # 3. Generate fresh progress summary across past 3-10 sessions
    record = await ai_service.generate_and_save_progress_summary(db, patient_id, limit=10)
    return ProgressSummaryResponse(
        id=record.id,
        patient_id=record.patient_id,
        status="completed",
        session_count=record.session_count,
        min_sessions_required=3,
        summary=record.summary,
        session_ids=[uuid.UUID(sid) if isinstance(sid, str) else sid for sid in record.session_ids] if record.session_ids else [],
        model_version=record.model_version,
        created_at=record.created_at,
    )


