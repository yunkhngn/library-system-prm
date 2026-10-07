import os
import httpx
import pytest

BACKEND_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8080")
AI_BASE_URL = os.environ.get("AI_SERVICE_URL", "http://localhost:8001")


def test_backend_actuator_health():
    with httpx.Client(base_url=BACKEND_BASE_URL, timeout=10) as client:
        response = client.get("/actuator/health")
        assert response.status_code == 200
        data = response.json()
        assert data.get("status") == "UP"


def test_backend_openapi_docs():
    with httpx.Client(base_url=BACKEND_BASE_URL, timeout=10) as client:
        response = client.get("/v3/api-docs")
        assert response.status_code == 200
        data = response.json()
        assert "openapi" in data
        assert "components" in data
        assert "securitySchemes" in data["components"]
        assert "bearerAuth" in data["components"]["securitySchemes"]
        assert data["components"]["securitySchemes"]["bearerAuth"]["scheme"] == "bearer"


def test_backend_swagger_ui_html():
    with httpx.Client(base_url=BACKEND_BASE_URL, timeout=10) as client:
        response = client.get("/swagger-ui/index.html")
        assert response.status_code == 200
        assert "html" in response.headers.get("content-type", "").lower() or "<!DOCTYPE html>" in response.text


def test_backend_business_api_requires_auth():
    with httpx.Client(base_url=BACKEND_BASE_URL, timeout=10) as client:
        response = client.get("/api/v1/users")
        assert response.status_code == 401


def test_ai_service_health():
    with httpx.Client(base_url=AI_BASE_URL, timeout=10) as client:
        response = client.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json().get("status") == "ok"


def test_ai_service_readiness():
    with httpx.Client(base_url=AI_BASE_URL, timeout=10) as client:
        response = client.get("/api/v1/ready")
        assert response.status_code == 200
        assert response.json().get("ready") is True
