from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from sqlalchemy import inspect, text
from sqlalchemy.exc import SQLAlchemyError

# Load environment variables from project root .env as early as possible
_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(_ROOT / ".env")
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


@app.exception_handler(SQLAlchemyError)
async def _db_error(request: Request, exc: SQLAlchemyError):
    print(f"DB error {request.method} {request.url.path}: {exc}")
    return JSONResponse(status_code=500, content={"detail": str(exc.__class__.__name__)})


def _add_missing_columns(table: str, columns: list[tuple[str, str]]) -> None:
    """create_all creates tables, not new columns on tables that already exist."""
    try:
        inspector = inspect(engine)
        if table not in inspector.get_table_names():
            return
        existing = {c["name"] for c in inspector.get_columns(table)}
        missing = [(name, ddl) for name, ddl in columns if name not in existing]
        if not missing:
            return
        with engine.begin() as conn:
            for name, ddl in missing:
                conn.execute(text(f'ALTER TABLE {table} ADD COLUMN "{name}" {ddl}'))
                print(f"added {table}.{name}")
    except Exception as e:
        print(f"ensure {table} columns: {e}")


_add_missing_columns(
    "users",
    [("picture", "VARCHAR")],
)
_add_missing_columns(
    "reports",
    [
        ("title", "VARCHAR(255) DEFAULT ''"),
        ("description", "VARCHAR DEFAULT ''"),
        ("category", "VARCHAR(50) DEFAULT 'Other'"),
        ("latitude", "FLOAT DEFAULT 0"),
        ("longitude", "FLOAT DEFAULT 0"),
        ("location", "VARCHAR DEFAULT ''"),
        ("image", "VARCHAR"),
        ("severity", "VARCHAR(20) DEFAULT 'medium'"),
        ("status", "VARCHAR(20) DEFAULT 'Open'"),
        ("is_draft", "BOOLEAN DEFAULT FALSE"),
        ("time", "TIMESTAMP"),
    ],
)


@app.get("/")
async def root():
    return {"message": "Hello World"}
