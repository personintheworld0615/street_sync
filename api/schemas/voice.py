from typing import Literal

from pydantic import BaseModel, Field


class VoiceReportInput(BaseModel):

    description: str = Field(min_length=1, description="Spoken report transcript")


class ModelOutput(BaseModel):

    title: str = Field(description="Punchy work-order style title, ~3 words")
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
