from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
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
    create_access_token,
    delete_supabase_user,
    fetch_supabase_user,
    get_current_user,
    hash_password,
    security,
    upsert_user_from_supabase,
    verify_password,
)
from api.services.reports import delete_account
from api.services.storage import upload_user_picture

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_for(user: User, access_token: str | None = None) -> TokenResponse:
    return TokenResponse(
        access_token=access_token or create_access_token(user.id),
        token_type="bearer",
        user_id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        picture=user.picture,
    )


@router.post("/signup", response_model=TokenResponse)
def signup(body: SignupRequest, db: Session = Depends(get_db)):
    """Legacy email/password signup (kept for older clients)."""
    existing = db.query(User).filter(User.email == body.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    user = User(
        first_name=body.first_name,
        last_name=body.last_name,
        email=body.email,
        password=hash_password(body.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _token_for(user)


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """Legacy email/password login (kept for older clients)."""
    user = db.query(User).filter(User.email == body.email).first()
    if not user or not verify_password(body.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
    return _token_for(user)


@router.post("/sync", response_model=TokenResponse)
def sync_supabase_user(
    body: SyncRequest,
    db: Session = Depends(get_db),
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """Upsert the local user from a Supabase access token and return profile."""
    token = credentials.credentials
    sb_user = fetch_supabase_user(token)
    user = upsert_user_from_supabase(
        db,
        sb_user,
        first_name=body.first_name,
        last_name=body.last_name,
    )
    return _token_for(user, access_token=token)


@router.get("/me", response_model=TokenResponse)
def me(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    current_user: User = Depends(get_current_user),
):
    return _token_for(current_user, access_token=credentials.credentials)


@router.post("/picture", response_model=PictureResponse)
async def upload_picture(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a profile photo to Supabase Storage; store public URL on the user."""
    data = await image.read()
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

    supabase_uid = None
    try:
        sb_user = fetch_supabase_user(credentials.credentials)
        supabase_uid = sb_user.get("id")
    except HTTPException:
        supabase_uid = None

    result = delete_account(db, current_user.id)
    if isinstance(supabase_uid, str):
        delete_supabase_user(supabase_uid)
    return result
