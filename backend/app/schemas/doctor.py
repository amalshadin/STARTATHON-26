"""Doctor Pydantic schemas."""
from __future__ import annotations
import uuid
from datetime import datetime
from typing import Optional
from pydantic import EmailStr, Field
from app.schemas.common import HapticBaseModel


class DoctorCreate(HapticBaseModel):
    """
    Used during doctor self-registration (POST /auth/register-doctor).
    The profile is created by FastAPI after Supabase Auth creates the account.
    """
    full_name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    phone: Optional[str] = Field(None, max_length=50)
    password: Optional[str] = Field(None, min_length=6, description="Optional password if creating Supabase account")
    specialization: Optional[str] = Field(None, max_length=255)
    license_number: Optional[str] = Field(None, max_length=100)
    institution: Optional[str] = Field(None, max_length=255)
    hospital_name: Optional[str] = Field(None, max_length=255)


class DoctorResponse(HapticBaseModel):
    """Doctor profile returned by the API. Does not expose sensitive data."""
    id: uuid.UUID
    full_name: str
    email: str
    phone: Optional[str] = None
    specialization: Optional[str] = None
    license_number: Optional[str] = None
    institution: Optional[str] = None
    hospital_name: Optional[str] = None
    created_at: datetime
