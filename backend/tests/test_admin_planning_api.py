import asyncio
import os
from io import BytesIO
from types import SimpleNamespace

from starlette.datastructures import UploadFile

os.environ.setdefault("DATABASE_URL", "sqlite+pysqlite:///:memory:")

from app.api.v1.routes import admin_planning  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.schemas.admin_planning import (  # noqa: E402
    AdminPlanningAutomationSettingsRequest,
    AdminPlanningGenerateDraftsRequest,
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
