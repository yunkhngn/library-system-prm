"""
Challenge-response liveness.

The backend issues a random ordered challenge (BLINK, then TURN_LEFT or TURN_RIGHT). A clip passes
only if, in that order, the single face in frame

  1. blinks   : eyes go open -> closed -> open within `liveness_blink_max_seconds`, and
  2. turns    : the nose moves at least `liveness_turn_delta` (≈ sin of the yaw) from the user's
                resting position in the requested direction, for a few consecutive frames.

A printed photo or a still image cannot blink or turn; a random challenge means a replayed clip
must also happen to contain the same actions in the same order.

Known limit (documented on purpose): this is not a passive anti-spoofing model. A targeted
real-time replay/deepfake that performs the requested actions is not detected.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple

import cv2
import numpy as np

from app.core.settings import settings
from app.models.schemas import ChallengeInstruction
from app.services.face_analysis import FaceAnalyzer, FaceObservation
from app.services.embedding_service import align_face, resize_rgb
from app.services.video_io import effective_fps, sane_fps, temp_clip

MIN_FPS, MAX_FPS, DEFAULT_FPS = 5.0, 60.0, 30.0
_MAX_FACELESS_RATIO = 0.70          # more than this without any face -> FACE_NOT_FOUND
_MAX_MULTI_FACE_RATIO = 0.20        # more than this with 2+ faces -> MULTIPLE_FACES


@dataclass
class LivenessResult:
    passed: bool
    score: float
    reason: Optional[str] = None
    # Set for input errors the API reports as 422 (FACE_NOT_FOUND / MULTIPLE_FACES) instead of a
    # determined "liveness failed" answer.
    error_code: Optional[str] = None


# ------------------------------------------------------------------------------------------
# Event detection on per-frame series
# ------------------------------------------------------------------------------------------
@dataclass(frozen=True)
class Event:
    start: int
    end: int
    strength: float  # blink: peak score; turn: peak signed delta


def find_blink(blink: Sequence[Optional[float]], dt: float, start: int = 0) -> Optional[Event]:
    """First open -> closed -> open transition at or after `start`. Frames without a face are skipped."""
    closed, opened = settings.liveness_blink_closed, settings.liveness_blink_open
    armed = False
    run_start: Optional[int] = None
    peak = 0.0
    for i in range(start, len(blink)):
        value = blink[i]
        if value is None:
            continue
        if run_start is None:
            if value <= opened:
                armed = True
            elif value >= closed and armed:
                run_start, peak = i, value
        else:
            peak = max(peak, value)
            if value <= opened:
                if (i - run_start) * dt <= settings.liveness_blink_max_seconds:
                    return Event(run_start, i, peak)
                run_start, armed = None, True  # eyes were closed too long: not a blink
            elif (i - run_start) * dt > settings.liveness_blink_max_seconds:
                run_start, armed = None, False  # still closed/squinting: wait for eyes to reopen
    return None


def find_turn(
    yaw: Sequence[Optional[float]], dt: float, baseline: float, direction: int, start: int = 0
) -> Tuple[Optional[Event], float]:
    """
    First sustained turn of at least `liveness_turn_delta` in `direction` (+1: nose towards the right
    of the image, -1: towards the left). Also returns the largest delta seen in the *opposite* direction.
    """
    needed = max(2, math.ceil(settings.liveness_turn_min_seconds / dt))
    run_start: Optional[int] = None
    run_len, peak, opposite_peak = 0, 0.0, 0.0
    found: Optional[Event] = None
    for i in range(start, len(yaw)):
        value = yaw[i]
        if value is None:
            continue
        delta = direction * (value - baseline)
        opposite_peak = max(opposite_peak, -delta)
        if delta >= settings.liveness_turn_delta:
            if run_start is None:
                run_start, run_len, peak = i, 0, 0.0
            run_len += 1
            peak = max(peak, delta)
            if run_len >= needed and found is None:
                found = Event(run_start, i, peak)
        else:
            run_start, run_len = None, 0
    return found, opposite_peak


def _median(values: Sequence[float]) -> float:
    return float(np.median(values)) if values else 0.0


def _margin(value: float, threshold: float, span: float) -> float:
    """0.5 right at the threshold, 1.0 at threshold+span or beyond."""
    return 0.5 + 0.5 * min(1.0, max(0.0, (value - threshold) / span))


# ------------------------------------------------------------------------------------------
# Challenge evaluation
# ------------------------------------------------------------------------------------------
def evaluate_challenge(
    observations: Sequence[FaceObservation],
    fps: float,
    instructions: Sequence[ChallengeInstruction],
    min_score: float = 0.90,
    mirrored: Optional[bool] = None,
) -> LivenessResult:
    total = len(observations)
    if total == 0:
        return LivenessResult(False, 0.0, "No video frames could be analysed", error_code="FACE_NOT_FOUND")

    mirrored = settings.liveness_mirrored_input if mirrored is None else mirrored
    fps = DEFAULT_FPS if not fps or fps != fps else min(MAX_FPS, max(MIN_FPS, fps))
    dt = 1.0 / fps

    with_face = sum(1 for o in observations if o.count >= 1)
    multi = sum(1 for o in observations if o.count > 1)
    single = sum(1 for o in observations if o.single)

    if with_face / total < 1.0 - _MAX_FACELESS_RATIO:
        return LivenessResult(False, 0.0, "No face found in the clip", error_code="FACE_NOT_FOUND")
    if multi / total > _MAX_MULTI_FACE_RATIO:
        return LivenessResult(False, 0.0, "More than one face in the clip", error_code="MULTIPLE_FACES")

    face_ratio = single / total
    if face_ratio < settings.liveness_min_face_ratio:
        return LivenessResult(False, 0.2, "Face was not consistently visible during the challenge")

    blink = [o.blink if o.single else None for o in observations]
    yaw = [o.yaw if o.single else None for o in observations]

    steps = sorted(instructions, key=lambda item: item.order)
    if not steps:
        return LivenessResult(False, 0.0, "Challenge has no instructions")

    cursor = 0
    margins: List[float] = [_margin(face_ratio, settings.liveness_min_face_ratio, 1.0 - settings.liveness_min_face_ratio)]
    passed_steps = 0

    for step in steps:
        if step.action == "BLINK":
            event = find_blink(blink, dt, cursor)
            if event is None:
                return _failed("A blink was not detected", passed_steps, len(steps))
            margins.append(_margin(event.strength, settings.liveness_blink_closed, 0.4))
            cursor = event.end
        elif step.action in ("TURN_LEFT", "TURN_RIGHT"):
            # In an un-mirrored view the user's left is the right of the image.
            direction = 1 if step.action == "TURN_LEFT" else -1
            if mirrored:
                direction = -direction
            before = [v for v in yaw[: cursor + 1] if v is not None]
            baseline = _median(before if len(before) >= 3 else [v for v in yaw if v is not None][:3])
            event, opposite = find_turn(yaw, dt, baseline, direction, cursor)
            if event is None:
                side = "left" if step.action == "TURN_LEFT" else "right"
                if opposite >= settings.liveness_turn_delta:
                    return _failed(f"Head turned the wrong way (expected {side})", passed_steps, len(steps))
                return _failed(f"A head turn to the {side} was not detected", passed_steps, len(steps))
            if opposite > event.strength:
                # The dominant movement was the wrong way; a brief right-way blip does not count.
                return _failed(
                    f"Head turned the wrong way (expected {'left' if step.action == 'TURN_LEFT' else 'right'})",
                    passed_steps,
                    len(steps),
                )
            margins.append(_margin(event.strength, settings.liveness_turn_delta, 0.30))
            cursor = event.end
        else:
            return _failed(f"Unsupported challenge action {step.action}", passed_steps, len(steps))
        passed_steps += 1

    score = round(min(0.99, 0.90 + 0.09 * (sum(margins) / len(margins))), 4)
    if score < min_score:
        return LivenessResult(False, score, "Liveness score below required threshold")
    return LivenessResult(True, score)


def _failed(reason: str, passed_steps: int, total_steps: int) -> LivenessResult:
    return LivenessResult(False, round(max(0.05, 0.5 * passed_steps / max(1, total_steps)), 4), reason)


# ------------------------------------------------------------------------------------------
# Video decoding + per-frame analysis
# ------------------------------------------------------------------------------------------
@dataclass
class ClipAnalysis:
    observations: List[FaceObservation]
    aligned: List[Optional[np.ndarray]]  # 112x112 RGB crops for frames with exactly one face
    fps: float                            # effective frame rate after striding


def analyze_clip(clip_bytes: bytes, analyzer: FaceAnalyzer) -> ClipAnalysis:
    """
    Decode an MP4 or WebM and analyse up to `liveness_max_frames` evenly strided frames, one at a time.

    The frame rate is derived from the decoded timestamps, because browser WebM reports none that
    can be trusted; the blink/turn timing rules depend on it.
    """
    with temp_clip(clip_bytes) as path:
        capture = cv2.VideoCapture(path)
        try:
            if not capture.isOpened():
                return ClipAnalysis([], [], DEFAULT_FPS)
            reported_fps = capture.get(cv2.CAP_PROP_FPS)
            frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
            stride = max(1, math.ceil(frame_count / settings.liveness_max_frames)) if frame_count > 0 else 1

            observations: List[FaceObservation] = []
            aligned: List[Optional[np.ndarray]] = []
            timestamps: List[float] = []
            index = 0
            while len(observations) < settings.liveness_max_frames * 2:
                ok, frame = capture.read()
                if not ok:
                    break
                if index % stride == 0:
                    rgb = resize_rgb(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB), settings.analysis_max_side_px)
                    observation = analyzer.analyze(rgb)
                    observations.append(observation)
                    aligned.append(align_face(rgb, observation.points5) if observation.single else None)
                    timestamps.append(float(capture.get(cv2.CAP_PROP_POS_MSEC) or 0.0))
                index += 1
        finally:
            capture.release()

    fallback = sane_fps(reported_fps) / stride
    return ClipAnalysis(observations, aligned, effective_fps(timestamps, fallback))


def evaluate_liveness(
    clip_bytes: bytes,
    instructions: List[ChallengeInstruction],
    min_score: float = 0.90,
    mock_mode: bool = False,
    analyzer: Optional[FaceAnalyzer] = None,
) -> LivenessResult:
    """Decode + evaluate in one call. In mock mode the result is synthetic."""
    if mock_mode:
        return LivenessResult(passed=True, score=0.98)

    if analyzer is None:
        from app.core.model_registry import model_registry

        analyzer = model_registry.analyzer
    if analyzer is None or len(clip_bytes) < 1000:
        return LivenessResult(passed=False, score=0.10, reason="Invalid, truncated or unanalysable video stream")

    analysis = analyze_clip(clip_bytes, analyzer)
    return evaluate_challenge(analysis.observations, analysis.fps, instructions, min_score)
