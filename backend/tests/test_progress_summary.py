"""
Tests for multi-session AI progress summary route:
- GET /patients/{patient_id}/progress-summary
Validates:
1. Returns 'insufficient_data' when fewer than 3 sessions exist.
2. Generates and persists progress summary when >= 3 sessions exist.
3. Returns cached progress summary on subsequent requests.
4. Regenerates on-demand when ?regenerate=true is provided.
"""
import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Game
from app.db.models.ai import PatientProgressSummary


def test_progress_summary_insufficient_sessions(
    client: TestClient, db_session: Session, mock_patient: dict
):
    """Verify that fewer than 3 sessions returns status='insufficient_data'."""
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]

    res = client.get(f"/patients/{patient_id}/progress-summary", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["status"] == "insufficient_data"
    assert data["min_sessions_required"] == 3
    assert data["session_count"] == 0
    assert data["summary"] is None
    assert "At least 3 completed game sessions are required" in data["message"]


def test_progress_summary_with_three_or_more_sessions(
    client: TestClient, db_session: Session, mock_patient: dict
):
    """Verify generation, persistence, and caching across 3+ game sessions."""
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]

    game = db_session.execute(select(Game).where(Game.is_active == True)).scalars().first()
    assert game is not None

    # 1. Create 3 game sessions with results and metrics
    session_ids = []
    for i in range(3):
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
                "accuracy": 0.80 + (i * 0.05),
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

    # 2. Request progress summary
    res = client.get(f"/patients/{patient_id}/progress-summary", headers=headers)
    assert res.status_code == 200, res.text
    data = res.json()

    assert data["status"] == "completed"
    assert data["session_count"] == 3
    assert data["summary"] is not None
    assert len(data["summary"]) > 20
    assert "weekly report" not in data["summary"].lower()
    assert len(data["session_ids"]) == 3
    summary_id = data["id"]

    # 3. Verify record was stored in patient_progress_summaries table
    db_record = db_session.get(PatientProgressSummary, uuid.UUID(summary_id))
    assert db_record is not None
    assert db_record.session_count == 3
    assert db_record.summary == data["summary"]

    # 4. Verify cached return on subsequent call
    res_cached = client.get(f"/patients/{patient_id}/progress-summary", headers=headers)
    assert res_cached.status_code == 200
    assert res_cached.json()["id"] == summary_id

    # 5. Verify on-demand regeneration with ?regenerate=true
    res_regen = client.get(f"/patients/{patient_id}/progress-summary?regenerate=true", headers=headers)
    assert res_regen.status_code == 200
    data_regen = res_regen.json()
    assert data_regen["status"] == "completed"
    assert data_regen["id"] != summary_id  # New record persisted
