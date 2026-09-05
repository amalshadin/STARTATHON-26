"""Common schema utilities shared across modules."""
from __future__ import annotations
import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class HapticBaseModel(BaseModel):
    """Base model with ORM mode enabled for all response schemas."""
    model_config = ConfigDict(from_attributes=True)


class UUIDResponse(HapticBaseModel):
    id: uuid.UUID
