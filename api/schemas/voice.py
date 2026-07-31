from typing import Literal

from pydantic import BaseModel, Field


class VoiceReportInput(BaseModel):
    """Input for voice-report AI analysis."""

    description: str = Field(min_length=1, description="Spoken report transcript")


class ModelOutput(BaseModel):
    """Structured AI output for a voice report."""

    title: str = Field(description="Punchy work-order style title, ~3–8 words")
    description: str = Field(
        description="Polished report description, about 20 words"
    )
    severity: Literal["low", "medium", "high"]
    category: Literal[
        "Road Damage",
        "Public Works",
        "Environmental",
        "Accessibility",
        "Other",
    ]
    confidence: float = Field(
        default=0.75,
        ge=0.0,
        le=1.0,
        description="Model confidence in category + severity",
    )
    rationale: str = Field(
        default="",
        description="One-line explanation of severity/category choice",
    )
