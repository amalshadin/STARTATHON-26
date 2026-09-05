"""Device and calibration service."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Device, DeviceCalibration
from app.schemas.device import CalibrationCreate, DeviceUpsert

logger = logging.getLogger(__name__)


def upsert_device(db: Session, data: DeviceUpsert) -> tuple[Device, bool]:
    """
    Create or update a Device record by device_identifier.
    last_seen_at is always updated. firmware/ble_name updated if provided.

    Returns:
        (device, was_created)
    """
    stmt = select(Device).where(Device.device_identifier == data.device_identifier)
    device = db.execute(stmt).scalar_one_or_none()

    if device is None:
        device = Device(
            device_identifier=data.device_identifier,
            ble_name=data.ble_name,
            firmware_version=data.firmware_version,
            hardware_version=data.hardware_version,
            last_seen_at=datetime.now(timezone.utc),
        )
        db.add(device)
        db.commit()
        db.refresh(device)
        return device, True
    else:
        # Update mutable fields
        if data.ble_name is not None:
            device.ble_name = data.ble_name
        if data.firmware_version is not None:
            device.firmware_version = data.firmware_version
        if data.hardware_version is not None:
            device.hardware_version = data.hardware_version
        device.last_seen_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(device)
        return device, False


def get_device_by_id(db: Session, device_id: uuid.UUID) -> Optional[Device]:
    return db.get(Device, device_id)


def add_calibration(
    db: Session,
    device_id: uuid.UUID,
    data: CalibrationCreate,
) -> DeviceCalibration:
    """
    Append a new immutable calibration record. Never updates existing records.
    Returns the new DeviceCalibration.
    """
    calibration = DeviceCalibration(
        device_id=device_id,
        patient_id=data.patient_id,
        flex_min=data.flex_min,
        flex_max=data.flex_max,
        notes=data.notes,
    )
    db.add(calibration)
    db.commit()
    db.refresh(calibration)
    return calibration


def get_latest_calibration(
    db: Session, device_id: uuid.UUID, patient_id: uuid.UUID
) -> Optional[DeviceCalibration]:
    """Return the most recent calibration for a device+patient pair."""
    stmt = (
        select(DeviceCalibration)
        .where(
            DeviceCalibration.device_id == device_id,
            DeviceCalibration.patient_id == patient_id,
        )
        .order_by(DeviceCalibration.calibrated_at.desc())
    )
    return db.execute(stmt).scalars().first()
