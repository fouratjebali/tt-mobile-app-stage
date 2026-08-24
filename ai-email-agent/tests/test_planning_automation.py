from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook

from api import app
from planning.database import PlanningDatabase


def workbook_bytes(rows: list[list[object]]) -> bytes:
    workbook = Workbook()
    worksheet = workbook.active
    for row in rows:
        worksheet.append(row)
    output = BytesIO()
    workbook.save(output)
    return output.getvalue()


def test_planning_automation_maps_contacts_and_skips_existing_drafts(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)
    planning = workbook_bytes(
        [
            [
                "Code session",
                "Module",
                "Date Debut",
                "Date Fin",
                "Lieu de formation",
                "Matricules",
                "Nom & Prenom",
            ],
            [
                "S9",
                "Architecture reseau mobile",
                "2026-09-22",
                "2026-09-23",
                "El Ghazela",
                "30003",
                "MANSOUR Yassine",
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
    assert import_response.status_code == 200
    import_id = import_response.json()["import_id"]

    contacts = workbook_bytes(
        [
            ["Matricule", "Nom et Prenom", "Email"],
            ["30003", "MANSOUR Yassine", "yassine.mansour@tunisietelecom.tn"],
        ]
    )
    contacts_response = client.post(
        "/planning/contacts/import",
        files={
            "files": (
                "contacts.xlsx",
                contacts,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert contacts_response.status_code == 200

    first_run = client.post(
        "/planning/automation/run",
        json={"import_id": import_id},
    )

    assert first_run.status_code == 200
    first_payload = first_run.json()
    assert first_payload["mapped"] == 1
    assert first_payload["generated"] == 1
    assert first_payload["skipped_existing"] == 0
    assert first_payload["drafts"][0]["recipients"] == [
        "yassine.mansour@tunisietelecom.tn"
    ]

    second_run = client.post(
        "/planning/automation/run",
        json={"import_id": import_id},
    )

    assert second_run.status_code == 200
    second_payload = second_run.json()
    assert second_payload["generated"] == 0
    assert second_payload["skipped_existing"] == 1


def test_manual_contact_save_can_complete_missing_participant(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)
    planning = workbook_bytes(
        [
            [
                "Code session",
                "Module",
                "Date Debut",
                "Date Fin",
                "Lieu de formation",
                "Matricules",
                "Nom & Prenom",
            ],
            [
                "S10",
                "Cloud et securite",
                "2026-09-24",
                "2026-09-25",
                "Tunis",
                "40004",
                "SAIDI Ines",
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

    missing_before = client.get(
        "/planning/missing-contacts",
        params={"import_id": import_id},
    )
    assert missing_before.json()["count"] == 1

    save_response = client.post(
        "/planning/contacts",
        json={
            "matricule": "40004",
            "full_name": "SAIDI Ines",
            "email": "ines.saidi@tunisietelecom.tn",
        },
    )
    assert save_response.status_code == 200

    apply_response = client.post(
        "/planning/contacts/apply",
        params={"import_id": import_id},
    )
    assert apply_response.status_code == 200
    assert apply_response.json()["mapped"] == 1

    missing_after = client.get(
        "/planning/missing-contacts",
        params={"import_id": import_id},
    )
    assert missing_after.json()["count"] == 0
