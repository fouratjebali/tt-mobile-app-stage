from datetime import datetime

from pydantic import BaseModel, Field

from app.models.auth import UserRole


class AdminUserResponse(BaseModel):
    id: str
    email: str
    display_name: str | None = None
    photo_url: str | None = None
    role: str = UserRole.USER.value
    is_active: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None


class AdminUsersResponse(BaseModel):
    users: list[AdminUserResponse]
    total: int
    limit: int
    offset: int


class UpdateAdminUserRoleRequest(BaseModel):
    role: UserRole = Field(
        description="New user role. Use admin, reviewer, viewer, or user."
    )


class UpdateAdminUserActiveRequest(BaseModel):
    is_active: bool = Field(description="Whether this user can access the app.")
