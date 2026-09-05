"""Games registry route. Flutter calls GET /games on startup to get game IDs."""
from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.database import get_db
from app.db.models import Profile
from app.schemas.game import GameResponse
from app.services import session_service

router = APIRouter(prefix="/games", tags=["Games"])


@router.get(
    "",
    response_model=List[GameResponse],
    summary="List active games",
    description=(
        "Returns the game registry. Flutter should call this on startup to get "
        "game IDs for use in game session uploads."
    ),
)
def list_games(
    db: Session = Depends(get_db),
    _: Profile = Depends(get_current_user),
) -> List[GameResponse]:
    games = session_service.get_all_games(db)
    return [GameResponse.model_validate(g) for g in games]
