import hashlib
import json
import logging
import threading
from pathlib import Path
from typing import Any, Dict, Optional

from app.core.settings import mock_mode, settings

logger = logging.getLogger("ai.models")

MANIFEST_PATH = Path(__file__).parent.parent / "models" / "manifest.json"
MOCK_MODEL_ID = "arcface-512-mock"


class ModelRegistry:
    """
    Owns the loaded inference models.

    `is_ready()` is true in mock mode, or when the real models are loaded and verified.
    Loading never raises: a failure is recorded in `load_error` and the service reports
    NOT_READY instead of pretending to work.
    """

    def __init__(self):
        self._manifest: Dict[str, Any] = {}
        self._lock = threading.Lock()
        self._embedder = None
        self._analyzer = None
        self.load_error: Optional[str] = None
        self._load_manifest()

    def _load_manifest(self):
        if MANIFEST_PATH.exists():
            with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                self._manifest = json.load(f)
        else:
            self._manifest = {
                "modelId": "arcface-512-r100",
                "modelVersion": "arcface-512-v1",
                "dimension": 512,
            }

    # --- manifest properties -------------------------------------------------------
    @property
    def model_id(self) -> str:
        return self._manifest.get("modelId", "arcface-512-r100")

    @property
    def model_version(self) -> str:
        return self._manifest.get("modelVersion", "arcface-512-v1")

    @property
    def reported_model_id(self) -> str:
        """Model id put on responses. Synthetic (mock) results are tagged so they never mix with real ones."""
        return MOCK_MODEL_ID if mock_mode() else self.model_id

    @property
    def liveness_model_version(self) -> str:
        return self._manifest.get("livenessModelVersion", settings.liveness_model_version)

    @property
    def dimension(self) -> int:
        return self._manifest.get("dimension", 512)

    def get_manifest(self) -> Dict[str, Any]:
        return dict(self._manifest)

    # --- loading -----------------------------------------------------------------------
    def _verified_path(self, key: str) -> Path:
        entry = self._manifest["files"][key]
        path = settings.model_dir / entry["name"]
        if not path.exists():
            raise FileNotFoundError(f"{path} is missing; run `python scripts/fetch_models.py`")
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
        if digest.hexdigest() != entry["sha256"]:
            raise ValueError(f"{path.name} checksum mismatch; run `python scripts/fetch_models.py`")
        return path

    def load(self) -> bool:
        """Load and verify the real models. Safe to call repeatedly."""
        with self._lock:
            if self._embedder is not None and self._analyzer is not None:
                return True
            try:
                import onnxruntime as ort

                from app.services.face_analysis import MediaPipeFaceAnalyzer

                embedding_path = self._verified_path("embedding")
                landmarker_path = self._verified_path("landmarker")

                session = ort.InferenceSession(str(embedding_path), providers=["CPUExecutionProvider"])
                output_dim = session.get_outputs()[0].shape[-1]
                if output_dim != self.dimension:
                    raise ValueError(f"embedding model outputs {output_dim} dims, expected {self.dimension}")

                self._embedder = session
                self._analyzer = MediaPipeFaceAnalyzer(str(landmarker_path))
                self.load_error = None
                logger.info("face models loaded (%s)", self.model_version)
                return True
            except Exception as exc:  # noqa: BLE001 - reported through readiness, never raised
                self._embedder = None
                self._analyzer = None
                self.load_error = f"{type(exc).__name__}: {exc}"
                logger.error("face models failed to load: %s", self.load_error)
                return False

    def unload(self) -> None:
        with self._lock:
            if self._analyzer is not None:
                self._analyzer.close()
            self._embedder = None
            self._analyzer = None

    def install(self, embedder, analyzer) -> None:
        """Inject models (used by tests with fakes)."""
        with self._lock:
            self._embedder = embedder
            self._analyzer = analyzer
            self.load_error = None

    # --- accessors -----------------------------------------------------------------------
    @property
    def embedder(self):
        return self._embedder

    @property
    def analyzer(self):
        return self._analyzer

    def is_loaded(self) -> bool:
        return self._embedder is not None and self._analyzer is not None

    def is_ready(self) -> bool:
        return True if mock_mode() else self.is_loaded()


model_registry = ModelRegistry()
