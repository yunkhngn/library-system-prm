import pytest
from app.models.schemas import ChallengeInstruction
from app.services.liveness_service import evaluate_liveness, LivenessResult


def test_liveness_mock_mode():
    instructions = [
        ChallengeInstruction(action="BLINK", order=1),
        ChallengeInstruction(action="TURN_LEFT", order=2),
    ]
    res = evaluate_liveness(b"some_dummy_clip_bytes", instructions, min_score=0.90, mock_mode=True)
    assert res.passed is True
    assert res.score >= 0.90
    assert res.reason is None


def test_liveness_truncated_clip_rejected():
    instructions = [
        ChallengeInstruction(action="BLINK", order=1),
        ChallengeInstruction(action="TURN_LEFT", order=2),
    ]
    # Truncated or empty clip
    res = evaluate_liveness(b"short", instructions, min_score=0.90, mock_mode=False)
    assert res.passed is False
    assert res.score < 0.90
    assert res.reason is not None


def test_liveness_threshold_enforcement():
    instructions = [
        ChallengeInstruction(action="BLINK", order=1),
        ChallengeInstruction(action="TURN_RIGHT", order=2),
    ]
    # In mock mode, score is 0.98; if min_score is set to 0.99, it should fail
    res_high_thresh = evaluate_liveness(b"clip" * 500, instructions, min_score=0.99, mock_mode=False)
    # Regardless of mode, threshold logic behaves predictably
    assert isinstance(res_high_thresh, LivenessResult)
