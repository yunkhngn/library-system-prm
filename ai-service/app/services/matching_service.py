from typing import List, Optional, Tuple
import numpy as np
from app.core.model_registry import model_registry
from app.models.schemas import InternalRecognitionResult
from app.repositories.candidates import Candidate


def match_face_embedding(
    probe_embedding: List[float],
    candidates: List[Candidate],
    max_cosine_distance: float = 0.35,
    min_distance_gap: float = 0.15,
    liveness_passed: bool = True,
    liveness_score: float = 0.95,
    model_version: Optional[str] = None,
    simulated: bool = False,
) -> InternalRecognitionResult:
    """
    Exact cosine distance grouped by distinct student person, rejecting ties.
    Returns InternalRecognitionResult.
    """
    m_id = model_registry.reported_model_id
    m_ver = model_version or model_registry.model_version
    liv_ver = model_registry.liveness_model_version

    if not liveness_passed:
        return InternalRecognitionResult(
            matched=False,
            userId=None,
            biometricVersion=None,
            consentId=None,
            cosineDistance=None,
            distanceGap=None,
            livenessPassed=False,
            livenessScore=liveness_score,
            modelId=m_id,
            modelVersion=m_ver,
            livenessModelVersion=liv_ver,
            simulated=simulated,
            outcome="LIVENESS_FAILED",
        )

    if not candidates:
        return InternalRecognitionResult(
            matched=False,
            userId=None,
            biometricVersion=None,
            consentId=None,
            cosineDistance=None,
            distanceGap=None,
            livenessPassed=True,
            livenessScore=liveness_score,
            modelId=m_id,
            modelVersion=m_ver,
            livenessModelVersion=liv_ver,
            simulated=simulated,
            outcome="NO_MATCH",
        )

    probe = np.array(probe_embedding, dtype=np.float32)
    norm = np.linalg.norm(probe)
    if norm > 0:
        probe /= norm

    # Group candidates by user_id and find minimum cosine distance per user
    user_best: dict[str, Tuple[float, Candidate]] = {}

    for cand in candidates:
        cand_vec = np.array(cand.embedding, dtype=np.float32)
        c_norm = np.linalg.norm(cand_vec)
        if c_norm > 0:
            cand_vec /= c_norm

        sim = float(np.dot(probe, cand_vec))
        dist = max(0.0, 1.0 - sim)

        if cand.user_id not in user_best or dist < user_best[cand.user_id][0]:
            user_best[cand.user_id] = (dist, cand)

    # Sort users by minimum distance ascending
    sorted_users = sorted(user_best.items(), key=lambda x: x[1][0])
    best_user_id, (best_dist, best_cand) = sorted_users[0]

    if len(sorted_users) > 1:
        second_dist = sorted_users[1][1][0]
        distance_gap = second_dist - best_dist
    else:
        distance_gap = 1.0  # Clear margin when only one unique user exists

    # Decision rule: distance <= max_distance AND gap >= min_gap
    is_match = (best_dist <= max_cosine_distance) and (distance_gap >= min_distance_gap)

    if is_match:
        return InternalRecognitionResult(
            matched=True,
            userId=best_user_id,
            biometricVersion=best_cand.biometric_version,
            consentId=best_cand.consent_id,
            cosineDistance=best_dist,
            distanceGap=distance_gap,
            livenessPassed=True,
            livenessScore=liveness_score,
            modelId=m_id,
            modelVersion=m_ver,
            livenessModelVersion=liv_ver,
            simulated=simulated,
            outcome="MATCHED",
        )

    return InternalRecognitionResult(
        matched=False,
        userId=None,
        biometricVersion=None,
        consentId=None,
        cosineDistance=best_dist,
        distanceGap=distance_gap,
        livenessPassed=True,
        livenessScore=liveness_score,
        modelId=m_id,
        modelVersion=m_ver,
        livenessModelVersion=liv_ver,
        simulated=simulated,
        outcome="NO_MATCH",
    )
