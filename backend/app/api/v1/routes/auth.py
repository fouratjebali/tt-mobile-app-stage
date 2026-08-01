from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_bearer_token, get_current_user
from app.db.session import get_db
from app.models.auth import User
from app.schemas.auth import (
    AuthResponse,
    GmailAuthUrlResponse,
    GoogleAuthRequest,
    UserResponse,
)
from app.services.auth_service import AuthService


router = APIRouter()


@router.post("/google", response_model=AuthResponse)
def sign_in_with_google(
    request: GoogleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, session_token = AuthService(db).sign_in_with_google(request)
    return AuthResponse(session_token=session_token, user=_to_user_response(user))


@router.get("/gmail/url", response_model=GmailAuthUrlResponse)
def gmail_auth_url() -> GmailAuthUrlResponse:
    return GmailAuthUrlResponse(
        flow="mobile_google_sign_in",
        auth_url=None,
        message=(
            "Android uses native Google Sign-In. Send the Google tokens to "
            "POST /api/v1/auth/google or /api/v1/auth/gmail/callback."
        ),
    )


@router.post("/gmail/callback", response_model=AuthResponse)
def gmail_callback(
    request: GoogleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, session_token = AuthService(db).sign_in_with_google(request)
    return AuthResponse(session_token=session_token, user=_to_user_response(user))


@router.get("/me", response_model=UserResponse)
def me(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return _to_user_response(user)


@router.get("/session", response_model=UserResponse)
def session(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return _to_user_response(user)


@router.post("/refresh", response_model=UserResponse)
def refresh_session(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return _to_user_response(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    response: Response,
    token: Annotated[str, Depends(get_bearer_token)],
    _: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db),
) -> Response:
    AuthService(db).logout(token)
    return response


def _to_user_response(user) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        photo_url=user.photo_url,
    )
