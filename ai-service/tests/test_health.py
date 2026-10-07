import os
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.settings import settings

VALID_KEY = settings.service_api_key


@pytest.mark.asyncio
async def test_health_check_public():
    """Health check is public, does not require X-Service-Key."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "ai-service"


@pytest.mark.asyncio
async def test_readiness_requires_service_key():
    """Readiness endpoint requires valid X-Service-Key header."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Missing key
        res_missing = await ac.get("/api/v1/ready")
        assert res_missing.status_code == 401
        assert res_missing.json()["code"] == "INVALID_SERVICE_KEY"

        # Invalid key
        res_invalid = await ac.get("/api/v1/ready", headers={"X-Service-Key": "wrong-secret-key"})
        assert res_invalid.status_code == 401
        assert res_invalid.json()["code"] == "INVALID_SERVICE_KEY"


@pytest.mark.asyncio
async def test_readiness_mock_mode(monkeypatch):
    """In mock mode, readiness returns 200 with simulated=True."""
    monkeypatch.setenv("AI_MOCK_MODE", "true")
    headers = {"X-Service-Key": VALID_KEY}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/ready", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "READY"
    assert data["mode"] == "MOCK"
    assert data["simulated"] is True
    assert data["reason"] is None


@pytest.mark.asyncio
async def test_readiness_real_mode_not_ready(monkeypatch):
    """In real mode with unready models, readiness returns 503 with NOT_READY."""
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    monkeypatch.setenv("AI_MODELS_READY", "false")
    headers = {"X-Service-Key": VALID_KEY}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/ready", headers=headers)
    assert response.status_code == 503
    data = response.json()
    assert data["status"] == "NOT_READY"
    assert data["mode"] == "REAL"
    assert data["simulated"] is False
    assert data["reason"] == "MODEL_NOT_READY"


@pytest.mark.asyncio
async def test_readiness_real_mode_ready(monkeypatch):
    """In real mode with models loaded, readiness returns 200 with READY."""
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    monkeypatch.setenv("AI_MODELS_READY", "true")
    headers = {"X-Service-Key": VALID_KEY}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/ready", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "READY"
    assert data["mode"] == "REAL"
    assert data["simulated"] is False
    assert data["reason"] is None
