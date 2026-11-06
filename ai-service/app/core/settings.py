import os
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_TRUTHY = ("true", "1", "yes")


def mock_mode() -> bool:
    """
    True only when synthetic (hash based) embeddings/liveness are explicitly requested.

    Read from the environment on every call so tests can toggle it. Defaults to False:
    the service performs real inference unless AI_MOCK_MODE=true is set.
    """
    return os.getenv("AI_MOCK_MODE", "false").lower() in _TRUTHY


class Settings(BaseSettings):
    port: int = 8001
    host: str = "0.0.0.0"
    service_api_key: str = "dev-internal-service-key-change-in-prod"
    ai_mock_mode: bool = False

    face_model_id: str = "arcface-512-r100"
    face_model_version: str = "arcface-512-v1"
    liveness_model_version: str = "challenge-landmark-v1"

    # --- Model files (see scripts/fetch_models.py) ---------------------------------
    model_dir: Path = Path(__file__).resolve().parent.parent / "models"
    embedding_model_file: str = "arcfaceresnet100-8.onnx"
    landmarker_model_file: str = "face_landmarker.task"

    max_image_size_bytes: int = 5 * 1024 * 1024        # 5 MB per image
    max_total_image_bytes: int = 25 * 1024 * 1024     # 25 MB total
    max_image_megapixels: int = 16 * 1000 * 1000      # 16 MP max
    max_video_size_bytes: int = 10 * 1024 * 1024      # 10 MB per video clip

    min_images_count: int = 3
    max_images_count: int = 5

    # --- Image quality (enrollment) ---------------------------------------------------
    analysis_max_side_px: int = 960        # frames/images are downscaled to this before analysis
    min_face_px: int = 80                  # smallest acceptable face width in the analysed image
    enroll_max_yaw: float = 0.55           # |nose offset ratio| allowed for enrollment photos (~33 degrees)
    min_sharpness: float = 25.0            # variance of Laplacian on the 112x112 aligned face
    # Same person across expressive/blurred frames measured 0.27-0.53; different people 0.89-1.12.
    enroll_max_pairwise_distance: float = 0.65

    # --- Liveness / challenge ---------------------------------------------------------
    liveness_max_frames: int = 90          # frames analysed per clip (strided if longer)
    liveness_min_face_ratio: float = 0.70  # share of frames that must contain exactly one face
    liveness_blink_closed: float = 0.50    # blendshape score treated as "eyes closed"
    liveness_blink_open: float = 0.30      # blendshape score treated as "eyes open"
    liveness_blink_max_seconds: float = 0.80
    liveness_turn_delta: float = 0.30      # nose offset change (≈ sin of yaw) that counts as a turn
    liveness_turn_min_seconds: float = 0.10
    liveness_frontal_max_yaw: float = 0.20  # frames used for the identity probe
    liveness_max_identity_drift: float = 0.50  # cosine distance between start/end of the clip
    # TURN_LEFT/TURN_RIGHT are the *user's* left/right. In an un-mirrored video the user's
    # left is the right side of the image. Set true if the client records a mirrored clip.
    liveness_mirrored_input: bool = False

    timezone: str = "Asia/Ho_Chi_Minh"

    model_config = SettingsConfigDict(
        env_prefix="AI_",
        env_file=".env",
        extra="ignore",
        protected_namespaces=("settings_",),
    )


settings = Settings()
