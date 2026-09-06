"""
Central import for all SQLAlchemy models.

IMPORTANT: This file must import all model classes in dependency order
(parents before children) so that:
  1. Alembic autogenerate can detect all tables via Base.metadata.
  2. SQLAlchemy's mapper registry can resolve all string-based relationship
     references (e.g., Mapped["GameSession"]) before the first session query.

Add new model files here when introducing new game-related models.
"""
# Enums exposed for use in services and schemas
from app.db.models.profile import (
    Profile,
    Doctor,
    Patient,
    DoctorPatient,
    PatientInvitation,
    UserRole,
    RelationshipStatus,
)

from app.db.models.device import (
    Device,
    PatientDevice,
    DeviceCalibration,
)

from app.db.models.game import Game

from app.db.models.session import (
    GameSession,
    GameResult,
    SessionMetric,
    SessionStatus,
)

from app.db.models.ai import (
    AIAnalysis,
    ClinicalReport,
    AIAnalysisStatus,
    AgentType,
)

__all__ = [
    # Profile
    "Profile", "Doctor", "Patient", "DoctorPatient", "PatientInvitation",
    "UserRole", "RelationshipStatus",
    # Device
    "Device", "PatientDevice", "DeviceCalibration",
    # Game
    "Game",
    # Session
    "GameSession", "GameResult", "SessionMetric", "SessionStatus",
    # AI
    "AIAnalysis", "ClinicalReport", "AIAnalysisStatus", "AgentType",
]
