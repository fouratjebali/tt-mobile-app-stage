from datetime import UTC, datetime
from hashlib import sha256
from secrets import token_urlsafe

from fastapi import HTTPException, status
from google.auth.transport import requests
from google.oauth2 import id_token
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.auth import User
from app.repositories.auth_repository import AuthRepository
from app.schemas.auth import GoogleAuthRequest


class AuthService:
    def __init__(self, db: Session) -> None:
        self._repository = AuthRepository(db)

    def sign_in_with_google(self, request: GoogleAuthRequest) -> tuple[User, str]:
        profile = self._verify_google_id_token(request.id_token)
        user = self._repository.upsert_user(
            google_sub=profile["sub"],
            email=profile["email"],
            display_name=profile.get("name"),
            photo_url=profile.get("picture"),
        )

        session_token = token_urlsafe(48)
        self._repository.create_session(
            user=user,
            session_token_hash=self._hash_token(session_token),
            google_access_token=request.access_token,
            google_id_token=request.id_token,
            google_refresh_token=request.refresh_token,
            expires_at=self._parse_expiry(profile.get("exp")),
        )
        return user, session_token

    def get_current_user(self, session_token: str) -> User:
        user = self._repository.get_user_by_session_hash(
            self._hash_token(session_token)
        )
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired session.",
            )
        return user

    def logout(self, session_token: str) -> None:
        self._repository.delete_session(self._hash_token(session_token))

    def _verify_google_id_token(self, token: str | None) -> dict[str, object]:
        if not token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing Google ID token.",
            )

        audience = (
            settings.GOOGLE_OAUTH_CLIENT_ID
            or settings.GOOGLE_OAUTH_SERVER_CLIENT_ID
            or None
        )

        try:
            profile = id_token.verify_oauth2_token(
                token,
                requests.Request(),
                audience=audience,
            )
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google ID token.",
            ) from error

        if profile.get("email_verified") is False:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Google email is not verified.",
            )

        if not profile.get("sub") or not profile.get("email"):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google profile is incomplete.",
            )

        return profile

    def _hash_token(self, token: str) -> str:
        return sha256(token.encode("utf-8")).hexdigest()

    def _parse_expiry(self, expiry: object) -> datetime | None:
        if not isinstance(expiry, int):
            return None

        return datetime.fromtimestamp(expiry, tz=UTC)
