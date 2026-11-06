"""Real (non-mock) clip recognition: liveness -> best frames -> ArcFace -> 1:N match."""
from typing import List, Sequence

import numpy as np

from app.core.model_registry import model_registry
from app.core.security import AiApiException
from app.core.settings import settings
from app.models.schemas import ChallengeInstruction, InternalRecognitionResult
from app.repositories.candidates import Candidate
from app.services.embedding_service import embed_aligned, sharpness
from app.services.liveness_service import ClipAnalysis, LivenessResult, analyze_clip, evaluate_challenge
from app.services.matching_service import match_face_embedding

_PROBE_FRAMES = 3


def _frontal_indices(analysis: ClipAnalysis) -> List[int]:
    return [
        i
        for i, observation in enumerate(analysis.observations)
        if analysis.aligned[i] is not None
        and observation.yaw is not None
        and abs(observation.yaw) <= settings.liveness_frontal_max_yaw
        and (observation.blink is None or observation.blink <= settings.liveness_blink_open)
        and (observation.face_width_px or 0.0) >= settings.min_face_px
    ]


def probe_embedding(analysis: ClipAnalysis, frontal: Sequence[int]):
    """
    Returns (probe_vector, identity_drift).

    The probe is the mean of the sharpest frontal frames. `identity_drift` is the cosine distance
    between the first and last frontal frame: a large value means a different face appeared
    mid-clip (e.g. one person blinks, another is recognised).
    """
    ranked = sorted(frontal, key=lambda i: sharpness(analysis.aligned[i]), reverse=True)
    best = ranked[:_PROBE_FRAMES]
    chosen = list(dict.fromkeys([frontal[0], frontal[-1], *best]))

    vectors = dict(zip(chosen, embed_aligned([analysis.aligned[i] for i in chosen])))
    drift = 1.0 - float(np.dot(vectors[frontal[0]], vectors[frontal[-1]]))

    mean = np.mean([vectors[i] for i in best], axis=0)
    return (mean / np.linalg.norm(mean)).astype(np.float32), drift


def _liveness_failed(result: LivenessResult, model_version: str) -> InternalRecognitionResult:
    return match_face_embedding(
        probe_embedding=[],
        candidates=[],
        liveness_passed=False,
        liveness_score=result.score,
        model_version=model_version,
        simulated=False,
    )


def recognize_clip(
    clip_bytes: bytes,
    instructions: List[ChallengeInstruction],
    candidates: List[Candidate],
    *,
    max_cosine_distance: float,
    min_distance_gap: float,
    liveness_min_score: float,
    model_version: str,
) -> InternalRecognitionResult:
    analyzer = model_registry.analyzer
    if analyzer is None or model_registry.embedder is None:
        raise AiApiException(status_code=503, code="MODEL_NOT_READY", message="Face models are not loaded")

    analysis = analyze_clip(clip_bytes, analyzer)
    liveness = evaluate_challenge(analysis.observations, analysis.fps, instructions, liveness_min_score)

    if liveness.error_code:
        raise AiApiException(status_code=422, code=liveness.error_code, message=liveness.reason or "Invalid clip")
    if not liveness.passed:
        return _liveness_failed(liveness, model_version)

    frontal = _frontal_indices(analysis)
    if not frontal:
        raise AiApiException(
            status_code=422, code="LOW_QUALITY", message="No clear, front-facing frame was found in the clip"
        )

    probe, drift = probe_embedding(analysis, frontal)
    if drift > settings.liveness_max_identity_drift:
        return _liveness_failed(LivenessResult(False, 0.30, "Face identity changed during the clip"), model_version)

    return match_face_embedding(
        probe_embedding=probe.tolist(),
        candidates=candidates,
        max_cosine_distance=max_cosine_distance,
        min_distance_gap=min_distance_gap,
        liveness_passed=True,
        liveness_score=liveness.score,
        model_version=model_version,
        simulated=False,
    )
