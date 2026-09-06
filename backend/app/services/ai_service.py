"""
AI Analysis service for rehabilitation data.
Aggregates telemetry, orchestrates Gemini generation, and persists results to PostgreSQL.
"""
from __future__ import annotations

import logging
import uuid
from typing import Any, Dict, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.config import get_settings
from app.db.database import SessionLocal
from app.db.models.ai import AgentType, AIAnalysis, AIAnalysisStatus, PatientProgressSummary
from app.db.models.game import Game
from app.db.models.profile import Patient
from app.db.models.session import GameResult, GameSession, SessionMetric
from app.schemas.ai import AIOverviewResponse, ProgressSummaryResponse
from app.services.gemini_service import (
    generate_gemini_rehabilitation_overview,
    generate_multi_session_progress_summary,
)

logger = logging.getLogger(__name__)
settings = get_settings()


def build_session_telemetry_payload(
    db: Session,
    game_session: GameSession,
) -> Dict[str, Any]:
    """Assembles all available telemetry and metadata for a game session."""
    patient = db.get(Patient, game_session.patient_id) if game_session.patient_id else None
    game = db.get(Game, game_session.game_id) if game_session.game_id else None

    # Fetch results and metrics
    stmt_result = select(GameResult).where(GameResult.game_session_id == game_session.id)
    game_result = db.execute(stmt_result).scalar_one_or_none()

    stmt_metric = select(SessionMetric).where(SessionMetric.game_session_id == game_session.id)
    session_metric = db.execute(stmt_metric).scalar_one_or_none()

    duration_s = (game_session.duration_ms // 1000) if game_session.duration_ms else 0

    return {
        "patient_id": str(patient.id) if patient else None,
        "patient_name": (patient.profile.full_name if (patient and patient.profile) else "Patient"),
        "affected_side": patient.affected_side if patient else None,
        "game_id": str(game.id) if game else str(game_session.game_id),
        "game_title": game.name if game else "Rehabilitation Activity",
        "game_slug": game.slug if game else "custom-game",
        "configuration": game_session.configuration or {},
        "started_at": game_session.started_at.isoformat() if game_session.started_at else None,
        "duration_s": duration_s or 0,
        "score": game_result.score if game_result else 0,
        "accuracy": game_result.accuracy if game_result else 0.0,
        "completion_rate": game_result.completion_rate if game_result else 1.0,
        "repetitions": game_result.repetitions if game_result else 0,
        "game_metrics": game_result.metrics if game_result else {},
        "kinematics": session_metric.metrics if session_metric else {},
    }


async def process_and_save_ai_analysis(
    db: Session,
    game_session_id: uuid.UUID,
) -> Optional[AIAnalysis]:
    """Runs Gemini generation for a game session and saves to ai_analyses table."""
    game_session = db.get(GameSession, game_session_id)
    if not game_session:
        logger.error("GameSession %s not found for AI analysis", game_session_id)
        return None

    patient_id = game_session.patient_id
    telemetry = build_session_telemetry_payload(db, game_session)

    # Call Gemini
    ai_output = await generate_gemini_rehabilitation_overview(telemetry)

    # Check for existing analysis record to update idempotently
    stmt = select(AIAnalysis).where(AIAnalysis.game_session_id == game_session_id)
    analysis = db.execute(stmt).scalar_one_or_none()

    if analysis:
        analysis.status = AIAnalysisStatus.completed
        analysis.result = ai_output
        analysis.model_version = settings.gemini_model or "gemini-2.0-flash"
    else:
        analysis = AIAnalysis(
            patient_id=patient_id,
            game_session_id=game_session.id,
            agent_type=AgentType.clinical_summary,
            status=AIAnalysisStatus.completed,
            result=ai_output,
            model_version=settings.gemini_model or "gemini-2.0-flash",
            confidence=0.90,
        )
        db.add(analysis)

    db.commit()
    db.refresh(analysis)
    logger.info("Saved AIAnalysis %s for patient %s", analysis.id, patient_id)
    return analysis


async def run_session_analysis_background(game_session_id: uuid.UUID) -> None:
    """Entry point for FastAPI BackgroundTasks (creates its own database session)."""
    db = SessionLocal()
    try:
        await process_and_save_ai_analysis(db, game_session_id)
    except Exception as exc:
        logger.exception("Background AI analysis failed for session %s: %s", game_session_id, exc)
    finally:
        db.close()


def get_latest_patient_overview(
    db: Session,
    patient_id: uuid.UUID,
) -> Optional[AIAnalysis]:
    """Retrieves the most recent completed AI analysis for a patient."""
    stmt = (
        select(AIAnalysis)
        .where(
            AIAnalysis.patient_id == patient_id,
            AIAnalysis.status == AIAnalysisStatus.completed,
        )
        .order_by(AIAnalysis.created_at.desc())
        .limit(1)
    )
    return db.execute(stmt).scalar_one_or_none()


def format_ai_response(analysis: AIAnalysis) -> AIOverviewResponse:
    """Formats an AIAnalysis ORM model into the standard response schema."""
    result_data = analysis.result or {}
    return AIOverviewResponse(
        id=analysis.id,
        patient_id=analysis.patient_id,
        game_session_id=analysis.game_session_id,
        agent_type=analysis.agent_type,
        status=analysis.status,
        overview=result_data.get("overview"),
        parameter_suggestions=result_data.get("parameter_suggestions"),
        key_metrics_summary=result_data.get("key_metrics_summary"),
        focus_areas=result_data.get("focus_areas"),
        model_version=analysis.model_version,
        confidence=analysis.confidence,
        created_at=analysis.created_at,
    )


def get_patient_session_batch(
    db: Session,
    patient_id: uuid.UUID,
    limit: int = 10,
) -> list[GameSession]:
    """
    Retrieves the most recent completed game sessions for a patient up to limit (default 10),
    ordered newest to oldest. Eager-loads game, result, and session_metric.
    """
    stmt = (
        select(GameSession)
        .options(
            joinedload(GameSession.game),
            joinedload(GameSession.result),
            joinedload(GameSession.metrics),
        )
        .where(GameSession.patient_id == patient_id)
        .order_by(GameSession.started_at.desc())
        .limit(limit)
    )
    return list(db.execute(stmt).scalars().unique().all())


def get_latest_progress_summary(
    db: Session,
    patient_id: uuid.UUID,
) -> Optional[PatientProgressSummary]:
    """Retrieves the most recent multi-session progress summary for a patient."""
    stmt = (
        select(PatientProgressSummary)
        .where(PatientProgressSummary.patient_id == patient_id)
        .order_by(PatientProgressSummary.created_at.desc())
        .limit(1)
    )
    return db.execute(stmt).scalar_one_or_none()


async def generate_and_save_progress_summary(
    db: Session,
    patient_id: uuid.UUID,
    limit: int = 10,
) -> PatientProgressSummary:
    """
    Collects past 3 to 10 game sessions for a patient, passes the aggregated telemetry
    to Gemini to generate a longitudinal progress overview, and saves it to patient_progress_summaries.
    Raises ValueError if fewer than 3 sessions exist.
    """
    sessions = get_patient_session_batch(db, patient_id, limit=limit)
    if len(sessions) < 3:
        raise ValueError(
            f"At least 3 completed game sessions are required to generate a progress summary. Current sessions: {len(sessions)}"
        )

    # Build telemetry payload for each session
    batch_telemetry = []
    for s in sessions:
        batch_telemetry.append(build_session_telemetry_payload(db, s))

    # Generate summary text with Gemini
    summary_text = await generate_multi_session_progress_summary(batch_telemetry)

    # Persist record in patient_progress_summaries
    record = PatientProgressSummary(
        patient_id=patient_id,
        session_count=len(sessions),
        session_ids=[str(s.id) for s in sessions],
        summary=summary_text,
        model_version=settings.gemini_model or "gemini-2.0-flash",
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    logger.info(
        "Saved longitudinal progress summary %s for patient %s across %d sessions",
        record.id, patient_id, len(sessions),
    )
    return record

