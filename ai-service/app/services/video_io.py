"""
Video clip helpers shared by upload validation and liveness analysis.

Clips arrive as MP4 (mobile cameras) or WebM (browser MediaRecorder). The latter commonly has no
duration or frame count and a meaningless frame rate in its header, so timing is derived from the
frame timestamps the decoder reports rather than from container metadata.
"""
import os
import tempfile
from contextlib import contextmanager
from typing import Iterator, List, Optional, Sequence

DEFAULT_FPS = 30.0
_MIN_PLAUSIBLE_FPS, _MAX_PLAUSIBLE_FPS = 1.0, 120.0


def detect_container(content: bytes) -> Optional[str]:
    """'mp4', 'webm', or None, from the leading bytes (never from a filename or MIME type)."""
    if len(content) >= 8 and content[4:8] == b"ftyp":
        return "mp4"
    if len(content) >= 4 and content[:4] == b"\x1a\x45\xdf\xa3":
        return "webm"
    return None


@contextmanager
def temp_clip(content: bytes, container: Optional[str] = None) -> Iterator[str]:
    """Write the clip to a temporary file (decoders need a path) and always delete it."""
    suffix = f".{container or detect_container(content) or 'mp4'}"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(content)
        path = tmp.name
    try:
        yield path
    finally:
        if os.path.exists(path):
            os.remove(path)


def sane_fps(reported: Optional[float]) -> float:
    if reported and _MIN_PLAUSIBLE_FPS <= reported <= _MAX_PLAUSIBLE_FPS:
        return float(reported)
    return DEFAULT_FPS


def effective_fps(timestamps_ms: Sequence[float], reported: Optional[float] = None) -> float:
    """Frame rate from decoder timestamps; falls back to the reported rate, then to 30."""
    if len(timestamps_ms) >= 2:
        span_ms = timestamps_ms[-1] - timestamps_ms[0]
        monotonic = all(b >= a for a, b in zip(timestamps_ms, timestamps_ms[1:]))
        if span_ms > 0 and monotonic:
            fps = (len(timestamps_ms) - 1) * 1000.0 / span_ms
            if _MIN_PLAUSIBLE_FPS <= fps <= _MAX_PLAUSIBLE_FPS:
                return fps
    return sane_fps(reported)


def clip_duration_seconds(timestamps_ms: List[float], frame_count: int, reported_fps: Optional[float]) -> float:
    """Duration of a decoded clip: frames / effective frame rate."""
    if frame_count <= 0:
        return 0.0
    return frame_count / effective_fps(timestamps_ms, reported_fps)
