"""Shared test doubles. Imported as `support` (pytest puts the tests directory on sys.path)."""
import numpy as np

from app.services.face_analysis import FaceObservation

# Plausible ArcFace-ordered landmarks for a ~200px face inside a 400x400 image.
FACE_POINTS = np.array([[160, 170], [240, 170], [200, 215], [165, 255], [235, 255]], dtype=np.float32)


def good_observation(**overrides) -> FaceObservation:
    fields = dict(count=1, points5=FACE_POINTS, face_width_px=200.0, blink=0.05, yaw=0.0)
    fields.update(overrides)
    return FaceObservation(**fields)


class FakeAnalyzer:
    """Returns a scripted observation per call (the last one repeats)."""

    def __init__(self, *observations: FaceObservation):
        self._observations = list(observations) or [good_observation()]
        self.calls = 0

    def analyze(self, rgb):
        observation = self._observations[min(self.calls, len(self._observations) - 1)]
        self.calls += 1
        return observation

    def close(self):
        pass


class FakeSession:
    """Stands in for an onnxruntime session. `vectors` are returned in call order."""

    class _Input:
        name = "data"

    def __init__(self, vectors):
        self._vectors = [np.asarray(v, dtype=np.float32) for v in vectors]
        self._next = 0

    def get_inputs(self):
        return [self._Input()]

    def run(self, _outputs, feeds):
        tensor = next(iter(feeds.values()))
        # Mirrors the real ArcFace R100 ONNX graph: input (1, 3, 112, 112), batch fixed at 1.
        assert tensor.shape == (1, 3, 112, 112), f"unexpected input shape {tensor.shape}"
        row = self._vectors[min(self._next, len(self._vectors) - 1)]
        self._next += 1
        return [row[None]]


def unit(seed: int) -> np.ndarray:
    v = np.random.RandomState(seed).randn(512).astype(np.float32)
    return v / np.linalg.norm(v)


def near(base: np.ndarray, seed: int, amount: float = 0.1) -> np.ndarray:
    noise = unit(seed)
    v = base + amount * noise
    return v / np.linalg.norm(v)
