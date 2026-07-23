from datetime import datetime, timedelta, timezone

from jose import jwt

from passlib.context import CryptContext

SECRET_KEY = "change-me-to-a-real-secret"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 7

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(plain:str)->str:
    return pwd_context.hash(plain)
def verify_password(plain:str, hashed:str)->bool:
    return pwd_context.verify(plain, hashed)
def create_access_token(user_id: int)->str:
    expire = datetime.now(timezone.utc) + timedelta(hours=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
