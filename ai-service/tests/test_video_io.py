"""
MP4 and WebM clips, including browser-style WebM whose container metadata is missing or wrong.

MediaRecorder (Chrome) writes WebM with no duration/frame count and a bogus frame rate, so duration
and fps must come from the frame timestamps, not from CAP_PROP_FRAME_COUNT / CAP_PROP_FPS.
"""
import cv2
import numpy as np
import pytest

from app.core.security import AiApiException
from app.services import image_decoder, liveness_service
from app.services.image_decoder import validate_video_clip
from app.services.video_io import detect_container, effective_fps
from support import FakeAnalyzer, good_observation

MP4_HEAD = b"\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2mp41"
WEBM_HEAD = b"\x1a\x45\xdf\xa3\x9fB\x86\x81\x01B\xf7\x81\x01"


def write_clip(path, fourcc, fps=30, seconds=2.0, size=(160, 120)):
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*fourcc), fps, size)
    if not writer.isOpened():
        pytest.skip(f"this OpenCV build cannot encode {fourcc}")
    for i in range(int(fps * seconds)):
        writer.write(np.full((size[1], size[0], 3), (i * 5) % 255, np.uint8))
    writer.release()
    return path.read_bytes()


class FakeCapture:
    """A cv2.VideoCapture whose container metadata is wrong, like a browser recording."""

    frames = 90
    spacing_ms = 1000.0 / 30.0
    reported_fps = 1000.0          # WebM time base leaking out as the "frame rate"
    reported_count = -1.0          # unknown

    def __init__(self, *_):
        self._i = 0

    def isOpened(self):
        return True

    def read(self):
        if self._i >= self.frames:
            return False, None
        self._i += 1
        return True, np.zeros((120, 160, 3), np.uint8)

    def get(self, prop):
        if prop == cv2.CAP_PROP_FPS:
            return self.reported_fps
        if prop == cv2.CAP_PROP_FRAME_COUNT:
            return self.reported_count
        if prop == cv2.CAP_PROP_POS_MSEC:
            return (self._i - 1) * self.spacing_ms
        return 0.0

    def release(self):
        pass


@pytest.fixture
def browser_style_capture(monkeypatch):
    monkeypatch.setattr(cv2, "VideoCapture", FakeCapture)
    return FakeCapture


# ------------------------------------------------------------------ container detection
def test_detects_mp4_and_webm_and_nothing_else():
    assert detect_container(MP4_HEAD) == "mp4"
    assert detect_container(WEBM_HEAD) == "webm"
    assert detect_container(b"RIFF\x00\x00\x00\x00AVI LIST") is None
    assert detect_container(b"\x1a\x45\xdf") is None
    assert detect_container(b"") is None


# ------------------------------------------------------------------ fps from timestamps
def test_effective_fps_uses_timestamps_not_the_reported_rate():
    stamps = [i * 1000.0 / 30.0 for i in range(60)]
    assert effective_fps(stamps, reported=1000.0) == pytest.approx(30.0, rel=0.01)


def test_effective_fps_falls_back_when_timestamps_are_unusable():
    assert effective_fps([0.0, 0.0, 0.0], reported=25.0) == 25.0
    assert effective_fps([], reported=0.0) == 30.0       # nonsense -> default
    assert effective_fps([5.0, 4.0, 3.0], reported=1000.0) == 30.0


# ------------------------------------------------------------------ real files
@pytest.mark.parametrize("fourcc,ext,head", [("mp4v", "mp4", MP4_HEAD), ("VP80", "webm", WEBM_HEAD)])
def test_real_clip_in_either_container_is_accepted(tmp_path, fourcc, ext, head):
    clip = write_clip(tmp_path / f"clip.{ext}", fourcc)
    assert detect_container(clip) == ext
    assert validate_video_clip(clip) == pytest.approx(2.0, abs=0.25)


def test_real_webm_is_analysed_frame_by_frame(tmp_path):
    clip = write_clip(tmp_path / "clip.webm", "VP80", fps=30, seconds=2.0)
    analysis = liveness_service.analyze_clip(clip, FakeAnalyzer(good_observation()))
    assert len(analysis.observations) == 60
    assert analysis.fps == pytest.approx(30.0, rel=0.05)


# ------------------------------------------------------------------ browser-style metadata
def test_clip_with_bogus_fps_and_unknown_frame_count_is_accepted(browser_style_capture):
    # Frame count / reported fps would say 0.09 s and be rejected as too short.
    assert validate_video_clip(WEBM_HEAD + b"\x00" * 64) == pytest.approx(3.0, abs=0.2)


def test_analysis_uses_timestamp_frame_rate_for_such_a_clip(browser_style_capture):
    analysis = liveness_service.analyze_clip(WEBM_HEAD + b"\x00" * 64, FakeAnalyzer(good_observation()))
    assert len(analysis.observations) == 90
    assert analysis.fps == pytest.approx(30.0, rel=0.02)


def test_too_long_clip_is_rejected(monkeypatch):
    class Long(FakeCapture):
        frames = 210  # 7 s at 30 fps

    monkeypatch.setattr(cv2, "VideoCapture", Long)
    with pytest.raises(AiApiException) as info:
        validate_video_clip(WEBM_HEAD + b"\x00" * 64)
    assert info.value.code == "VIDEO_INVALID" and info.value.status_code == 422


def test_too_short_clip_is_rejected(monkeypatch):
    class Short(FakeCapture):
        frames = 5  # 0.17 s

    monkeypatch.setattr(cv2, "VideoCapture", Short)
    with pytest.raises(AiApiException) as info:
        validate_video_clip(WEBM_HEAD + b"\x00" * 64)
    assert info.value.code == "VIDEO_INVALID"


def test_unknown_container_is_rejected():
    with pytest.raises(AiApiException) as info:
        validate_video_clip(b"RIFF\x00\x00\x00\x00AVI LIST" + b"\x00" * 64)
    assert info.value.code == "VIDEO_INVALID" and "MP4" in info.value.message and "WebM" in info.value.message
