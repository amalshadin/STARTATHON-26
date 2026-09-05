"""
Pytest configuration and shared fixtures for HapticSync backend tests.
"""
from __future__ import annotations

import uuid
from typing import Generator

import jwt
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.deps import get_current_doctor, get_current_patient, get_current_user
from app.db.database import SessionLocal, engine, get_db
from app.db.models import Doctor, Patient, Profile, UserRole
from app.main import app

settings = get_settings()


@pytest.fixture(scope="session")
def client() -> Generator[TestClient, None, None]:
    """TestClient instance for API requests."""
    with TestClient(app) as c:
        yield c


@pytest.fixture
def db_session() -> Generator[Session, None, None]:
    """
    Transactional database session that rolls back after each test,
    ensuring database state remains pristine.
    """
    connection = engine.connect()
    transaction = connection.begin()
    session = SessionLocal(bind=connection, join_transaction_mode="create_savepoint")

    # Override the get_db dependency for the duration of the test
    app.dependency_overrides[get_db] = lambda: session

    yield session

    app.dependency_overrides.pop(get_db, None)
    session.close()
    transaction.rollback()
    connection.close()


def create_mock_jwt(user_id: uuid.UUID, email: str) -> str:
    """Generate a valid Supabase JWT for testing."""
    payload = {
        "sub": str(user_id),
        "email": email,
        "aud": "authenticated",
        "role": "authenticated",
    }
    secret = settings.supabase_jwt_secret or "test-secret"
    return jwt.encode(payload, secret, algorithm="HS256")


@pytest.fixture
def mock_doctor(db_session: Session) -> dict:
    """Creates a mock doctor profile & record in the test transaction."""
    doctor_id = uuid.uuid4()
    profile = Profile(
        id=doctor_id,
        email=f"doctor-{doctor_id.hex[:8]}@example.com",
        role=UserRole.doctor,
        full_name="Dr. Test Specialist",
        phone="+919876543210",
    )
    db_session.add(profile)
    db_session.flush()

    doctor = Doctor(
        id=doctor_id,
        full_name=profile.full_name,
        specialization="Neurologist",
        license_number="MED-12345",
        hospital_name="Apex Rehab",
    )
    db_session.add(doctor)
    db_session.flush()

    token = create_mock_jwt(doctor_id, profile.email)
    return {
        "profile": profile,
        "doctor": doctor,
        "token": token,
        "headers": {"Authorization": f"Bearer {token}"},
    }


@pytest.fixture
def mock_patient(db_session: Session) -> dict:
    """Creates a mock patient profile & record in the test transaction."""
    patient_id = uuid.uuid4()
    profile = Profile(
        id=patient_id,
        email=f"patient-{patient_id.hex[:8]}@example.com",
        role=UserRole.patient,
        full_name="Test Patient",
        phone="+919876543211",
    )
    db_session.add(profile)
    db_session.flush()

    patient = Patient(
        id=patient_id,
        affected_side="right",
        notes="Stroke recovery test case",
    )
    db_session.add(patient)
    db_session.flush()

    token = create_mock_jwt(patient_id, profile.email)
    return {
        "profile": profile,
        "patient": patient,
        "token": token,
        "headers": {"Authorization": f"Bearer {token}"},
    }
