import json
import os
import secrets
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from dotenv import load_dotenv

from api.database import get_db
from api.models.reports import User

# Same root .env as database.py (project root)
_ROOT = Path(__file__).resolve().parent.parent.parent
load_dotenv(_ROOT / ".env")
load_dotenv()

try:
    SECRET_KEY = os.environ["SECRET_KEY"]
except KeyError as exc:
    raise RuntimeError(
        "SECRET_KEY is not set. Add it to your .env "
        "(see .env.example). Generate with: "
        'python3 -c "import secrets; print(secrets.token_hex(32))"'
    ) from exc

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 90

SUPABASE_URL = (os.getenv("SUPABASE_URL") or "").rstrip("/")
SUPABASE_SERVICE_KEY = (
    os.getenv("SUPABASE_SERVICE_KEY")
    or os.getenv("SUPABASE_KEY")
    or ""
)
SUPABASE_ANON_KEY = (
    os.getenv("SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_PUBLISHABLE_KEY")
    or ""
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def _supabase_apikey() -> str:
    return SUPABASE_SERVICE_KEY or SUPABASE_ANON_KEY


def fetch_supabase_user(access_token: str) -> dict[str, Any]:
    """Validate a Supabase access token via Auth API and return the user JSON."""
    if not SUPABASE_URL or not _supabase_apikey():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase auth is not configured on the API",
        )

    req = urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/user",
        headers={
            "Authorization": f"Bearer {access_token}",
            "apikey": _supabase_apikey(),
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Supabase token",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate Supabase token",
        ) from exc


def delete_supabase_user(supabase_user_id: str) -> None:
    """Best-effort delete of the Auth user (requires service role key)."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY or not supabase_user_id:
        return
    req = urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/admin/users/{supabase_user_id}",
        headers={
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "apikey": SUPABASE_SERVICE_KEY,
        },
        method="DELETE",
    )
    try:
        with urllib.request.urlopen(req, timeout=10):
            return
    except Exception:
        # Local DB delete should still succeed even if Auth cleanup fails.
        return


def _names_from_supabase(sb_user: dict[str, Any]) -> tuple[str, str]:
    meta = sb_user.get("user_metadata") or {}
    first = (meta.get("first_name") or "").strip()
    last = (meta.get("last_name") or "").strip()
    if not first:
        full = (meta.get("full_name") or meta.get("name") or "").strip()
        if full:
            parts = full.split()
            first = parts[0]
            last = " ".join(parts[1:]) if len(parts) > 1 else last
    if not first:
        email = (sb_user.get("email") or "citizen").split("@")[0]
        first = email or "Citizen"
    return first[:100], last[:100]


def upsert_user_from_supabase(
    db: Session,
    sb_user: dict[str, Any],
    *,
    first_name: str | None = None,
    last_name: str | None = None,
) -> User:
    email = (sb_user.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Supabase user has no email",
        )

    meta_first, meta_last = _names_from_supabase(sb_user)
    first = (first_name or meta_first).strip() or meta_first
    last = (last_name if last_name is not None else meta_last).strip()

    picture = None
    meta = sb_user.get("user_metadata") or {}
    for key in ("avatar_url", "picture"):
        raw = meta.get(key)
        if isinstance(raw, str) and raw.strip():
            picture = raw.strip()
            break

    user = db.query(User).filter(User.email == email).first()
    if user is None:
        user = User(
            first_name=first,
            last_name=last,
            email=email,
            password=hash_password(secrets.token_urlsafe(32)),
            picture=picture,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    changed = False
    if first_name and user.first_name != first:
        user.first_name = first
        changed = True
    if last_name is not None and user.last_name != last:
        user.last_name = last
        changed = True
    if picture and not user.picture:
        user.picture = picture
        changed = True
    if changed:
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def _user_from_legacy_jwt(token: str, db: Session) -> User | None:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        sub = payload.get("sub")
        if sub is None:
            return None
        user_id = int(sub)
    except (JWTError, TypeError, ValueError):
        return None

    return db.query(User).filter(User.id == user_id).first()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials

    legacy = _user_from_legacy_jwt(token, db)
    if legacy is not None:
        return legacy

    sb_user = fetch_supabase_user(token)
    return upsert_user_from_supabase(db, sb_user)


def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(optional_security),
    db: Session = Depends(get_db),
) -> User | None:
    """Return the logged-in user if a valid Bearer token is present; else None."""
    if credentials is None:
        return None
    try:
        return get_current_user(credentials=credentials, db=db)
    except HTTPException:
        return None
