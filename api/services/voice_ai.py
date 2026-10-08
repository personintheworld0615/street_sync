import json
import os

import httpx
from fastapi import HTTPException

from api.schemas.voice import ModelOutput

# Placeholder list. New categories can be added here later. Jev only picks one.
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

_KEYWORD_CATEGORIES = {
    "Streets & Transportation": (
        "pothole",
        "sidewalk",
        "curb",
        "traffic light",
        "street light",
        "sign",
        "debris",
        "parking",
    ),
    "Trash & Environment": (
        "litter",
        "garbage",
        "trash",
        "recycling",
        "dumping",
        "graffiti",
        "pollution",
    ),
    "Nature & Water": (
        "tree",
        "branch",
        "flood",
        "drain",
        "standing water",
        "sewer",
    ),
    "Buildings & Public Spaces": (
        "building",
        "park",
        "housing",
        "animal",
        "rodent",
    ),
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


def analyze_voice_report(description: str) -> ModelOutput:
    text = description.strip()
    if not text:
        raise HTTPException(400, "Description required")

    category, emergency, needs_detail = _judge(text)
    title, polished_description = _generate_ai_title_and_description(text)
    return ModelOutput(
        title=title,
        description=polished_description,
        category=category,
        emergency=emergency,
        needs_detail=needs_detail,
    )


def _generate_ai_title_and_description(text: str) -> tuple[str, str]:
    """Generates both a professional title and a polished description from raw speech transcript."""
    api_key = os.getenv("OPENROUTER_API_KEY")
    if api_key:
        try:
            model = os.getenv("OPENROUTER_MODEL", "google/gemini-2.0-flash-lite-001")
            response = httpx.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": os.getenv("OPENROUTER_HTTP_REFERER", "https://streetsync.app"),
                    "X-Title": os.getenv("OPENROUTER_APP_TITLE", "Street Sync"),
                },
                json={
                    "model": model,
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {
                            "role": "system",
                            "content": (
                                "You are a civic infrastructure report assistant. Given a raw spoken transcript of a civic issue, "
                                "return a JSON object with two fields:\n"
                                "1. 'title': A short, title-cased, professional summary (3 to 6 words max, no quotation marks).\n"
                                "2. 'description': A clear, concise, polished description (1 to 2 sentences) removing conversational filler "
                                "(e.g., 'um', 'yeah', 'so I am walking') while preserving all factual details, locations, and numbers.\n"
                                'JSON format: {"title": "...", "description": "..."}'
                            ),
                        },
                        {
                            "role": "user",
                            "content": text,
                        },
                    ],
                    "max_tokens": 120,
                    "temperature": 0.2,
                },
                timeout=8,
            )
            if response.status_code == 200:
                data = response.json()
                choices = data.get("choices")
                if isinstance(choices, list) and len(choices) > 0:
                    raw_content = choices[0].get("message", {}).get("content", "").strip()
                    if raw_content:
                        try:
                            parsed = json.loads(raw_content)
                            ai_title = parsed.get("title", "").strip().strip('"\'')
                            ai_desc = parsed.get("description", "").strip()
                            if ai_title and ai_desc:
                                return ai_title, ai_desc
                        except Exception:
                            pass
        except Exception as err:
            print(f"OpenRouter title & description generation error: {err}")

    title = _smart_fallback_title(text)
    desc = _smart_fallback_description(text)
    return title, desc


def _smart_fallback_description(text: str) -> str:
    cleaned = text.strip()
    prefixes = [
        "there is a ", "there is ", "there's a ", "there's ", "i noticed a ", "i noticed ",
        "i want to report a ", "i want to report ", "reporting a ", "reporting ",
        "i see a ", "i see ", "hey ", "hi ", "please fix ", "can you fix "
    ]
    lowered = cleaned.lower()
    for prefix in prefixes:
        if lowered.startswith(prefix):
            cleaned = cleaned[len(prefix):]
            lowered = cleaned.lower()
            break

    if cleaned:
        cleaned = cleaned[0].upper() + cleaned[1:]
    return cleaned if cleaned else text


def _smart_fallback_title(text: str) -> str:
    cleaned = text.strip()
    prefixes = [
        "there is a ", "there is ", "there's a ", "there's ", "i noticed a ", "i noticed ",
        "i want to report a ", "i want to report ", "reporting a ", "reporting ",
        "i see a ", "i see ", "hey ", "hi ", "please fix ", "can you fix "
    ]
    lowered = cleaned.lower()
    for prefix in prefixes:
        if lowered.startswith(prefix):
            cleaned = cleaned[len(prefix):]
            lowered = cleaned.lower()
            break

    words = cleaned.split()
    title = " ".join(words[:6]).strip()
    if len(title) > 60:
        title = title[:57].rstrip() + "..."
    return title.title() if title else "Civic Report"


def _judge(text: str) -> tuple[str, bool, bool]:
    answers = _ask_jev(text)
    if answers is None:
        return _keyword_category(text), _looks_like_emergency(text), _looks_vague(text)

    category = _category_from(answers.get("category"), text)
    emergency = _noul(answers.get("emergency")) >= 0.65 or _looks_like_emergency(text)
    needs_detail = _noul(answers.get("vague")) >= 0.6
    return category, emergency, needs_detail


def _ask_jev(text: str) -> dict | None:
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
                "questions": {
                    "category": {
                        "type": "choice",
                        "instructions": (
                            "Which one category best fits this civic report?"
                        ),
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
                            "A city crew could not tell what is wrong from "
                            "this text. A greeting, one vague word, or no "
                            "actual problem is vague. A clear problem is not."
                        ),
                    },
                },
            },
            timeout=20,
        )
    except httpx.HTTPError as error:
        print(f"Jev request failed: {error}")
        return None

    if response.status_code != 200:
        print(f"Jev error {response.status_code}")
        return None

    body = response.json()
    answers = body.get("answers")
    if not isinstance(answers, dict):
        return None
    return answers


def _category_from(answer, text: str) -> str:
    if not isinstance(answer, dict):
        return _keyword_category(text)
    choice = answer.get("choice")
    confidence = answer.get("confidence")
    if not isinstance(choice, str) or choice not in _CATEGORIES:
        return _keyword_category(text)
    if isinstance(confidence, (int, float)) and confidence < 0.35:
        return _keyword_category(text)
    return choice


def _noul(answer) -> float:
    if not isinstance(answer, dict):
        return 0.0
    value = answer.get("noul")
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def _keyword_category(text: str) -> str:
    lowered = text.lower()
    best = "Other"
    best_hits = 0
    for category, words in _KEYWORD_CATEGORIES.items():
        hits = sum(1 for word in words if word in lowered)
        if hits > best_hits:
            best = category
            best_hits = hits
    return best


def _looks_like_emergency(text: str) -> bool:
    lowered = text.lower()
    return any(phrase in lowered for phrase in _EMERGENCY_PHRASES)


def _looks_vague(text: str) -> bool:
    return len(text.split()) < 4
