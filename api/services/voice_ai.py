from __future__ import annotations

import json
import os
import re

import httpx
from fastapi import HTTPException

from api.schemas.voice import ModelOutput
from api.services.voice_rules import (
    Normalized,
    extract_fields,
    extract_spoken_location,
    has_problem_cue,
    is_greeting_only,
    keyword_category,
    meaningful_word_count,
    normalize_transcript,
)

# Jev only picks one. New categories can be added here later.
_CATEGORIES = {
    "Pothole": "A hole or crack in the road",
    "Damaged Sidewalk/Curb": "Broken sidewalk or curb",
    "Traffic Light": "A traffic signal problem",
    "Street Light": "A street light out or damaged",
    "Damaged/Missing Sign": "A road sign damaged or missing",
    "Road Debris": "Something in the road",
    "Parking/Traffic": "Parking or traffic problem",
    "Litter/Garbage": "Litter or garbage",
    "Missed Trash/Recycling": "Trash or recycling not picked up",
    "Illegal Dumping": "Dumped trash or debris",
    "Graffiti": "Graffiti",
    "Pollution": "Pollution or a spill",
    "Hazardous Waste": "Hazardous material that is not an active emergency",
    "Noise": "An ongoing noise problem",
    "Fallen Tree/Branch": "A fallen tree or branch",
    "Overgrown Vegetation": "Overgrown plants blocking a path",
    "Tree Maintenance": "A tree that needs care",
    "Flooding": "Flooding that is not a life-threatening emergency",
    "Clogged Storm Drain": "A blocked storm drain",
    "Standing Water": "Standing water",
    "Sewer/Water Problem": "A sewer or water-line problem",
    "Building Damage": "Damage to a public building",
    "Property Maintenance": "A property that needs maintenance",
    "Construction/Code Violation": "A construction or code problem",
    "Housing/Rental Problem": "A housing or rental problem",
    "Park Maintenance": "A park that needs maintenance",
    "Animal Issue": "An animal issue in a public place",
    "Rodent/Insect Issue": "Rodents or insects",
    "Other": "None of the other categories fit",
}

_EMERGENCY_PHRASES = (
    "call 911",
    "heart attack",
    "not breathing",
    "can't breathe",
    "cannot breathe",
    "gunshot",
    "shooting",
    "stabbed",
    "overdose",
    "unconscious",
    "building is on fire",
    "house is on fire",
)

_JEV_QUESTIONS = {
    "category": {
        "type": "choice",
        "instructions": "Which one category best fits this civic report?",
        "criteria": _CATEGORIES,
    },
    "emergency": {
        "type": "noul",
        "instructions": (
            "Someone should call 911 now: a fire, a medical "
            "emergency, a crime in progress, or a person in "
            "immediate danger. A pothole, trash, graffiti, a "
            "broken light, or a fallen branch is not a 911 call."
        ),
    },
    "vague": {
        "type": "noul",
        "instructions": (
            "A city crew could not act on this. It is vague if it is a "
            "greeting or filler, does not say what is wrong, or is not a "
            "public street, park, property, or environment problem a city "
            "handles (for example a personal phone, a private dispute, or "
            "small talk). A clear public problem is not vague even if it is "
            "short or has no address, because the map pin gives the location."
        ),
    },
}

# Signs the transcript is rambling speech that the free cleanup can't fix.
_NARRATIVE = re.compile(
    r"\b(?:i was|i'm|i am|so i|and then|kind of|sort of|basically|literally|"
    r"anyway|like,|you see)\b",
    re.I,
)
_SENTENCE_END = re.compile(r"[.!?]")

_FILLER_PREFIXES = (
    "there is a ", "there is ", "there's a ", "there's ", "i noticed a ",
    "i noticed ", "i want to report a ", "i want to report ", "reporting a ",
    "reporting ", "i see a ", "i see ", "hey ", "hi ", "please fix ",
    "can you fix ",
)


def analyze_voice_report(description: str, rewrite: bool = True) -> ModelOutput:
    raw = description.strip()
    if not raw:
        raise HTTPException(400, "Description required")

    norm = normalize_transcript(raw)
    text = norm.text or raw
    words = meaningful_word_count(text)
    cue = has_problem_cue(text)
    keyword = keyword_category(text)
    confident = keyword.strong and cue
    trace = {
        "words": words,
        "replacements": len(norm.replacements),
        "keyword": keyword.category,
        "confident": confident,
    }

    if _looks_like_emergency(text):
        trace["emergency_rule"] = True
        _log(trace)
        return ModelOutput(
            title=_fallback_title(text, keyword.category, None),
            description=_fallback_description(text),
            category=keyword.category,
            emergency=True,
            normalized_transcript=text,
        )

    too_short = is_greeting_only(text) or words < 3 or (words < 4 and not confident)

    # Emergency is always checked by Jev; the phrase list is not enough on its own.
    asked = ["emergency"]
    if not confident:
        asked.append("category")
        if not too_short:
            asked.append("vague")
    answers = _ask_jev(text, asked) or {}
    trace["jev"] = asked if answers else None

    category = (
        _category_from(answers.get("category"), keyword.category)
        if "category" in answers
        else keyword.category
    )
    emergency = _noul(answers.get("emergency")) >= 0.65
    vague = _noul(answers["vague"]) if "vague" in answers else None

    reasons = []
    if too_short:
        reasons.append("too_short")
    if not cue and (vague is None or vague >= 0.5):
        reasons.append("no_problem")
    if category == "Other" and (not cue or (vague is not None and vague >= 0.5)):
        reasons.append("unclear_category")
    if vague is not None and vague >= 0.6:
        reasons.append("jev_vague")
    needs_detail = bool(reasons) and not emergency

    fields = extract_fields(text, category)
    missing = [name for name, value in fields.items() if not value]
    location = extract_spoken_location(text)

    title = _fallback_title(text, category, location)
    polished = _fallback_description(text)
    if rewrite and not emergency and not needs_detail and _needs_rewrite(norm, text, words):
        result = _rewrite_with_luna(text, category)
        trace["luna"] = result is not None
        if result:
            title, polished, luna_location = result
            if not location and luna_location and _appears_in(luna_location, text):
                location = luna_location

    trace.update(category=category, reasons=reasons, missing=missing, location=bool(location))
    _log(trace)
    return ModelOutput(
        title=title,
        description=polished,
        category=category,
        emergency=emergency,
        needs_detail=needs_detail,
        needs_detail_reasons=reasons,
        fields=fields,
        missing_fields=missing,
        mentioned_location=location,
        normalized_transcript=text,
    )


def _needs_rewrite(norm: Normalized, text: str, words: int) -> bool:
    if words > 25 or norm.filler_removed >= 2:
        return True
    if _NARRATIVE.search(text):
        return True
    return words > 15 and not _SENTENCE_END.search(text)


def _rewrite_with_luna(text: str, category: str) -> tuple[str, str, str | None] | None:
    """One small chat call: polished description, short title, spoken place."""
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        return None
    try:
        response = httpx.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": os.getenv("OPENROUTER_HTTP_REFERER", "https://streetsync.app"),
                "X-Title": os.getenv("OPENROUTER_APP_TITLE", "Street Sync"),
            },
            json={
                "model": os.getenv("OPENROUTER_MODEL", "openai/gpt-6-luna"),
                "response_format": {"type": "json_object"},
                "reasoning": {"effort": "low", "exclude": True},
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You turn a spoken civic issue report into a clean report. "
                            f"The category is {category}. Return JSON with:\n"
                            "1. 'title': 3 to 6 words, title case, no quotes.\n"
                            "2. 'description': 1 to 2 clear sentences. Remove filler and "
                            "first-person storytelling. Keep every fact, place, number, "
                            "and pole or sign code exactly. Do not add anything that was "
                            "not said.\n"
                            "3. 'mentioned_location': the street address, intersection, or "
                            "named place the speaker said, copied from the text, or null.\n"
                            '{"title": "...", "description": "...", "mentioned_location": null}'
                        ),
                    },
                    {"role": "user", "content": text},
                ],
                "max_tokens": 300,
                "temperature": 0.2,
            },
            timeout=8,
        )
        if response.status_code != 200:
            print(f"Luna rewrite error {response.status_code}")
            return None
        choices = response.json().get("choices") or []
        content = (choices[0].get("message", {}).get("content") or "").strip() if choices else ""
        parsed = json.loads(content)
        title = str(parsed.get("title") or "").strip().strip("\"'")
        polished = str(parsed.get("description") or "").strip()
        location = parsed.get("mentioned_location")
        location = location.strip() if isinstance(location, str) and location.strip() else None
        if title and polished:
            return title, polished, location
    except Exception as err:
        print(f"Luna rewrite failed: {err}")
    return None


def _appears_in(phrase: str, text: str) -> bool:
    """Guard against a model inventing a place that was never said."""
    lowered = text.lower()
    tokens = re.findall(r"[a-z0-9']+", phrase.lower())
    return bool(tokens) and all(token in lowered for token in tokens)


def _strip_filler_prefix(text: str) -> str:
    cleaned = text.strip()
    lowered = cleaned.lower()
    for prefix in _FILLER_PREFIXES:
        if lowered.startswith(prefix):
            return cleaned[len(prefix):]
    return cleaned


def _fallback_description(text: str) -> str:
    cleaned = _strip_filler_prefix(text)
    if not cleaned:
        return text
    cleaned = cleaned[0].upper() + cleaned[1:]
    if cleaned[-1] not in ".!?":
        cleaned += "."
    return cleaned


def _place_case(place: str) -> str:
    """Capitalize words but keep "5th" and "and" as spoken."""
    return " ".join(
        w if w.lower() in ("and", "of") or not w[0].isalpha() else w[0].upper() + w[1:]
        for w in place.split()
    )


def _fallback_title(text: str, category: str, location: str | None) -> str:
    if category and category != "Other":
        if location and len(location) <= 30:
            return f"{category} on {_place_case(location)}"
        return category
    words = _strip_filler_prefix(text).split()
    title = " ".join(words[:6]).strip()
    if len(title) > 60:
        title = title[:57].rstrip() + "..."
    return title.title() if title else "Civic Report"


def _ask_jev(text: str, asked: list[str]) -> dict | None:
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        print("Jev skipped: OPENROUTER_API_KEY is not set")
        return None

    try:
        response = httpx.post(
            "https://openrouter.ai/api/v1/systemone",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "jev-latest",
                "state": text,
                "questions": {name: _JEV_QUESTIONS[name] for name in asked},
            },
            timeout=20,
        )
    except httpx.HTTPError as error:
        print(f"Jev request failed: {error}")
        return None

    if response.status_code != 200:
        print(f"Jev error {response.status_code}")
        return None

    answers = response.json().get("answers")
    if not isinstance(answers, dict):
        return None
    return answers


def _category_from(answer, fallback: str) -> str:
    if not isinstance(answer, dict):
        return fallback
    choice = answer.get("choice")
    confidence = answer.get("confidence")
    if not isinstance(choice, str) or choice not in _CATEGORIES:
        return fallback
    if isinstance(confidence, (int, float)) and confidence < 0.35:
        return fallback
    return choice


def _noul(answer) -> float:
    if not isinstance(answer, dict):
        return 0.0
    value = answer.get("noul")
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def _looks_like_emergency(text: str) -> bool:
    lowered = text.lower()
    return any(phrase in lowered for phrase in _EMERGENCY_PHRASES)


def _log(trace: dict) -> None:
    print("voice_ai " + json.dumps(trace))
