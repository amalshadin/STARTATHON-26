"""AI analysis schemas (rehabilitation overview and parameter suggestions)."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import Field

from app.db.models.ai import AgentType, AIAnalysisStatus
from app.schemas.common import HapticBaseModel


class ParameterSuggestions(HapticBaseModel):
    difficulty: Optional[str] = Field(None, description="Suggested difficulty level (e.g. easy, medium, hard)")
    target_speed_bpm: Optional[int] = Field(None, description="Suggested tempo or target speed")
    target_threshold: Optional[float] = Field(None, description="Suggested ROM or grip threshold")
    duration_target_s: Optional[int] = Field(None, description="Suggested session target duration in seconds")
    rationale: Optional[str] = Field(None, description="Clinical/analytical rationale for suggested adjustments")
    additional_parameters: Optional[Dict[str, Any]] = Field(
        default_factory=dict,
        description="Game-specific parameter overrides or suggestions",
    )


class AIOverviewResult(HapticBaseModel):
    overview: str = Field(..., description="Natural language clinical rehabilitation briefing")
    parameter_suggestions: ParameterSuggestions = Field(
        default_factory=ParameterSuggestions,
        description="Suggested parameter updates for game or therapy configuration",
    )
    key_metrics_summary: Optional[Dict[str, Any]] = Field(
        default_factory=dict,
        description="Key extracted rehabilitation metrics highlights",
    )
    focus_areas: Optional[List[str]] = Field(
        default_factory=list,
        description="Target focus areas for upcoming rehabilitation sessions",
    )


class AIOverviewResponse(HapticBaseModel):
    id: uuid.UUID
    patient_id: uuid.UUID
    game_session_id: Optional[uuid.UUID] = None
    agent_type: AgentType
    status: AIAnalysisStatus
    overview: Optional[str] = None
    parameter_suggestions: Optional[Dict[str, Any]] = None
    key_metrics_summary: Optional[Dict[str, Any]] = None
    focus_areas: Optional[List[str]] = None
    model_version: Optional[str] = None
    confidence: Optional[float] = None
    created_at: datetime


class AIGenerateRequest(HapticBaseModel):
    game_session_id: Optional[uuid.UUID] = None
    force_regenerate: bool = False


class ProgressSummaryResponse(HapticBaseModel):
    id: Optional[uuid.UUID] = None
    patient_id: uuid.UUID
    status: str = Field(..., description="'completed' if generated, 'insufficient_data' if fewer than 3 sessions exist")
    session_count: int = Field(..., description="Number of sessions analyzed (between 3 and 10, or current count if < 3)")
    min_sessions_required: int = Field(3, description="Minimum sessions required for progress summary")
    summary: Optional[str] = Field(None, description="Longitudinal rehabilitation progress overview across evaluated sessions")
    session_ids: List[uuid.UUID] = Field(default_factory=list, description="IDs of the game sessions included in this overview")
    model_version: Optional[str] = None
    created_at: Optional[datetime] = None
    message: Optional[str] = None

