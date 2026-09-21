from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, EmailStr


class Reports(BaseModel):
    title: str
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
    title: str
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


class ReportStatusUpdate(BaseModel):
    """Dashboard payload: change report status (+ optional staff comment)."""

    status: str
    comment: Optional[str] = None


class UpdateOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    report_id: int
    user_id: int
    report_title: str
    old_status: str
    new_status: str
    comment: Optional[str] = None
    is_read: bool = False
    created_at: datetime


class Badge(BaseModel):
    name: str
    description: str
    icon: str


class Users(BaseModel):
    first_name: str
    last_name: str
    total_reports: int = 0


class UsersDetailed(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    first_name: str
    last_name: str
    reports: List[ReportsFull] = Field(default_factory=list)
    total_reports: int = 0
