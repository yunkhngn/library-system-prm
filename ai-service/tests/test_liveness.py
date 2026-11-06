"""
Liveness logic on fabricated per-frame observations (no models, no video).

Convention used below: yaw > 0 means the nose moves towards the right of the image, which is the
user's LEFT in an un-mirrored view (so TURN_LEFT needs yaw to rise).
"""
import numpy as np
import pytest

from app.models.schemas import ChallengeInstruction
from app.services.face_analysis import NO_FACE, FaceObservation
from app.services.liveness_service import evaluate_challenge, evaluate_liveness, find_blink, find_turn

FPS = 30.0
POINTS = np.zeros((5, 2), dtype=np.float32)


def obs(blink=0.05, yaw=0.0, count=1) -> FaceObservation:
    return FaceObservation(count=count, points5=POINTS, face_width_px=200.0, blink=blink, yaw=yaw)


def clip(blink_at=None, turn=None, frames=90, blink_frames=4, blink_peak=0.85):
    """
    A clip of `frames` frames. Optional blink starting at `blink_at`; optional (start, delta) turn
    held to the end of the clip.
    """
    out = []
    for i in range(frames):
        blink = 0.05
        if blink_at is not None and blink_at <= i < blink_at + blink_frames:
            blink = blink_peak
        yaw = 0.0
        if turn is not None and i >= turn[0]:
            yaw = turn[1]
        out.append(obs(blink=blink, yaw=yaw))
    return out


def challenge(second="TURN_LEFT"):
    return [ChallengeInstruction(action="BLINK", order=1), ChallengeInstruction(action=second, order=2)]


# ------------------------------------------------------------------ happy paths
def test_blink_then_turn_left_passes():
    result = evaluate_challenge(clip(blink_at=10, turn=(40, +0.45)), FPS, challenge("TURN_LEFT"))
    assert result.passed is True
    assert result.score >= 0.90
    assert result.reason is None and result.error_code is None


def test_blink_then_turn_right_passes():
    result = evaluate_challenge(clip(blink_at=10, turn=(40, -0.45)), FPS, challenge("TURN_RIGHT"))
    assert result.passed is True


def test_instruction_order_field_is_respected():
    shuffled = [ChallengeInstruction(action="TURN_LEFT", order=2), ChallengeInstruction(action="BLINK", order=1)]
    assert evaluate_challenge(clip(blink_at=10, turn=(40, +0.45)), FPS, shuffled).passed is True


def test_mirrored_input_flips_turn_direction():
    mirrored = clip(blink_at=10, turn=(40, -0.45))
    assert evaluate_challenge(mirrored, FPS, challenge("TURN_LEFT"), mirrored=True).passed is True
    assert evaluate_challenge(mirrored, FPS, challenge("TURN_LEFT"), mirrored=False).passed is False


def test_user_not_centred_at_start_still_passes():
    """The turn is measured against the user's own resting position, not against zero."""
    frames = [obs(blink=f.blink, yaw=f.yaw + 0.25) for f in clip(blink_at=10, turn=(40, +0.45))]
    assert evaluate_challenge(frames, FPS, challenge("TURN_LEFT")).passed is True


# ------------------------------------------------------------------ attacks / failures
def test_static_photo_fails():
    result = evaluate_challenge(clip(), FPS, challenge())
    assert result.passed is False
    assert "blink" in result.reason.lower()
    assert result.score < 0.90


def test_blink_without_turn_fails():
    result = evaluate_challenge(clip(blink_at=10), FPS, challenge("TURN_LEFT"))
    assert result.passed is False
    assert "turn" in result.reason.lower()
    assert 0 < result.score < 0.90  # one of two steps done


def test_turn_without_blink_fails():
    assert evaluate_challenge(clip(turn=(40, +0.45)), FPS, challenge()).passed is False


def test_wrong_direction_fails_with_explicit_reason():
    result = evaluate_challenge(clip(blink_at=10, turn=(40, -0.45)), FPS, challenge("TURN_LEFT"))
    assert result.passed is False
    assert "wrong way" in result.reason


def test_mostly_wrong_way_with_a_brief_right_way_fails():
    """Swinging the head hard the wrong way, then barely the right way, is not the requested turn."""
    frames = clip(blink_at=10)
    for i in range(40, 60):
        frames[i] = obs(yaw=-0.9)   # big move the wrong way (TURN_LEFT needs yaw to rise)
    for i in range(70, 90):
        frames[i] = obs(yaw=+0.35)  # small move the right way
    result = evaluate_challenge(frames, FPS, challenge("TURN_LEFT"))
    assert result.passed is False
    assert "wrong way" in result.reason


def test_overshoot_then_correct_turn_passes():
    """A small wrong-way wobble before a clear turn the right way is fine."""
    frames = clip(blink_at=10)
    for i in range(35, 40):
        frames[i] = obs(yaw=-0.15)
    for i in range(45, 90):
        frames[i] = obs(yaw=+0.5)
    assert evaluate_challenge(frames, FPS, challenge("TURN_LEFT")).passed is True


def test_turn_before_blink_fails_order():
    result = evaluate_challenge(clip(blink_at=60, turn=(10, +0.45)), FPS, challenge("TURN_LEFT"))
    assert result.passed is False


def test_small_head_movement_is_not_a_turn():
    assert evaluate_challenge(clip(blink_at=10, turn=(40, +0.12)), FPS, challenge("TURN_LEFT")).passed is False


def test_one_frame_head_jerk_is_not_a_turn():
    frames = clip(blink_at=10)
    frames[50] = obs(yaw=0.9)
    assert evaluate_challenge(frames, FPS, challenge("TURN_LEFT")).passed is False


def test_eyes_closed_photo_is_not_a_blink():
    frames = [obs(blink=0.9) for _ in range(90)]
    assert find_blink([f.blink for f in frames], 1 / FPS) is None


def test_eyes_held_closed_too_long_is_not_a_blink():
    series = [0.05] * 10 + [0.9] * 40 + [0.05] * 10
    assert find_blink(series, 1 / FPS) is None


def test_squint_that_never_reaches_closed_is_not_a_blink():
    series = [0.05] * 10 + [0.42] * 5 + [0.05] * 10
    assert find_blink(series, 1 / FPS) is None


def test_short_blink_detected_with_missing_face_frames_in_between():
    series = [0.05] * 5 + [0.8, None, 0.8] + [0.05] * 5
    event = find_blink(series, 1 / FPS)
    assert event is not None
    assert event.strength == pytest.approx(0.8)


def test_slow_camera_blink_of_one_frame_detected():
    series = [0.05, 0.05, 0.9, 0.05, 0.05]
    assert find_blink(series, 1 / 10.0) is not None


def test_find_turn_reports_opposite_peak():
    event, opposite = find_turn([0.0] * 10 + [-0.5] * 10, 1 / FPS, baseline=0.0, direction=+1)
    assert event is None
    assert opposite == pytest.approx(0.5)


# ------------------------------------------------------------------ input problems
def test_no_face_is_an_input_error():
    result = evaluate_challenge([NO_FACE] * 60, FPS, challenge())
    assert result.passed is False
    assert result.error_code == "FACE_NOT_FOUND"


def test_two_faces_is_an_input_error():
    frames = [obs(count=2) for _ in range(60)]
    assert evaluate_challenge(frames, FPS, challenge()).error_code == "MULTIPLE_FACES"


def test_face_lost_for_much_of_the_clip_fails():
    frames = clip(blink_at=10, turn=(40, +0.45))
    frames = [f if i % 3 else NO_FACE for i, f in enumerate(frames)]
    frames = [f if i % 2 else NO_FACE for i, f in enumerate(frames)]
    result = evaluate_challenge(frames, FPS, challenge())
    assert result.passed is False


def test_empty_clip_fails():
    assert evaluate_challenge([], FPS, challenge()).passed is False


def test_score_threshold_is_enforced():
    frames = clip(blink_at=10, turn=(40, +0.45))
    assert evaluate_challenge(frames, FPS, challenge(), min_score=0.90).passed is True
    assert evaluate_challenge(frames, FPS, challenge(), min_score=0.999).passed is False


def test_unknown_frame_rate_falls_back_to_default():
    assert evaluate_challenge(clip(blink_at=10, turn=(40, +0.45)), float("nan"), challenge()).passed is True


# ------------------------------------------------------------------ evaluate_liveness wrapper
def test_mock_mode_is_synthetic_pass():
    result = evaluate_liveness(b"some_dummy_clip_bytes", challenge(), min_score=0.90, mock_mode=True)
    assert result.passed is True and result.score >= 0.90


def test_truncated_clip_rejected_in_real_mode():
    class Fake:
        def analyze(self, rgb):
            return NO_FACE

        def close(self):
            pass

    result = evaluate_liveness(b"short", challenge(), min_score=0.90, mock_mode=False, analyzer=Fake())
    assert result.passed is False and result.reason
