"""
Tests for health check and root endpoints.
"""
from fastapi.testclient import TestClient


def test_root_endpoint(client: TestClient):
    """Test root endpoint returns API metadata."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["project"] == "HapticSync API"
    assert data["version"] == "0.1.0"
    assert "health" in data
    assert "docs" in data


def test_health_check(client: TestClient, db_session):
    """Test health check route verifies database connectivity."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["api"] == "ok"
    assert data["database"] == "ok"
