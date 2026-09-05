"""Auth-related Pydantic schemas (PIN onboarding)."""
from __future__ import annotations
from pydantic import BaseModel, EmailStr, Field


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
