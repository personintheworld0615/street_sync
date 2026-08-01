"""OpenRouter-backed analysis for voice reports (AI-only, no keyword heuristics)."""

from __future__ import annotations

import json
import os
import re
from typing import Optional

from fastapi import HTTPException

from api.schemas.voice import ModelOutput

CATEGORIES = (
    "Road Damage",
    "Public Works",
    "Environmental",
    "Accessibility",
    "Other",
)

_SYSTEM_PROMPT = """You are Street Sync's civic intelligence layer — the same kind of
assistant a city 311 / public-works desk would trust.

Given a spoken street-issue transcript, extract a polished structured report.

Return a JSON object with exactly these fields:
- title: Punchy work-order style title, 3–8 words. Title Case. No quotes. No period.
  Prefer specificity ("Deep Pothole Blocking Lane") over vague ("Road Issue").
- description: About 20 words (18–22). One polished sentence a dispatcher could use as
  the report body. Fix speech grammar, keep the key facts, sound professional.
- severity: one of low, medium, high
- category: one of Road Damage, Public Works, Environmental, Accessibility, Other
- confidence: number from 0.0 to 1.0 — how sure you are about category + severity
- rationale: one short sentence explaining why you chose that severity/category

Category guide:
- Road Damage: potholes, cracks, pavement, sinkholes, broken roadway/sidewalk surface
- Public Works: lights, signs, hydrants, manholes, trash, graffiti, town infrastructure
- Environmental: trees, flooding, litter, spills, drainage, pollution
- Accessibility: ramps, curb cuts, ADA, mobility barriers, crosswalk signals for disability
- Other: anything that does not fit above

Severity guide:
- high: unsafe, blocked travel, injury risk, emergency, collapsed, gas/fire
- medium: noticeable problem that should be fixed soon
- low: minor, cosmetic, faded, non-urgent

Be decisive and impressive — cities want clarity, not hedged fluff.
Respond with JSON only. No markdown.
"""


def _extract_json(text: str) -> Optional[dict]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    try:
        data = json.loads(cleaned)
        return data if isinstance(data, dict) else None
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if not match:
            return None
        try:
            data = json.loads(match.group(0))
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            return None


def _normalize_output(data: dict) -> ModelOutput:
    """Coerce model quirks into a valid ModelOutput."""
    title = str(data.get("title") or "").strip().strip('"').rstrip(".")
    # Prefer description; accept legacy "summary" key if a model still uses it.
    description = str(
        data.get("description") or data.get("summary") or ""
    ).strip()
    rationale = str(data.get("rationale") or "").strip()
    severity = str(data.get("severity") or "medium").strip().lower()
    if severity not in ("low", "medium", "high"):
        severity = "medium"

    category = str(data.get("category") or "Other").strip()
    # Light alias cleanup only — not keyword classification.
    aliases = {
        "road damage": "Road Damage",
        "public works": "Public Works",
        "environmental": "Environmental",
        "accessibility": "Accessibility",
        "other": "Other",
    }
    category = aliases.get(category.lower(), category)
    if category not in CATEGORIES:
        category = "Other"

    try:
        confidence = float(data.get("confidence", 0.75))
    except (TypeError, ValueError):
        confidence = 0.75
    confidence = max(0.0, min(1.0, confidence))

    if not title:
        raise ValueError("Model returned empty title")
    if not description:
        description = title
    else:
        # Soft-trim runaway descriptions toward ~20 words.
        words = description.split()
        if len(words) > 28:
            description = " ".join(words[:22]).rstrip(".,;") + "."
    if not rationale:
        rationale = f"Classified as {category} with {severity} severity."

    return ModelOutput(
        title=title,
        description=description,
        severity=severity,  # type: ignore[arg-type]
        category=category,  # type: ignore[arg-type]
        confidence=confidence,
        rationale=rationale,
    )


def _openrouter_analyze(description: str) -> ModelOutput:
    api_key = (os.getenv("OPENROUTER_API_KEY") or "").strip()
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="OPENROUTER_API_KEY is not configured on the API server.",
        )

    try:
        from openai import OpenAI
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail="openai package not installed. Run: pip install openai",
        ) from e

    model = (os.getenv("OPENROUTER_MODEL") or "openai/gpt-5.6-luna-pro").strip()

    # trust_env=False avoids broken HTTP(S)_PROXY settings on some hosts (e.g. Render)
    # that otherwise surface as opaque "Connection error" failures.
    try:
        import httpx
    except ImportError as e:
        raise HTTPException(
            status_code=503,
            detail="httpx package not installed (required by openai).",
        ) from e

    http_client = httpx.Client(
        timeout=httpx.Timeout(45.0, connect=15.0),
        trust_env=False,
        follow_redirects=True,
    )
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=api_key,
        timeout=45.0,
        max_retries=2,
        http_client=http_client,
    )
    extra_headers: dict[str, str] = {}
    referer = os.getenv("OPENROUTER_HTTP_REFERER")
    app_title = os.getenv("OPENROUTER_APP_TITLE", "Street Sync")
    if referer:
        extra_headers["HTTP-Referer"] = referer
    if app_title:
        extra_headers["X-Title"] = app_title

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": (
                        "Turn this spoken civic report into structured JSON.\n\n"
                        f"Transcript:\n{description.strip()}"
                    ),
                },
            ],
            response_format={"type": "json_object"},
            temperature=0.35,
            extra_headers=extra_headers or None,
        )
    except Exception as e:
        print(f"OpenRouter voice analyze request failed ({model}): {e}")
        raise HTTPException(
            status_code=502,
            detail=f"OpenRouter request failed: {e}",
        ) from e

    text = (response.choices[0].message.content or "").strip()
    if not text:
        raise HTTPException(status_code=502, detail="OpenRouter returned an empty response.")

    data = _extract_json(text)
    if not data:
        raise HTTPException(
            status_code=502,
            detail="OpenRouter returned non-JSON content.",
        )

    try:
        return _normalize_output(data)
    except Exception as e:
        print(f"OpenRouter voice analyze parse failed: {e}; raw={text[:400]}")
        raise HTTPException(
            status_code=502,
            detail=f"Could not parse AI analysis: {e}",
        ) from e


def analyze_voice_report(description: str) -> ModelOutput:
    cleaned = (description or "").strip()
    if not cleaned:
        raise HTTPException(status_code=400, detail="Description is required.")

    return _openrouter_analyze(cleaned)
