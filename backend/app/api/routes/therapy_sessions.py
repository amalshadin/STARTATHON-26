"""
Therapy session routes.
Patient-authenticated: patients upload their own sessions.
"""
from __future__ import annotations

import uuid
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_patient
from app.db.database import get_db
from app.db.models import Patient
from app.schemas.session import TherapySessionCreate, TherapySessionResponse
from app.services import session_service

router = APIRouter(prefix="/therapy-sessions", tags=["Therapy Sessions"])


@router.post(
    "",
    response_model=TherapySessionResponse,
    summary="Create therapy session (idempotent)",
    description=(
        "Flutter uploads a therapy session after it completes. "
        "The id must be a client-generated UUID v4. "
        "Sending the same id twice returns the existing session (idempotent retry). "
        "Returns 201 for new sessions, 200 for idempotent replays."
    ),
)
def create_therapy_session(
    body: TherapySessionCreate,
    response: Response,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> TherapySessionResponse:
    # Security: the session must belong to the authenticated patient
    if body.patient_id != patient.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot create therapy sessions for another patient",
        )

    session, created = session_service.upsert_therapy_session(db, body)
    response.status_code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
    if not created:
        response.headers["X-Idempotent-Replayed"] = "true"

    return TherapySessionResponse.model_validate(session)


@router.get(
    "/{session_id}",
    response_model=TherapySessionResponse,
    summary="Get therapy session",
)
def get_therapy_session(
    session_id: uuid.UUID,
    db: Session = Depends(get_db),
    patient: Patient = Depends(get_current_patient),
) -> TherapySessionResponse:
    session = session_service.get_therapy_session(db, session_id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    # Security: patient can only view their own sessions
    if session.patient_id != patient.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    return TherapySessionResponse.model_validate(session)
