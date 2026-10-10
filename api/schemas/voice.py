from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field


class VoiceReportInput(BaseModel):

    description: str = Field(
        min_length=1,
        max_length=2000,
        description="Spoken report transcript",
    )
    rewrite: bool = Field(
        default=True,
        description="False skips the paid rewrite; use for submit-time checks",
    )


class ModelOutput(BaseModel):

    title: str
    description: str
    severity: Literal["low", "medium", "high"] = "medium"
    category: str
    emergency: bool = False
    needs_detail: bool = False
    ## too_short | no_problem | unclear_category | jev_vague
    needs_detail_reasons: List[str] = []
    ## Category-specific fields, e.g. {"pole_number": "A1234"} for Street Light.
    fields: Dict[str, Optional[str]] = {}
    missing_fields: List[str] = []
    mentioned_location: Optional[str] = None
    normalized_transcript: str = ""
