import os
from fastapi import APIRouter, Response, status

router = APIRouter(prefix="/api/v1", tags=["Health"])

@router.get("/health")
def health_check():
    """Process liveness probe."""
    return {"status": "ok", "service": "ai-service"}

@router.get("/ready")
def readiness_check(response: Response):
    """Readiness probe verifying operational status and model readiness."""
    mock_mode = os.getenv("AI_MOCK_MODE", "true").lower() in ("true", "1", "yes")
    
    if mock_mode:
        return {
            "ready": True,
            "service": "ai-service",
            "mode": "mock",
            "modelsLoaded": True,
            "version": "0.1.0"
        }
    
    # In real mode, models readiness will be checked from model registry in Task 10
    models_ready = os.getenv("AI_MODELS_READY", "false").lower() in ("true", "1", "yes")
    if not models_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {
            "ready": False,
            "service": "ai-service",
            "mode": "real",
            "modelsLoaded": False,
            "error": "MODEL_NOT_READY"
        }

    return {
        "ready": True,
        "service": "ai-service",
        "mode": "real",
        "modelsLoaded": True,
        "version": "0.1.0"
    }
