import os
from typing import Optional
from fastapi import APIRouter, Depends, Response, status
from app.core.security import verify_service_key
from app.core.settings import settings
from app.models.schemas import AiHealth, AiReadiness

router = APIRouter(prefix="/api/v1", tags=["Health"])


@router.get("/health", response_model=AiHealth, summary="aiHealth")
def health_check():
    """Process liveness probe, public without credentials."""
    return AiHealth(status="ok", service="ai-service")


@router.get(
    "/ready",
    response_model=AiReadiness,
    dependencies=[Depends(verify_service_key)],
    summary="aiReady",
)
def readiness_check(response: Response):
    """
    Readiness probe verifying operational status and model readiness.
    Protected by X-Service-Key.
    """
    mock_mode = os.getenv("AI_MOCK_MODE", "true").lower() in ("true", "1", "yes")

    if mock_mode:
        return AiReadiness(
            status="READY",
            mode="MOCK",
            modelId=settings.face_model_id,
            modelVersion=settings.face_model_version,
            livenessModelVersion=settings.liveness_model_version,
            simulated=True,
            reason=None,
        )

    # In REAL mode, check if models are ready
    models_ready = os.getenv("AI_MODELS_READY", "false").lower() in ("true", "1", "yes")
    if not models_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return AiReadiness(
            status="NOT_READY",
            mode="REAL",
            modelId=None,
            modelVersion=None,
            livenessModelVersion=None,
            simulated=False,
            reason="MODEL_NOT_READY",
        )

    return AiReadiness(
        status="READY",
        mode="REAL",
        modelId=settings.face_model_id,
        modelVersion=settings.face_model_version,
        livenessModelVersion=settings.liveness_model_version,
        simulated=False,
        reason=None,
    )
