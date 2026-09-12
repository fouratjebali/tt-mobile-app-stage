import json
from time import perf_counter
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_admin_manager, get_current_admin_user
from app.core.config import settings
from app.db.session import get_db
from app.models.app_settings import AppSettings
from app.models.auth import User
from app.repositories.admin_dashboard_repository import AdminDashboardRepository
from app.repositories.audit_repository import AuditRepository, audit_metadata
from app.repositories.auth_repository import AuthRepository
from app.schemas.audit import AuditLogResponse, AuditLogsResponse
from app.schemas.admin import (
    AdminOverviewResponse,
    AdminOverviewSystem,
    AdminUserResponse,
    AdminUsersResponse,
    UpdateAdminUserActiveRequest,
    UpdateAdminUserRoleRequest,
)


router = APIRouter()

DASHBOARD_SETTINGS_DEFAULTS: dict[str, Any] = {
    "review_threshold": 40,
    "audit_retention_days": 180,
    "support_email": "dashboard.admin@tunisietelecom.tn",
}


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
    "/overview",
    response_model=AdminOverviewResponse,
    summary="Get admin dashboard overview",
    description="Returns top-level users, email workflow and notification counters.",
)
def admin_overview(
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
) -> AdminOverviewResponse:
    payload = AdminDashboardRepository(db).overview()
    return AdminOverviewResponse(
        generated_at=datetime.now(tz=UTC),
        users=payload["users"],
        email=payload["email"],
        notifications=payload["notifications"],
        training=payload["training"],
        system=AdminOverviewSystem(
            api_prefix=settings.API_V1_PREFIX,
            admin_api_prefix=settings.ADMIN_API_PREFIX,
            admin_base_path=f"{settings.API_V1_PREFIX}{settings.ADMIN_API_PREFIX}",
        ),
    )


@router.get(
    "/health",
    summary="Get admin dashboard health",
    description="Returns a dashboard-friendly health summary for Angular.",
)
def admin_health(
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, Any]:
    started_at = perf_counter()
    services: list[dict[str, str]] = [
        {
            "name": "Backend API",
            "status": "healthy",
            "message": "Operational",
        }
    ]

    try:
        db.execute(text("SELECT 1"))
        database_status = "healthy"
        database_message = "Connected"
    except Exception as exc:
        database_status = "down"
        database_message = str(exc)
    services.append(
        {
            "name": "Database",
            "status": database_status,
            "message": database_message,
        }
    )

    mail_connector_status = "healthy" if settings.AGENT1_URL else "degraded"
    services.append(
        {
            "name": "Mail connector",
            "status": mail_connector_status,
            "message": "Operational" if settings.AGENT1_URL else "Not configured",
        }
    )

    try:
        db.execute(text("SELECT COUNT(*) FROM audit_logs"))
        audit_status = "healthy"
        audit_message = "Writing events"
    except Exception as exc:
        audit_status = "degraded"
        audit_message = str(exc)
    services.append(
        {
            "name": "Audit stream",
            "status": audit_status,
            "message": audit_message,
        }
    )

    status_value = (
        "healthy"
        if all(service["status"] == "healthy" for service in services)
        else "degraded"
    )
    return {
        "status": status_value,
        "checked_at": datetime.now(tz=UTC).isoformat(),
        "latency_ms": round((perf_counter() - started_at) * 1000, 2),
        "services": services,
    }


@router.get(
    "/settings",
    summary="Get admin dashboard settings",
    description="Returns dashboard policy settings used by the admin frontend.",
)
def get_admin_settings(
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, Any]:
    return {
        "status": "ok",
        "settings": _load_dashboard_settings(db),
    }


@router.patch(
    "/settings",
    summary="Update admin dashboard settings",
    description="Updates dashboard policy settings used by the admin frontend.",
)
def update_admin_settings(
    payload: dict[str, Any],
    current_user: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, Any]:
    current = _load_dashboard_settings(db)
    allowed_updates = {
        key: payload[key]
        for key in DASHBOARD_SETTINGS_DEFAULTS
        if key in payload
    }
    updated = {**current, **allowed_updates}
    _save_dashboard_settings(db, updated)
    AuditRepository(db).create(
        actor=current_user,
        action="admin.settings.update",
        resource_type="settings",
        resource_id="dashboard",
        metadata={"updated": allowed_updates},
    )
    return {
        "status": "ok",
        "settings": updated,
    }


@router.get(
    "/audit-logs",
    response_model=AuditLogsResponse,
    summary="List audit logs",
    description="Lists admin dashboard actions for compliance and troubleshooting.",
)
def list_audit_logs(
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
    actor_email: str | None = Query(default=None, min_length=1),
    action: str | None = Query(default=None, min_length=1),
    resource_type: str | None = Query(default=None, min_length=1),
    resource_id: str | None = Query(default=None, min_length=1),
    status: str | None = Query(default=None, min_length=1),
    search: str | None = Query(default=None, min_length=1),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> AuditLogsResponse:
    logs, total = AuditRepository(db).list(
        actor_email=actor_email,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        status=status,
        search=search,
        date_from=date_from,
        date_to=date_to,
        limit=limit,
        offset=offset,
    )
    return AuditLogsResponse(
        logs=[_to_audit_log_response(log) for log in logs],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/audit-logs/{log_id}",
    response_model=AuditLogResponse,
    summary="Get audit log",
    description="Returns one audit log entry.",
)
def get_audit_log(
    log_id: str,
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
) -> AuditLogResponse:
    log = AuditRepository(db).get(log_id)
    if log is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audit log not found.",
        )
    return _to_audit_log_response(log)


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

    repository = AuthRepository(db)
    target_user = repository.get_user_by_id(user_id)
    previous_role = target_user.role if target_user is not None else ""
    user = repository.update_user_role(user_id=user_id, role=request.role)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    AuditRepository(db).create(
        actor=admin_user,
        action="admin.user.role.update",
        resource_type="user",
        resource_id=user.id,
        metadata={
            "target_email": user.email,
            "previous_role": previous_role,
            "new_role": user.role,
        },
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

    repository = AuthRepository(db)
    target_user = repository.get_user_by_id(user_id)
    previous_active = target_user.is_active if target_user is not None else None
    user = repository.update_user_active_state(
        user_id=user_id,
        is_active=request.is_active,
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    AuditRepository(db).create(
        actor=admin_user,
        action="admin.user.active.update",
        resource_type="user",
        resource_id=user.id,
        metadata={
            "target_email": user.email,
            "previous_active": previous_active,
            "new_active": user.is_active,
        },
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


def _to_audit_log_response(log) -> AuditLogResponse:
    return AuditLogResponse(
        id=log.id,
        actor_user_id=log.actor_user_id,
        actor_email=log.actor_email,
        actor_role=log.actor_role,
        action=log.action,
        resource_type=log.resource_type,
        resource_id=log.resource_id,
        status=log.status,
        metadata=audit_metadata(log),
        created_at=log.created_at,
    )


def _load_dashboard_settings(db: Session) -> dict[str, Any]:
    row = (
        db.query(AppSettings)
        .filter(AppSettings.key == "admin_dashboard")
        .one_or_none()
    )
    if row is None or not row.value:
        return {
            **DASHBOARD_SETTINGS_DEFAULTS,
            "support_email": (
                settings.ADMIN_DASHBOARD_EMAIL
                or DASHBOARD_SETTINGS_DEFAULTS["support_email"]
            ),
        }
    try:
        stored = json.loads(row.value)
    except json.JSONDecodeError:
        stored = {}
    return {
        **DASHBOARD_SETTINGS_DEFAULTS,
        "support_email": (
            settings.ADMIN_DASHBOARD_EMAIL
            or DASHBOARD_SETTINGS_DEFAULTS["support_email"]
        ),
        **{
            key: value
            for key, value in stored.items()
            if key in DASHBOARD_SETTINGS_DEFAULTS
        },
    }


def _save_dashboard_settings(db: Session, payload: dict[str, Any]) -> None:
    row = (
        db.query(AppSettings)
        .filter(AppSettings.key == "admin_dashboard")
        .one_or_none()
    )
    if row is None:
        row = AppSettings(key="admin_dashboard", value="{}")
        db.add(row)
    row.value = json.dumps(payload)
    row.is_active = True
    db.commit()
