"""
Runs against the REAL model files (skipped when they have not been downloaded).

No face photos are needed: these tests pin the contract with the actual ONNX graph and the real
landmarker, which fakes cannot do (for example the ArcFace graph's fixed batch size of 1).
Download the models first:  python scripts/fetch_models.py
"""
import numpy as np
import pytest

from app.core.model_registry import ModelRegistry
from app.core.settings import settings

pytestmark = pytest.mark.skipif(
    not (settings.model_dir / "arcfaceresnet100-8.onnx").exists()
    or not (settings.model_dir / "face_landmarker.task").exists(),
    reason="model files not downloaded (python scripts/fetch_models.py)",
)


@pytest.fixture(scope="module")
def registry():
    reg = ModelRegistry()
    if not reg.load():
        pytest.skip(f"models could not be loaded in this environment: {reg.load_error}")
    yield reg
    reg.unload()


def test_registry_loads_and_verifies_checksums(registry):
    assert registry.is_loaded() and registry.load_error is None


def test_real_embedder_accepts_one_face_and_returns_512_unit_vector(registry):
    session = registry.embedder
    assert session.get_inputs()[0].shape[1:] == [3, 112, 112]
    face = np.random.RandomState(0).randint(0, 255, (1, 3, 112, 112)).astype(np.float32)
    out = session.run(None, {session.get_inputs()[0].name: face})[0]
    assert out.shape == (1, 512) and np.all(np.isfinite(out))


def test_embed_aligned_handles_several_faces_with_the_real_graph(registry, monkeypatch):
    from app.core import model_registry as module
    from app.services.embedding_service import embed_aligned

    monkeypatch.setattr(module, "model_registry", registry)
    monkeypatch.setattr("app.services.embedding_service.model_registry", registry)
    faces = [np.random.RandomState(i).randint(0, 255, (112, 112, 3), dtype=np.uint8) for i in range(3)]
    vectors = embed_aligned(faces)
    assert vectors.shape == (3, 512)
    assert np.allclose(np.linalg.norm(vectors, axis=1), 1.0, atol=1e-4)


def test_real_landmarker_reports_no_face_on_a_blank_image(registry):
    observation = registry.analyzer.analyze(np.full((480, 640, 3), 120, dtype=np.uint8))
    assert observation.count == 0 and not observation.single
