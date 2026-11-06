import cv2
import numpy as np
import pytest

from app.core.security import AiApiException
from app.services.embedding_service import extract_face_embeddings
from support import FakeAnalyzer, FakeSession, good_observation, near, unit


def jpeg(seed: int = 0, size: int = 400) -> bytes:
    """A decodable, high-detail (so 'sharp') JPEG. The fake analyzer supplies the face."""
    rng = np.random.RandomState(seed)
    ok, buf = cv2.imencode(".jpg", rng.randint(0, 255, (size, size, 3), dtype=np.uint8))
    assert ok
    return buf.tobytes()


THREE = [jpeg(1), jpeg(2), jpeg(3)]


# ------------------------------------------------------------------ mock mode (synthetic)
def test_mock_vectors_are_unit_512(monkeypatch):
    monkeypatch.setenv("AI_MOCK_MODE", "true")
    vectors = extract_face_embeddings([b"a", b"b", b"c"])
    assert len(vectors) == 3
    for vector in vectors:
        arr = np.array(vector, dtype=np.float32)
        assert arr.shape == (512,) and np.all(np.isfinite(arr))
        assert np.linalg.norm(arr) == pytest.approx(1.0, rel=1e-4)


def test_invalid_image_count_rejected(monkeypatch):
    monkeypatch.setenv("AI_MOCK_MODE", "true")
    for payload in ([b"1", b"2"], [b"1"] * 6):
        with pytest.raises(AiApiException) as info:
            extract_face_embeddings(payload)
        assert info.value.code == "IMAGE_INVALID"


# ------------------------------------------------------------------ real mode, fake models
def test_real_mode_without_models_is_not_ready(monkeypatch):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    with pytest.raises(AiApiException) as info:
        extract_face_embeddings(THREE)
    assert info.value.status_code == 503 and info.value.code == "MODEL_NOT_READY"


def test_real_mode_returns_unit_vectors_from_the_model(monkeypatch, install_models):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    base = unit(7)
    install_models(FakeAnalyzer(good_observation()), FakeSession([base, near(base, 8), near(base, 9)]))
    vectors = extract_face_embeddings(THREE)
    assert len(vectors) == 3
    assert all(np.linalg.norm(v) == pytest.approx(1.0, rel=1e-4) and len(v) == 512 for v in vectors)


def test_real_mode_normalises_model_output(monkeypatch, install_models):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    base = unit(7)
    install_models(FakeAnalyzer(good_observation()), FakeSession([base * 40, near(base, 8) * 25, near(base, 9) * 3]))
    for vector in extract_face_embeddings(THREE):
        assert np.linalg.norm(vector) == pytest.approx(1.0, rel=1e-4)


@pytest.mark.parametrize(
    "observation,code",
    [
        (good_observation(count=0, points5=None, face_width_px=None), "FACE_NOT_FOUND"),
        (good_observation(count=2), "MULTIPLE_FACES"),
        (good_observation(face_width_px=30.0), "LOW_QUALITY"),
        (good_observation(yaw=0.9), "LOW_QUALITY"),
    ],
)
def test_real_mode_rejects_unusable_photos(monkeypatch, install_models, observation, code):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    install_models(FakeAnalyzer(observation), FakeSession([unit(1)]))
    with pytest.raises(AiApiException) as info:
        extract_face_embeddings(THREE)
    assert info.value.status_code == 422 and info.value.code == code
    assert "Image 1" in info.value.message


def test_real_mode_rejects_blurry_photo(monkeypatch, install_models):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    flat = cv2.imencode(".jpg", np.full((400, 400, 3), 128, dtype=np.uint8))[1].tobytes()
    install_models(FakeAnalyzer(good_observation()), FakeSession([unit(1)]))
    with pytest.raises(AiApiException) as info:
        extract_face_embeddings([flat, flat, flat])
    assert info.value.code == "LOW_QUALITY" and "blurry" in info.value.message


def test_real_mode_rejects_mixed_identities(monkeypatch, install_models):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    install_models(FakeAnalyzer(good_observation()), FakeSession([unit(1), unit(1), unit(2)]))
    with pytest.raises(AiApiException) as info:
        extract_face_embeddings(THREE)
    assert info.value.code == "INCONSISTENT_FACES"


def test_real_mode_rejects_undecodable_image(monkeypatch, install_models):
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    install_models(FakeAnalyzer(good_observation()), FakeSession([unit(1)]))
    with pytest.raises(AiApiException) as info:
        extract_face_embeddings([b"not an image", b"x", b"y"])
    assert info.value.code == "IMAGE_INVALID"
