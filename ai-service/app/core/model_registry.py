import json
import os
from pathlib import Path
from typing import Dict, Any, Optional

MANIFEST_PATH = Path(__file__).parent.parent / "models" / "manifest.json"


class ModelRegistry:
    def __init__(self):
        self._manifest: Dict[str, Any] = {}
        self._is_loaded = False
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

    @property
    def model_id(self) -> str:
        return self._manifest.get("modelId", "arcface-512-r100")

    @property
    def model_version(self) -> str:
        return self._manifest.get("modelVersion", "arcface-512-v1")

    @property
    def dimension(self) -> int:
        return self._manifest.get("dimension", 512)

    def is_ready(self) -> bool:
        mock_mode = os.getenv("AI_MOCK_MODE", "true").lower() in ("true", "1", "yes")
        if mock_mode:
            return True
        models_ready = os.getenv("AI_MODELS_READY", "false").lower() in ("true", "1", "yes")
        return models_ready

    def get_manifest(self) -> Dict[str, Any]:
        return dict(self._manifest)


model_registry = ModelRegistry()
