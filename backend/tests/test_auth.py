"""
Tests for authentication: PIN hashing/verification and auth routes.
"""
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import generate_pin, hash_pin, verify_pin
from app.db.models import Patient, PatientInvitation, Profile, UserRole


def test_pin_hashing_and_verification():
    """Verify PIN hashing, verification, and random generation."""
    pin = generate_pin(6)
    assert len(pin) == 6
    assert pin.isdigit()

    hashed = hash_pin(pin)
    assert hashed != pin
    assert verify_pin(pin, hashed) is True
    assert verify_pin("000000", hashed) is False


def test_verify_pin_invalid_email(client: TestClient, db_session: Session):
    """Submitting PIN for non-existent email returns 401."""
    response = client.post(
        "/auth/verify-pin",
        json={"email": "nonexistent@example.com", "pin": "123456"},
    )
    assert response.status_code == 401
    assert "Invalid email or PIN" in response.json()["detail"]


def test_verify_pin_success_and_replay_lockout(
    client: TestClient, db_session: Session, mock_doctor: dict
):
    """
    Test full PIN verification workflow:
    1. Create patient with active invitation.
    2. Test wrong PIN decrements attempt count.
    3. Test correct PIN succeeds and marks invitation used.
    4. Replaying used PIN fails.
    """
    patient_id = uuid.uuid4()
    email = f"patient-{patient_id.hex[:8]}@example.com"
    plain_pin = "482915"

    profile = Profile(
        id=patient_id,
        email=email,
        role=UserRole.patient,
        full_name="Alice Recovering",
    )
    db_session.add(profile)

    patient = Patient(id=patient_id)
    db_session.add(patient)

    invitation = PatientInvitation(
        patient_id=patient_id,
        pin_hash=hash_pin(plain_pin),
        expires_at=datetime.now(timezone.utc) + timedelta(hours=24),
        is_used=False,
        attempt_count=0,
        created_by=mock_doctor["doctor"].id,
    )
    db_session.add(invitation)
    db_session.flush()

    # 1. Incorrect PIN attempt
    wrong_res = client.post("/auth/verify-pin", json={"email": email, "pin": "999999"})
    assert wrong_res.status_code == 401
    assert "Invalid PIN" in wrong_res.json()["detail"]

    # 2. Correct PIN attempt
    correct_res = client.post("/auth/verify-pin", json={"email": email, "pin": plain_pin})
    assert correct_res.status_code == 200
    data = correct_res.json()
    assert "PIN verified" in data["message"]

    # 3. Subsequent attempt with same PIN should now be rejected as already used
    reused_res = client.post("/auth/verify-pin", json={"email": email, "pin": plain_pin})
    assert reused_res.status_code == 401
    assert "No valid invitation found" in reused_res.json()["detail"]


def test_doctor_registration(client: TestClient, db_session: Session):
    """
    Test doctor profile registration after Supabase Auth creation.
    """
    from tests.conftest import create_mock_jwt

    new_doctor_id = uuid.uuid4()
    doc_email = f"doctor-{new_doctor_id.hex[:8]}@hospital.org"
    token = create_mock_jwt(new_doctor_id, doc_email)

    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "email": doc_email,
        "full_name": "Dr. Sarah Connor",
        "phone": "+919876543200",
        "specialization": "Neuro-rehabilitation",
        "license_number": "MED-REG-999",
        "hospital_name": "Metropolitan Health",
    }

    # First registration -> 201 Created
    res = client.post("/auth/register-doctor", json=payload, headers=headers)
    assert res.status_code == 201
    doc_data = res.json()
    assert doc_data["full_name"] == "Dr. Sarah Connor"
    assert doc_data["specialization"] == "Neuro-rehabilitation"

    # Re-registration (idempotent) -> returns existing doctor
    res_repeat = client.post("/auth/register-doctor", json=payload, headers=headers)
    assert res_repeat.status_code == 200
    assert res_repeat.json()["id"] == str(new_doctor_id)


def test_doctor_registration_without_token(client: TestClient, db_session: Session):
    """
    Test direct doctor registration without a pre-existing Bearer token.
    """
    doc_email = f"direct-doctor-{uuid.uuid4().hex[:8]}@hospital.org"
    payload = {
        "email": doc_email,
        "full_name": "Dr. Direct Portal",
        "specialization": "Physical Therapy",
        "hospital_name": "City Health",
    }

    # No Authorization header provided
    res = client.post("/auth/register-doctor", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["email"] == doc_email
    assert data["full_name"] == "Dr. Direct Portal"

    # Idempotent replay with same email
    res_repeat = client.post("/auth/register-doctor", json=payload)
    assert res_repeat.status_code == 200
    assert res_repeat.json()["id"] == data["id"]
