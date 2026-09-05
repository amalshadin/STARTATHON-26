"""Auth-related Pydantic schemas (PIN onboarding)."""
from __future__ import annotations
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

    magic_link: A Supabase-generated single-use URL. Flutter should open this
    in a browser/WebView. It signs the patient in and redirects to the app
    where they can set a permanent password.

    If SUPABASE_SERVICE_ROLE_KEY is not configured (dev mode), magic_link
    will be null and a message will explain what to do.
    """
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
