import json
from time import perf_counter
from datetime import UTC, datetime
from typing import Annotated, Any
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import desc, func, or_, select, text
from sqlalchemy.orm import Session

from app.api.dependencies import (
    get_current_admin_manager,
    get_current_admin_user,
    get_current_super_admin,
)
from app.core.config import settings
from app.db.session import get_db
from app.models.app_settings import AppSettings
from app.models.audit import AuditLog
from app.models.auth import AdminCredential, User, UserRole
from app.repositories.admin_dashboard_repository import AdminDashboardRepository
from app.repositories.audit_repository import AuditRepository, audit_metadata
from app.repositories.auth_repository import AuthRepository
from app.schemas.audit import AuditLogResponse, AuditLogsResponse
from app.schemas.admin import (
    AdminOverviewResponse,
    AdminOverviewSystem,
    AdminUserResponse,
    AdminUsersResponse,
    CreateDashboardAdminRequest,
    DashboardAdminResponse,
    DashboardAdminsResponse,
    UpdateDashboardAdminActiveRequest,
    UpdateDashboardAdminPasswordRequest,
    UpdateDashboardAdminRequest,
    UpdateAdminUserActiveRequest,
    UpdateAdminUserRoleRequest,
)
from app.services.planning_management_gateway import (
    PlanningManagementGateway,
    get_planning_management_gateway,
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
    current_user: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
    request: Request,
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
    payload = {
        "status": status_value,
        "checked_at": datetime.now(tz=UTC).isoformat(),
        "latency_ms": round((perf_counter() - started_at) * 1000, 2),
        "services": services,
    }
    AuditRepository(db).create(
        actor=current_user,
        action="admin.health.check",
        resource_type="health",
        status="success" if status_value == "healthy" else "failed",
        summary="Checked admin dashboard health",
        metadata={"health_status": status_value, "services": services},
        **_request_audit_context(request),
    )
    return payload


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
    return _update_dashboard_policy_settings(db, current_user, payload)


@router.get(
    "/settings/system",
    summary="Get supervised system settings",
    description=(
        "Returns read-only operational settings that the admin dashboard can display "
        "without exposing secrets."
    ),
)
def get_admin_system_settings(
    _: Annotated[User, Depends(get_current_admin_user)],
) -> dict[str, Any]:
    return {
        "status": "ok",
        "settings": _system_supervision_settings(),
    }


@router.get(
    "/settings/supervision",
    summary="Get admin settings page payload",
    description=(
        "Returns dashboard policy, automation and read-only system settings for the "
        "admin settings page."
    ),
)
async def get_admin_settings_supervision(
    _: Annotated[User, Depends(get_current_admin_user)],
    db: Annotated[Session, Depends(get_db)],
    gateway: Annotated[
        PlanningManagementGateway,
        Depends(get_planning_management_gateway),
    ],
) -> dict[str, Any]:
    dashboard_policy = _load_dashboard_settings(db)
    planning_automation = await _load_planning_automation_settings(gateway)
    system_payload = _system_supervision_settings()

    return {
        "status": "ok",
        "generated_at": datetime.now(tz=UTC).isoformat(),
        "settings": {
            "dashboard_policy": dashboard_policy,
            "planning_automation": planning_automation,
            "system": system_payload,
        },
        "sections": [
            {
                "key": "dashboard_policy",
                "title": "Dashboard policy",
                "editable": True,
                "endpoint": (
                    f"{settings.API_V1_PREFIX}"
                    f"{settings.ADMIN_API_PREFIX}/settings/policies"
                ),
                "settings": dashboard_policy,
                "controls": [
                    {
                        "key": "review_threshold",
                        "type": "number",
                        "label": "Review queue warning threshold",
                        "min": 1,
                        "max": 500,
                    },
                    {
                        "key": "audit_retention_days",
                        "type": "number",
                        "label": "Audit retention in days",
                        "min": 30,
                        "max": 3650,
                    },
                    {
                        "key": "support_email",
                        "type": "email",
                        "label": "Support contact",
                    },
                ],
            },
            {
                "key": "planning_automation",
                "title": "Planning automation",
                "editable": planning_automation["available"],
                "endpoint": (
                    f"{settings.API_V1_PREFIX}"
                    f"{settings.ADMIN_API_PREFIX}/planning/automation/settings"
                ),
                "settings": planning_automation["settings"],
                "status": (
                    "available"
                    if planning_automation["available"]
                    else "unavailable"
                ),
                "error": planning_automation["error"],
                "controls": [
                    {
                        "key": "auto_run_after_import",
                        "type": "boolean",
                        "label": "Generate drafts after import",
                    },
                    {
                        "key": "default_email_type",
                        "type": "select",
                        "label": "Default draft type",
                        "options": ["auto", "confirmation", "sensibilisation"],
                    },
                    {
                        "key": "include_population",
                        "type": "boolean",
                        "label": "Include participants in drafts",
                    },
                    {
                        "key": "max_drafts_per_run",
                        "type": "number",
                        "label": "Draft limit per run",
                        "min": 1,
                        "max": 500,
                    },
                ],
            },
            {
                "key": "system",
                "title": "System supervision",
                "editable": False,
                "settings": system_payload,
                "controls": [
                    {
                        "key": "backend",
                        "type": "readonly",
                        "label": "Backend API",
                    },
                    {
                        "key": "database",
                        "type": "readonly",
                        "label": "Database",
                    },
                    {
                        "key": "mail_connector",
                        "type": "readonly",
                        "label": "Mail connector",
                    },
                    {
                        "key": "admin_credentials",
                        "type": "readonly",
                        "label": "Preset admin credentials",
                    },
                ],
            },
        ],
    }


@router.patch(
    "/settings/policies",
    summary="Update supervised dashboard policies",
    description=(
        "Updates editable dashboard policy settings. This is equivalent to PATCH "
        "/settings but is clearer for the admin settings page."
    ),
)
def update_admin_policy_settings(
    payload: dict[str, Any],
    current_user: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, Any]:
    return _update_dashboard_policy_settings(db, current_user, payload)


@router.get(
    "/usage/overview",
    summary="Get admin usage overview",
    description="Returns usage analytics cards for the admin dashboard.",
)
def get_admin_usage_overview(
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    admin_id: str | None = Query(default=None),
) -> dict[str, Any]:
    logs = _usage_logs(db, date_from=date_from, date_to=date_to, admin_id=admin_id)
    active_admins = _active_dashboard_admin_count(db)
    most_active = _most_active_admin(db, logs)
    return {
        "total_actions": len(logs),
        "login_count": _count_actions(logs, "login"),
        "create_count": _count_actions(logs, "create"),
        "update_count": _count_actions(logs, "update"),
        "delete_count": _count_actions(logs, "delete"),
        "health_check_count": _count_actions(logs, "health"),
        "failed_actions": sum(1 for log in logs if log.status != "success"),
        "active_admins": active_admins,
        "most_active_admin": most_active,
    }


@router.get(
    "/usage/actions",
    summary="List admin usage actions",
    description="Returns the usage trace table from audit logs.",
)
def list_admin_usage_actions(
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
    admin_id: str | None = Query(default=None),
    action: str | None = Query(default=None),
    resource_type: str | None = Query(default=None),
    status: str | None = Query(default=None),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> dict[str, Any]:
    clauses = _usage_clauses(
        admin_id=admin_id,
        action=action,
        resource_type=resource_type,
        status=status,
        date_from=date_from,
        date_to=date_to,
    )
    total = int(db.scalar(select(func.count(AuditLog.id)).where(*clauses)) or 0)
    logs = list(
        db.scalars(
            select(AuditLog)
            .where(*clauses)
            .order_by(desc(AuditLog.created_at), desc(AuditLog.id))
            .limit(limit)
            .offset(offset)
        )
    )
    return {
        "items": [_usage_action_item(log) for log in logs],
        "total": total,
        "limit": limit,
        "offset": offset,
    }


@router.get(
    "/usage/actions/{log_id}",
    summary="Get admin usage action",
    description="Returns one audit log entry with full metadata for a detail drawer.",
)
def get_admin_usage_action(
    log_id: str,
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
) -> dict[str, Any]:
    log = AuditRepository(db).get(log_id)
    if log is None:
        raise HTTPException(status_code=404, detail="Usage action not found.")
    return {"status": "ok", "item": _usage_action_item(log)}


@router.get(
    "/usage/admins",
    response_model=DashboardAdminsResponse,
    summary="List admins for usage analytics",
    description="Lists dashboard admins with action counts.",
)
def list_usage_admins(
    _: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
    search: str | None = Query(default=None),
    role: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> DashboardAdminsResponse:
    credentials, total = AuthRepository(db).list_admin_credentials(
        search=search,
        role=role,
        limit=limit,
        offset=offset,
    )
    return DashboardAdminsResponse(
        items=[_to_dashboard_admin_response(db, credential) for credential in credentials],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/usage/admins/{admin_id}/overview",
    summary="Get per-admin usage overview",
    description="Returns usage analytics cards for one dashboard admin.",
)
def get_usage_admin_overview(
    admin_id: str,
    current_user: Annotated[User, Depends(get_current_admin_manager)],
    db: Annotated[Session, Depends(get_db)],
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
) -> dict[str, Any]:
    payload = get_admin_usage_overview(
        current_user,
        db,
        date_from=date_from,
        date_to=date_to,
        admin_id=admin_id,
    )
    credential = AuthRepository(db).get_admin_credential_by_user_id(admin_id)
    if credential is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    payload["admin"] = _to_dashboard_admin_response(db, credential).model_dump()
    return payload


@router.get(
    "/admins",
    response_model=DashboardAdminsResponse,
    summary="List dashboard admins",
    description="Lists preset dashboard admin accounts.",
)
def list_dashboard_admins(
    _: Annotated[User, Depends(get_current_super_admin)],
    db: Annotated[Session, Depends(get_db)],
    search: str | None = Query(default=None),
    role: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> DashboardAdminsResponse:
    credentials, total = AuthRepository(db).list_admin_credentials(
        search=search,
        role=role,
        limit=limit,
        offset=offset,
    )
    return DashboardAdminsResponse(
        items=[_to_dashboard_admin_response(db, credential) for credential in credentials],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post(
    "/admins",
    response_model=DashboardAdminResponse,
    summary="Create dashboard admin",
    description="Creates a dashboard admin credential. Super admin only.",
)
def create_dashboard_admin(
    request_body: CreateDashboardAdminRequest,
    current_user: Annotated[User, Depends(get_current_super_admin)],
    db: Annotated[Session, Depends(get_db)],
    request: Request,
) -> DashboardAdminResponse:
    repository = AuthRepository(db)
    try:
        credential = repository.create_dashboard_admin(
            username=request_body.username,
            password=request_body.password,
            email=request_body.email,
            display_name=request_body.display_name,
            role=request_body.role,
            is_active=request_body.is_active,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    response = _to_dashboard_admin_response(db, credential)
    _audit_admin_management(
        db,
        current_user,
        "admin.admin.create",
        "Created dashboard admin",
        credential.user_id,
        request,
        after=response.model_dump(),
    )
    return response


@router.get(
    "/admins/{admin_id}",
    response_model=DashboardAdminResponse,
    summary="Get dashboard admin",
    description="Returns one dashboard admin account.",
)
def get_dashboard_admin(
    admin_id: str,
    _: Annotated[User, Depends(get_current_super_admin)],
    db: Annotated[Session, Depends(get_db)],
) -> DashboardAdminResponse:
    credential = AuthRepository(db).get_admin_credential_by_user_id(admin_id)
    if credential is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    return _to_dashboard_admin_response(db, credential)


@router.patch(
    "/admins/{admin_id}",
    response_model=DashboardAdminResponse,
    summary="Update dashboard admin",
    description="Updates a dashboard admin profile, role or active state.",
)
def update_dashboard_admin(
    admin_id: str,
    request_body: UpdateDashboardAdminRequest,
    current_user: Annotated[User, Depends(get_current_super_admin)],
    db: Annotated[Session, Depends(get_db)],
    request: Request,
) -> DashboardAdminResponse:
    repository = AuthRepository(db)
    credential = repository.get_admin_credential_by_user_id(admin_id)
    if credential is None or credential.user is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    before = _to_dashboard_admin_response(db, credential).model_dump()
    _ensure_admin_update_allowed(
        repository,
        credential.user,
        new_role=request_body.role,
        new_active=request_body.is_active,
    )
    try:
        updated = repository.update_dashboard_admin(
            user_id=admin_id,
            username=request_body.username,
            email=request_body.email,
            display_name=request_body.display_name,
            role=request_body.role,
            is_active=request_body.is_active,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if updated is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    response = _to_dashboard_admin_response(db, updated)
    after = response.model_dump()
    _audit_admin_management(
        db,
        current_user,
        "admin.admin.update",
        "Updated dashboard admin",
        admin_id,
        request,
        before=before,
        after=after,
        changed_fields=_changed_fields(before, after),
    )
    return response


@router.patch(
    "/admins/{admin_id}/active",
    response_model=DashboardAdminResponse,
    summary="Enable or disable dashboard admin",
    description="Changes dashboard admin active state. Super admin only.",
)
def update_dashboard_admin_active(
    admin_id: str,
    request_body: UpdateDashboardAdminActiveRequest,
    current_user: Annotated[User, Depends(get_current_super_admin)],
    db: Annotated[Session, Depends(get_db)],
    request: Request,
) -> DashboardAdminResponse:
    repository = AuthRepository(db)
    credential = repository.get_admin_credential_by_user_id(admin_id)
    if credential is None or credential.user is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    before = _to_dashboard_admin_response(db, credential).model_dump()
    _ensure_admin_update_allowed(
        repository,
        credential.user,
        new_active=request_body.is_active,
    )
    updated = repository.update_dashboard_admin_active_state(
        user_id=admin_id,
        is_active=request_body.is_active,
    )
    if updated is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    response = _to_dashboard_admin_response(db, updated)
    after = response.model_dump()
    _audit_admin_management(
        db,
        current_user,
        "admin.admin.active.update",
        "Updated dashboard admin active state",
        admin_id,
        request,
        before=before,
        after=after,
        changed_fields=_changed_fields(before, after),
    )
    return response


@router.patch(
    "/admins/{admin_id}/password",
    response_model=DashboardAdminResponse,
    summary="Update dashboard admin password",
    description="Updates a dashboard admin password without returning any hash.",
)
def update_dashboard_admin_password(
    admin_id: str,
    request_body: UpdateDashboardAdminPasswordRequest,
    current_user: Annotated[User, Depends(get_current_super_admin)],
    db: Annotated[Session, Depends(get_db)],
    request: Request,
) -> DashboardAdminResponse:
    repository = AuthRepository(db)
    try:
        credential = repository.update_dashboard_admin_password(
            user_id=admin_id,
            password=request_body.password,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if credential is None:
        raise HTTPException(status_code=404, detail="Admin not found.")
    response = _to_dashboard_admin_response(db, credential)
    _audit_admin_management(
        db,
        current_user,
        "admin.admin.password.update",
        "Updated dashboard admin password",
        admin_id,
        request,
        metadata={"changed_fields": ["password"]},
    )
    return response


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
        summary=f"Updated user role for {user.email}",
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
        summary=f"Updated user active state for {user.email}",
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


def _to_dashboard_admin_response(
    db: Session,
    credential: AdminCredential,
) -> DashboardAdminResponse:
    user = credential.user
    return DashboardAdminResponse(
        id=user.id,
        email=user.email,
        username=credential.username,
        display_name=user.display_name,
        role=user.role,
        is_active=bool(user.is_active and credential.is_active),
        last_login_at=credential.last_login_at,
        actions_count=_admin_action_count(db, user.id),
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
        summary=log.summary or _default_audit_summary(log),
        metadata=audit_metadata(log),
        ip_address=log.ip_address or "",
        user_agent=log.user_agent or "",
        request_method=log.request_method or "",
        request_path=log.request_path or "",
        created_at=log.created_at,
    )


def _usage_action_item(log: AuditLog) -> dict[str, Any]:
    return {
        "id": log.id,
        "actor_user_id": log.actor_user_id,
        "actor_email": log.actor_email,
        "actor_role": log.actor_role,
        "action": log.action,
        "resource_type": log.resource_type,
        "resource_id": log.resource_id,
        "status": log.status,
        "summary": log.summary or _default_audit_summary(log),
        "metadata": audit_metadata(log),
        "ip_address": log.ip_address or "",
        "user_agent": log.user_agent or "",
        "request_method": log.request_method or "",
        "request_path": log.request_path or "",
        "created_at": log.created_at.isoformat() if log.created_at else None,
    }


def _usage_clauses(
    *,
    admin_id: str | None = None,
    action: str | None = None,
    resource_type: str | None = None,
    status: str | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
) -> list[Any]:
    clauses: list[Any] = []
    if admin_id:
        clauses.append(AuditLog.actor_user_id == admin_id.strip())
    if action:
        clauses.append(AuditLog.action == action.strip())
    if resource_type:
        clauses.append(AuditLog.resource_type == resource_type.strip())
    if status:
        clauses.append(func.lower(AuditLog.status) == status.strip().lower())
    if date_from:
        clauses.append(AuditLog.created_at >= date_from)
    if date_to:
        clauses.append(AuditLog.created_at <= date_to)
    return clauses


def _usage_logs(
    db: Session,
    *,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    admin_id: str | None = None,
) -> list[AuditLog]:
    return list(
        db.scalars(
            select(AuditLog).where(
                *_usage_clauses(
                    admin_id=admin_id,
                    date_from=date_from,
                    date_to=date_to,
                )
            )
        )
    )


def _count_actions(logs: list[AuditLog], keyword: str) -> int:
    return sum(1 for log in logs if keyword in (log.action or "").lower())


def _active_dashboard_admin_count(db: Session) -> int:
    return int(
        db.scalar(
            select(func.count(AdminCredential.id))
            .join(User)
            .where(
                User.role.in_([UserRole.SUPER_ADMIN.value, UserRole.ADMIN.value]),
                User.is_active.is_(True),
                AdminCredential.is_active.is_(True),
            )
        )
        or 0
    )


def _most_active_admin(
    db: Session,
    logs: list[AuditLog],
) -> dict[str, Any] | None:
    grouped: dict[str, int] = {}
    for log in logs:
        if not log.actor_user_id:
            continue
        grouped[log.actor_user_id] = grouped.get(log.actor_user_id, 0) + 1
    if not grouped:
        return None
    admin_id, actions = max(grouped.items(), key=lambda item: item[1])
    user = db.get(User, admin_id)
    if user is None:
        return {
            "id": admin_id,
            "email": "",
            "display_name": "",
            "actions": actions,
        }
    return {
        "id": user.id,
        "email": user.email,
        "display_name": user.display_name,
        "actions": actions,
    }


def _admin_action_count(db: Session, admin_id: str) -> int:
    return int(
        db.scalar(
            select(func.count(AuditLog.id)).where(AuditLog.actor_user_id == admin_id)
        )
        or 0
    )


def _ensure_admin_update_allowed(
    repository: AuthRepository,
    target_user: User,
    *,
    new_role: str | None = None,
    new_active: bool | None = None,
) -> None:
    target_is_super_admin = target_user.role == UserRole.SUPER_ADMIN.value
    target_is_active = bool(target_user.is_active)
    next_role = (new_role or target_user.role or "").strip().lower()
    next_active = target_is_active if new_active is None else bool(new_active)
    would_remove_super_admin = (
        target_is_super_admin
        and target_is_active
        and (next_role != UserRole.SUPER_ADMIN.value or not next_active)
    )
    if would_remove_super_admin and repository.count_active_super_admins() <= 1:
        raise HTTPException(
            status_code=400,
            detail="You cannot deactivate or demote the last active super admin.",
        )


def _audit_admin_management(
    db: Session,
    actor: User,
    action: str,
    summary: str,
    resource_id: str,
    request: Request | None,
    *,
    before: dict[str, Any] | None = None,
    after: dict[str, Any] | None = None,
    changed_fields: list[str] | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    payload = metadata or {}
    if before is not None:
        payload["before"] = before
    if after is not None:
        payload["after"] = after
    if changed_fields is not None:
        payload["changed_fields"] = changed_fields
    AuditRepository(db).create(
        actor=actor,
        action=action,
        resource_type="admin",
        resource_id=resource_id,
        summary=summary,
        metadata=payload,
        **_request_audit_context(request),
    )


def _request_audit_context(request: Request | None) -> dict[str, str]:
    if request is None:
        return {
            "ip_address": "",
            "user_agent": "",
            "request_method": "",
            "request_path": "",
        }
    return {
        "ip_address": request.client.host if request.client else "",
        "user_agent": request.headers.get("user-agent", ""),
        "request_method": request.method,
        "request_path": str(request.url.path),
    }


def _changed_fields(before: dict[str, Any], after: dict[str, Any]) -> list[str]:
    return [
        key
        for key, value in after.items()
        if key in before and before.get(key) != value
    ]


def _default_audit_summary(log: AuditLog) -> str:
    action = (log.action or "action").replace(".", " ")
    resource = log.resource_type or "resource"
    return f"{action} on {resource}".strip()


def _update_dashboard_policy_settings(
    db: Session,
    current_user: User,
    payload: dict[str, Any],
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
        summary="Updated dashboard settings",
        metadata={"updated": allowed_updates},
    )
    return {
        "status": "ok",
        "settings": updated,
    }


async def _load_planning_automation_settings(
    gateway: PlanningManagementGateway,
) -> dict[str, Any]:
    try:
        payload = await gateway.get("automation/settings")
    except HTTPException as exc:
        return {
            "available": False,
            "settings": {},
            "error": exc.detail,
        }

    settings_payload = (
        payload.get("settings", payload)
        if isinstance(payload, dict)
        else {}
    )
    if not isinstance(settings_payload, dict):
        settings_payload = {}
    return {
        "available": True,
        "settings": settings_payload,
        "error": None,
    }


def _system_supervision_settings() -> dict[str, Any]:
    return {
        "application": {
            "name": settings.APP_NAME,
            "version": settings.APP_VERSION,
        },
        "backend": {
            "api_prefix": settings.API_V1_PREFIX,
            "admin_api_prefix": settings.ADMIN_API_PREFIX,
            "admin_base_path": (
                f"{settings.API_V1_PREFIX}{settings.ADMIN_API_PREFIX}"
            ),
            "cors_origins": settings.cors_allowed_origins,
        },
        "database": {
            "configured": bool(settings.DATABASE_URL),
            "driver": _url_scheme(settings.DATABASE_URL),
        },
        "mail_connector": {
            "agent1_configured": bool(settings.AGENT1_URL),
            "agent2_configured": bool(settings.AGENT2_URL),
            "outlook_client_configured": bool(settings.MICROSOFT_CLIENT_ID),
            "agent1_endpoint": _safe_url_label(settings.AGENT1_URL),
        },
        "email_pipeline": {
            "enabled": settings.EMAIL_PIPELINE_ENABLED,
            "interval_seconds": settings.EMAIL_PIPELINE_INTERVAL_SECONDS,
            "max_emails": settings.EMAIL_PIPELINE_MAX_EMAILS,
        },
        "admin_credentials": {
            "preset_username_configured": bool(settings.ADMIN_DASHBOARD_USERNAME),
            "preset_password_configured": bool(settings.ADMIN_DASHBOARD_PASSWORD),
            "admin_email_configured": bool(settings.ADMIN_DASHBOARD_EMAIL),
            "display_name": settings.ADMIN_DASHBOARD_DISPLAY_NAME,
        },
    }


def _safe_url_label(value: str) -> str:
    if not value:
        return ""
    parsed = urlparse(value)
    if not parsed.scheme or not parsed.netloc:
        return "configured"
    return f"{parsed.scheme}://{parsed.netloc}"


def _url_scheme(value: str) -> str:
    if not value:
        return ""
    parsed = urlparse(value)
    return parsed.scheme or "configured"


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
