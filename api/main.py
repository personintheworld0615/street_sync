from datetime import datetime, timezone
from typing import Dict, List, Literal, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="StreetSync API", description="API for the StreetSync app")
