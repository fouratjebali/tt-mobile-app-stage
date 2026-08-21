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
    MicrosoftAuthRequest,
    UserResponse,
)
from app.services.auth_service import AuthService


router = APIRouter()


@router.post(
    "/google",
    response_model=AuthResponse,
    summary="Sign in with Google tokens",
    description=(
        "Receives Google Sign-In tokens from the Android app, verifies the "
        "Google ID token, upserts the user, creates a backend session and "
        "returns a Bearer session token."
    ),
)
def sign_in_with_google(
    request: GoogleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, session_token = AuthService(db).sign_in_with_google(request)
    return AuthResponse(session_token=session_token, user=_to_user_response(user))


@router.post(
    "/microsoft",
    response_model=AuthResponse,
    summary="Sign in with Microsoft tokens",
    description=(
        "Receives Microsoft OAuth tokens from the mobile app, verifies the "
        "access token with Microsoft Graph, upserts the user, creates a "
        "backend session and returns a Bearer session token."
    ),
)
def sign_in_with_microsoft(
    request: MicrosoftAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, session_token = AuthService(db).sign_in_with_microsoft(request)
    return AuthResponse(session_token=session_token, user=_to_user_response(user))


@router.get(
    "/gmail/url",
    response_model=GmailAuthUrlResponse,
    summary="Describe the Gmail OAuth entry point",
    description=(
        "Documents the OAuth entry point for the mobile flow. Android uses "
        "native Google Sign-In, so this endpoint explains where tokens must "
        "be submitted."
    ),
)
def gmail_auth_url() -> GmailAuthUrlResponse:
    return GmailAuthUrlResponse(
        flow="mobile_microsoft_sign_in",
        auth_url=None,
        message=(
            "Android uses Microsoft OAuth through AppAuth. Send the Microsoft "
            "tokens to POST /api/v1/auth/microsoft."
        ),
    )


@router.post(
    "/gmail/callback",
    response_model=AuthResponse,
    summary="Complete Gmail OAuth callback",
    description=(
        "Compatibility endpoint for the OAuth callback naming used in the "
        "Sprint 4 backlog. It accepts the same payload as /auth/google."
    ),
)
def gmail_callback(
    request: GoogleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, session_token = AuthService(db).sign_in_with_google(request)
    return AuthResponse(session_token=session_token, user=_to_user_response(user))


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user",
    description="Returns the authenticated user from the Bearer session token.",
)
def me(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return _to_user_response(user)


@router.get(
    "/session",
    response_model=UserResponse,
    summary="Validate current session",
    description="Validates the Bearer token and returns the session user.",
)
def session(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return _to_user_response(user)


@router.post(
    "/refresh",
    response_model=UserResponse,
    summary="Refresh current session",
    description=(
        "Validates the current backend session. A future iteration can extend "
        "this endpoint to rotate session tokens or refresh Google tokens."
    ),
)
def refresh_session(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return _to_user_response(user)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Logout current session",
    description="Deletes the backend session associated with the Bearer token.",
)
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
