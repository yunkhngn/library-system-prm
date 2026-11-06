"""
Inspect a recorded kiosk clip: what the service sees, and whether it would pass each challenge.

    python scripts/inspect_clip.py path/to/clip.mp4

Prints the blink/yaw signals (downsampled) and the liveness verdict for BLINK followed by
TURN_LEFT and by TURN_RIGHT. Use it on clips recorded with the real kiosk camera to tune the
AI_LIVENESS_* thresholds and to check whether the client records a mirrored video
(AI_LIVENESS_MIRRORED_INPUT): if a user who clearly turned to THEIR left only passes TURN_RIGHT,
the clip is mirrored.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.model_registry import model_registry  # noqa: E402
from app.models.schemas import ChallengeInstruction  # noqa: E402
from app.services.liveness_service import analyze_clip, evaluate_challenge, find_blink  # noqa: E402


def main(path: str) -> int:
    if not model_registry.load():
        print(f"models not loaded: {model_registry.load_error}")
        return 1

    analysis = analyze_clip(Path(path).read_bytes(), model_registry.analyzer)
    observations = analysis.observations
    print(f"{len(observations)} frames analysed at {analysis.fps:.1f} fps")

    print("\nframe  faces  blink   yaw")
    for i, o in enumerate(observations):
        if i % 3 == 0:
            blink = "  -  " if o.blink is None else f"{o.blink:5.2f}"
            yaw = "  -  " if o.yaw is None else f"{o.yaw:+5.2f}"
            print(f"{i:5d}  {o.count:5d}  {blink}  {yaw}")

    blink_series = [o.blink if o.single else None for o in observations]
    print("\nblink event:", find_blink(blink_series, 1.0 / analysis.fps))

    for second in ("TURN_LEFT", "TURN_RIGHT"):
        steps = [ChallengeInstruction(action="BLINK", order=1), ChallengeInstruction(action=second, order=2)]
        verdict = evaluate_challenge(observations, analysis.fps, steps)
        print(f"BLINK -> {second}: passed={verdict.passed} score={verdict.score:.3f} reason={verdict.reason}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
