class SignupRequest(BaseModel):
    name: str = Field(min_length=1,max_length=100)
    email: EmailStr
    password: str = Field(min_length=8,max_length=100)
class LoginRequest(BaseModel):
    email: EmailStr
    password: str
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    name: str
