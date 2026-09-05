"""Auth-related Pydantic schemas (PIN onboarding)."""
from __future__ import annotations
import uuid
from typing import Optional
from pydantic import BaseModel, EmailStr, Field, model_validator
from app.schemas.doctor import DoctorResponse


class PinVerifyRequest(BaseModel):
    """Request body for POST /auth/verify-pin."""
    email: EmailStr
    pin: str = Field(..., min_length=6, max_length=6, pattern=r"^\d{6}$",
                     description="6-digit numeric PIN issued by doctor")


class PinVerifyResponse(BaseModel):
    """
    Returned after a successful PIN verification.
    Includes patient_id and a Bearer access_token for the patient session.
    """
    patient_id: Optional[uuid.UUID] = None
    access_token: Optional[str] = None
    token_type: str = "bearer"
    magic_link: str | None = None
    message: str


class LoginRequest(BaseModel):
    """
    Request body for POST /auth/login.
    Supports either email or username (which can be email or doctor license number), and password.
    """
    username: Optional[str] = Field(None, description="Username, email, or license number (e.g. DOC-001001)")
    email: Optional[str] = Field(None, description="Email address")
    password: str = Field(..., min_length=1, description="Password")

    @model_validator(mode="after")
    def check_identifier(self) -> "LoginRequest":
        if not self.email and not self.username:
            raise ValueError("Either 'email' or 'username' must be provided")
        return self


class LoginResponse(BaseModel):
    """
    Response body returned on successful doctor login.
    """
    access_token: str
    token_type: str = "bearer"
    doctor: DoctorResponse
    doctor_profile: Optional[DoctorResponse] = None
