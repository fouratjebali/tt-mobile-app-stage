from datetime import datetime

from pydantic import BaseModel


class GoogleAuthRequest(BaseModel):
    access_token: str = "google-access-token"
    id_token: str | None = "google-id-token"
    refresh_token: str | None = None


class UserResponse(BaseModel):
    id: str = "user-id"
    email: str = "user@example.com"
    display_name: str | None = None
    photo_url: str | None = None


class AuthResponse(BaseModel):
    session_token: str = "backend-session-token"
    token_type: str = "Bearer"
    expires_at: datetime | None = None
    user: UserResponse


class GmailAuthUrlResponse(BaseModel):
    flow: str
    auth_url: str | None = None
    message: str
