"""
Game registry model.

Architecture decision:
  The games table is a registry/catalogue, NOT a per-session table.
  Adding a new game (e.g., a memory coordination game) only requires
  inserting a new row here — no schema migration needed.

  Current games:
    - Piano      / slug: "piano"
    - Pick-Place / slug: "pick_and_place"

  Game-specific configuration and metrics live in JSONB columns on
  game_sessions and game_results respectively.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import List, Optional

from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


class Game(Base):
    """
    Game definition / registry entry.
    Seeded during the initial migration (see alembic/versions/).
    """
    __tablename__ = "games"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(
        String(100), nullable=False, comment="Human-readable name, e.g. 'Piano'"
    )
    slug: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        nullable=False,
        index=True,
        comment="Machine-readable identifier, e.g. 'piano' or 'pick_and_place'",
    )
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    version: Mapped[str] = mapped_column(String(20), nullable=False, default="1.0")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    game_sessions: Mapped[List["GameSession"]] = relationship(
        "GameSession", back_populates="game"
    )
