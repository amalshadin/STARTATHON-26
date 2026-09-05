"""
Patient service: doctor-initiated patient creation with PIN onboarding.

Flow for POST /patients:
  1. Verify email not already in use.
  2. Create Supabase Auth user (via Admin API) with a random strong temp password.
     Patient never knows this temp password.
  3. Create Profile + Patient records in our DB.
  4. Create DoctorPatient relationship.
  5. Generate 6-digit PIN, store bcrypt hash in PatientInvitation.
  6. Return PIN (plaintext, shown once) + patient record to the doctor.

If SUPABASE_SERVICE_ROLE_KEY is not configured (dev mode), step 2 is skipped
and the patient profile is created without a corresponding Supabase Auth account.
The doctor must create the Supabase account manually via the dashboard.
"""
from __future__ import annotations

import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import (
    create_supabase_user,
    generate_pin,
    hash_pin,
)
from app.db.models import (
    Doctor,
    DoctorPatient,
    Patient,
    PatientInvitation,
    Profile,
    RelationshipStatus,
    UserRole,
)
from app.schemas.patient import PatientCreate, PatientCreateResponse, PatientResponse

logger = logging.getLogger(__name__)
settings = get_settings()


def create_patient(
    db: Session,
    data: PatientCreate,
    doctor: Doctor,
) -> tuple[Patient, str, datetime]:
    """
    Create a new patient account.

    Returns:
        (patient, plaintext_pin, pin_expires_at)
        The plaintext PIN must be shown to the doctor and then discarded.
        Only the bcrypt hash is stored in the database.

    Raises:
        ValueError: if email is already registered.
        RuntimeError: if Supabase user creation fails.
    """
    # 1. Check email uniqueness
    existing = db.execute(
        select(Profile).where(Profile.email == data.email)
    ).scalar_one_or_none()
    if existing:
        raise ValueError(f"Email '{data.email}' is already registered")

    # 2. Determine the patient's Supabase auth UUID
    patient_auth_id = uuid.uuid4()  # default: we generate it

    if settings.supabase_service_role_key:
        # Create Supabase Auth account with a random strong temp password
        temp_password = secrets.token_urlsafe(32)
        try:
            supabase_user = create_supabase_user(data.email, temp_password)
            patient_auth_id = uuid.UUID(supabase_user["id"])
            logger.info("Created Supabase user %s for %s", patient_auth_id, data.email)
        except RuntimeError as e:
            logger.error("Supabase user creation failed: %s", e)
            raise
    else:
        logger.warning(
            "SUPABASE_SERVICE_ROLE_KEY not set — patient %s created in DB only. "
            "Create the Supabase Auth account manually using the Supabase dashboard.",
            data.email,
        )

    # 3. Create Profile record (id == supabase auth uuid)
    profile = Profile(
        id=patient_auth_id,
        email=data.email,
        role=UserRole.patient,
        full_name=data.full_name,
        phone=data.phone,
    )
    db.add(profile)
    db.flush()  # Ensure profile.id is set before creating Patient

    # 4. Create Patient record
    patient = Patient(
        id=patient_auth_id,
        date_of_birth=data.date_of_birth,
        gender=data.gender,
        stroke_date=data.stroke_date,
        affected_side=data.affected_side,
        notes=data.notes,
        created_by_doctor_id=doctor.id,
    )
    db.add(patient)
    db.flush()

    # 5. Create DoctorPatient relationship
    relationship_record = DoctorPatient(
        doctor_id=doctor.id,
        patient_id=patient_auth_id,
        status=RelationshipStatus.active,
    )
    db.add(relationship_record)
    db.flush()

    # 6. Generate PIN and store hash
    plain_pin = generate_pin(6)
    pin_expires_at = datetime.now(timezone.utc) + timedelta(hours=settings.pin_expiry_hours)
    invitation = PatientInvitation(
        patient_id=patient_auth_id,
        pin_hash=hash_pin(plain_pin),
        expires_at=pin_expires_at,
        is_used=False,
        attempt_count=0,
        created_by=doctor.id,
    )
    db.add(invitation)
    db.commit()
    db.refresh(patient)

    return patient, plain_pin, pin_expires_at


def get_patient_by_id(db: Session, patient_id: uuid.UUID) -> Optional[Patient]:
    """Fetch a patient by their UUID. Returns None if not found."""
    return db.get(Patient, patient_id)


def get_doctor_patients(db: Session, doctor: Doctor) -> List[Patient]:
    """Return all patients with an active relationship to this doctor."""
    stmt = (
        select(Patient)
        .join(DoctorPatient, DoctorPatient.patient_id == Patient.id)
        .where(
            DoctorPatient.doctor_id == doctor.id,
            DoctorPatient.status == RelationshipStatus.active,
        )
    )
    return list(db.execute(stmt).scalars().all())


def get_pending_invitation(db: Session, patient_id: uuid.UUID) -> Optional[PatientInvitation]:
    """Get the most recent active (unused, not expired) invitation for a patient."""
    now = datetime.now(timezone.utc)
    stmt = (
        select(PatientInvitation)
        .where(
            PatientInvitation.patient_id == patient_id,
            PatientInvitation.is_used == False,
            PatientInvitation.expires_at > now,
            PatientInvitation.attempt_count < settings.pin_max_attempts,
        )
        .order_by(PatientInvitation.created_at.desc())
    )
    return db.execute(stmt).scalar_one_or_none()
