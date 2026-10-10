import json
import os
import re
import secrets
import urllib.error
import urllib.parse
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
ACCESS_TOKEN_EXPIRE_DAYS = 7

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


def _supabase_admin_request(
    method: str,
    path: str,
    *,
    body: dict[str, Any] | None = None,
    query: str = "",
) -> tuple[int, dict[str, Any] | list[Any] | None]:
    """Call Supabase Auth Admin API. Returns (status_code, parsed JSON or None)."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase admin auth is not configured on the API",
        )
    url = f"{SUPABASE_URL}/auth/v1{path}"
    if query:
        url = f"{url}?{query}"
    data = None
    headers = {
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "apikey": SUPABASE_SERVICE_KEY,
        "Content-Type": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8")
            parsed = json.loads(raw) if raw else None
            return resp.status, parsed
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8")
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = {"msg": raw or str(exc.reason)}
        return exc.code, parsed


_SUPABASE_USER_ID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def is_supabase_user_id(value: str | None) -> bool:
    return bool(value and _SUPABASE_USER_ID.match(value))


def delete_supabase_user(supabase_user_id: str) -> bool:
    """Hard-delete the Auth user. A missing user counts as already deleted."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY or not is_supabase_user_id(supabase_user_id):
        print(
            "delete_supabase_user skipped: missing SUPABASE_URL, "
            "SUPABASE_SERVICE_KEY, or a Supabase user id"
        )
        return False
    try:
        status_code, payload = _supabase_admin_request(
            "DELETE",
            f"/admin/users/{supabase_user_id}",
            body={"should_soft_delete": False},
        )
        # 404: already gone, so a retry can still remove the app profile.
        if status_code in (200, 204, 404):
            return True
        print(f"delete_supabase_user failed ({status_code}): {payload}")
        return False
    except Exception as exc:
        print(f"delete_supabase_user error: {exc}")
        return False


def supabase_user_id_from_access_token(access_token: str) -> str | None:
    """Read the Auth user UUID from a Supabase access token (unverified decode)."""
    try:
        parts = access_token.split(".")
        if len(parts) < 2:
            return None
        payload_b64 = parts[1]
        padding = "=" * (-len(payload_b64) % 4)
        raw = __import__("base64").urlsafe_b64decode(payload_b64 + padding)
        payload = json.loads(raw.decode("utf-8"))
        sub = payload.get("sub")
        return sub if isinstance(sub, str) and sub else None
    except Exception:
        return None


def admin_find_user_id_by_email(email: str) -> str | None:
    """Return the Supabase Auth user id for an email, if any."""
    target = email.strip().lower()
    status_code, payload = _supabase_admin_request(
        "GET",
        "/admin/users",
        query=f"page=1&per_page=200&email={urllib.parse.quote(target)}",
    )
    if status_code >= 400 or not isinstance(payload, dict):
        detail = "Could not look up the sign-in account"
        if isinstance(payload, dict):
            detail = str(payload.get("msg") or payload.get("message") or detail)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=detail,
        )
    users = payload.get("users") or []
    for user in users:
        if not isinstance(user, dict):
            continue
        user_email = str(user.get("email") or "").strip().lower()
        if user_email == target:
            uid = user.get("id")
            return uid if isinstance(uid, str) else None
    return None


def admin_create_confirmed_user(
    *,
    email: str,
    password: str,
    first_name: str,
    last_name: str,
    email_confirm: bool = True,
) -> dict[str, Any]:
    """Create a Supabase Auth user. Signup uses email_confirm=True (no confirmation email)."""
    status_code, payload = _supabase_admin_request(
        "POST",
        "/admin/users",
        body={
            "email": email.strip().lower(),
            "password": password,
            "email_confirm": email_confirm,
            "user_metadata": {
                "first_name": first_name,
                "last_name": last_name,
            },
        },
    )
    if status_code in (200, 201) and isinstance(payload, dict):
        return payload

    msg = ""
    if isinstance(payload, dict):
        msg = str(
            payload.get("msg")
            or payload.get("message")
            or payload.get("error_description")
            or ""
        )
    if status_code in (400, 422) and "already" in msg.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    print(f"admin_create_confirmed_user failed ({status_code})")
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Could not create auth user",
    )


def admin_confirm_user_email(email: str) -> bool:
    """Mark a Supabase Auth user's email as confirmed. Returns True if updated."""
    uid = admin_find_user_id_by_email(email)
    if not uid:
        return False
    status_code, _payload = _supabase_admin_request(
        "PUT",
        f"/admin/users/{uid}",
        body={"email_confirm": True},
    )
    return status_code < 400


def _local_password_matches(user: User, password: str) -> bool:
    if not user.password:
        return False
    try:
        return verify_password(password, user.password)
    except Exception:
        return False


def assert_staff(user: User) -> None:
    """Status changes are limited to emails listed in STAFF_EMAILS."""
    raw = os.getenv("STAFF_EMAILS") or ""
    allowed = {part.strip().lower() for part in raw.split(",") if part.strip()}
    email = (user.email or "").strip().lower()
    if not email or email not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff access required",
        )


def ensure_email_confirmed_for_login(email: str, password: str, db: Session) -> None:
    """
    Confirm a Supabase email only after the local password hash matches.
    A Supabase rate-limit response must not confirm the account.
    """
    normalized = email.strip().lower()
    grant = supabase_password_grant(normalized, password)
    if grant.get("access_token"):
        return

    err = str(grant.get("error") or grant.get("error_code") or "").lower()
    desc = str(
        grant.get("msg")
        or grant.get("error_description")
        or grant.get("message")
        or ""
    ).lower()
    if "rate limit" in desc or "rate_limit" in err or "too many" in desc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Try again in a little while.",
        )

    unconfirmed = (
        "email_not_confirmed" in err or "email not confirmed" in desc
    )
    if not unconfirmed:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    user = db.query(User).filter(User.email == normalized).first()
    if user is None or not _local_password_matches(user, password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    if not admin_confirm_user_email(normalized):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    grant2 = supabase_password_grant(normalized, password)
    if not grant2.get("access_token"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )


def supabase_password_grant(email: str, password: str) -> dict[str, Any]:
    """Exchange email/password for a Supabase session (no emails sent)."""
    if not SUPABASE_URL or not _supabase_apikey():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase auth is not configured on the API",
        )
    body = json.dumps(
        {"email": email.strip().lower(), "password": password}
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
        data=body,
        headers={
            "apikey": _supabase_apikey(),
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8")
        try:
            return json.loads(raw) if raw else {"msg": str(exc.reason)}
        except json.JSONDecodeError:
            return {"msg": raw or str(exc.reason)}


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
    create_if_missing: bool = True,
) -> tuple[User, bool]:
    """Return (user, created). Raises 404 when missing and create_if_missing is False."""
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
        if not create_if_missing:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Profile not found",
            )
        user = User(
            first_name=first,
            last_name=last,
            email=email,
            password=hash_password(secrets.token_urlsafe(32)),
            picture=picture,
            ai_tour_completed=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user, True

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
    return user, False


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
    """Resolve the StreetSync profile for a token.

    The local users table is the source of truth. A bare Supabase Auth session
    (e.g. Google before terms) must NOT auto-create a profile row here.
    """
    token = credentials.credentials

    legacy = _user_from_legacy_jwt(token, db)
    if legacy is not None:
        return legacy

    sb_user = fetch_supabase_user(token)
    user, _created = upsert_user_from_supabase(
        db,
        sb_user,
        create_if_missing=False,
    )
    return user


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
