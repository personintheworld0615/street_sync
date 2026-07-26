import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# Load .env from project root (parent of api/) or current working directory.
_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(_ROOT / ".env")
load_dotenv()

# 1. Prefer a single DATABASE_URL (Render / Neon style)
DATABASE_URL = os.getenv("DATABASE_URL")

# 2. Or build from split vars (current Render + local .env setup)
if not DATABASE_URL:
    user = os.getenv("user")
    password = os.getenv("password")
    host = os.getenv("host")
    port = os.getenv("port")
    dbname = os.getenv("dbname")
    if all([user, password, host, port, dbname]):
        DATABASE_URL = (
            f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{dbname}"
            f"?sslmode=require"
        )

# 3. Local fallback when nothing else is provided
if not DATABASE_URL:
    DATABASE_URL = "sqlite:///./app.db"

# SQLAlchemy wants postgresql://, not postgres://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
    )
else:
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
