from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, EmailStr, Field


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
class SignupRequest(BaseModel):
    name: str = Field(min_length=1,max_length=100)
    email: EmailStr
    password: str = Field(min_length=8,max_length=100)
class LoginRequest(BaseModel):
    email: EmailStr
    password: str
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    name: str

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
