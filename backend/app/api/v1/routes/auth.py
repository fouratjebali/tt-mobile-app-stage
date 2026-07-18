from fastapi import APIRouter, Depends, Header, Response, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.auth import AuthResponse, GoogleAuthRequest, UserResponse
from app.services.auth_service import AuthService


router = APIRouter()


@router.post("/google", response_model=AuthResponse)
def sign_in_with_google(
    request: GoogleAuthRequest,
    db: Session = Depends(get_db),
) -> AuthResponse:
    user, session_token = AuthService(db).sign_in_with_google(request)
    return AuthResponse(session_token=session_token, user=_to_user_response(user))


@router.get("/me", response_model=UserResponse)
def me(
    authorization: str = Header(default=""),
    db: Session = Depends(get_db),
) -> UserResponse:
    user = AuthService(db).get_current_user(_extract_bearer_token(authorization))
    return _to_user_response(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    response: Response,
    authorization: str = Header(default=""),
    db: Session = Depends(get_db),
) -> Response:
    AuthService(db).logout(_extract_bearer_token(authorization))
    return response


def _extract_bearer_token(authorization: str) -> str:
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return ""

    return token


def _to_user_response(user) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        photo_url=user.photo_url,
    )
