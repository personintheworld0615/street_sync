from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from api.schemas.auth import SignupRequest, LoginRequest, TokenResponse
from api.services.auth import hash_password, verify_password, create_access_token
from api.models.reports import User
from api.database import get_db

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/signup", response_model=TokenResponse)
def signup(body:SignupRequest, db:Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == body.email).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
    user = User(
        name=body.name,
        email=body.email,
        password=hash_password(body.password)
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    access_token = create_access_token(user.id)
    return TokenResponse(access_token=access_token, token_type="bearer", user_id=user.id, name=user.name
    )
@router.post("/login", response_model=TokenResponse)
def login(body:LoginRequest, db:Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email).first()
    if not user or not verify_password(body.password, user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    access_token = create_access_token(user.id)
    return TokenResponse(access_token=access_token, token_type="bearer", user_id=user.id, name=user.name
    )
