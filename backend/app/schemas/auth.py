from datetime import datetime

from pydantic import BaseModel


class GoogleAuthRequest(BaseModel):
    access_token: str
    id_token: str | None = None
    refresh_token: str | None = None


class UserResponse(BaseModel):
    id: str
    email: str
    display_name: str | None = None
    photo_url: str | None = None


class AuthResponse(BaseModel):
    session_token: str
    token_type: str = "Bearer"
    expires_at: datetime | None = None
    user: UserResponse
