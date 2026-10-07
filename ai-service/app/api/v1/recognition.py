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

    # 6. Evaluate anti-spoofing and liveness
    from app.services.liveness_service import evaluate_liveness, extract_frames_from_clip
    from app.services.matching_service import match_face_embedding
    from app.services.embedding_service import compute_deterministic_vector
    from app.repositories.candidates import load_active_candidates

    liveness_res = evaluate_liveness(
        clip_bytes,
        parsed_instructions,
        min_score=livenessMinScore,
        mock_mode=mock_mode,
    )

    if not liveness_res.passed:
        return match_face_embedding(
            probe_embedding=[],
            candidates=[],
            max_cosine_distance=maxCosineDistance,
            min_distance_gap=minDistanceGap,
            liveness_passed=False,
            liveness_score=liveness_res.score,
            model_version=modelVersion,
            simulated=mock_mode,
        )

    # 7. Load enrolled student candidates from DB view
    candidates = load_active_candidates()
    if not candidates:
        return match_face_embedding(
            probe_embedding=[],
            candidates=[],
            max_cosine_distance=maxCosineDistance,
            min_distance_gap=minDistanceGap,
            liveness_passed=True,
            liveness_score=liveness_res.score,
            model_version=modelVersion,
            simulated=mock_mode,
        )

    # 8. Extract face embedding from video probe
    frames = extract_frames_from_clip(clip_bytes)
    probe_img_bytes = None
    if frames:
        mid_idx = len(frames) // 2
        try:
            import cv2
            success, enc = cv2.imencode(".jpg", frames[mid_idx])
            if success:
                probe_img_bytes = enc.tobytes()
        except Exception:
            pass

    if probe_img_bytes is None:
        probe_img_bytes = clip_bytes[:16384]

    probe_vector = compute_deterministic_vector(probe_img_bytes).tolist()

    return match_face_embedding(
        probe_embedding=probe_vector,
        candidates=candidates,
        max_cosine_distance=maxCosineDistance,
        min_distance_gap=minDistanceGap,
        liveness_passed=True,
        liveness_score=liveness_res.score,
        model_version=modelVersion,
        simulated=mock_mode,
    )
