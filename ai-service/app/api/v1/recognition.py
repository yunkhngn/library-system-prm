import json
import os
import uuid
from typing import List
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from app.core.security import verify_service_key, AiApiException
from app.core.settings import settings
from app.models.schemas import ChallengeInstruction, InternalRecognitionResult
from app.services.image_decoder import validate_video_clip

router = APIRouter(prefix="/api/v1", tags=["Recognition"])


@router.post(
    "/recognize",
    response_model=InternalRecognitionResult,
    dependencies=[Depends(verify_service_key)],
    summary="recognizeFace",
)
async def recognize_face(
    clip: UploadFile = File(...),
    challengeId: str = Form(...),
    challengeInstructions: str = Form(...),
    modelVersion: str = Form(...),
    maxCosineDistance: float = Form(...),
    minDistanceGap: float = Form(...),
    livenessMinScore: float = Form(...),
):
    # 1. Validate challengeId
    try:
        uuid.UUID(challengeId)
    except Exception:
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="CHALLENGE_INVALID",
            message=f"Invalid challengeId format: '{challengeId}'",
        )

    # 2. Validate challengeInstructions JSON
    try:
        raw_instructions = json.loads(challengeInstructions)
    except json.JSONDecodeError as e:
        raise AiApiException(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="INVALID_JSON",
            message=f"challengeInstructions is not valid JSON: {str(e)}",
        )

    if not isinstance(raw_instructions, list) or len(raw_instructions) != 2:
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="CHALLENGE_INVALID",
            message="challengeInstructions must contain exactly 2 ordered challenge actions",
        )

    try:
        parsed_instructions = [ChallengeInstruction(**item) for item in raw_instructions]
    except Exception as e:
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="CHALLENGE_INVALID",
            message=f"Invalid challenge instructions format: {str(e)}",
        )

    # 3. Validate threshold ranges
    if not (0.0 <= maxCosineDistance <= 2.0):
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="VALIDATION_ERROR",
            message="maxCosineDistance must be between 0.0 and 2.0",
        )
    if not (0.0 <= minDistanceGap <= 2.0):
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="VALIDATION_ERROR",
            message="minDistanceGap must be between 0.0 and 2.0",
        )
    if not (0.0 <= livenessMinScore <= 1.0):
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="VALIDATION_ERROR",
            message="livenessMinScore must be between 0.0 and 1.0",
        )

    # 4. Validate video clip stream
    clip_bytes = await clip.read()
    validate_video_clip(clip_bytes, filename=clip.filename or "clip.mp4")

    # 5. Check mock / real operational status
    mock_mode = os.getenv("AI_MOCK_MODE", "true").lower() in ("true", "1", "yes")
    models_ready = os.getenv("AI_MODELS_READY", "false").lower() in ("true", "1", "yes")

    if not mock_mode and not models_ready:
        raise AiApiException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code="MODEL_NOT_READY",
            message="Recognition models are not ready for inference",
        )

    if not mock_mode and modelVersion != settings.face_model_version:
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="MODEL_VERSION_MISMATCH",
            message=f"Model version '{modelVersion}' does not match loaded model '{settings.face_model_version}'",
        )

    # In mock mode, return simulated non-matching / matching result
    return InternalRecognitionResult(
        matched=False,
        userId=None,
        biometricVersion=None,
        consentId=None,
        cosineDistance=None,
        distanceGap=None,
        livenessPassed=True,
        livenessScore=0.98,
        modelId=settings.face_model_id,
        modelVersion=modelVersion,
        livenessModelVersion=settings.liveness_model_version,
        simulated=mock_mode,
        outcome="NO_MATCH",
    )
