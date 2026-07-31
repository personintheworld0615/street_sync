"""Gemini-backed analysis for voice reports (title, severity, category)."""

from __future__ import annotations

import json
import os
import re
from typing import Optional

from api.schemas.reports import ModelOutput

CATEGORIES = (
    "Road Damage",
    "Public Works",
    "Environmental",
    "Accessibility",
    "Other",
)

_CATEGORY_KEYWORDS = {
    "Accessibility": [
        "wheelchair",
        "ramp",
        "curb cut",
        "accessible",
        "ada",
        "crosswalk signal",
        "blind",
        "cane",
    ],
    "Road Damage": [
        "pothole",
        "crack",
        "pavement",
        "asphalt",
        "road",
        "sidewalk broken",
        "sinkhole",
    ],
    "Public Works": [
        "streetlight",
        "lamp",
        "traffic light",
        "sign",
        "hydrant",
        "manhole",
        "trash",
        "dumpster",
        "graffiti",
    ],
    "Environmental": [
        "flood",
        "flooding",
        "tree",
        "branch",
        "litter",
        "spill",
        "pollution",
        "drainage",
        "storm drain",
    ],
}

_URGENCY = [
    "blocked",
    "unsafe",
    "injury",
    "injured",
    "flooding",
    "fallen",
    "no ramp",
    "entire lane",
    "emergency",
    "dangerous",
    "collapsed",
    "fire",
    "gas leak",
]

_DOWNGRADE = [
    "minor",
    "small",
    "cosmetic",
    "faded",
    "slowly",
    "not urgent",
]

_SYSTEM_PROMPT = """You analyze municipal street/civic issue reports from spoken descriptions.

Return structured fields only:
- title: short, clear issue title (about 3–8 words). No quotes. No trailing period.
- severity: one of low, medium, high
- category: one of Road Damage, Public Works, Environmental, Accessibility, Other

Category guide:
- Road Damage: potholes, cracks, pavement, sinkholes, broken roadway/sidewalk surface
- Public Works: lights, signs, hydrants, manholes, trash, graffiti, town infrastructure
- Environmental: trees, flooding, litter, spills, drainage, pollution
- Accessibility: ramps, curb cuts, ADA, mobility barriers, crosswalk signals for disability
- Other: anything that does not fit above

Severity guide:
- high: unsafe, blocked, injury risk, emergency, collapsed, gas/fire
- medium: noticeable problem that should be fixed soon
- low: minor, cosmetic, faded, non-urgent
"""


def _keyword_hits(text: str, keywords: list[str]) -> int:
    return sum(1 for kw in keywords if kw in text)


def _heuristic_analyze(description: str) -> ModelOutput:
    """Offline fallback when Gemini is unavailable."""
    desc = description.lower().strip()

    best_category = "Other"
    best_hits = 0
    for category in ("Accessibility", "Road Damage", "Public Works", "Environmental"):
        hits = _keyword_hits(desc, _CATEGORY_KEYWORDS[category])
        if hits > best_hits:
            best_hits = hits
            best_category = category
    if best_hits == 0:
        best_category = "Other"

    score = {
        "Accessibility": 3,
        "Road Damage": 2,
        "Public Works": 2,
        "Environmental": 1,
    }.get(best_category, 2)
    score += min(_keyword_hits(desc, _URGENCY), 2)
    score -= min(_keyword_hits(desc, _DOWNGRADE), 2)

    if score >= 3:
        severity = "high"
    elif score <= 1:
        severity = "low"
    else:
        severity = "medium"

    words = re.findall(r"[A-Za-z0-9']+", description.strip())
    title_words = words[:6] if words else ["New", "Issue"]
    title = " ".join(title_words)
    if title:
        title = title[0].upper() + title[1:]

    return ModelOutput(title=title, severity=severity, category=best_category)  # type: ignore[arg-type]


def _gemini_analyze(description: str) -> Optional[ModelOutput]:
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        return None

    try:
        import google.generativeai as genai
    except ImportError:
        return None

    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name=os.getenv("GEMINI_MODEL", "gemini-2.0-flash"),
            system_instruction=_SYSTEM_PROMPT,
        )
        # Flat schema avoids $defs/$ref issues with Gemini structured output.
        schema = {
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "severity": {"type": "string", "enum": ["low", "medium", "high"]},
                "category": {
                    "type": "string",
                    "enum": list(CATEGORIES),
                },
            },
            "required": ["title", "severity", "category"],
        }
        response = model.generate_content(
            f"Voice report description:\n{description.strip()}",
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                response_schema=schema,
                temperature=0.2,
            ),
        )
        text = (response.text or "").strip()
        if not text:
            return None
        data = json.loads(text)
        return ModelOutput.model_validate(data)
    except Exception as e:
        print(f"Gemini voice analyze failed, using heuristic: {e}")
        return None


def analyze_voice_report(description: str) -> ModelOutput:
    cleaned = (description or "").strip()
    if not cleaned:
        return ModelOutput(title="New Issue", severity="medium", category="Other")

    # Prefer Gemini structured output; fall back to local heuristics.
    result = _gemini_analyze(cleaned)
    if result is not None:
        return result
    return _heuristic_analyze(cleaned)
