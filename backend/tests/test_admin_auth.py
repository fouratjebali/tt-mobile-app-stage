import os
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")

import app.models  # noqa: E402,F401
from app.api.dependencies import (  # noqa: E402
    get_current_admin_manager,
    get_current_admin_planning_editor,
    get_current_admin_user,
)
from app.api.v1.routes.admin import (  # noqa: E402
    admin_health,
    get_admin_settings,
    get_audit_log,
    list_audit_logs,
    update_admin_settings,
    update_user_active_state,
    update_user_role,
)
from app.core.config import Settings  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.models.app_settings import AppSettings  # noqa: E402
from app.models.audit import AuditLog  # noqa: E402
from app.models.auth import AdminCredential, AuthSession, User, UserRole  # noqa: E402
from app.repositories.auth_repository import AuthRepository  # noqa: E402
from app.schemas.admin import (  # noqa: E402
    UpdateAdminUserActiveRequest,
    UpdateAdminUserRoleRequest,
)
from app.services.auth_service import AuthService  # noqa: E402


def _session():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(
        bind=engine,
        tables=[
            User.__table__,
            AuthSession.__table__,
            AdminCredential.__table__,
            AuditLog.__table__,
            AppSettings.__table__,
        ],
    )
    session_factory = sessionmaker(bind=engine)
    return session_factory()


def test_new_users_default_to_regular_active_role():
    db = _session()
    try:
        user = AuthRepository(db).upsert_user(
            google_sub="microsoft:user-1",
            email="user@tunisietelecom.tn",
            display_name="Regular User",
            photo_url=None,
        )

        assert user.role == UserRole.USER.value
        assert user.is_active is True
    finally:
        db.close()


def test_standard_admin_api_prefix_contract():
    settings = Settings()

    assert settings.API_V1_PREFIX == "/api/v1"
    assert settings.ADMIN_API_PREFIX == "/admin"
    assert f"{settings.API_V1_PREFIX}{settings.ADMIN_API_PREFIX}" == "/api/v1/admin"


def test_backend_allows_local_admin_dashboard_origin():
    settings = Settings()

    assert "http://localhost:4200" in settings.cors_allowed_origins
    assert "http://127.0.0.1:4200" in settings.cors_allowed_origins


def test_admin_audit_log_routes_are_exposed():
    from app.api.v1.routes import admin, auth

    route_paths = {f"/admin{route.path}" for route in admin.router.routes}
    auth_route_paths = {f"/auth{route.path}" for route in auth.router.routes}

    assert "/admin/audit-logs" in route_paths
    assert "/admin/audit-logs/{log_id}" in route_paths
    assert "/admin/health" in route_paths
    assert "/admin/settings" in route_paths
    assert "/auth/admin/login" in auth_route_paths


def test_admin_health_and_settings_contract():
    db = _session()
    admin = SimpleNamespace(
        id="admin-1",
        email="admin@tunisietelecom.tn",
        role=UserRole.ADMIN.value,
    )
    try:
        health = admin_health(admin, db)
        assert health["status"] == "healthy"
        assert {service["name"] for service in health["services"]} == {
            "Backend API",
            "Database",
            "Mail connector",
            "Audit stream",
        }

        defaults = get_admin_settings(admin, db)
        assert defaults["settings"]["review_threshold"] == 40

        updated = update_admin_settings(
            {
                "review_threshold": 55,
                "audit_retention_days": 90,
                "support_email": "support@tunisietelecom.tn",
                "ignored": "value",
            },
            admin,
            db,
        )
        assert updated["settings"] == {
            "review_threshold": 55,
            "audit_retention_days": 90,
            "support_email": "support@tunisietelecom.tn",
        }
        assert get_admin_settings(admin, db)["settings"]["review_threshold"] == 55
    finally:
        db.close()


def test_configured_admin_email_is_promoted():
    db = _session()
    try:
        repository = AuthRepository(db)
        user = repository.upsert_user(
            google_sub="microsoft:boss",
            email="boss@tunisietelecom.tn",
            display_name="Boss",
            photo_url=None,
        )

        promoted = repository.promote_configured_admin(
            user,
            {"boss@tunisietelecom.tn", "other@tunisietelecom.tn"},
        )

        assert promoted.role == UserRole.ADMIN.value
        assert promoted.is_active is True
    finally:
        db.close()


def test_preset_admin_credentials_login_creates_admin_session():
    db = _session()
    try:
        repository = AuthRepository(db)
        repository.upsert_admin_credential(
            username="admin",
            password="secret-password",
            email="dashboard@tunisietelecom.tn",
            display_name="Dashboard Admin",
        )

        user, session_token = AuthService(db).sign_in_with_admin_credentials(
            SimpleNamespace(username="admin", password="secret-password")
        )

        assert user.email == "dashboard@tunisietelecom.tn"
        assert user.role == UserRole.ADMIN.value
        assert session_token
        assert get_current_admin_manager(
            AuthService(db).get_current_user(session_token)
        ).email == "dashboard@tunisietelecom.tn"
        assert repository.get_admin_credential("admin").last_login_at is not None

        with pytest.raises(HTTPException) as exc:
            AuthService(db).sign_in_with_admin_credentials(
                SimpleNamespace(username="admin", password="bad-password")
            )
        assert exc.value.status_code == 401
    finally:
        db.close()


def test_disabled_user_session_is_rejected():
    db = _session()
    try:
        service = AuthService(db)
        repository = AuthRepository(db)
        user = repository.upsert_user(
            google_sub="microsoft:disabled",
            email="disabled@tunisietelecom.tn",
            display_name="Disabled",
            photo_url=None,
        )
        repository.update_user_active_state(user_id=user.id, is_active=False)
        repository.create_session(
            user=user,
            session_token_hash=service._hash_token("session-token"),
            google_access_token="access-token",
            google_id_token=None,
            google_refresh_token=None,
            expires_at=None,
        )

        with pytest.raises(HTTPException) as exc:
            service.get_current_user("session-token")

        assert exc.value.status_code == 403
    finally:
        db.close()


def test_admin_dependencies_enforce_roles():
    admin = SimpleNamespace(role=UserRole.ADMIN.value)
    reviewer = SimpleNamespace(role=UserRole.REVIEWER.value)
    regular_user = SimpleNamespace(role=UserRole.USER.value)

    assert get_current_admin_user(admin) is admin
    assert get_current_admin_user(reviewer) is reviewer
    assert get_current_admin_manager(admin) is admin
    assert get_current_admin_planning_editor(admin) is admin
    assert get_current_admin_planning_editor(reviewer) is reviewer

    with pytest.raises(HTTPException) as user_exc:
        get_current_admin_user(regular_user)
    assert user_exc.value.status_code == 403

    with pytest.raises(HTTPException) as reviewer_exc:
        get_current_admin_manager(reviewer)
    assert reviewer_exc.value.status_code == 403

    with pytest.raises(HTTPException) as editor_exc:
        get_current_admin_planning_editor(regular_user)
    assert editor_exc.value.status_code == 403


def test_admin_cannot_remove_own_role_or_disable_self():
    db = _session()
    try:
        admin = AuthRepository(db).upsert_user(
            google_sub="microsoft:admin",
            email="admin@tunisietelecom.tn",
            display_name="Admin",
            photo_url=None,
        )
        AuthRepository(db).update_user_role(user_id=admin.id, role=UserRole.ADMIN)

        with pytest.raises(HTTPException) as role_exc:
            update_user_role(
                user_id=admin.id,
                request=UpdateAdminUserRoleRequest(role=UserRole.VIEWER),
                admin_user=admin,
                db=db,
            )
        assert role_exc.value.status_code == 400

        with pytest.raises(HTTPException) as active_exc:
            update_user_active_state(
                user_id=admin.id,
                request=UpdateAdminUserActiveRequest(is_active=False),
                admin_user=admin,
                db=db,
            )
        assert active_exc.value.status_code == 400
    finally:
        db.close()


def test_admin_user_mutations_create_audit_logs():
    db = _session()
    try:
        repository = AuthRepository(db)
        admin = repository.upsert_user(
            google_sub="microsoft:admin",
            email="admin@tunisietelecom.tn",
            display_name="Admin",
            photo_url=None,
        )
        repository.update_user_role(user_id=admin.id, role=UserRole.ADMIN)
        user = repository.upsert_user(
            google_sub="microsoft:reviewer",
            email="reviewer@tunisietelecom.tn",
            display_name="Reviewer",
            photo_url=None,
        )

        updated_role = update_user_role(
            user_id=user.id,
            request=UpdateAdminUserRoleRequest(role=UserRole.REVIEWER),
            admin_user=admin,
            db=db,
        )
        updated_active = update_user_active_state(
            user_id=user.id,
            request=UpdateAdminUserActiveRequest(is_active=False),
            admin_user=admin,
            db=db,
        )

        assert updated_role.role == UserRole.REVIEWER.value
        assert updated_active.is_active is False

        audit_page = list_audit_logs(
            admin,
            db,
            actor_email="admin@tunisietelecom.tn",
            action=None,
            resource_type="user",
            resource_id=None,
            status="success",
            search="reviewer",
            date_from=None,
            date_to=None,
            limit=10,
            offset=0,
        )
        assert audit_page.total == 2
        assert audit_page.logs[0].actor_email == "admin@tunisietelecom.tn"
        assert audit_page.logs[0].resource_type == "user"
        assert audit_page.logs[0].metadata["target_email"] == "reviewer@tunisietelecom.tn"

        detail = get_audit_log(audit_page.logs[0].id, admin, db)
        assert detail.id == audit_page.logs[0].id
        assert detail.status == "success"
    finally:
        db.close()
