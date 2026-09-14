"""Session Pydantic schemas (therapy sessions, game sessions, results, metrics)."""
from __future__ import annotations
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import Field
from app.schemas.common import HapticBaseModel
from app.db.models.session import SessionStatus


# ── Game Session ──────────────────────────────────────────────────────────────

class GameSessionCreate(HapticBaseModel):
    """
    POST /game-sessions — idempotent.
    configuration must include the exact game parameters used during play.
    """
    id: uuid.UUID = Field(..., description="Client-generated UUID v4")
    patient_id: Optional[uuid.UUID] = Field(None, description="Patient UUID (defaults to authenticated patient)")
    game_id: uuid.UUID
    device_id: Optional[uuid.UUID] = None
    calibration_id: Optional[uuid.UUID] = None
    started_at: datetime
    ended_at: Optional[datetime] = None
    duration_ms: Optional[int] = Field(None, ge=0)
    status: SessionStatus = SessionStatus.completed
    configuration: Optional[Dict[str, Any]] = Field(
        default_factory=dict,
        description=(
            "Game parameters at session time. "
            "Piano: {difficulty, tempo_bpm, target_notes}. "
            "Pick-Place: {difficulty, object_count, object_speed}."
        ),
    )
    game_version: Optional[str] = Field(None, max_length=50)


class GameSessionResponse(HapticBaseModel):
    id: uuid.UUID
    patient_id: uuid.UUID
    game_id: uuid.UUID
    device_id: Optional[uuid.UUID] = None
    calibration_id: Optional[uuid.UUID] = None
    started_at: datetime
    ended_at: Optional[datetime] = None
    duration_ms: Optional[int] = None
    status: SessionStatus
    configuration: Optional[Dict[str, Any]] = None
    game_version: Optional[str] = None
    created_at: datetime


# ── Game Result ───────────────────────────────────────────────────────────────

class GameResultCreate(HapticBaseModel):
    """
    POST /game-sessions/{id}/results — idempotent (UNIQUE on game_session_id).
    Include both common columns and game-specific metrics in metrics JSONB.
    """
    score: Optional[int] = Field(None, ge=0)
    accuracy: Optional[float] = Field(None, ge=0.0, le=1.0)
    completion_rate: Optional[float] = Field(None, ge=0.0, le=1.0)
    repetitions: Optional[int] = Field(None, ge=0)
    metrics: Optional[Dict[str, Any]] = Field(
        None,
        description=(
            "Game-specific metrics. "
            "Piano: {notes_hit, notes_missed, avg_reaction_ms, finger_accuracy:{...}}. "
            "Pick-Place: {objects_picked, objects_missed, avg_pick_ms, movement_velocity}."
        ),
    )


class GameResultResponse(HapticBaseModel):
    id: uuid.UUID
    game_session_id: uuid.UUID
    score: Optional[int] = None
    accuracy: Optional[float] = None
    completion_rate: Optional[float] = None
    repetitions: Optional[int] = None
    metrics: Optional[Dict[str, Any]] = None
    created_at: datetime


# ── Session Metrics ───────────────────────────────────────────────────────────

class SessionMetricCreate(HapticBaseModel):
    """
    POST /game-sessions/{id}/metrics — idempotent (UNIQUE on game_session_id).
    algorithm_version tags which signal processing version produced these values.
    """
    algorithm_version: str = Field("v0.1", max_length=20)
    metrics: Dict[str, Any] = Field(
        ...,
        description=(
            "Sensor-derived rehabilitation indicators. "
            "Example: {finger_1_rom: 64.2, finger_2_rom: 58.7, "
            "movement_smoothness: 0.87, wrist_stability: 0.76, "
            "oscillation_index: 0.12}. "
            "IMPORTANT: these are system-computed indicators, NOT clinical diagnoses."
        ),
    )


class SessionMetricResponse(HapticBaseModel):
    id: uuid.UUID
    game_session_id: uuid.UUID
    algorithm_version: str
    metrics: Dict[str, Any]
    created_at: datetime


# ── Session history (for patient dashboard) ───────────────────────────────────

class GameSessionSummary(HapticBaseModel):
    """Lightweight game session summary for patient history views."""
    id: uuid.UUID
    game_id: uuid.UUID
    started_at: datetime
    duration_ms: Optional[int] = None
    status: SessionStatus
    score: Optional[int] = None
    accuracy: Optional[float] = None

