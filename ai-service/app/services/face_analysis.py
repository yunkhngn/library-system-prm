"""
Per-image face analysis: detection, 5-point landmarks, blink score and head-turn proxy.

Backed by the MediaPipe Face Landmarker (Apache-2.0). Everything else in the service depends
only on the small `FaceObservation` value object, so alignment, liveness and matching can be
unit tested with fabricated observations and no model files.
"""
from __future__ import annotations

import threading
from dataclasses import dataclass
from typing import Optional, Protocol

import numpy as np

# MediaPipe face-mesh landmark indices.
_IRIS_IMAGE_LEFT = 468
_IRIS_IMAGE_RIGHT = 473
_NOSE_TIP = 1
_MOUTH_IMAGE_LEFT = 61
_MOUTH_IMAGE_RIGHT = 291
_CHEEK_IMAGE_LEFT = 234
_CHEEK_IMAGE_RIGHT = 454


@dataclass(frozen=True)
class FaceObservation:
    """What we know about one frame. `count` is the number of faces found."""

    count: int
    # (5, 2) float32 pixel coordinates in the analysed image, ArcFace order:
    # image-left eye, image-right eye, nose tip, image-left mouth corner, image-right mouth corner.
    points5: Optional[np.ndarray] = None
    face_width_px: Optional[float] = None
    # 0 (eyes open) .. 1 (eyes closed); mean of the two eye-blink blendshapes.
    blink: Optional[float] = None
    # Nose offset from the face centre divided by half the face width. ~sin(yaw).
    # Positive = nose towards the right side of the image (the user's left in an un-mirrored view).
    yaw: Optional[float] = None

    @property
    def single(self) -> bool:
        return self.count == 1 and self.points5 is not None


NO_FACE = FaceObservation(count=0)


class FaceAnalyzer(Protocol):
    def analyze(self, rgb: np.ndarray) -> FaceObservation: ...

    def close(self) -> None: ...


def observation_from_landmarks(landmarks, blendshapes, width: int, height: int, count: int) -> FaceObservation:
    """Pure conversion from MediaPipe landmark/blendshape objects (duck-typed) to an observation."""

    def px(i: int) -> np.ndarray:
        return np.array([landmarks[i].x * width, landmarks[i].y * height], dtype=np.float32)

    points5 = np.stack(
        [px(_IRIS_IMAGE_LEFT), px(_IRIS_IMAGE_RIGHT), px(_NOSE_TIP), px(_MOUTH_IMAGE_LEFT), px(_MOUTH_IMAGE_RIGHT)]
    )

    xs = np.array([lm.x for lm in landmarks[:468]], dtype=np.float32) * width
    face_width = float(xs.max() - xs.min())

    cheek_l = landmarks[_CHEEK_IMAGE_LEFT].x
    cheek_r = landmarks[_CHEEK_IMAGE_RIGHT].x
    half = abs(cheek_r - cheek_l) / 2.0
    yaw: Optional[float] = None
    if half > 1e-4:
        centre = (cheek_l + cheek_r) / 2.0
        yaw = float(np.clip((landmarks[_NOSE_TIP].x - centre) / half, -2.0, 2.0))

    blink: Optional[float] = None
    if blendshapes:
        scores = {b.category_name: float(b.score) for b in blendshapes}
        if "eyeBlinkLeft" in scores and "eyeBlinkRight" in scores:
            blink = (scores["eyeBlinkLeft"] + scores["eyeBlinkRight"]) / 2.0

    return FaceObservation(count=count, points5=points5, face_width_px=face_width, blink=blink, yaw=yaw)


class MediaPipeFaceAnalyzer:
    """Thread-safe wrapper (the underlying task object is not) around the Face Landmarker."""

    def __init__(self, model_path: str):
        import mediapipe as mp
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        self._mp = mp
        self._landmarker = vision.FaceLandmarker.create_from_options(
            vision.FaceLandmarkerOptions(
                base_options=mp_python.BaseOptions(model_asset_path=model_path),
                running_mode=vision.RunningMode.IMAGE,
                num_faces=2,  # 2 is enough to reject "more than one person in frame"
                output_face_blendshapes=True,
            )
        )
        self._lock = threading.Lock()

    def analyze(self, rgb: np.ndarray) -> FaceObservation:
        height, width = rgb.shape[:2]
        image = self._mp.Image(image_format=self._mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
        with self._lock:
            result = self._landmarker.detect(image)
        count = len(result.face_landmarks)
        if count == 0:
            return NO_FACE
        blendshapes = result.face_blendshapes[0] if result.face_blendshapes else None
        return observation_from_landmarks(result.face_landmarks[0], blendshapes, width, height, count)

    def close(self) -> None:
        with self._lock:
            self._landmarker.close()
