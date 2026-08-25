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


def test_training_draft_review_update_and_approve(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)
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
                "S6",
                "Cybersecurite operationnelle",
                "TT Formation",
                "Anouar ALAYA",
                "2026-09-10",
                "2026-09-11",
                "Centre Urbain Nord",
                "10001",
                "AMRI Salma",
                "salma.amri@tunisietelecom.tn",
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

    generate_response = client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    )
    draft = generate_response.json()["drafts"][0]

    edit_response = client.patch(
        f"/planning/drafts/{draft['id']}",
        json={
            "subject": "Confirmation de presence - Cybersecurite operationnelle",
            "body": draft["body"] + "\nMerci de confirmer votre disponibilite.",
            "recipients": [
                "salma.amri@tunisietelecom.tn",
                "salma.amri@tunisietelecom.tn",
            ],
        },
    )

    assert edit_response.status_code == 200
    edited = edit_response.json()["draft"]
    assert edited["status"] == "EDITED"
    assert edited["recipients"] == ["salma.amri@tunisietelecom.tn"]
    assert edited["metadata"]["ready_to_send"] is False
    assert edited["metadata"]["last_review_action"] == "edited"

    approve_response = client.post(f"/planning/drafts/{draft['id']}/approve")

    assert approve_response.status_code == 200
    approved = approve_response.json()["draft"]
    assert approved["status"] == "APPROVED"
    assert approved["metadata"]["ready_to_send"] is True
    assert approved["metadata"]["last_review_action"] == "approved"

    locked_edit_response = client.patch(
        f"/planning/drafts/{draft['id']}",
        json={"body": "Modification apres approbation"},
    )
    assert locked_edit_response.status_code == 409


def test_training_draft_review_requires_recipients_before_approval(tmp_path):
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
                "S7",
                "Gestion de la relation client",
                "2026-09-14",
                "2026-09-15",
                "Tunis",
                "20002",
                "TRABELSI Karim",
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
    generate_response = client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "sensibilisation"},
    )
    draft = generate_response.json()["drafts"][0]

    approve_response = client.post(f"/planning/drafts/{draft['id']}/approve")

    assert approve_response.status_code == 409
    assert "recipient" in approve_response.json()["detail"]

    reject_response = client.post(
        f"/planning/drafts/{draft['id']}/reject",
        json={"reason": "Coordonnees manquantes"},
    )
    assert reject_response.status_code == 200
    rejected = reject_response.json()["draft"]
    assert rejected["status"] == "REJECTED"
    assert rejected["metadata"]["ready_to_send"] is False
    assert rejected["metadata"]["rejection_reason"] == "Coordonnees manquantes"


def test_training_draft_can_be_regenerated_in_place(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)
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
                "S13",
                "Exploitation mobile avancee",
                "TT Formation",
                "Anouar ALAYA",
                "2026-10-01",
                "2026-10-02",
                "El Ghazela",
                "60006",
                "BEN AMOR Lina",
                "lina.benamor@tunisietelecom.tn",
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
    generate_response = client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    )
    draft = generate_response.json()["drafts"][0]

    edit_response = client.patch(
        f"/planning/drafts/{draft['id']}",
        json={"subject": "Manual subject", "body": "Manual body"},
    )
    assert edit_response.status_code == 200
    assert edit_response.json()["draft"]["status"] == "EDITED"

    regenerate_response = client.post(
        f"/planning/drafts/{draft['id']}/regenerate",
        json={
            "email_type": "sensibilisation",
            "include_population": True,
        },
    )

    assert regenerate_response.status_code == 200
    regenerated = regenerate_response.json()["draft"]
    assert regenerated["id"] == draft["id"]
    assert regenerated["email_type"] == "sensibilisation"
    assert regenerated["status"] == "WAITING_REVIEW"
    assert regenerated["subject"] != "Manual subject"
    assert "Sensibilisation" in regenerated["subject"]
    assert regenerated["metadata"]["last_review_action"] == "regenerated"
    assert regenerated["metadata"]["previous_status"] == "EDITED"
