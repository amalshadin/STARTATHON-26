"""Doctor self-service routes (GET /me for doctors)."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_doctor, get_current_user
from app.db.database import get_db
from app.db.models import Doctor, Profile
from app.schemas.doctor import DoctorResponse

router = APIRouter(prefix="/doctors", tags=["Doctors"])


@router.get("/me", response_model=DoctorResponse, summary="Get current doctor profile")
def get_me(
    doctor: Doctor = Depends(get_current_doctor),
) -> DoctorResponse:
    """Returns the authenticated doctor's profile."""
    return DoctorResponse(
        id=doctor.id,
        full_name=doctor.profile.full_name,
        email=doctor.profile.email,
        phone=doctor.profile.phone,
        specialization=doctor.specialization,
        institution=doctor.institution,
        hospital_name=doctor.hospital_name,
        created_at=doctor.created_at,
    )
