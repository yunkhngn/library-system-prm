"""recognize_clip orchestration with a scripted clip analysis and fake models (no video, no model files)."""
import numpy as np
import pytest

from app.core.security import AiApiException
from app.models.schemas import ChallengeInstruction
from app.repositories.candidates import Candidate
from app.services import recognition_service
from app.services.face_analysis import NO_FACE
from app.services.liveness_service import ClipAnalysis
from support import FakeAnalyzer, FakeSession, good_observation, near, unit

INSTRUCTIONS = [ChallengeInstruction(action="BLINK", order=1), ChallengeInstruction(action="TURN_LEFT", order=2)]
BASE = unit(11)


def crop(seed: int) -> np.ndarray:
    return np.random.RandomState(seed).randint(0, 255, (112, 112, 3), dtype=np.uint8)


def scripted_clip(blink=True, turn=True, frontal=True, frames=90) -> ClipAnalysis:
    """Frames 0-9 frontal & open, blink at 10-13, turn left from 40 on (unless disabled)."""
    observations, aligned = [], []
    for i in range(frames):
        blink_score = 0.9 if (blink and 10 <= i < 14) else 0.05
        yaw = 0.5 if (turn and i >= 40) else 0.0
        if not frontal:
            yaw += 0.9  # always looking well away from the camera
        observations.append(good_observation(blink=blink_score, yaw=yaw))
        aligned.append(crop(i))
    return ClipAnalysis(observations, aligned, fps=30.0)


def candidates(vector=BASE) -> list:
    return [Candidate("user-1", "consent-1", 3, vector.tolist(), "arcface-512-r100", "arcface-512-v1")]


def run(analysis, vectors, cands=None, min_score=0.90, monkeypatch=None, install=None):
    monkeypatch.setattr(recognition_service, "analyze_clip", lambda *_: analysis)
    install(FakeAnalyzer(), FakeSession(vectors))
    return recognition_service.recognize_clip(
        b"clip",
        INSTRUCTIONS,
        candidates() if cands is None else cands,
        max_cosine_distance=0.5,
        min_distance_gap=0.15,
        liveness_min_score=min_score,
        model_version="arcface-512-v1",
    )


def same_person(n=10):
    return [near(BASE, 100 + i, 0.05) for i in range(n)]


def test_matches_enrolled_user_after_real_liveness(monkeypatch, install_models):
    result = run(scripted_clip(), same_person(), monkeypatch=monkeypatch, install=install_models)
    assert result.outcome == "MATCHED" and result.matched is True
    assert result.userId == "user-1" and result.biometricVersion == 3
    assert result.livenessPassed is True and result.livenessScore >= 0.90
    assert result.simulated is False
    assert result.cosineDistance < 0.2


def test_unknown_face_is_no_match(monkeypatch, install_models):
    result = run(scripted_clip(), same_person(), cands=candidates(unit(999)), monkeypatch=monkeypatch, install=install_models)
    assert result.outcome == "NO_MATCH" and result.matched is False and result.userId is None
    assert result.livenessPassed is True


def test_failed_liveness_never_matches_even_for_the_right_face(monkeypatch, install_models):
    result = run(scripted_clip(blink=False), same_person(), monkeypatch=monkeypatch, install=install_models)
    assert result.outcome == "LIVENESS_FAILED" and result.matched is False and result.userId is None
    assert result.livenessPassed is False and result.simulated is False


def test_no_turn_fails_liveness(monkeypatch, install_models):
    result = run(scripted_clip(turn=False), same_person(), monkeypatch=monkeypatch, install=install_models)
    assert result.outcome == "LIVENESS_FAILED"


def test_no_frontal_frame_is_low_quality(monkeypatch, install_models):
    # A face that never looks at the camera still has to be rejected, but as an input problem.
    analysis = scripted_clip(frontal=False)
    # make the (shifted) baseline turn pass so we reach the frontal check
    with pytest.raises(AiApiException) as info:
        run(analysis, same_person(), monkeypatch=monkeypatch, install=install_models)
    assert info.value.status_code == 422 and info.value.code == "LOW_QUALITY"


def test_different_face_mid_clip_fails_liveness(monkeypatch, install_models):
    # Embedding order is: first frontal frame, last frontal frame, then the sharpest frames.
    vectors = [unit(1), unit(2)] + same_person()
    result = run(scripted_clip(), vectors, monkeypatch=monkeypatch, install=install_models)
    assert result.outcome == "LIVENESS_FAILED" and result.matched is False


def test_no_face_in_clip_is_422(monkeypatch, install_models):
    analysis = ClipAnalysis([NO_FACE] * 60, [None] * 60, fps=30.0)
    with pytest.raises(AiApiException) as info:
        run(analysis, same_person(), monkeypatch=monkeypatch, install=install_models)
    assert info.value.status_code == 422 and info.value.code == "FACE_NOT_FOUND"


def test_two_people_in_clip_is_422(monkeypatch, install_models):
    analysis = ClipAnalysis([good_observation(count=2)] * 60, [None] * 60, fps=30.0)
    with pytest.raises(AiApiException) as info:
        run(analysis, same_person(), monkeypatch=monkeypatch, install=install_models)
    assert info.value.code == "MULTIPLE_FACES"


def test_models_not_loaded_is_503():
    with pytest.raises(AiApiException) as info:
        recognition_service.recognize_clip(
            b"clip", INSTRUCTIONS, [], max_cosine_distance=0.5, min_distance_gap=0.15,
            liveness_min_score=0.9, model_version="arcface-512-v1",
        )
    assert info.value.status_code == 503 and info.value.code == "MODEL_NOT_READY"
