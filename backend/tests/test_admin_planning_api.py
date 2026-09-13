import asyncio
import os
from io import BytesIO
from types import SimpleNamespace

from starlette.datastructures import UploadFile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")

from app.api.v1.routes import admin_planning  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.models.audit import AuditLog  # noqa: E402
from app.models.responsable import Responsable  # noqa: E402
from app.schemas.admin_planning import (  # noqa: E402
    AdminPlanningAutomationSettingsRequest,
    AdminPlanningBulkDraftActionRequest,
    AdminPlanningBulkSendDraftsRequest,
    AdminPlanningGenerateDraftsRequest,
    AdminPlanningResponsableDirectoryRequest,
    AdminPlanningRunAutomationRequest,
    AdminPlanningSendDraftRequest,
    AdminPlanningUpdateDraftRequest,
)


class FakePlanningGateway:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, object, object]] = []

    async def get(self, path: str, params=None):
        self.calls.append(("GET", path, params, None))
        if path == "imports":
            return [{"import_id": "import-1"}]
        return {"status": "ok", "path": path, "params": params}

    async def post_json(
        self,
        path: str,
        payload: dict,
        *,
        params=None,
        authorization: str | None = None,
    ):
        self.calls.append(("POST", path, params, {**payload, "_auth": authorization}))
        return {"status": "ok", "path": path, "payload": payload}

    async def patch_json(self, path: str, payload: dict, *, params=None):
        self.calls.append(("PATCH", path, params, payload))
        return {"status": "ok", "path": path, "payload": payload}

    async def delete(self, path: str, params=None):
        self.calls.append(("DELETE", path, params, None))
        return {"status": "ok", "path": path, "deleted": True}

    async def post_files(self, path: str, files: list[UploadFile], *, params=None):
        filenames = [file.filename for file in files]
        self.calls.append(("FILES", path, params, filenames))
        return {"status": "ok", "path": path, "filenames": filenames}


def test_admin_planning_router_uses_standard_admin_prefix():
    route_paths = {
        f"{settings.ADMIN_API_PREFIX}/planning{route.path}"
        for route in admin_planning.router.routes
    }

    assert "/admin/planning/imports" in route_paths
    assert "/admin/planning/sessions" in route_paths
    assert "/admin/planning/responsables" in route_paths
    assert "/admin/planning/analytics/overview" in route_paths
    assert "/admin/planning/analytics/files" in route_paths
    assert "/admin/planning/analytics/drafts" in route_paths
    assert "/admin/planning/analytics/users" in route_paths
    assert "/admin/planning/responsables/{contact_key}" in route_paths
    assert "/admin/planning/automation/jobs" in route_paths
    assert "/admin/planning/automation/jobs/{job_id}" in route_paths
    assert "/admin/planning/automation/jobs/{job_id}/logs" in route_paths
    assert "/admin/planning/drafts/review" in route_paths
    assert "/admin/planning/drafts/bulk-action" in route_paths
    assert "/admin/planning/drafts/bulk-send" in route_paths
    assert "/admin/planning/drafts/{draft_id}/send" in route_paths


def test_admin_planning_read_routes_forward_to_planning_service():
    gateway = FakePlanningGateway()
    admin_user = SimpleNamespace(role="viewer")

    imports = asyncio.run(admin_planning.list_planning_imports(admin_user, gateway))
    sessions = asyncio.run(
        admin_planning.list_training_sessions(
            admin_user,
            gateway,
            import_id="import-1",
            year="2026",
            month="09",
            date_from="2026-09-01",
            date_to="2026-09-30",
            status="confirmed",
            domain="IT",
            training_mode="presentiel",
            training_type="inter",
            cabinet="TT Formation",
            location="Tunis",
            responsible="Salim",
            search="securite",
            has_participants=True,
            missing_contacts=False,
            sort_by="module",
            sort_direction="desc",
            limit=25,
            offset=50,
        )
    )

    assert imports == {
        "status": "ok",
        "count": 1,
        "imports": [{"import_id": "import-1"}],
    }
    assert sessions["params"] == {
        "import_id": "import-1",
        "year": "2026",
        "month": "09",
        "date_from": "2026-09-01",
        "date_to": "2026-09-30",
        "session_status": "confirmed",
        "domain": "IT",
        "training_mode": "presentiel",
        "training_type": "inter",
        "cabinet": "TT Formation",
        "location": "Tunis",
        "responsible": "Salim",
        "search": "securite",
        "has_participants": True,
        "missing_contacts": False,
        "sort_by": "module",
        "sort_direction": "desc",
        "limit": 25,
        "offset": 50,
    }
    assert gateway.calls[:2] == [
        ("GET", "imports", None, None),
        ("GET", "sessions", sessions["params"], None),
    ]


def test_admin_planning_analytics_routes_forward_to_planning_service():
    gateway = FakePlanningGateway()
    admin_user = SimpleNamespace(role="viewer")
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(bind=engine, tables=[AuditLog.__table__])
    db = sessionmaker(bind=engine)()

    try:
        overview = asyncio.run(
            admin_planning.get_planning_analytics_overview(
                admin_user,
                gateway,
                db,
                date_from="2026-09-01",
                date_to="2026-09-30",
            )
        )
        files = asyncio.run(
            admin_planning.get_planning_file_analytics(
                admin_user,
                gateway,
                date_from="2026-09-01",
                date_to="2026-09-30",
                limit=12,
            )
        )
        drafts = asyncio.run(
            admin_planning.get_planning_draft_analytics(
                admin_user,
                gateway,
                date_from="2026-09-01",
                date_to="2026-09-30",
                limit=15,
            )
        )

        assert overview["path"] == "analytics/overview"
        assert overview["admin_usage"] == {
            "users": 0,
            "actions_total": 0,
            "imports_created": 0,
            "files_treated": 0,
            "drafts_prepared": 0,
            "drafts_reviewed": 0,
            "drafts_sent": 0,
        }
        assert files["path"] == "analytics/files"
        assert drafts["path"] == "analytics/drafts"
        assert gateway.calls[:3] == [
            (
                "GET",
                "analytics/overview",
                {"date_from": "2026-09-01", "date_to": "2026-09-30"},
                None,
            ),
            (
                "GET",
                "analytics/files",
                {"date_from": "2026-09-01", "date_to": "2026-09-30", "limit": 12},
                None,
            ),
            (
                "GET",
                "analytics/drafts",
                {"date_from": "2026-09-01", "date_to": "2026-09-30", "limit": 15},
                None,
            ),
        ]
    finally:
        db.close()


def test_admin_planning_user_analytics_group_audit_logs():
    admin_user = SimpleNamespace(role="viewer")
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(bind=engine, tables=[AuditLog.__table__])
    db = sessionmaker(bind=engine)()
    db.add_all(
        [
            AuditLog(
                actor_user_id="user-1",
                actor_email="admin@tt.tn",
                actor_role="admin",
                action="admin.planning.import.create",
                resource_type="planning",
                resource_id="import-1",
                metadata_json='{"file_count": 2}',
            ),
            AuditLog(
                actor_user_id="user-1",
                actor_email="admin@tt.tn",
                actor_role="admin",
                action="admin.planning.drafts.generate",
                resource_type="planning",
                resource_id="import-1",
                metadata_json='{"draft_count": 8}',
            ),
            AuditLog(
                actor_user_id="user-2",
                actor_email="reviewer@tt.tn",
                actor_role="reviewer",
                action="admin.planning.draft.reject",
                resource_type="planning",
                resource_id="7",
                metadata_json='{"draft_id": 7}',
            ),
        ]
    )
    db.commit()

    try:
        usage = admin_planning.get_planning_user_analytics(
            admin_user,
            db,
            date_from=None,
            date_to=None,
            limit=20,
            offset=0,
        )

        assert usage["total"] == 2
        assert usage["users"][0]["actor_email"] == "admin@tt.tn"
        assert usage["users"][0]["imports_created"] == 1
        assert usage["users"][0]["files_treated"] == 2
        assert usage["users"][0]["drafts_prepared"] == 8
        assert usage["users"][1]["actor_email"] == "reviewer@tt.tn"
        assert usage["users"][1]["drafts_reviewed"] == 1
    finally:
        db.close()


def test_admin_planning_write_routes_forward_clean_payloads():
    gateway = FakePlanningGateway()
    editor = SimpleNamespace(role="reviewer")

    asyncio.run(
        admin_planning.generate_training_drafts(
            AdminPlanningGenerateDraftsRequest(
                import_id="import-1",
                session_key="session-1",
                email_type="confirmation",
                limit=10,
            ),
            editor,
            gateway,
        )
    )
    asyncio.run(
        admin_planning.update_automation_settings(
            AdminPlanningAutomationSettingsRequest(
                auto_run_after_import=True,
                max_drafts_per_run=20,
            ),
            editor,
            gateway,
        )
    )
    asyncio.run(
        admin_planning.update_training_draft(
            7,
            AdminPlanningUpdateDraftRequest(subject="Objet", recipients=["rh@tt.tn"]),
            editor,
            gateway,
        )
    )

    assert gateway.calls == [
        (
            "POST",
            "drafts/generate",
            None,
            {
                "import_id": "import-1",
                "session_key": "session-1",
                "email_type": "confirmation",
                "include_population": True,
                "limit": 10,
                "replace_existing": False,
                "responsables": [],
                "_auth": None,
            },
        ),
        (
            "PATCH",
            "automation/settings",
            None,
            {"auto_run_after_import": True, "max_drafts_per_run": 20},
        ),
        (
            "PATCH",
            "drafts/7",
            None,
            {"subject": "Objet", "recipients": ["rh@tt.tn"]},
        ),
    ]


def test_admin_automation_jobs_routes_forward_filters_and_admin_identity():
    gateway = FakePlanningGateway()
    viewer = SimpleNamespace(role="viewer")
    editor = SimpleNamespace(role="reviewer", email="admin@tunisietelecom.tn")

    asyncio.run(
        admin_planning.run_planning_automation(
            AdminPlanningRunAutomationRequest(
                import_id="import-1",
                email_type="confirmation_presence",
                include_population=True,
                limit=20,
                replace_existing=True,
            ),
            editor,
            gateway,
        )
    )
    asyncio.run(
        admin_planning.list_planning_automation_jobs(
            viewer,
            gateway,
            import_id="import-1",
            job_status="OK",
            job_type="draft_generation",
            limit=25,
            offset=50,
        )
    )
    asyncio.run(admin_planning.get_planning_automation_job(7, viewer, gateway))
    asyncio.run(
        admin_planning.list_planning_automation_job_logs(
            7,
            viewer,
            gateway,
            limit=10,
            offset=5,
        )
    )

    assert gateway.calls == [
        (
            "POST",
            "automation/run",
            None,
            {
                "import_id": "import-1",
                "email_type": "confirmation_presence",
                "include_population": True,
                "limit": 20,
                "replace_existing": True,
                "upcoming_days": 7,
                "requested_by": "admin@tunisietelecom.tn",
                "responsables": [],
                "_auth": None,
            },
        ),
        (
            "GET",
            "automation/jobs",
            {
                "import_id": "import-1",
                "job_status": "OK",
                "job_type": "draft_generation",
                "limit": 25,
                "offset": 50,
            },
            None,
        ),
        ("GET", "automation/jobs/7", None, None),
        ("GET", "automation/jobs/7/logs", {"limit": 10, "offset": 5}, None),
    ]


def test_admin_responsables_directory_routes_manage_backend_table():
    gateway = FakePlanningGateway()
    viewer = SimpleNamespace(role="viewer")
    editor = SimpleNamespace(
        id="reviewer-1",
        email="reviewer@tunisietelecom.tn",
        role="reviewer",
    )
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(bind=engine, tables=[Responsable.__table__])
    db = sessionmaker(bind=engine)()
    db.add(
        Responsable(
            nom_complet="Sami Ben Hassine",
            fonction="Responsable RH",
            grande_residence="DIRECTION REGIONALE KEBILI",
            normalized_name="sami ben hassine",
            normalized_fonction="responsable rh",
            normalized_grande_residence="direction regionale kebili",
            source_file="Responsables_RH.xlsx",
            source_sheet="Responsables RH",
            source_row=50,
        )
    )
    db.commit()

    responsables = asyncio.run(
        admin_planning.list_responsables_directory(
            viewer,
            db,
            search="sami",
            role=None,
            residence="DIRECTION REGIONALE KEBILI",
            direction=None,
            has_email=None,
            duplicate_emails=None,
            source_file=None,
            limit=20,
            offset=0,
        )
    )
    asyncio.run(
        admin_planning.import_responsables_directory(
            editor,
            gateway,
            [UploadFile(filename="annuaire.xlsx", file=BytesIO(b"data"))],
            import_id="import-1",
        )
    )
    created = asyncio.run(
        admin_planning.create_responsable_directory_entry(
            AdminPlanningResponsableDirectoryRequest(
                nom_complet="Mouna Trabelsi",
                fonction="DIR C/R",
                grande_residence="DIRECTION REGIONALE SFAX",
            ),
            editor,
            db,
        )
    )
    responsable_id = created["responsable"]["id"]
    detail = asyncio.run(
        admin_planning.get_responsable_directory_contact(
            responsable_id,
            viewer,
            db,
        )
    )
    updated = asyncio.run(
        admin_planning.update_responsable_directory_entry(
            responsable_id,
            AdminPlanningResponsableDirectoryRequest(
                nom_complet="Mouna Trabelsi",
                fonction="Responsable RH",
                grande_residence="DIRECTION REGIONALE SFAX",
            ),
            editor,
            db,
        )
    )
    asyncio.run(
        admin_planning.delete_responsable_directory_contact(
            responsable_id,
            editor,
            db,
        )
    )
    after_delete = asyncio.run(
        admin_planning.list_responsables_directory(
            viewer,
            db,
            search="Mouna",
            role=None,
            residence=None,
            direction=None,
            has_email=None,
            duplicate_emails=None,
            source_file=None,
            limit=20,
            offset=0,
        )
    )

    assert responsables["total"] == 1
    assert responsables["responsables"][0]["nom_complet"] == "Sami Ben Hassine"
    assert created["status"] == "ok"
    assert detail["responsable"]["nom_complet"] == "Mouna Trabelsi"
    assert updated["responsable"]["fonction"] == "Responsable RH"
    assert after_delete["total"] == 0
    assert gateway.calls == [
        ("FILES", "contacts/import", {"import_id": "import-1"}, ["annuaire.xlsx"]),
    ]


def test_admin_draft_review_and_bulk_action_routes_forward_payloads():
    gateway = FakePlanningGateway()
    viewer = SimpleNamespace(role="viewer")
    editor = SimpleNamespace(role="reviewer")

    asyncio.run(
        admin_planning.get_training_draft_review(
            viewer,
            gateway,
            import_id="import-1",
            session_key="session-1",
            draft_status="WAITING_REVIEW,EDITED",
            email_type="confirmation_presence",
            limit=25,
            offset=50,
        )
    )
    asyncio.run(
        admin_planning.bulk_review_training_drafts(
            AdminPlanningBulkDraftActionRequest(
                draft_ids=["draft_1", "2", 2],
                action="approve",
                review_notes="Validated",
            ),
            editor,
            gateway,
        )
    )
    asyncio.run(
        admin_planning.bulk_send_training_drafts(
            AdminPlanningBulkSendDraftsRequest(
                draft_ids=[1, 2],
                confirmation="SEND_APPROVED_DRAFT",
                confirmed_draft_count=2,
                confirmed_total_recipient_count=2,
            ),
            editor,
            gateway,
            authorization="Bearer backend-session",
        )
    )

    assert gateway.calls == [
        (
            "GET",
            "drafts/review",
            {
                "import_id": "import-1",
                "session_key": "session-1",
                "draft_status": "WAITING_REVIEW,EDITED",
                "email_type": "confirmation_presence",
                "limit": 25,
                "offset": 50,
            },
            None,
        ),
        (
            "POST",
            "drafts/bulk-action",
            None,
            {
                "draft_ids": [1, 2, 2],
                "action": "approve",
                "reason": "Validated",
                "email_type": "auto",
                "include_population": True,
                "_auth": None,
            },
        ),
        (
            "POST",
            "drafts/bulk-send",
            None,
            {
                "draft_ids": [1, 2],
                "confirmed": True,
                "confirmed_draft_count": 2,
                "confirmed_total_recipient_count": 2,
                "_auth": "Bearer backend-session",
            },
        ),
    ]


def test_admin_planning_file_upload_and_send_routes_forward_context():
    gateway = FakePlanningGateway()
    editor = SimpleNamespace(role="admin")
    files = [
        UploadFile(filename="planning.xlsx", file=BytesIO(b"data")),
    ]

    preview = asyncio.run(
        admin_planning.preview_planning_import(editor, gateway, files)
    )
    sent = asyncio.run(
        admin_planning.send_training_draft(
            15,
            AdminPlanningSendDraftRequest(
                confirmed=True,
                confirmed_recipient_count=2,
                confirmed_subject="Confirmation formation",
            ),
            editor,
            gateway,
            authorization="Bearer backend-session",
        )
    )

    assert preview["filenames"] == ["planning.xlsx"]
    assert sent["payload"] == {
        "confirmed": True,
        "confirmed_recipient_count": 2,
        "confirmed_subject": "Confirmation formation",
    }
    assert gateway.calls == [
        ("FILES", "import/preview", None, ["planning.xlsx"]),
        (
            "POST",
            "drafts/15/send",
            None,
            {
                "confirmed": True,
                "confirmed_recipient_count": 2,
                "confirmed_subject": "Confirmation formation",
                "_auth": "Bearer backend-session",
            },
        ),
    ]
