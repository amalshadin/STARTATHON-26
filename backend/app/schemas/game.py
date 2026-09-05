"""Game registry Pydantic schemas."""
from __future__ import annotations
import uuid
from datetime import datetime
from pydantic import Field
from app.schemas.common import HapticBaseModel


class GameResponse(HapticBaseModel):
    """Game definition returned by GET /games."""
    id: uuid.UUID
    name: str
    slug: str
    description: str | None = None
    version: str
    is_active: bool
    created_at: datetime
