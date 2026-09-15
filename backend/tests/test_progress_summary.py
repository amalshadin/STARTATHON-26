"""
Tests for multi-session AI progress summary route and auto-generation:
- GET /patients/{patient_id}/progress-summary
- GET /patients/{patient_id}/ai-progress-overview
- Auto-generation of 5-session overview right after session analysis
"""
import uuid
from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Game
from app.db.models.ai import AIAnalysis, PatientProgressSummary
from app.services import ai_service


def test_progress_summary_insufficient_sessions(
    client: TestClient, db_session: Session, mock_patient: dict
):
    """Verify that 0 sessions returns status='insufficient_data'."""
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]

    res = client.get(f"/patients/{patient_id}/progress-summary", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["status"] == "insufficient_data"
    assert data["min_sessions_required"] == 1
    assert data["session_count"] == 0
    assert data["summary"] is None
    assert "At least 1 completed game session is required" in data["message"]


def test_progress_summary_with_five_sessions(
    client: TestClient, db_session: Session, mock_patient: dict
):
    """Verify generation, persistence, and caching across 5 game sessions."""
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]

    game = db_session.execute(select(Game).where(Game.is_active == True)).scalars().first()
    assert game is not None

    # 1. Create 6 game sessions with results and metrics (to verify it caps at the latest 5)
    session_ids = []
    for i in range(6):
        gs_id = uuid.uuid4()
        session_ids.append(str(gs_id))
        now_iso = datetime.now(timezone.utc).isoformat()

        # Create session
        client.post(
            "/game-sessions",
            json={
                "id": str(gs_id),
                "patient_id": str(patient_id),
                "game_id": str(game.id),
                "started_at": now_iso,
                "duration_ms": 60000 + (i * 10000),
                "status": "completed",
            },
            headers=headers,
        )

        # Upload results
        client.post(
            f"/game-sessions/{gs_id}/results",
            json={
                "score": 100 + (i * 20),
                "accuracy": 0.80 + (i * 0.02),
                "repetitions": 10 + i,
            },
            headers=headers,
        )

        # Upload metrics
        client.post(
            f"/game-sessions/{gs_id}/metrics",
            json={
                "algorithm_version": "v1.0",
                "metrics": {"rom_deg": 60.0 + i, "smoothness": 0.85},
            },
            headers=headers,
        )

    # 2. Request progress summary via primary route
    res = client.get(f"/patients/{patient_id}/progress-summary", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()

    assert data["status"] == "completed"
    assert data["session_count"] == 5  # Evaluates the latest 5 sessions
    assert data["summary"] is not None
    assert len(data["summary"]) > 20
    assert "weekly report" not in data["summary"].lower()
    assert len(data["session_ids"]) == 5
    summary_id = data["id"]

    # 3. Verify record was stored in patient_progress_summaries table
    db_record = db_session.get(PatientProgressSummary, uuid.UUID(summary_id))
    assert db_record is not None
    assert db_record.session_count == 5
    assert db_record.summary == data["summary"]

    # 4. Verify cached return on subsequent call (instant return from DB)
    res_cached = client.get(f"/patients/{patient_id}/progress-summary", headers=headers)
    assert res_cached.status_code == 200
    assert res_cached.json()["id"] == summary_id

    # 5. Verify alias route /ai-progress-overview returns the same cached overview
    res_alias = client.get(f"/patients/{patient_id}/ai-progress-overview", headers=headers)
    assert res_alias.status_code == 200
    assert res_alias.json()["id"] == summary_id

    # 6. Verify on-demand regeneration with ?regenerate=true
    res_regen = client.get(f"/patients/{patient_id}/progress-summary?regenerate=true", headers=headers)
    assert res_regen.status_code == 200
    data_regen = res_regen.json()
    assert data_regen["status"] == "completed"
    assert data_regen["id"] != summary_id  # New record persisted


@pytest.mark.asyncio
async def test_auto_generate_progress_summary_after_session_analysis(
    db_session: Session, mock_patient: dict
):
    """Verify that generating an overview for a specific game session immediately triggers the 5-session progress overview."""
    patient_id = mock_patient["profile"].id
    game = db_session.execute(select(Game).where(Game.is_active == True)).scalars().first()

    # Create a completed session
    gs_id = uuid.uuid4()
    from app.db.models.session import GameSession, GameResult, SessionStatus
    gs = GameSession(
        id=gs_id,
        patient_id=patient_id,
        game_id=game.id,
        started_at=datetime.now(timezone.utc),
        duration_ms=60000,
        status=SessionStatus.completed,
    )
    db_session.add(gs)
    res = GameResult(
        game_session_id=gs_id,
        score=150,
        accuracy=0.88,
        repetitions=15,
        completion_rate=1.0,
    )
    db_session.add(res)
    db_session.commit()

    # Process AI analysis for this specific session
    analysis = await ai_service.process_and_save_ai_analysis(db_session, gs_id, trigger_progress_summary=True)
    assert analysis is not None

    # Verify that patient_progress_summaries table now has a progress overview for this patient!
    summary = ai_service.get_latest_progress_summary(db_session, patient_id)
    assert summary is not None
    assert summary.session_count >= 1
    assert summary.summary is not None
    assert len(summary.summary) > 20

