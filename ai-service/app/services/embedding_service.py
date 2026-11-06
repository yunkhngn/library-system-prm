"""
Face embeddings.

Real path: decode -> detect exactly one face -> quality gate -> 5-point alignment to the ArcFace
template -> ArcFace R100 (ONNX) -> L2-normalised 512-d vector.

Mock path (AI_MOCK_MODE=true only): hash based synthetic vectors. They carry no face information
and exist so the API can be exercised without model files. The backend refuses results flagged
`simulated`, so they can never record an entry or exit.
"""
import hashlib
from typing import List, Optional

import cv2
import numpy as np

from app.core.model_registry import model_registry
from app.core.security import AiApiException
from app.core.settings import mock_mode, settings
from app.services.face_analysis import FaceAnalyzer, FaceObservation

# Reference landmark positions of the ArcFace 112x112 template.
ARCFACE_TEMPLATE = np.array(
    [[38.2946, 51.6963], [73.5318, 51.5014], [56.0252, 71.7366], [41.5493, 92.3655], [70.7299, 92.2041]],
    dtype=np.float32,
)
ALIGNED_SIZE = 112


# ------------------------------------------------------------------------------------------
# Image helpers
# ------------------------------------------------------------------------------------------
def decode_to_rgb(image_bytes: bytes, max_side: Optional[int] = None) -> np.ndarray:
    """Decode (honouring EXIF orientation) and downscale to `max_side`. Returns an RGB array."""
    bgr = cv2.imdecode(np.frombuffer(image_bytes, dtype=np.uint8), cv2.IMREAD_COLOR)
    if bgr is None:
        raise AiApiException(status_code=422, code="IMAGE_INVALID", message="Image could not be decoded")
    return resize_rgb(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), max_side or settings.analysis_max_side_px)


def resize_rgb(rgb: np.ndarray, max_side: int) -> np.ndarray:
    height, width = rgb.shape[:2]
    scale = max_side / float(max(height, width))
    if scale >= 1.0:
        return rgb
    return cv2.resize(rgb, (max(1, round(width * scale)), max(1, round(height * scale))), interpolation=cv2.INTER_AREA)


def align_face(rgb: np.ndarray, points5: np.ndarray) -> np.ndarray:
    """Similarity-transform the face to the 112x112 ArcFace template."""
    matrix, _ = cv2.estimateAffinePartial2D(points5.astype(np.float32), ARCFACE_TEMPLATE, method=cv2.LMEDS)
    if matrix is None:
        raise AiApiException(status_code=422, code="LOW_QUALITY", message="Face landmarks are degenerate")
    return cv2.warpAffine(rgb, matrix, (ALIGNED_SIZE, ALIGNED_SIZE), borderValue=0)


def sharpness(aligned_rgb: np.ndarray) -> float:
    """Variance of the Laplacian of the aligned face: low = blurry."""
    gray = cv2.cvtColor(aligned_rgb, cv2.COLOR_RGB2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def embed_aligned(aligned_faces: List[np.ndarray]) -> np.ndarray:
    """Run ArcFace on aligned RGB faces. Returns an (n, 512) array of unit vectors."""
    session = model_registry.embedder
    if session is None:
        raise AiApiException(status_code=503, code="MODEL_NOT_READY", message="Face embedding model is not loaded")
    # The ONNX Model Zoo graph normalises internally: it expects raw 0-255 RGB, NCHW. Its batch
    # dimension is fixed at 1, so faces are embedded one at a time.
    input_name = session.get_inputs()[0].name
    output = np.concatenate(
        [
            session.run(None, {input_name: np.transpose(face.astype(np.float32), (2, 0, 1))[None]})[0]
            for face in aligned_faces
        ]
    )
    norms = np.linalg.norm(output, axis=1, keepdims=True)
    if not np.all(np.isfinite(output)) or np.any(norms == 0):
        raise AiApiException(status_code=500, code="INTERNAL_ERROR", message="Embedding model returned an invalid vector")
    return (output / norms).astype(np.float32)


# ------------------------------------------------------------------------------------------
# Enrollment
# ------------------------------------------------------------------------------------------
def require_single_face(observation: FaceObservation, label: str) -> None:
    if observation.count == 0:
        raise AiApiException(status_code=422, code="FACE_NOT_FOUND", message=f"{label}: no face detected")
    if observation.count > 1:
        raise AiApiException(status_code=422, code="MULTIPLE_FACES", message=f"{label}: more than one face detected")


def _check_enrollment_quality(observation: FaceObservation, aligned: np.ndarray, label: str) -> None:
    if (observation.face_width_px or 0.0) < settings.min_face_px:
        raise AiApiException(
            status_code=422, code="LOW_QUALITY", message=f"{label}: face is too small, move closer to the camera"
        )
    if observation.yaw is not None and abs(observation.yaw) > settings.enroll_max_yaw:
        raise AiApiException(status_code=422, code="LOW_QUALITY", message=f"{label}: face must look at the camera")
    if sharpness(aligned) < settings.min_sharpness:
        raise AiApiException(status_code=422, code="LOW_QUALITY", message=f"{label}: image is too blurry")


def _enroll_real(images: List[bytes], analyzer: FaceAnalyzer) -> List[List[float]]:
    aligned_faces: List[np.ndarray] = []
    for index, content in enumerate(images, start=1):
        label = f"Image {index}"
        rgb = decode_to_rgb(content)
        observation = analyzer.analyze(rgb)
        require_single_face(observation, label)
        aligned = align_face(rgb, observation.points5)
        _check_enrollment_quality(observation, aligned, label)
        aligned_faces.append(aligned)

    vectors = embed_aligned(aligned_faces)

    # All photos must show the same person.
    for i in range(len(vectors)):
        for j in range(i + 1, len(vectors)):
            distance = 1.0 - float(np.dot(vectors[i], vectors[j]))
            if distance > settings.enroll_max_pairwise_distance:
                raise AiApiException(
                    status_code=422,
                    code="INCONSISTENT_FACES",
                    message=f"Images {i + 1} and {j + 1} appear to show different people",
                )
    return [vector.tolist() for vector in vectors]


# ------------------------------------------------------------------------------------------
# Mock (synthetic, AI_MOCK_MODE=true only)
# ------------------------------------------------------------------------------------------
def compute_deterministic_vector(image_bytes: bytes, seed_salt: str = "salt") -> np.ndarray:
    """Synthetic unit vector derived from a hash. Contains NO facial information."""
    hasher = hashlib.sha256(image_bytes + seed_salt.encode("utf-8")).digest()
    rng = np.random.RandomState(int.from_bytes(hasher[:4], "little"))
    vec = rng.randn(512).astype(np.float32)
    norm = np.linalg.norm(vec)
    if norm > 0:
        vec /= norm
    return vec


def _enroll_mock(images: List[bytes]) -> List[List[float]]:
    base_seed = hashlib.sha256(images[0]).digest()
    rng = np.random.RandomState(int.from_bytes(base_seed[:4], "little"))
    base_vec = rng.randn(512).astype(np.float32)
    base_vec /= np.linalg.norm(base_vec)

    embeddings: List[np.ndarray] = [base_vec]
    for _ in images[1:]:
        noise_dir = rng.randn(512).astype(np.float32)
        noise_dir /= np.linalg.norm(noise_dir)
        v = 0.98 * base_vec + 0.02 * noise_dir
        embeddings.append(v / np.linalg.norm(v))
    return [v.tolist() for v in embeddings]


# ------------------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------------------
def extract_face_embeddings(images: List[bytes], simulated: Optional[bool] = None) -> List[List[float]]:
    """3-5 enrollment photos -> one L2-normalised 512-d embedding per photo."""
    if len(images) < settings.min_images_count or len(images) > settings.max_images_count:
        raise AiApiException(
            status_code=422,
            code="IMAGE_INVALID",
            message=f"Enrollment requires {settings.min_images_count}-{settings.max_images_count} images, got {len(images)}",
        )

    use_mock = mock_mode() if simulated is None else simulated
    if use_mock:
        return _enroll_mock(images)

    analyzer = model_registry.analyzer
    if analyzer is None or model_registry.embedder is None:
        raise AiApiException(status_code=503, code="MODEL_NOT_READY", message="Face models are not loaded")
    return _enroll_real(images, analyzer)
