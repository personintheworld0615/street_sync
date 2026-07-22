from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class Reports(BaseModel):
    description: str
    category: str
    latitude: float
    longitude: float
    location: str
    image: Optional[str] = None
    time: datetime
    severity: Literal["low", "medium", "high"]
    user_id: int
    isDraft: bool = False


class ReportsFull(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    description: str
    category: str
    latitude: float
    longitude: float
    location: str
    image: Optional[str] = None
    time: datetime
    severity: str
    status: str
    user_id: int
    isDraft: bool = False


class Users(BaseModel):
    name: str
    total_reports: int = 0


class UsersDetailed(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    reports: List[ReportsFull] = Field(default_factory=list)
    total_reports: int = 0
