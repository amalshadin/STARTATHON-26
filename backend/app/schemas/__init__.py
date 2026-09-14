# HapticSync schemas package
from app.schemas.common import HapticBaseModel, UUIDResponse
from app.schemas.auth import PinVerifyRequest, PinVerifyResponse
from app.schemas.patient import PatientCreate, PatientResponse, PatientCreateResponse
from app.schemas.doctor import DoctorCreate, DoctorResponse
from app.schemas.device import DeviceUpsert, DeviceResponse, CalibrationCreate, CalibrationResponse
from app.schemas.game import GameResponse
from app.schemas.session import (
    GameSessionCreate, GameSessionResponse,
    GameResultCreate, GameResultResponse,
    SessionMetricCreate, SessionMetricResponse,
    GameSessionSummary,
)
from app.schemas.ai import (
    ParameterSuggestions,
    AIOverviewResult,
    AIOverviewResponse,
    AIGenerateRequest,
)

