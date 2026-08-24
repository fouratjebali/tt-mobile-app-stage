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
