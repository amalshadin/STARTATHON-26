"""Device and calibration Pydantic schemas."""
from __future__ import annotations
import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import Field
from app.schemas.common import HapticBaseModel


class DeviceUpsert(HapticBaseModel):
    """
    POST /devices — register or update a device.
    If device_identifier already exists, firmware/name are updated.
    """
    device_identifier: str = Field(
        ..., max_length=100, description="BLE MAC address or unique hardware ID"
    )
    ble_name: Optional[str] = Field(None, max_length=100)
    firmware_version: Optional[str] = Field(None, max_length=50)
    hardware_version: Optional[str] = Field(None, max_length=50)


class DeviceResponse(HapticBaseModel):
    id: uuid.UUID
    device_identifier: str
    ble_name: Optional[str] = None
    firmware_version: Optional[str] = None
    hardware_version: Optional[str] = None
    created_at: datetime
    last_seen_at: Optional[datetime] = None


class CalibrationCreate(HapticBaseModel):
    """
    POST /devices/{device_id}/calibrations.
    Creates a new immutable calibration record (never updates existing).
    flex_min/flex_max: raw ADC values per finger. Length must equal the number
    of flex sensors (currently 3 for HapticSync hardware).
    """
    patient_id: uuid.UUID
    flex_min: List[float] = Field(
        ..., min_length=1, max_length=5,
        description="Raw ADC at full extension per finger [f1, f2, f3]"
    )
    flex_max: List[float] = Field(
        ..., min_length=1, max_length=5,
        description="Raw ADC at full flexion per finger [f1, f2, f3]"
    )
    notes: Optional[str] = None


class CalibrationResponse(HapticBaseModel):
    id: uuid.UUID
    device_id: uuid.UUID
    patient_id: uuid.UUID
    flex_min: Optional[List[float]] = None
    flex_max: Optional[List[float]] = None
    calibrated_at: datetime
    notes: Optional[str] = None
