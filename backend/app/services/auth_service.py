from base64 import b64encode
from datetime import UTC, datetime
from hashlib import sha256
from secrets import token_urlsafe

from fastapi import HTTPException, status
from google.auth.transport import requests
from google.oauth2 import id_token
import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.auth import User
from app.repositories.auth_repository import AuthRepository
from app.schemas.auth import GoogleAuthRequest, MicrosoftAuthRequest


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

    def sign_in_with_microsoft(
        self,
        request: MicrosoftAuthRequest,
    ) -> tuple[User, str]:
        profile = self._fetch_microsoft_profile(request.access_token)
        microsoft_id = str(profile.get("id") or "").strip()
        email = str(
            profile.get("mail") or profile.get("userPrincipalName") or ""
        ).strip()
        if not microsoft_id or not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Microsoft profile is incomplete.",
            )

        existing_user = self._repository.get_user_by_email(email)
        should_reset_mailbox_cache = existing_user is not None
        user = self._repository.upsert_user(
            google_sub=f"microsoft:{microsoft_id}",
            email=email,
            display_name=profile.get("displayName"),
            photo_url=self._fetch_microsoft_photo_data_uri(request.access_token),
        )
        if should_reset_mailbox_cache:
            self._repository.clear_mailbox_cache(user)

        session_token = token_urlsafe(48)
        self._repository.delete_sessions_for_user(user)
        self._repository.create_session(
            user=user,
            session_token_hash=self._hash_token(session_token),
            google_access_token=request.access_token,
            google_id_token=request.id_token,
            google_refresh_token=request.refresh_token,
            expires_at=request.expires_at,
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
        if not _is_microsoft_user(user):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Please connect your Outlook account.",
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

    def _fetch_microsoft_profile(self, access_token: str) -> dict[str, object]:
        if not access_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Missing Microsoft access token.",
            )

        try:
            with httpx.Client(timeout=settings.HEALTHCHECK_TIMEOUT_SECONDS) as client:
                response = client.get(
                    "https://graph.microsoft.com/v1.0/me",
                    params={
                        "$select": "id,displayName,mail,userPrincipalName",
                    },
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Microsoft sign-in token is invalid or expired.",
            ) from error
        except httpx.HTTPError as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Microsoft sign-in is temporarily unavailable.",
            ) from error

        profile = response.json()
        if not isinstance(profile, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Microsoft returned an invalid profile response.",
            )
        return profile

    def _fetch_microsoft_photo_data_uri(self, access_token: str) -> str | None:
        try:
            with httpx.Client(timeout=settings.HEALTHCHECK_TIMEOUT_SECONDS) as client:
                response = client.get(
                    "https://graph.microsoft.com/v1.0/me/photo/$value",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                if response.status_code == status.HTTP_404_NOT_FOUND:
                    return None
                response.raise_for_status()
        except httpx.HTTPError:
            return None

        content_type = response.headers.get("content-type", "image/jpeg")
        encoded = b64encode(response.content).decode("ascii")
        return f"data:{content_type};base64,{encoded}"

    def _hash_token(self, token: str) -> str:
        return sha256(token.encode("utf-8")).hexdigest()

    def _parse_expiry(self, expiry: object) -> datetime | None:
        if not isinstance(expiry, int):
            return None

        return datetime.fromtimestamp(expiry, tz=UTC)


def _is_microsoft_user(user: User) -> bool:
    return str(user.google_sub or "").startswith("microsoft:")
