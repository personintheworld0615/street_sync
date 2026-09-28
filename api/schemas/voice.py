from typing import Literal

from pydantic import BaseModel, Field


class VoiceReportInput(BaseModel):

    description: str = Field(
        min_length=1,
        max_length=2000,
        description="Spoken report transcript",
    )


class ModelOutput(BaseModel):

    title: str = Field(description="Opening words of the report, not a model rewrite")
    description: str = Field(description="The person's own description")
    severity: Literal["low", "medium", "high"] = "medium"
    category: str
    emergency: bool = False
    needs_detail: bool = False
