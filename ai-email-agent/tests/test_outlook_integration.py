from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook

import api
from outlook.session_store import OutlookSessionStore
from planning.database import PlanningDatabase


class FakeGraphClient:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    def get_me(self, access_token: str) -> dict:
        assert access_token == "graph-access-token"
        return {
            "id": "user-1",
            "mail": "formation@tunisietelecom.tn",
            "displayName": "Formation TT",
        }

    def send_mail(self, **kwargs) -> dict:
        self.sent.append(kwargs)
        return {
            "provider": "microsoft_graph",
            "status": "accepted",
            "message_id": "graph-sendmail-test",
        }

    def refresh_access_token(self, refresh_token: str) -> dict:
        return {}


def workbook_bytes(rows: list[list[object]]) -> bytes:
    workbook = Workbook()
    worksheet = workbook.active
    for row in rows:
        worksheet.append(row)
    output = BytesIO()
    workbook.save(output)
    return output.getvalue()


def configure_test_services(tmp_path, monkeypatch, graph_client):
    db_path = tmp_path / "planning.db"
    api.planning_import_service.database = PlanningDatabase(db_path)
    monkeypatch.setattr(api, "outlook_session_store", OutlookSessionStore(db_path))
    monkeypatch.setattr(api, "outlook_graph_client", graph_client)


def test_microsoft_auth_stores_backend_session(tmp_path, monkeypatch):
    graph = FakeGraphClient()
    configure_test_services(tmp_path, monkeypatch, graph)
    client = TestClient(api.app)

    response = client.post(
        "/auth/microsoft",
        json={
            "access_token": "graph-access-token",
            "refresh_token": "graph-refresh-token",
            "expires_at": "2099-01-01T00:00:00+00:00",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["user"]["email"] == "formation@tunisietelecom.tn"
    assert payload["session_token"]

    me_response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {payload['session_token']}"},
    )
    assert me_response.status_code == 200
    assert me_response.json()["display_name"] == "Formation TT"


def test_send_training_draft_uses_outlook_after_approval(tmp_path, monkeypatch):
    graph = FakeGraphClient()
    configure_test_services(tmp_path, monkeypatch, graph)
    session = api.outlook_session_store.create_session(
        access_token="graph-access-token",
        refresh_token="graph-refresh-token",
        expires_at="2099-01-01T00:00:00+00:00",
        user_id="user-1",
        email="formation@tunisietelecom.tn",
        display_name="Formation TT",
    )
    client = TestClient(api.app)
    planning = workbook_bytes(
        [
            [
                "Code session",
                "Module",
                "Cabinet",
                "Formateur",
                "Date Debut",
                "Date Fin",
                "Lieu de formation",
                "Matricules",
                "Nom & Prenom",
                "Email",
            ],
            [
                "S8",
                "Exploitation IPMSAN",
                "TT Formation",
                "Maher ben Hassine",
                "2026-09-20",
                "2026-09-21",
                "Salle El Ghazela",
                "75266",
                "BOUNEB Zied",
                "zied.bouneb@tunisietelecom.tn",
            ],
        ]
    )

    import_response = client.post(
        "/planning/import",
        files={
            "files": (
                "planning.xlsx",
                planning,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    import_id = import_response.json()["import_id"]
    draft = client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    ).json()["drafts"][0]

    blocked_send = client.post(
        f"/planning/drafts/{draft['id']}/send",
        headers={"Authorization": f"Bearer {session.session_token}"},
    )
    assert blocked_send.status_code == 409

    approve_response = client.post(f"/planning/drafts/{draft['id']}/approve")
    assert approve_response.status_code == 200

    send_response = client.post(
        f"/planning/drafts/{draft['id']}/send",
        headers={"Authorization": f"Bearer {session.session_token}"},
    )

    assert send_response.status_code == 200
    sent_draft = send_response.json()["draft"]
    assert sent_draft["status"] == "SENT"
    assert sent_draft["metadata"]["provider_message_id"] == "graph-sendmail-test"
    assert graph.sent[0]["access_token"] == "graph-access-token"
    assert graph.sent[0]["recipients"] == ["zied.bouneb@tunisietelecom.tn"]
    assert graph.sent[0]["html_body"]
