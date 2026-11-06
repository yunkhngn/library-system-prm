import json
import uuid
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from fastapi.concurrency import run_in_threadpool
from app.core.security import verify_service_key, AiApiException
from app.core.model_registry import model_registry
from app.core.settings import mock_mode as is_mock_mode, settings
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

    # 5. Operational status
    mock_mode = is_mock_mode()

    if not model_registry.is_ready():
        raise AiApiException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code="MODEL_NOT_READY",
            message="Recognition models are not ready for inference",
            fallback_recommended=True,
        )

    if not mock_mode and modelVersion != settings.face_model_version:
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="MODEL_VERSION_MISMATCH",
            message=f"Model version '{modelVersion}' does not match loaded model '{settings.face_model_version}'",
        )

    from app.repositories.candidates import load_active_candidates

    # 6. Real inference (CPU heavy: keep it off the event loop)
    if not mock_mode:
        from app.services.recognition_service import recognize_clip

        candidates = await run_in_threadpool(load_active_candidates)
        return await run_in_threadpool(
            recognize_clip,
            clip_bytes,
            parsed_instructions,
            candidates,
            max_cosine_distance=maxCosineDistance,
            min_distance_gap=minDistanceGap,
            liveness_min_score=livenessMinScore,
            model_version=modelVersion,
        )

    # 7. Mock path (AI_MOCK_MODE=true): synthetic and always flagged `simulated`.
    from app.services.embedding_service import compute_deterministic_vector
    from app.services.liveness_service import evaluate_liveness
    from app.services.matching_service import match_face_embedding

    liveness_res = evaluate_liveness(clip_bytes, parsed_instructions, min_score=livenessMinScore, mock_mode=True)
    candidates = load_active_candidates()
    probe = compute_deterministic_vector(clip_bytes[:16384]).tolist() if candidates else []
    return match_face_embedding(
        probe_embedding=probe,
        candidates=candidates,
        max_cosine_distance=maxCosineDistance,
        min_distance_gap=minDistanceGap,
        liveness_passed=liveness_res.passed,
        liveness_score=liveness_res.score,
        model_version=modelVersion,
        simulated=True,
    )
