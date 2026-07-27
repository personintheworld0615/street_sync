from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from sqlalchemy import inspect, text

# Load environment variables from .env as early as possible
load_dotenv()

from api.routes.auth import router as auth_router
from api.database import Base, engine
from api.models import reports as models_reports 
from api.routes.reports import router as reports_router

app = FastAPI(title="StreetSync API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(reports_router)
app.include_router(auth_router)
Base.metadata.create_all(bind=engine)


def _ensure_user_picture_column() -> None:
    """create_all won't add columns to existing tables — patch users.picture."""
    try:
        inspector = inspect(engine)
        if "users" not in inspector.get_table_names():
            return
        columns = {c["name"] for c in inspector.get_columns("users")}
        if "picture" in columns:
            return
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE users ADD COLUMN picture VARCHAR"))
    except Exception as e:
        print(f"ensure users.picture column: {e}")


_ensure_user_picture_column()


@app.get("/")
async def root():
    return {"message": "Hello World"}
