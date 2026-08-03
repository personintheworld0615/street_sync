"""Quick smoke test for OpenRouter voice-report analysis.

Run from repo root:
  python test.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Allow `from api...` when run from repo root
_ROOT = Path(__file__).resolve().parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from dotenv import load_dotenv

load_dotenv(_ROOT / ".env")
load_dotenv()

from api.services.voice_ai import analyze_voice_report

SAMPLE = (
    "There's a huge pothole in the right lane on Main Street near the bakery. "
    "Cars are swerving around it and someone almost hit a cyclist."
)


def main() -> None:
    print(f"Transcript:\n  {SAMPLE}\n")
    print("Calling OpenRouter…")
    result = analyze_voice_report(SAMPLE)
    print("\nResult:")
    print(json.dumps(result.model_dump(), indent=2))


if __name__ == "__main__":
    main()
