"""
Session models: TherapySession, GameSession, GameResult, SessionMetric.

Architecture decisions:

1. TherapySession is the top-level container for a clinical visit/home session.
   A therapy session may contain multiple game sessions (Piano + Pick-and-Place).
   Without this level, longitudinal queries across games in one visit require
   timestamp range joining, which is fragile.

2. id fields are client-generated UUIDs (no server-side default).
   Flutter generates UUID v4 before the session starts and sends it with the upload.
   This enables IDEMPOTENT uploads: if the same UUID is sent twice (retry after
   network failure), the second POST returns the existing record rather than
   creating a duplicate. The UNIQUE constraint on the primary key enforces this.

3. GameSession.configuration is JSONB (not a separate config table).
   Configuration is game-specific and varies between Piano/Pick-and-Place/future games.
   The configuration is immutable after the session — it records the exact parameters
   under which the session ran, for later metric interpretation.

4. GameResult vs SessionMetric separation:
   - GameResult: game performance data (score, accuracy, game-specific JSONB metrics).
     Uploaded immediately when the game ends. Fast, always present.
   - SessionMetric: sensor-derived rehabilitation metrics (ROM, velocity, smoothness).
     May be uploaded separately after heavier processing, or omitted if the
     algorithm isn't yet implemented for this game. Each has a UNIQUE constraint
     on game_session_id so they can be uploaded independently and idempotently.

5. Algorithm versioning:
   SessionMetric.algorithm_version tags which metric algorithm produced the values.
   This is important because when algorithms improve, we need to know which sessions
   used which version of the algorithm, especially for longitudinal comparisons.

6. No raw telemetry is stored here.
   The Flutter app buffers raw sensor samples locally during a session.
   Only derived metrics reach the cloud database. See the architecture docs
   for the reasoning behind this decision.
"""
from __future__ import annotations

import enum
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import BigInteger, DateTime, Enum as SAEnum, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


# ── Enum ──────────────────────────────────────────────────────────────────────

class SessionStatus(str, enum.Enum):
    completed = "completed"
    abandoned = "abandoned"
    interrupted = "interrupted"


# ── Models ────────────────────────────────────────────────────────────────────

class TherapySession(Base):
    """
    Top-level container representing one rehabilitation session (home or clinical).
    May contain multiple GameSession records.

    id is CLIENT-GENERATED (Flutter UUID v4). No server-side default.
    POST /therapy-sessions is idempotent: re-sending the same id returns
    the existing record.
    """
    __tablename__ = "therapy_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        comment="Client-generated UUID v4 (enables idempotent retry on upload failure)",
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
        comment="Nullable: session may occur without a glove (future UI-only mode)",
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False,
        comment="Session start time as recorded by Flutter (device clock)",
    )
    ended_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    duration_s: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, comment="Total session duration in seconds"
    )
    status: Mapped[SessionStatus] = mapped_column(
        SAEnum(SessionStatus, name="session_status"),
        nullable=False,
        default=SessionStatus.completed,
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    patient: Mapped["Patient"] = relationship("Patient", back_populates="therapy_sessions")
    device: Mapped[Optional["Device"]] = relationship("Device", back_populates="therapy_sessions")
    game_sessions: Mapped[list["GameSession"]] = relationship(
        "GameSession", back_populates="therapy_session"
    )
    ai_analyses: Mapped[list["AIAnalysis"]] = relationship(
        "AIAnalysis", back_populates="therapy_session"
    )
    clinical_reports: Mapped[list["ClinicalReport"]] = relationship(
        "ClinicalReport", back_populates="therapy_session"
    )


class GameSession(Base):
    """
    A single game played within a TherapySession.

    id is CLIENT-GENERATED (Flutter UUID v4).
    configuration records the exact game parameters so later analysis
    knows under what conditions the results were produced.
    """
    __tablename__ = "game_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        comment="Client-generated UUID v4",
    )
    therapy_session_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("therapy_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    game_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("games.id"),
        nullable=False,
        index=True,
    )
    device_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
    )
    calibration_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("device_calibrations.id", ondelete="SET NULL"),
        nullable=True,
        comment="The calibration active at the time of this session",
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_ms: Mapped[Optional[int]] = mapped_column(
        BigInteger, nullable=True, comment="Game duration in milliseconds"
    )
    status: Mapped[SessionStatus] = mapped_column(
        SAEnum(SessionStatus, name="session_status"),
        nullable=False,
        default=SessionStatus.completed,
    )
    configuration: Mapped[Optional[dict]] = mapped_column(
        JSONB,
        nullable=True,
        comment=(
            "Game config at session time. Examples:\n"
            "  Piano:       {difficulty:2, tempo_bpm:80, target_notes:30}\n"
            "  Pick-Place:  {difficulty:3, object_count:10, object_speed:1.2}"
        ),
    )
    game_version: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True,
        comment="Version of the game/Flutter app that ran this session",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    therapy_session: Mapped["TherapySession"] = relationship(
        "TherapySession", back_populates="game_sessions"
    )
    game: Mapped["Game"] = relationship("Game", back_populates="game_sessions")
    device: Mapped[Optional["Device"]] = relationship("Device", back_populates="game_sessions")
    calibration: Mapped[Optional["DeviceCalibration"]] = relationship(
        "DeviceCalibration", back_populates="game_sessions"
    )
    result: Mapped[Optional["GameResult"]] = relationship(
        "GameResult", back_populates="game_session", uselist=False
    )
    metrics: Mapped[Optional["SessionMetric"]] = relationship(
        "SessionMetric", back_populates="game_session", uselist=False
    )
    ai_analyses: Mapped[list["AIAnalysis"]] = relationship(
        "AIAnalysis", back_populates="game_session"
    )


class GameResult(Base):
    """
    Performance results for a completed GameSession.

    Common cross-game fields are proper columns (score, accuracy, completion_rate,
    repetitions) for efficient querying and sorting.

    Game-specific metrics (notes_hit, objects_picked, etc.) live in JSONB because
    they differ per game and new games would otherwise require schema migrations.

    POST /game-sessions/{id}/results is idempotent via UNIQUE(game_session_id).
    Re-uploading the same game session's results returns the existing record.
    """
    __tablename__ = "game_results"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    game_session_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("game_sessions.id", ondelete="CASCADE"),
        unique=True,       # Enforces one result per game session
        nullable=False,
        index=True,
    )
    score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    accuracy: Mapped[Optional[float]] = mapped_column(
        nullable=True, comment="0.0–1.0"
    )
    completion_rate: Mapped[Optional[float]] = mapped_column(
        nullable=True, comment="0.0–1.0, fraction of game objectives completed"
    )
    repetitions: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, comment="Total repetitions (notes played, objects picked, etc.)"
    )
    metrics: Mapped[Optional[dict]] = mapped_column(
        JSONB,
        nullable=True,
        comment=(
            "Game-specific metrics. Examples:\n"
            "  Piano: {notes_hit:42, notes_missed:8, avg_reaction_ms:420,\n"
            "          finger_accuracy:{finger_1:0.94, finger_2:0.88, finger_3:0.91}}\n"
            "  Pick-Place: {objects_picked:12, objects_missed:2, avg_pick_ms:850,\n"
            "               movement_velocity:1.42, movement_smoothness:0.81}"
        ),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    game_session: Mapped["GameSession"] = relationship(
        "GameSession", back_populates="result"
    )


class SessionMetric(Base):
    """
    Sensor-derived rehabilitation metrics for a GameSession.

    Separate from GameResult so that:
      - Flutter can upload game results immediately (fast path).
      - Heavier sensor processing can be uploaded later (slow path).
      - Future server-side reprocessing can update metrics without touching results.

    algorithm_version tags which signal processing version produced these values.
    This is important for longitudinal validity: when the algorithm improves,
    historical sessions keep their original metrics with their original version tag.

    metrics JSONB examples:
      {
        "finger_1_rom": 64.2,     # Range of motion in normalized units
        "finger_2_rom": 58.7,
        "finger_3_rom": 61.4,
        "finger_1_velocity": 2.4, # Normalized flexion velocity
        "finger_2_velocity": 2.1,
        "finger_3_velocity": 2.3,
        "movement_smoothness": 0.87,  # 0.0–1.0, higher is smoother
        "wrist_stability": 0.76,      # 0.0–1.0, higher is more stable
        "oscillation_index": 0.12     # Tremor-like activity (NOT a diagnosis)
      }

    IMPORTANT: metrics are system-computed rehabilitation indicators.
    They are NOT medical diagnoses. Label them accordingly in any UI.
    """
    __tablename__ = "session_metrics"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    game_session_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("game_sessions.id", ondelete="CASCADE"),
        unique=True,       # One metric record per game session
        nullable=False,
        index=True,
    )
    algorithm_version: Mapped[str] = mapped_column(
        String(20), nullable=False, default="v0.1"
    )
    metrics: Mapped[dict] = mapped_column(JSONB, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    game_session: Mapped["GameSession"] = relationship(
        "GameSession", back_populates="metrics"
    )
