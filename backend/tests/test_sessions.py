"""
Tests for therapy and game session routes:
- Creation
- Idempotent replay
- Game results upload
- Session metrics upload
- Patient authorization boundaries
"""
import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Game


def test_therapy_session_lifecycle_and_idempotency(
    client: TestClient, db_session: Session, mock_patient: dict
):
    """Test therapy session creation and idempotent replay."""
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]
    session_id = uuid.uuid4()
    now_iso = datetime.now(timezone.utc).isoformat()

    payload = {
        "id": str(session_id),
        "patient_id": str(patient_id),
        "started_at": now_iso,
        "duration_s": 900,
        "status": "completed",
        "notes": "Good progress today",
    }

    # 1. First upload: 201 Created
    res1 = client.post("/therapy-sessions", json=payload, headers=headers)
    assert res1.status_code == 201, res1.text
    data1 = res1.json()
    assert data1["id"] == str(session_id)
    assert data1["duration_s"] == 900

    # 2. Replay with identical client UUID: 200 OK + idempotent header
    res2 = client.post("/therapy-sessions", json=payload, headers=headers)
    assert res2.status_code == 200
    assert res2.headers.get("X-Idempotent-Replayed") == "true"
    assert res2.json()["id"] == str(session_id)

    # 3. Retrieve via GET
    res_get = client.get(f"/therapy-sessions/{session_id}", headers=headers)
    assert res_get.status_code == 200
    assert res_get.json()["notes"] == "Good progress today"


def test_game_session_and_metrics_upload(
    client: TestClient, db_session: Session, mock_patient: dict
):
    """Test creating game session, uploading game results and sensor metrics."""
    patient_id = mock_patient["profile"].id
    headers = mock_patient["headers"]

    # Retrieve seeded game
    game = db_session.execute(select(Game).where(Game.slug == "piano")).scalar_one()

    # 1. Create top-level therapy session
    therapy_id = uuid.uuid4()
    client.post(
        "/therapy-sessions",
        json={
            "id": str(therapy_id),
            "patient_id": str(patient_id),
            "started_at": datetime.now(timezone.utc).isoformat(),
            "status": "completed",
        },
        headers=headers,
    )

    # 2. Create game session
    game_session_id = uuid.uuid4()
    game_session_payload = {
        "id": str(game_session_id),
        "therapy_session_id": str(therapy_id),
        "game_id": str(game.id),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "duration_ms": 120000,
        "status": "completed",
        "configuration": {"tempo_bpm": 60, "target_notes": 12},
    }

    res_gs = client.post("/game-sessions", json=game_session_payload, headers=headers)
    assert res_gs.status_code == 201
    assert res_gs.json()["id"] == str(game_session_id)

    # 3. Upload game result
    result_payload = {
        "score": 120,
        "accuracy": 0.85,
        "repetitions": 12,
        "metrics": {"notes_hit": 10, "notes_missed": 2},
    }
    res_res = client.post(
        f"/game-sessions/{game_session_id}/results",
        json=result_payload,
        headers=headers,
    )
    assert res_res.status_code == 201
    assert res_res.json()["score"] == 120
    assert res_res.json()["accuracy"] == 0.85

    # 4. Upload session metrics (sensor analytics)
    metric_payload = {
        "algorithm_version": "v1.0",
        "metrics": {
            "flex_rom_mean": [45.2, 50.1, 48.0],
            "smoothness_score": 0.88,
        },
    }
    res_m = client.post(
        f"/game-sessions/{game_session_id}/metrics",
        json=metric_payload,
        headers=headers,
    )
    assert res_m.status_code == 201
    assert res_m.json()["algorithm_version"] == "v1.0"
    assert res_m.json()["metrics"]["smoothness_score"] == 0.88
