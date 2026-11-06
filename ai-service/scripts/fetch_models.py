"""
Download the face models listed in app/models/manifest.json and verify their SHA-256.

    python scripts/fetch_models.py            # fetch anything missing or corrupted
    python scripts/fetch_models.py --check    # verify only, exit 1 if anything is missing

Standard library only, so it can run before the service dependencies are installed
(for example in a Docker build layer).
"""
from __future__ import annotations

import hashlib
import json
import sys
import urllib.request
from pathlib import Path

MODELS_DIR = Path(__file__).resolve().parent.parent / "app" / "models"
MANIFEST = MODELS_DIR / "manifest.json"


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch(entry: dict, check_only: bool) -> bool:
    target = MODELS_DIR / entry["name"]
    if target.exists() and sha256_of(target) == entry["sha256"]:
        print(f"ok       {entry['name']}")
        return True
    if check_only:
        print(f"MISSING  {entry['name']} (absent or checksum mismatch)")
        return False

    print(f"download {entry['name']} <- {entry['url']}")
    partial = target.with_suffix(target.suffix + ".part")
    with urllib.request.urlopen(entry["url"], timeout=120) as response, partial.open("wb") as out:
        while chunk := response.read(1 << 20):
            out.write(chunk)
    actual = sha256_of(partial)
    if actual != entry["sha256"]:
        partial.unlink(missing_ok=True)
        print(f"FAILED   {entry['name']}: sha256 {actual} != expected {entry['sha256']}")
        return False
    partial.replace(target)
    print(f"ok       {entry['name']}")
    return True


def main() -> int:
    check_only = "--check" in sys.argv[1:]
    files = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
    results = [fetch(entry, check_only) for entry in files.values()]
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
