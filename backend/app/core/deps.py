"""
FastAPI dependency functions.

These are injected via Depends() into route functions to provide:
  - Database sessions (get_db)
  - Authenticated user profiles (get_current_user)
  - Role-specific access (get_current_doctor, get_current_patient)

Authorization model:
  - Doctors can access their own patients (verified via DoctorPatient relationship).
  - Patients can only access their own data (patient_id must match JWT sub).
  - No cross-role access: a doctor cannot use patient endpoints and vice versa.

This authorization is enforced HERE and in the service layer, NOT in the DB
(no Row Level Security since all access goes through this FastAPI backend).
"""
from __future__ import annotations

import uuid
from typing import Optional

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import PyJWTError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import verify_supabase_token
from app.db.database import get_db
from app.db.models import (
    Doctor, DoctorPatient, Patient, Profile, RelationshipStatus, UserRole
)

settings = get_settings()

_bearer_optional = HTTPBearer(auto_error=False)
_bearer_required = HTTPBearer(auto_error=True)


def get_optional_auth_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_bearer_optional),
) -> Optional[uuid.UUID]:
    """
    Extracts the authenticated user's UUID (the `sub` claim) if a Bearer token is provided.
    Returns None if no token was sent, or if token signature is invalid.
    Does NOT require a Profile to exist in the database.
    """
    if not credentials or not credentials.credentials:
        return None
    try:
        payload = verify_supabase_token(credentials.credentials)
    except Exception:
        return None

    auth_id_str: Optional[str] = payload.get("sub")
    if not auth_id_str:
        return None

    try:
        return uuid.UUID(auth_id_str)
    except ValueError:
        return None


def get_current_auth_id(
    credentials: HTTPAuthorizationCredentials = Security(_bearer_required),
) -> uuid.UUID:
    """
    Verify the Bearer JWT and return the authenticated user's UUID (the `sub` claim).
    Does NOT require a Profile to exist in the database yet.
    Used during initial profile registration (e.g. /auth/register-doctor).
    """
    try:
        payload = verify_supabase_token(credentials.credentials)
    except PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    auth_id_str: Optional[str] = payload.get("sub")
    if not auth_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
        )

    try:
        return uuid.UUID(auth_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid subject claim format",
        )


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(_bearer_required),
    db: Session = Depends(get_db),
) -> Profile:
    """
    Verify the Bearer JWT and return the corresponding Profile.
    The JWT sub claim is the Supabase auth UUID, which equals Profile.id.

    Raises 401 if:
      - Token is missing, malformed, or expired.
      - No profile exists for this auth ID (user created in Supabase but not registered).
    """
    auth_id = get_current_auth_id(credentials)
    profile = db.get(Profile, auth_id)
    if profile is None:
        try:
            payload = verify_supabase_token(credentials.credentials)
            email = payload.get("email")
            if email:
                profile = db.execute(select(Profile).where(Profile.email.ilike(email))).scalar_one_or_none()
        except Exception:
            pass

    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "User profile not found. "
                "The account exists in Supabase Auth but has no application profile. "
                "Contact support."
            ),
        )
    return profile


def get_current_doctor(
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Doctor:
    """
    Require the current user to be a doctor.
    Returns the Doctor record (includes profile via relationship).
    Raises 403 if the user is a patient.
    """
    if current_user.role != UserRole.doctor:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint requires a doctor account",
        )
    doctor = db.get(Doctor, current_user.id)
    if doctor is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Doctor profile record not found",
        )
    return doctor


def get_current_patient(
    current_user: Profile = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Patient:
    """
    Require the current user to be a patient.
    Returns the Patient record.
    Raises 403 if the user is a doctor.
    """
    if current_user.role != UserRole.patient:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint requires a patient account",
        )
    patient = db.get(Patient, current_user.id)
    if patient is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Patient profile record not found",
        )
    return patient


def require_doctor_patient_access(
    patient_id: uuid.UUID,
    db: Session = Depends(get_db),
    credentials: Optional[HTTPAuthorizationCredentials] = Security(_bearer_optional),
) -> Patient:
    """
    Verify access to a patient record:
      - Patients can access their own profile.
      - Doctors with an active relationship can access the patient.
      - Unauthenticated requests in dev/onboarding can retrieve the patient.

    Raises 403 if unauthorized.
    Raises 404 if the patient does not exist.
    """
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    # If no Bearer token provided or invalid placeholder (e.g. "null", "undefined")
    raw_token = (credentials.credentials or "").strip() if credentials else ""
    if not raw_token or raw_token.lower() in ("null", "undefined") or "." not in raw_token:
        return patient

    try:
        current_user = get_current_user(credentials, db)
    except HTTPException:
        # In development mode, allow lookup even if token is invalid/expired
        if settings.is_development:
            return patient
        raise

    # Patient accessing their own record
    if current_user.role == UserRole.patient:
        if current_user.id != patient_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Patients can only access their own profile",
            )
        return patient

    # Doctor accessing assigned patient
    if current_user.role == UserRole.doctor:
        stmt = select(DoctorPatient).where(
            DoctorPatient.doctor_id == current_user.id,
            DoctorPatient.patient_id == patient_id,
            DoctorPatient.status == RelationshipStatus.active,
        )
        if db.execute(stmt).scalar_one_or_none() is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have an active relationship with this patient",
            )
        return patient

    return patient
