"""
Hardware models: Device, PatientDevice, DeviceCalibration.

Architecture decisions:

1. Device is glove-centric (identified by BLE MAC or unique hardware ID).
   PatientDevice tracks which patient is currently using which device,
   supporting device replacement and history.

2. DeviceCalibration is APPEND-ONLY (never updated in place).
   Each calibration event creates a new row. GameSessions reference
   calibration_id so we always know exactly what calibration was active
   when a particular session was recorded.
   This is critical for interpreting historical metric data correctly
   when calibration values drift or change over time.

3. flex_min / flex_max are PostgreSQL FLOAT arrays.
   Current hardware has 3 flex sensors → arrays of length 3.
   Schema supports up to N sensors without migration (array length is flexible).
   Index 0 = finger_1, index 1 = finger_2, index 2 = finger_3.

4. No FSR (Force Sensitive Resistor): the spec uses MPU6050 + 3 flex sensors only.
   FSR fields from the earlier Flutter prototype are intentionally excluded.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import List, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PGUUID
from sqlalchemy import Float
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


class Device(Base):
    """
    Physical HapticSync smart glove device.
    device_identifier is the BLE MAC address or a unique hardware ID.
    firmware_version and hardware_version are updated by the Flutter app
    on each connection (via POST /devices upsert).
    """
    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    device_identifier: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False, index=True,
        comment="BLE MAC address or unique hardware ID",
    )
    ble_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    firmware_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    hardware_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True,
        comment="Updated by Flutter app on each BLE connection",
    )

    # Relationships
    patient_devices: Mapped[List["PatientDevice"]] = relationship(
        "PatientDevice", back_populates="device"
    )
    calibrations: Mapped[List["DeviceCalibration"]] = relationship(
        "DeviceCalibration", back_populates="device"
    )
    game_sessions: Mapped[List["GameSession"]] = relationship(
        "GameSession", back_populates="device"
    )


class PatientDevice(Base):
    """
    Tracks which patient is using which device over time.
    is_active=False when a device is unassigned or replaced.
    Multiple historical records are allowed per (patient, device) pair.
    """
    __tablename__ = "patient_devices"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    unassigned_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships
    patient: Mapped["Patient"] = relationship("Patient", back_populates="patient_devices")
    device: Mapped["Device"] = relationship("Device", back_populates="patient_devices")


class DeviceCalibration(Base):
    """
    Immutable calibration record for a device+patient pair.

    APPEND-ONLY: Never update in place. Each calibration session creates
    a new row. GameSession.calibration_id references the exact calibration
    that was active during that session, enabling correct historical metric
    interpretation even when calibration values change later.

    flex_min[i] = raw ADC value when finger i is fully extended.
    flex_max[i] = raw ADC value when finger i is fully flexed.

    Current hardware: 3 fingers → arrays have length 3.
    Indices: [0]=finger_1, [1]=finger_2, [2]=finger_3.

    Important: We do NOT claim these values represent absolute finger angles.
    They are device-specific ADC extremes used for [0.0, 1.0] normalization.
    """
    __tablename__ = "device_calibrations"

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    device_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("patients.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    flex_min: Mapped[Optional[List[float]]] = mapped_column(
        ARRAY(Float),
        nullable=True,
        comment="Raw ADC values at full extension, per finger [f1, f2, f3]",
    )
    flex_max: Mapped[Optional[List[float]]] = mapped_column(
        ARRAY(Float),
        nullable=True,
        comment="Raw ADC values at full flexion, per finger [f1, f2, f3]",
    )
    calibrated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    device: Mapped["Device"] = relationship("Device", back_populates="calibrations")
    patient: Mapped["Patient"] = relationship("Patient")
    game_sessions: Mapped[List["GameSession"]] = relationship(
        "GameSession", back_populates="calibration"
    )
