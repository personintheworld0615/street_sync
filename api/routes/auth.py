import re

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from api.database import get_db
from api.models.reports import User
from api.schemas.auth import (
    LoginRequest,
    PictureResponse,
    SignupRequest,
    SyncRequest,
    TokenResponse,
)
from api.services.auth import (
    admin_confirm_user_email,
    admin_create_confirmed_user,
    admin_find_user_id_by_email,
    create_access_token,
    delete_supabase_user,
    ensure_email_confirmed_for_login,
    fetch_supabase_user,
    send_signup_confirmation_email,
    get_current_user,
    hash_password,
    is_supabase_user_id,
    security,
    supabase_password_grant,
    supabase_user_id_from_access_token,
    upsert_user_from_supabase,
)
from api.services.rate_limit import client_ip, hit
from api.services.reports import delete_account
from api.services.storage import MAX_IMAGE_BYTES, upload_user_picture

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_for(
    user: User,
    access_token: str | None = None,
    *,
    email_confirmation_required: bool = False,
    is_new_user: bool = False,
) -> TokenResponse:
    return TokenResponse(
        access_token=access_token or create_access_token(user.id),
        token_type="bearer",
        user_id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        picture=user.picture,
        email_confirmation_required=email_confirmation_required,
        is_new_user=is_new_user,
        ai_tour_completed=bool(getattr(user, "ai_tour_completed", False)),
    )


@router.post("/signup", response_model=TokenResponse)
def signup(body: SignupRequest, request: Request, db: Session = Depends(get_db)):
    """Create a Supabase user and email a confirmation link when mail can be sent."""
    hit("auth-signup", client_ip(request), limit=5, window_seconds=3600)
    email = str(body.email).strip().lower()
    password = body.password
    if not (
        re.search(r"[A-Z]", password)
        and re.search(r"[a-z]", password)
        and re.search(r"[0-9]", password)
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password needs an uppercase letter, a lowercase letter, and a number",
        )
    existing = db.query(User).filter(User.email == email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    try:
        admin_create_confirmed_user(
            email=email,
            password=body.password,
            first_name=body.first_name,
            last_name=body.last_name,
            email_confirm=False,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not create auth user",
        ) from exc

    user = User(
        first_name=body.first_name,
        last_name=body.last_name,
        email=email,
        password=hash_password(body.password),
        ai_tour_completed=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    sent = send_signup_confirmation_email(email)
    if not sent:
        # Mail is not configured. Confirm the account so signup is not a dead end.
        admin_confirm_user_email(email)
    return _token_for(user, email_confirmation_required=sent, is_new_user=True)


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Sign in via Supabase and sync the local profile row on success."""
    ip = client_ip(request)
    email = str(body.email).strip().lower()
    hit("auth-login-ip", ip, limit=10, window_seconds=900)
    hit("auth-login-email", email, limit=8, window_seconds=900)

    grant = supabase_password_grant(email, body.password)
    access_token = grant.get("access_token")
    if not access_token:
        error = str(grant.get("error") or grant.get("error_code") or "").lower()
        detail = str(
            grant.get("msg")
            or grant.get("error_description")
            or grant.get("message")
            or "Invalid credentials"
        )
        if "email_not_confirmed" in error or "email not confirmed" in detail.lower():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Please confirm your email before signing in.",
            )
        if "rate limit" in detail.lower() or "rate_limit" in error or "too many" in detail.lower():
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests. Try again in a little while.",
            )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    sb_user = fetch_supabase_user(access_token)
    user, created = upsert_user_from_supabase(db, sb_user)
    return _token_for(user, access_token=access_token, is_new_user=created)


@router.post("/ensure-confirmed")
def ensure_confirmed(
    body: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Confirm the user's email in Supabase when login is blocked because the
    address is unconfirmed. Requires the local password hash to match.
    Rate-limit errors do not confirm the account.
    """
    ip = client_ip(request)
    email = str(body.email).strip().lower()
    hit("auth-confirm-ip", ip, limit=5, window_seconds=900)
    hit("auth-confirm-email", email, limit=5, window_seconds=900)
    ensure_email_confirmed_for_login(email, body.password, db)
    return {"ok": True}


@router.post("/sync", response_model=TokenResponse)
def sync_supabase_user(
    body: SyncRequest,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """Upsert the local user from a Supabase access token and return profile."""
    token = credentials.credentials
    sb_user = fetch_supabase_user(token)
    user, created = upsert_user_from_supabase(
        db,
        sb_user,
        first_name=body.first_name,
        last_name=body.last_name,
        create_if_missing=body.create_if_missing,
    )
    return _token_for(user, access_token=token, is_new_user=created)


@router.post("/tour-complete", response_model=TokenResponse)
def complete_ai_tour(
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    current_user: User = Depends(get_current_user),
):
    """Mark the home AI tour as finished or skipped."""
    if not current_user.ai_tour_completed:
        current_user.ai_tour_completed = True
        db.add(current_user)
        db.commit()
        db.refresh(current_user)
    return _token_for(current_user, access_token=credentials.credentials)


@router.get("/me", response_model=TokenResponse)
def me(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    current_user: User = Depends(get_current_user),
):
    return _token_for(current_user, access_token=credentials.credentials)


@router.post("/picture", response_model=PictureResponse)
async def upload_picture(
    request: Request,
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a profile photo to Supabase Storage; store public URL on the user."""
    hit("auth-picture", str(current_user.id), limit=20, window_seconds=3600)
    data = await image.read(MAX_IMAGE_BYTES + 1)
    if not data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty image upload",
        )
    picture_url = upload_user_picture(
        user_id=current_user.id,
        data=data,
        content_type=image.content_type or "image/jpeg",
        filename=image.filename,
    )
    current_user.picture = picture_url
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return PictureResponse(picture=picture_url)


@router.delete("/delete", response_model=dict)
@router.delete("/delete/{user_id}", response_model=dict)
def delete_account_route(
    user_id: int | None = None,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
    current_user: User = Depends(get_current_user),
):
    if user_id is not None and user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not allowed to delete another user's account",
        )

    token = credentials.credentials
    supabase_uid: str | None = None
    try:
        sb_user = fetch_supabase_user(token)
        raw_id = sb_user.get("id")
        if isinstance(raw_id, str) and is_supabase_user_id(raw_id):
            supabase_uid = raw_id
    except HTTPException:
        supabase_uid = None

    if not supabase_uid:
        decoded = supabase_user_id_from_access_token(token)
        if is_supabase_user_id(decoded):
            supabase_uid = decoded

    if not supabase_uid and current_user.email:
        supabase_uid = admin_find_user_id_by_email(current_user.email)

    # Auth goes first. A failed Auth delete leaves the profile in place.
    if supabase_uid and not delete_supabase_user(supabase_uid):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=(
                "Could not delete the sign-in account. "
                "Your profile was not removed."
            ),
        )

    try:
        result = delete_account(db, current_user.id)
    except HTTPException as exc:
        if exc.status_code != status.HTTP_404_NOT_FOUND:
            raise
        result = {"message": "Account deleted successfully"}
    result["supabase_auth_deleted"] = True
    return result
