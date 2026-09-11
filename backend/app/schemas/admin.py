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


class AdminOverviewUsers(BaseModel):
    total: int = 0
    active: int = 0
    inactive: int = 0
    admins: int = 0
    reviewers: int = 0
    viewers: int = 0
    regular_users: int = 0


class AdminOverviewEmail(BaseModel):
    total: int = 0
    unread: int = 0
    awaiting_review: int = 0
    urgent: int = 0
    analysed: int = 0
    pending: int = 0
    ignored: int = 0
    sent_replies: int = 0
    received_today: int = 0
    received_last_7_days: int = 0


class AdminOverviewNotifications(BaseModel):
    total: int = 0
    unread: int = 0


class AdminOverviewTraining(BaseModel):
    available: bool = False
    source: str = "planning-service"
    message: str | None = None
    total_sessions: int | None = None
    total_participants: int | None = None
    drafts_waiting_review: int | None = None
    missing_responsibles: int | None = None
    sent_drafts: int | None = None


class AdminOverviewSystem(BaseModel):
    api_prefix: str
    admin_api_prefix: str
    admin_base_path: str


class AdminOverviewResponse(BaseModel):
    generated_at: datetime
    users: AdminOverviewUsers
    email: AdminOverviewEmail
    notifications: AdminOverviewNotifications
    training: AdminOverviewTraining
    system: AdminOverviewSystem


class UpdateAdminUserRoleRequest(BaseModel):
    role: UserRole = Field(
        description="New user role. Use admin, reviewer, viewer, or user."
    )


class UpdateAdminUserActiveRequest(BaseModel):
    is_active: bool = Field(description="Whether this user can access the app.")
