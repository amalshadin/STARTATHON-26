"""Device and calibration routes."""
from __future__ import annotations

import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.database import get_db
from app.db.models import Profile
from app.schemas.device import (
    CalibrationCreate, CalibrationResponse, DeviceResponse, DeviceUpsert
)
from app.services import device_service

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.post(
    "",
    response_model=DeviceResponse,
    summary="Register or update a device",
    description=(
        "Upsert a HapticSync glove by device_identifier (BLE MAC). "
        "Call this on each BLE connection to update firmware_version and last_seen_at. "
        "Returns HTTP 200 for updates, 201 for new registrations."
    ),
)
def upsert_device(
    body: DeviceUpsert,
    db: Session = Depends(get_db),
    _: Profile = Depends(get_current_user),
) -> DeviceResponse:
    device, created = device_service.upsert_device(db, body)
    # Return 201 for new devices, 200 for existing (status_code set on router default 200)
    return DeviceResponse.model_validate(device)


@router.get("/{device_id}", response_model=DeviceResponse, summary="Get device by ID")
def get_device(
    device_id: uuid.UUID,
    db: Session = Depends(get_db),
    _: Profile = Depends(get_current_user),
) -> DeviceResponse:
    device = device_service.get_device_by_id(db, device_id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")
    return DeviceResponse.model_validate(device)


@router.post(
    "/{device_id}/calibrations",
    response_model=CalibrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add calibration (append-only)",
    description=(
        "Creates a new immutable calibration record for a device+patient pair. "
        "Never updates existing calibrations — each call appends a new row. "
        "Game sessions will reference this calibration_id."
    ),
)
def add_calibration(
    device_id: uuid.UUID,
    body: CalibrationCreate,
    db: Session = Depends(get_db),
    _: Profile = Depends(get_current_user),
) -> CalibrationResponse:
    device = device_service.get_device_by_id(db, device_id)
    if not device:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found")
    calibration = device_service.add_calibration(db, device_id, body)
    return CalibrationResponse.model_validate(calibration)


@router.get(
    "/{device_id}/calibrations/latest",
    response_model=Optional[CalibrationResponse],
    summary="Get latest calibration for device+patient",
)
def get_latest_calibration(
    device_id: uuid.UUID,
    patient_id: uuid.UUID,
    db: Session = Depends(get_db),
    _: Profile = Depends(get_current_user),
) -> Optional[CalibrationResponse]:
    calibration = device_service.get_latest_calibration(db, device_id, patient_id)
    if not calibration:
        return None
    return CalibrationResponse.model_validate(calibration)
