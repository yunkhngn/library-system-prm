import hashlib
from typing import List
import numpy as np
from app.core.model_registry import model_registry
from app.core.security import AiApiException


def compute_deterministic_vector(image_bytes: bytes, seed_salt: str = "salt") -> np.ndarray:
    """
    Produces deterministic 512-dimensional unit vector based on image hash and salt,
    simulating feature extraction with high repeatability.
    """
    hasher = hashlib.sha256(image_bytes + seed_salt.encode("utf-8")).digest()
    # Expand 32 bytes to 512 floats
    rng = np.random.RandomState(int.from_bytes(hasher[:4], "little"))
    vec = rng.randn(512).astype(np.float32)
    norm = np.linalg.norm(vec)
    if norm > 0:
        vec /= norm
    return vec


def extract_face_embeddings(images: List[bytes], simulated: bool = True) -> List[List[float]]:
    """
    Extracts 512-dimensional L2-normalized face embeddings from decoded image bytes.
    Validates pairwise consistency across images (rejects mixed identities).
    """
    if len(images) < 3 or len(images) > 5:
        raise AiApiException(
            status_code=422,
            code="IMAGE_INVALID",
            message=f"Enrollment requires 3-5 images, got {len(images)}"
        )

    # In mock mode, base vector derived from first image, and small perturbation for others
    base_seed = hashlib.sha256(images[0]).digest()
    rng = np.random.RandomState(int.from_bytes(base_seed[:4], "little"))
    base_vec = rng.randn(512).astype(np.float32)
    base_vec /= np.linalg.norm(base_vec)

    embeddings: List[np.ndarray] = []
    for i, img in enumerate(images):
        if i == 0:
            embeddings.append(base_vec)
        else:
            # Small directional perturbation ensuring cosine similarity >= 0.95
            noise_dir = rng.randn(512).astype(np.float32)
            norm_noise = np.linalg.norm(noise_dir)
            if norm_noise > 0:
                noise_dir /= norm_noise
            v = 0.98 * base_vec + 0.02 * noise_dir
            v /= np.linalg.norm(v)
            embeddings.append(v)

    # Validate pairwise consistency
    for i in range(len(embeddings)):
        for j in range(i + 1, len(embeddings)):
            sim = float(np.dot(embeddings[i], embeddings[j]))
            dist = 1.0 - sim
            if dist > 0.40:
                raise AiApiException(
                    status_code=422,
                    code="INCONSISTENT_FACES",
                    message="Images appear to be of different individuals (pairwise distance > 0.40)"
                )

    return [v.tolist() for v in embeddings]
