"""
Patient management routes (doctor-side).

All routes require a doctor JWT.
Authorization: doctors can only access their own patients.
"""
from __future__ import annotations

import logging
from typing import List
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_doctor, get_current_user, require_doctor_patient_access
from app.db.database import get_db
from app.db.models import Doctor, Profile
from app.schemas.patient import PatientCreate, PatientCreateResponse, PatientResponse
from app.schemas.session import TherapySessionWithGames, GameSessionSummary
from app.services import patient_service, session_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/patients", tags=["Patients"])


@router.post(
    "",
    response_model=PatientCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create patient account (doctor only)",
    description=(
        "Doctor creates a patient account. A 6-digit one-time PIN is generated and "
        "returned — share it with the patient. The PIN expires in 24 hours."
    ),
)
def create_patient(
    body: PatientCreate,
    db: Session = Depends(get_db),
    doctor: Doctor = Depends(get_current_doctor),
) -> PatientCreateResponse:
    try:
        patient, plain_pin, pin_expires_at = patient_service.create_patient(db, body, doctor)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to create Supabase account: {e}",
        )

    patient_data = PatientResponse(
        id=patient.id,
        full_name=patient.profile.full_name,
        email=patient.profile.email,
        phone=patient.profile.phone,
        date_of_birth=patient.date_of_birth,
        gender=patient.gender,
        affected_side=patient.affected_side,
        created_at=patient.created_at,
    )

    return PatientCreateResponse(
        patient=patient_data,
        pin=plain_pin,
        pin_expires_at=pin_expires_at,
    )


@router.get(
    "",
    response_model=List[PatientResponse],
    summary="List doctor's patients",
)
def list_patients(
    db: Session = Depends(get_db),
    doctor: Doctor = Depends(get_current_doctor),
) -> List[PatientResponse]:
    """Returns all patients with an active relationship to the authenticated doctor."""
    patients = patient_service.get_doctor_patients(db, doctor)
    return [
        PatientResponse(
            id=p.id,
            full_name=p.profile.full_name,
            email=p.profile.email,
            phone=p.profile.phone,
            date_of_birth=p.date_of_birth,
            gender=p.gender,
            affected_side=p.affected_side,
            created_at=p.created_at,
        )
        for p in patients
    ]


@router.get(
    "/{patient_id}",
    response_model=PatientResponse,
    summary="Get patient details",
)
def get_patient(
    patient_id: uuid.UUID,
    db: Session = Depends(get_db),
    patient=Depends(require_doctor_patient_access),
) -> PatientResponse:
    """Returns patient profile. Doctor must have an active relationship."""
    return PatientResponse(
        id=patient.id,
        full_name=patient.profile.full_name,
        email=patient.profile.email,
        phone=patient.profile.phone,
        date_of_birth=patient.date_of_birth,
        gender=patient.gender,
        affected_side=patient.affected_side,
        created_at=patient.created_at,
    )


@router.get(
    "/{patient_id}/history",
    response_model=List[TherapySessionWithGames],
    summary="Get patient session history",
)
def get_patient_history(
    patient_id: uuid.UUID,
    db: Session = Depends(get_db),
    patient=Depends(require_doctor_patient_access),
) -> List[TherapySessionWithGames]:
    """Returns recent therapy sessions with embedded game session summaries."""
    therapy_sessions = session_service.get_patient_therapy_sessions(db, patient_id)
    result = []
    for ts in therapy_sessions:
        game_summaries = []
        for gs in ts.game_sessions:
            game_summaries.append(GameSessionSummary(
                id=gs.id,
                game_id=gs.game_id,
                started_at=gs.started_at,
                duration_ms=gs.duration_ms,
                status=gs.status,
                score=gs.result.score if gs.result else None,
                accuracy=gs.result.accuracy if gs.result else None,
            ))
        result.append(TherapySessionWithGames(
            id=ts.id,
            started_at=ts.started_at,
            ended_at=ts.ended_at,
            duration_s=ts.duration_s,
            status=ts.status,
            game_sessions=game_summaries,
            created_at=ts.created_at,
        ))
    return result
