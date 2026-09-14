"""
Tests for AI rehabilitation overview and parameter suggestions.
Validates:
- On-demand AI overview generation
- Retrieval of cached AI overview via patient endpoint
- Asynchronous AI analysis execution after session metrics upload
- Proper schema validation for overview, parameter suggestions, and key metrics
"""
import uuid
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Game
from app.db.models.ai import AIAnalysis, AIAnalysisStatus


def test_ai_overview_generation_and_retrieval(
    client: TestClient, db_session: Session, mock_patient: dict
):
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]
    game_session_id = uuid.uuid4()
    now_iso = datetime.now(timezone.utc).isoformat()

    # Get an active game
    game = db_session.execute(select(Game).where(Game.is_active == True)).scalars().first()
    assert game is not None

    # 1. Create game session directly linked to patient
    res_gs = client.post(
        "/game-sessions",
        json={
            "id": str(game_session_id),
            "patient_id": str(patient_id),
            "game_id": str(game.id),
            "started_at": now_iso,
            "duration_ms": 300000,
            "status": "completed",
            "configuration": {"difficulty": "easy", "tempo_bpm": 60},
        },
        headers=headers,
    )
    assert res_gs.status_code == 201

    # 3. Upload results
    res_results = client.post(
        f"/game-sessions/{game_session_id}/results",
        json={
            "score": 450,
            "accuracy": 0.88,
            "completion_rate": 1.0,
            "repetitions": 15,
            "metrics": {"notes_hit": 22, "notes_missed": 3},
        },
        headers=headers,
    )
    assert res_results.status_code == 201

    # 4. Upload metrics (triggers background AI analysis)
    res_metrics = client.post(
        f"/game-sessions/{game_session_id}/metrics",
        json={
            "algorithm_version": "v1.0",
            "metrics": {
                "rom_deg": 65.5,
                "smoothness_score": 0.82,
                "peak_velocity_deg_s": 120.0,
            },
        },
        headers=headers,
    )
    assert res_metrics.status_code == 201

    # 5. Retrieve AI overview via GET /patients/{patient_id}/ai-overview
    res_overview = client.get(
        f"/patients/{patient_id}/ai-overview?regenerate=true",
        headers=headers,
    )
    assert res_overview.status_code == 200, res_overview.text
    data = res_overview.json()

    assert data["patient_id"] == str(patient_id)
    assert data["status"] == "completed"
    assert data["overview"] is not None
    assert "parameter_suggestions" in data
    assert data["parameter_suggestions"] is not None
    assert "difficulty" in data["parameter_suggestions"]
    assert "key_metrics_summary" in data

    # 6. Verify retrieved from DB without ?regenerate=true
    res_cached = client.get(
        f"/patients/{patient_id}/ai-overview",
        headers=headers,
    )
    assert res_cached.status_code == 200
    assert res_cached.json()["id"] == data["id"]
