"""Gemini-backed analysis for voice reports (title, severity, category)."""

from __future__ import annotations

import json
import os
import re
from typing import Optional
from dotenv import load_dotenv

from api.schemas.voice import ModelOutput

# Ensure .env is loaded
load_dotenv()

CATEGORIES = (
    "Road Damage",
    "Public Works",
    "Environmental",
    "Accessibility",
    "Other",
)

_SYSTEM_PROMPT = """You are Street Sync's civic intelligence layer — a professional assistant for public works dispatch.

Given a spoken street-issue transcript, extract a polished structured report.

Return a JSON object with exactly these fields:
- title: Punchy work-order style title, 3–8 words. Title Case. No quotes. No period.
  Prefer specificity ("Deep Pothole Blocking Lane") over vague ("Road Issue").
- description: About 20 words. One polished sentence for the report body. Fix grammar.
- severity: one of low, medium, high
- category: one of Road Damage, Public Works, Environmental, Accessibility, Other
- confidence: number from 0.0 to 1.0
- rationale: one short sentence explaining why you chose that severity/category

Category guide:
- Road Damage: potholes, cracks, pavement, sinkholes
- Public Works: lights, signs, hydrants, manholes, trash, graffiti
- Environmental: trees, flooding, litter, spills, drainage
- Accessibility: ramps, curb cuts, ADA, mobility barriers
- Other: anything else

Severity guide:
- high: unsafe, blocked travel, injury risk, emergency
- medium: needs fix soon
- low: minor, cosmetic, faded, non-urgent

Respond with JSON only.
"""

def _heuristic_analyze(description: str) -> ModelOutput:
    """Offline fallback logic."""
    desc = description.lower()
    category = "Other"
    if any(k in desc for k in ["pothole", "crack", "road"]): category = "Road Damage"
    elif any(k in desc for k in ["light", "sign", "trash"]): category = "Public Works"
    elif any(k in desc for k in ["tree", "flood", "drain"]): category = "Environmental"
    elif any(k in desc for k in ["wheelchair", "ramp", "ada"]): category = "Accessibility"
    
    severity = "medium"
    if any(k in desc for k in ["emergency", "unsafe", "danger", "blocked"]): severity = "high"
    elif any(k in desc for k in ["minor", "small", "cosmetic"]): severity = "low"
    
    words = description.split()
    title = " ".join(words[:5]).title() if words else "New Report"
    
    return ModelOutput(
        title=title,
        description=description,
        severity=severity,
        category=category,
        confidence=0.5,
        rationale="Heuristic fallback used."
    )

def _gemini_analyze(description: str) -> Optional[ModelOutput]:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("DEBUG: GEMINI_API_KEY missing")
        return None

    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            system_instruction=_SYSTEM_PROMPT,
        )
        
        response = model.generate_content(
            f"Transcript: {description}",
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )
        
        if response and response.text:
            data = json.loads(response.text.strip())
            return ModelOutput.model_validate(data)
    except Exception as e:
        print(f"DEBUG: Gemini AI failed: {e}")
    return None

def analyze_voice_report(description: str) -> ModelOutput:
    cleaned = (description or "").strip()
    if not cleaned:
        return _heuristic_analyze("New Issue")
    
    result = _gemini_analyze(cleaned)
    if result:
        return result
    return _heuristic_analyze(cleaned)
