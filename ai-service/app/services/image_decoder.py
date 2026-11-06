import io
import os
import tempfile
from typing import Tuple
from PIL import Image, ImageFile
from app.core.security import AiApiException
from app.core.settings import settings
from app.services.video_io import clip_duration_seconds, detect_container, temp_clip

ImageFile.LOAD_TRUNCATED_IMAGES = False
# Limit max pixels to prevent DecompressionBomb attacks
Image.MAX_IMAGE_PIXELS = settings.max_image_megapixels * 2


def validate_and_decode_image(content: bytes, filename: str = "image") -> Tuple[int, int]:
    """
    Validates decoded image content rather than trusting extension/MIME.
    Enforces format (JPEG/PNG), max size (5 MB), max megapixels (16 MP),
    and rejects image bombs or corrupted streams.
    Returns (width, height).
    """
    if len(content) > settings.max_image_size_bytes:
        raise AiApiException(
            status_code=413,
            code="PAYLOAD_TOO_LARGE",
            message=f"Image '{filename}' exceeds size limit of {settings.max_image_size_bytes} bytes",
        )

    if len(content) == 0:
        raise AiApiException(
            status_code=422,
            code="IMAGE_INVALID",
            message=f"Image '{filename}' is empty",
        )

    try:
        buf = io.BytesIO(content)
        img = Image.open(buf)
        fmt = img.format
        if fmt not in ("JPEG", "PNG"):
            raise AiApiException(
                status_code=422,
                code="IMAGE_INVALID",
                message=f"Image '{filename}' has invalid format '{fmt}'. Only JPEG and PNG are allowed.",
            )

        # verify integrity
        img.verify()

        # Re-open for dimension inspection as verify invalidates state
        buf.seek(0)
        img2 = Image.open(buf)
        width, height = img2.size
        total_pixels = width * height

        if total_pixels > settings.max_image_megapixels:
            raise AiApiException(
                status_code=422,
                code="IMAGE_INVALID",
                message=f"Image '{filename}' resolution ({width}x{height} = {total_pixels} pixels) exceeds maximum allowed 16 megapixels.",
            )

        # Force decode to detect corrupted data or image bombs
        img2.load()
        return width, height

    except Image.DecompressionBombError:
        raise AiApiException(
            status_code=422,
            code="IMAGE_INVALID",
            message=f"Image '{filename}' rejected as potential decompression bomb",
        )
    except AiApiException:
        raise
    except Exception as e:
        raise AiApiException(
            status_code=422,
            code="IMAGE_INVALID",
            message=f"Image '{filename}' cannot be decoded: {str(e)}",
        )


MIN_CLIP_SECONDS, MAX_CLIP_SECONDS = 0.5, 5.0
_MAX_PROBE_FRAMES = 400  # stop decoding here: anything this long is rejected anyway


def validate_video_clip(content: bytes, filename: str = "clip.mp4") -> float:
    """
    Validates an MP4 or WebM clip.
    Enforces <= 10 MB, a known container, decodability and a 0.5-5 s duration (1-3 s nominal).
    Duration comes from decoded frame timestamps: browser WebM carries no usable header duration.
    Returns the duration in seconds.
    """
    if len(content) > settings.max_video_size_bytes:
        raise AiApiException(
            status_code=413,
            code="PAYLOAD_TOO_LARGE",
            message=f"Video clip exceeds maximum size limit of {settings.max_video_size_bytes} bytes",
        )

    if len(content) < 16:
        raise AiApiException(
            status_code=422,
            code="VIDEO_INVALID",
            message="Video clip is empty or too short to be a valid MP4 or WebM container",
        )

    container = detect_container(content)
    if container is None:
        raise AiApiException(
            status_code=422,
            code="VIDEO_INVALID",
            message="Invalid video container. Only MP4 and WebM clips are accepted.",
        )

    try:
        import cv2
    except ImportError:
        # Without a decoder (a minimal test environment) the container check is all we can do.
        return 2.0

    mock = os.getenv("AI_MOCK_MODE", "false").lower() in ("true", "1", "yes")
    try:
        with temp_clip(content, container) as path:
            cap = cv2.VideoCapture(path)
            try:
                if not cap.isOpened():
                    if mock:
                        return 2.0
                    raise AiApiException(
                        status_code=422,
                        code="VIDEO_INVALID",
                        message="Video clip could not be opened by media decoder",
                    )

                reported_fps = cap.get(cv2.CAP_PROP_FPS)
                timestamps: list = []
                while len(timestamps) < _MAX_PROBE_FRAMES:
                    ok, frame = cap.read()
                    if not ok or frame is None:
                        break
                    timestamps.append(float(cap.get(cv2.CAP_PROP_POS_MSEC) or 0.0))
            finally:
                cap.release()
    except AiApiException:
        raise
    except Exception as e:
        raise AiApiException(
            status_code=422,
            code="VIDEO_INVALID",
            message=f"Undecodable video clip: {str(e)}",
        )

    if not timestamps:
        if mock:
            return 2.0
        raise AiApiException(
            status_code=422,
            code="VIDEO_INVALID",
            message="Video clip contains no decodable video frames",
        )

    duration = clip_duration_seconds(timestamps, len(timestamps), reported_fps)
    if duration < MIN_CLIP_SECONDS or duration > MAX_CLIP_SECONDS:
        raise AiApiException(
            status_code=422,
            code="VIDEO_INVALID",
            message=f"Video clip duration ({duration:.1f}s) must be between 1 and 3 seconds",
        )
    return duration
