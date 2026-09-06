"""
User identity models: Profile, Doctor, Patient, DoctorPatient, PatientInvitation.

Architecture decisions documented here:

1. Profile.id == Supabase auth.users.id
   The `sub` claim from the Supabase JWT is used as our profile primary key.
   This eliminates an extra auth_id join column and makes user lookup O(1).
   We never store passwords in this table — Supabase Auth owns authentication.

2. Doctor and Patient tables extend Profile via shared primary key (FK→profiles.id).
   This is the "concrete table inheritance" pattern: cleaner than a single large
   profiles table with many nullable columns, but avoids a full ORM inheritance
   hierarchy which would complicate queries.

3. DoctorPatient is a proper relationship table, NOT a doctor_id on patients.
   A patient may be seen by multiple doctors (primary + specialist).
   Relationships track status (active/inactive/transferred) and history.

4. PatientInvitation stores bcrypt(PIN), never the PIN plaintext.
   PIN expires after 24h. Max 5 attempts before lockout. One-time use.
   See services/patient_service.py for the full onboarding flow.
"""
from __future__ import annotations

import enum
import uuid
from datetime import datetime
from typing import List, Optional

from sqlalchemy import (
    Boolean, Date, DateTime, Enum as SAEnum,
    ForeignKey, Integer, String, Text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


# ── Enums ─────────────────────────────────────────────────────────────────────

class UserRole(str, enum.Enum):
    doctor = "doctor"
    patient = "patient"


class RelationshipStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"
    transferred = "transferred"


# ── Models ────────────────────────────────────────────────────────────────────

class Profile(Base):
    """
    Shared identity record for every user (doctor or patient).
    id == Supabase auth.users.id (the `sub` claim from the JWT).
    Role-specific data lives in Doctor or Patient child tables.
    """
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        comment="Must equal Supabase auth.users.id (JWT sub claim)",
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    role: Mapped[UserRole] = mapped_column(SAEnum(UserRole, name="user_role"), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    hashed_password: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # 1:1 role-specific extension records
    doctor: Mapped[Optional["Doctor"]] = relationship(
        "Doctor", back_populates="profile", uselist=False
    )
    patient: Mapped[Optional["Patient"]] = relationship(
        "Patient", back_populates="profile", uselist=False
    )


class Doctor(Base):
    """
    Doctor-specific profile data.
    id is a FK to profiles.id (shared primary key pattern).
    """
    __tablename__ = "doctors"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        primary_key=True,
    )
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    specialization: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    license_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    institution: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    hospital_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    profile: Mapped["Profile"] = relationship("Profile", back_populates="doctor")
    doctor_patients: Mapped[List["DoctorPatient"]] = relationship(
        "DoctorPatient", back_populates="doctor", foreign_keys="DoctorPatient.doctor_id"
    )
    created_invitations: Mapped[List["PatientInvitation"]] = relationship(
        "PatientInvitation",
        back_populates="created_by_doctor",
        foreign_keys="PatientInvitation.created_by",
    )
    clinical_reports: Mapped[List["ClinicalReport"]] = relationship(
        "ClinicalReport", back_populates="doctor"
    )


class Patient(Base):
    """
    Patient-specific profile data.
    id is a FK to profiles.id (shared primary key pattern).

    Notes:
      - stroke_date / affected_side are clinical context fields, NOT diagnoses.
      - notes is a free-text field for the doctor's non-diagnostic observations.
      - date_of_birth is stored so age can be computed for analytics (not displayed raw).
      - created_by_doctor_id records which doctor created this account.
    """
    __tablename__ = "patients"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        primary_key=True,
    )
    date_of_birth: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    stroke_date: Mapped[Optional[datetime]] = mapped_column(
        Date,
        nullable=True,
        comment="Date of stroke event — clinical context, not a diagnosis",
    )
    affected_side: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="left | right | bilateral",
    )
    notes: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Non-diagnostic clinical notes by the doctor",
    )
    created_by_doctor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("doctors.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="The doctor who created this patient account",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    profile: Mapped["Profile"] = relationship("Profile", back_populates="patient")
    doctor_patients: Mapped[List["DoctorPatient"]] = relationship(
        "DoctorPatient", back_populates="patient", foreign_keys="DoctorPatient.patient_id"
    )
    game_sessions: Mapped[List["GameSession"]] = relationship(
        "GameSession", back_populates="patient", cascade="all, delete-orphan"
    )
    patient_devices: Mapped[List["PatientDevice"]] = relationship(
        "PatientDevice", back_populates="patient"
    )
    invitations: Mapped[List["PatientInvitation"]] = relationship(
        "PatientInvitation",
        back_populates="patient",
        foreign_keys="PatientInvitation.patient_id",
    )
    ai_analyses: Mapped[List["AIAnalysis"]] = relationship(
        "AIAnalysis", back_populates="patient"
    )
    clinical_reports: Mapped[List["ClinicalReport"]] = relationship(
        "ClinicalReport", back_populates="patient"
    )


class DoctorPatient(Base):
    """
    Doctor–Patient relationship table.

    Reasons for a relationship table instead of doctor_id on Patient:
      - A patient may be under multiple doctors (primary + specialist).
      - Relationships have a lifecycle: active → inactive/transferred.
      - Historical relationship data matters for longitudinal clinical context.

    The service layer enforces that a (doctor_id, patient_id) pair
    has at most one 'active' record at a time.
    """
    __tablename__ = "doctor_patients"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    doctor_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("doctors.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[RelationshipStatus] = mapped_column(
        SAEnum(RelationshipStatus, name="relationship_status"),
        nullable=False,
        default=RelationshipStatus.active,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    ended_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    doctor: Mapped["Doctor"] = relationship(
        "Doctor", back_populates="doctor_patients", foreign_keys=[doctor_id]
    )
    patient: Mapped["Patient"] = relationship(
        "Patient", back_populates="doctor_patients", foreign_keys=[patient_id]
    )


class PatientInvitation(Base):
    """
    Short-lived, one-time PIN token used for patient onboarding.

    Security properties (see AD-2 in implementation_plan.md):
      - PIN is bcrypt-hashed — the plaintext PIN is never stored.
      - Expires after `pin_expiry_hours` (default: 24 hours).
      - One-time use: `is_used` is set to True after first successful verification.
      - Brute-force protected: locked after `pin_max_attempts` failed attempts.

    Flow:
      1. Doctor calls POST /patients → backend generates PIN, stores hash here.
      2. Doctor communicates PIN to patient verbally/on paper.
      3. Patient calls POST /auth/verify-pin → backend verifies → returns Supabase magic link.
      4. Patient opens magic link → sets permanent password.
    """
    __tablename__ = "patient_invitations"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    pin_hash: Mapped[str] = mapped_column(
        String(255), nullable=False, comment="bcrypt hash of the 6-digit PIN"
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_by: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("doctors.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    patient: Mapped["Patient"] = relationship(
        "Patient", back_populates="invitations", foreign_keys=[patient_id]
    )
    created_by_doctor: Mapped["Doctor"] = relationship(
        "Doctor", back_populates="created_invitations", foreign_keys=[created_by]
    )
