import json
import os
import httpx

from fastapi import HTTPException
from api.schemas.voice import ModelOutput


_SYSTEM_PROMPT = """
You are Street Sync's civic intelligence layer.

Given a spoken street issue transcript, return JSON only with:

{
  "title": "3-8 word Title Case work-order title",
  "description": "Professional ~20 word report description",
  "severity": "low | medium | high",
  "category": "Road Damage | Public Works | Environmental | Accessibility | Other",
  "confidence": 0.0,
  "rationale": "Short explanation"
}

Severity:
- high: unsafe, blocked travel, injury risk
- medium: should be fixed soon
- low: minor/cosmetic
"""


def analyze_voice_report(description: str) -> ModelOutput:
    if not description.strip():
        raise HTTPException(400, "Description required")

    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise HTTPException(503, "Missing API key")

    response = httpx.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json={
            "model": "openai/gpt-5.6-luna",
            "messages": [
                {
                    "role": "system",
                    "content": _SYSTEM_PROMPT
                },
                {
                    "role": "user",
                    "content": description
                }
            ],
            "response_format": {
                "type": "json_object"
            },
            "temperature": 0.1,
        },
        timeout=45,
    )

    if response.status_code != 200:
        raise HTTPException(
            502,
            f"OpenRouter error: {response.text}"
        )

    result = response.json()

    output = result["choices"][0]["message"]["content"]
    return ModelOutput(**json.loads(output))