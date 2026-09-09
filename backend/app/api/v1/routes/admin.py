from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_admin_manager, get_current_admin_user
from app.db.session import get_db
from app.models.auth import User
from app.repositories.auth_repository import AuthRepository
from app.schemas.admin import (
    AdminUserResponse,
    AdminUsersResponse,
    UpdateAdminUserActiveRequest,
    UpdateAdminUserRoleRequest,
)


router = APIRouter()


@router.get(
    "/me",
    response_model=AdminUserResponse,
    summary="Get current admin user",
    description="Validates dashboard access and returns the current admin identity.",
)
def admin_me(
    user: Annotated[User, Depends(get_current_admin_user)],
) -> AdminUserResponse:
    return _to_admin_user_response(user)


@router.get(
    "/users",
    response_model=AdminUsersResponse,
    summary="List users",
    description="Lists mobile/backend users for dashboard administration.",
)
def list_users(
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
    search: str | None = Query(default=None, min_length=1),
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminUsersResponse:
    users, total = AuthRepository(db).list_users(
        search=search,
        limit=limit,
        offset=offset,
    )
    return AdminUsersResponse(
        users=[_to_admin_user_response(user) for user in users],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.patch(
    "/users/{user_id}/role",
    response_model=AdminUserResponse,
    summary="Update user role",
    description="Updates a user's role for dashboard access control.",
)
def update_user_role(
    user_id: str,
    request: UpdateAdminUserRoleRequest,
    admin_user: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
) -> AdminUserResponse:
    if user_id == admin_user.id and request.role.value != "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot remove your own administrator role.",
        )

    user = AuthRepository(db).update_user_role(user_id=user_id, role=request.role)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    return _to_admin_user_response(user)


@router.patch(
    "/users/{user_id}/active",
    response_model=AdminUserResponse,
    summary="Enable or disable a user",
    description="Controls whether a user can authenticate with the app/dashboard.",
)
def update_user_active_state(
    user_id: str,
    request: UpdateAdminUserActiveRequest,
    admin_user: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
) -> AdminUserResponse:
    if user_id == admin_user.id and not request.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot disable your own administrator account.",
        )

    user = AuthRepository(db).update_user_active_state(
        user_id=user_id,
        is_active=request.is_active,
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    return _to_admin_user_response(user)


def _to_admin_user_response(user: User) -> AdminUserResponse:
    return AdminUserResponse(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        photo_url=user.photo_url,
        role=user.role,
        is_active=user.is_active,
        created_at=user.created_at,
        updated_at=user.updated_at,
    )
