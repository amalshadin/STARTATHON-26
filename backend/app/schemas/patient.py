"""Patient Pydantic schemas."""
from __future__ import annotations
import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import EmailStr, Field
from app.schemas.common import HapticBaseModel


class PatientCreate(HapticBaseModel):
    """
    Request body for POST /patients (doctor creates a patient).
    Triggers Supabase user creation + PIN generation.
    """
    full_name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    phone: Optional[str] = Field(None, max_length=50)
    date_of_birth: Optional[date] = None
    gender: Optional[str] = Field(None, max_length=20)
    stroke_date: Optional[date] = Field(
        None, description="Date of stroke event — clinical context only, not a diagnosis"
    )
    affected_side: Optional[str] = Field(
        None, max_length=20, description="left | right | bilateral"
    )
    notes: Optional[str] = Field(
        None, description="Non-diagnostic clinical notes"
    )


class PatientResponse(HapticBaseModel):
    """Patient profile data returned by the API."""
    id: uuid.UUID
    full_name: str
    email: str
    phone: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None
    affected_side: Optional[str] = None
    created_at: datetime


class PatientCreateResponse(HapticBaseModel):
    """
    Returned after POST /patients.
    Includes the one-time PIN that the doctor must communicate to the patient.
    The PIN is shown ONCE — it is not stored in plaintext.
    """
    patient: PatientResponse
    pin: str = Field(..., description="One-time 6-digit PIN — show to doctor, then discard")
    pin_expires_at: datetime
    message: str = "Share this PIN with the patient. It expires in 24 hours."
