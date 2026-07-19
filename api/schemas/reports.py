from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from typing import Literal
from typing import List
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
    isPending: bool = False

class ReportsFull(BaseModel):
    id: int
    description: str
    category: str
    latitude: float
    longitude: float
    location: str
    image: Optional[str] = None
    time: datetime
    severity: Literal["low", "medium", "high"]
    status: Literal["pending", "approved", "rejected"]
    user_id: int
    isPending: bool = False

class Users(BaseModel):
    name: str
    total_reports: int
class UsersDetailed(BaseModel):
    id: int
    name: str
    reports: List[ReportsFull]
    total_reports: int