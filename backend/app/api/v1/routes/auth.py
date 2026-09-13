from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_bearer_token, get_current_user
from app.db.session import get_db
from app.models.auth import User
from app.repositories.audit_repository import AuditRepository
from app.schemas.auth import (
    AdminLoginRequest,
    AuthResponse,
    GmailAuthUrlResponse,
    MicrosoftAuthRequest,
    UserResponse,
)
from app.services.auth_service import AuthService


router = APIRouter()


@router.post(
    "/google",
    response_model=AuthResponse,
    summary="Legacy Google sign-in",
    description=(
        "Legacy endpoint kept for compatibility. Google/Gmail login is "
        "disabled while the app uses Microsoft Outlook."
    ),
)
def sign_in_with_google() -> AuthResponse:
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Google/Gmail login is disabled. Please connect with Outlook.",
    )


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


@router.post(
    "/admin/login",
    response_model=AuthResponse,
    summary="Admin username and password login",
    description="Authenticates a preset dashboard admin stored in the database.",
)
def sign_in_with_admin_credentials(
    request: AdminLoginRequest,
    http_request: Request,
    db: Session = Depends(get_db),
) -> AuthResponse:
    try:
        user, session_token = AuthService(db).sign_in_with_admin_credentials(request)
    except HTTPException:
        AuditRepository(db).create(
            actor=None,
            action="admin.auth.login.failure",
            resource_type="auth",
            status="failed",
            summary="Failed admin dashboard login",
            metadata={"username": request.username},
            **_request_audit_context(http_request),
        )
        raise
    AuditRepository(db).create(
        actor=user,
        action="admin.auth.login.success",
        resource_type="auth",
        resource_id=user.id,
        summary="Admin dashboard login",
        metadata={"username": request.username},
        **_request_audit_context(http_request),
    )
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
        "Legacy Gmail callback. Gmail login is disabled while the app uses "
        "Microsoft Outlook."
    ),
)
def gmail_callback() -> AuthResponse:
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Google/Gmail login is disabled. Please connect with Outlook.",
    )


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
        "this endpoint to rotate session tokens or refresh Microsoft tokens."
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
    user: Annotated[User, Depends(get_current_user)],
    request: Request,
    db: Session = Depends(get_db),
) -> Response:
    AuthService(db).logout(token)
    AuditRepository(db).create(
        actor=user,
        action="admin.auth.logout",
        resource_type="auth",
        resource_id=user.id,
        summary="Admin dashboard logout",
        **_request_audit_context(request),
    )
    return response


def _to_user_response(user) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        photo_url=user.photo_url,
        role=user.role,
        is_active=user.is_active,
    )


def _request_audit_context(request: Request) -> dict[str, str]:
    return {
        "ip_address": request.client.host if request.client else "",
        "user_agent": request.headers.get("user-agent", ""),
        "request_method": request.method,
        "request_path": str(request.url.path),
    }
