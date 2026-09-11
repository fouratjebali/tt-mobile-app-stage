from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.auth import User, UserRole
from app.services.auth_service import AuthService


ADMIN_PORTAL_ROLES = {
    UserRole.ADMIN.value,
    UserRole.REVIEWER.value,
    UserRole.VIEWER.value,
}
ADMIN_MANAGER_ROLES = {UserRole.ADMIN.value}
ADMIN_PLANNING_EDITOR_ROLES = {
    UserRole.ADMIN.value,
    UserRole.REVIEWER.value,
}


def get_bearer_token(authorization: Annotated[str, Header()] = "") -> str:
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return token


def get_current_user(
    token: Annotated[str, Depends(get_bearer_token)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    return AuthService(db).get_current_user(token)


def get_current_admin_user(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    if _normalized_role(user) not in ADMIN_PORTAL_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin dashboard access is not enabled for this account.",
        )
    return user


def get_current_admin_manager(
    user: Annotated[User, Depends(get_current_admin_user)],
) -> User:
    if _normalized_role(user) not in ADMIN_MANAGER_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator role is required.",
        )
    return user


def get_current_admin_planning_editor(
    user: Annotated[User, Depends(get_current_admin_user)],
) -> User:
    if _normalized_role(user) not in ADMIN_PLANNING_EDITOR_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Planning reviewer or administrator role is required.",
        )
    return user


def _normalized_role(user: User) -> str:
    return str(user.role or UserRole.USER.value).strip().lower()
