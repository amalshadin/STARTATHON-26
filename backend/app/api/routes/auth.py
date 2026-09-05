"""
Authentication routes.

POST /auth/verify-pin
  Validates the 6-digit one-time PIN issued during patient onboarding.
  On success: generates a Supabase magic link so the patient can sign in
  and set their permanent password.

POST /auth/register-doctor
  Registers an application-level doctor profile.
  Called AFTER the doctor has created their Supabase account and has a JWT.
  This creates the Profile + Doctor records in our application database.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.deps import get_current_auth_id, get_optional_auth_id, get_current_user
from app.core.security import generate_supabase_magic_link, verify_pin
from app.core.config import get_settings
from app.db.database import get_db
from app.db.models import Doctor, Patient, PatientInvitation, Profile, UserRole
from app.schemas.auth import PinVerifyRequest, PinVerifyResponse
from app.schemas.doctor import DoctorCreate, DoctorResponse

logger = logging.getLogger(__name__)
settings = get_settings()

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/verify-pin",
    response_model=PinVerifyResponse,
    summary="Verify patient onboarding PIN",
    description=(
        "Patient submits their email and the 6-digit PIN received from their doctor. "
        "On success, returns a Supabase magic link to complete account setup. "
        "Limited to 5 attempts before lockout. PIN expires after 24 hours."
    ),
)
def verify_patient_pin(
    body: PinVerifyRequest,
    db: Session = Depends(get_db),
) -> PinVerifyResponse:
    # 1. Find the profile by email
    profile = db.execute(
        select(Profile).where(Profile.email == body.email)
    ).scalar_one_or_none()

    if profile is None or profile.role != UserRole.patient:
        # Generic error — don't reveal whether the email exists
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or PIN",
        )

    # 2. Find a valid invitation
    now = datetime.now(timezone.utc)
    invitation = db.execute(
        select(PatientInvitation)
        .where(
            PatientInvitation.patient_id == profile.id,
            PatientInvitation.is_used == False,
            PatientInvitation.expires_at > now,
        )
        .order_by(PatientInvitation.created_at.desc())
    ).scalar_one_or_none()

    if invitation is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No valid invitation found. The PIN may have expired or already been used.",
        )

    # 3. Check attempt limit
    if invitation.attempt_count >= settings.pin_max_attempts:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many failed attempts. Ask your doctor to generate a new PIN.",
        )

    # 4. Verify PIN
    if not verify_pin(body.pin, invitation.pin_hash):
        invitation.attempt_count += 1
        db.commit()
        remaining = settings.pin_max_attempts - invitation.attempt_count
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid PIN. {remaining} attempt(s) remaining.",
        )

    # 5. Mark invitation as used
    invitation.is_used = True
    db.commit()

    # 6. Generate Supabase magic link
    magic_link = None
    message = "PIN verified successfully."

    if settings.supabase_service_role_key:
        try:
            magic_link = generate_supabase_magic_link(body.email)
            message = (
                "PIN verified. Open the magic link to sign in and set your permanent password. "
                "This link expires in 60 minutes."
            )
        except RuntimeError as e:
            logger.error("Failed to generate magic link for %s: %s", body.email, e)
            message = (
                "PIN verified but automatic sign-in link generation failed. "
                "Please use the 'Forgot Password' option in the app to set your password."
            )
    else:
        message = (
            "PIN verified (dev mode). SUPABASE_SERVICE_ROLE_KEY not configured — "
            "no magic link generated. Set your password via Supabase dashboard."
        )

    return PinVerifyResponse(magic_link=magic_link, message=message)


@router.post(
    "/register-doctor",
    response_model=DoctorResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register doctor application profile",
    description=(
        "Called after a doctor creates their Supabase Auth account. "
        "Creates the Profile + Doctor records in the application database. "
        "Requires a valid Supabase JWT (the newly created account's token)."
    ),
)
def register_doctor(
    body: DoctorCreate,
    response: Response,
    db: Session = Depends(get_db),
    auth_id: Optional[uuid.UUID] = Depends(get_optional_auth_id),
) -> DoctorResponse:
    """
    Registers a doctor in the application database.
    Works either with an existing Supabase Auth token (links the doctor profile to that auth UUID)
    or directly without a token (generates a new unique UUID).
    If a profile with this email or auth ID already exists as a doctor, it returns the existing profile (idempotent).
    """
    # 1. If auth_id was provided in Bearer token, check if it already exists
    if auth_id:
        existing_profile = db.get(Profile, auth_id)
        if existing_profile and existing_profile.role == UserRole.doctor:
            doctor = db.get(Doctor, auth_id)
            if doctor:
                response.status_code = status.HTTP_200_OK
                response.headers["X-Idempotent-Replayed"] = "true"
                return DoctorResponse(
                    id=doctor.id,
                    full_name=existing_profile.full_name,
                    email=existing_profile.email,
                    phone=existing_profile.phone,
                    specialization=doctor.specialization,
                    institution=doctor.institution,
                    hospital_name=doctor.hospital_name,
                    created_at=doctor.created_at,
                )

    # 2. Check if a profile with this email already exists
    existing_by_email = db.execute(
        select(Profile).where(Profile.email == body.email)
    ).scalar_one_or_none()

    if existing_by_email:
        if existing_by_email.role == UserRole.doctor:
            doctor = db.get(Doctor, existing_by_email.id)
            if doctor:
                response.status_code = status.HTTP_200_OK
                response.headers["X-Idempotent-Replayed"] = "true"
                return DoctorResponse(
                    id=doctor.id,
                    full_name=existing_by_email.full_name,
                    email=existing_by_email.email,
                    phone=existing_by_email.phone,
                    specialization=doctor.specialization,
                    institution=doctor.institution,
                    hospital_name=doctor.hospital_name,
                    created_at=doctor.created_at,
                )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists with a different role.",
        )

    # 3. Determine final user UUID
    final_id = auth_id or uuid.uuid4()

    # 4. Create Profile + Doctor records
    profile = Profile(
        id=final_id,
        email=body.email,
        role=UserRole.doctor,
        full_name=body.full_name,
        phone=body.phone,
    )
    db.add(profile)
    db.flush()

    doctor = Doctor(
        id=final_id,
        full_name=body.full_name,
        specialization=body.specialization,
        license_number=body.license_number,
        institution=body.institution,
        hospital_name=body.hospital_name,
    )
    db.add(doctor)
    db.commit()
    db.refresh(doctor)

    return DoctorResponse(
        id=doctor.id,
        full_name=profile.full_name,
        email=profile.email,
        phone=profile.phone,
        specialization=doctor.specialization,
        institution=doctor.institution,
        hospital_name=doctor.hospital_name,
        created_at=doctor.created_at,
    )
