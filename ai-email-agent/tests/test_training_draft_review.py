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
                "Grande residence",
                "Resp RH",
                "Email Resp RH",
            ],
            [
                "S6",
                "Cybersecurite operationnelle",
                "TT Formation",
                "Anouar ALAYA",
                "2026-09-20",
                "2026-09-21",
                "Centre Urbain Nord",
                "10001",
                "AMRI Salma",
                "salma.amri@tunisietelecom.tn",
                "Tunis",
                "Responsable RH Tunis",
                "rh.tunis@tunisietelecom.tn",
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
                "rh.tunis@tunisietelecom.tn",
                "rh.tunis@tunisietelecom.tn",
            ],
        },
    )

    assert edit_response.status_code == 200
    edited = edit_response.json()["draft"]
    assert edited["status"] == "EDITED"
    assert edited["recipients"] == ["rh.tunis@tunisietelecom.tn"]
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


def test_training_draft_review_allows_manual_outlook_approval_without_recipients(tmp_path):
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
                "Grande residence",
                "Resp RH",
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

    assert approve_response.status_code == 200
    approved = approve_response.json()["draft"]
    assert approved["status"] == "APPROVED"
    assert approved["recipients"] == []
    assert approved["metadata"]["manual_outlook_send"] is True

    reject_response = client.post(
        f"/planning/drafts/{draft['id']}/reject",
        json={"reason": "Coordonnees manquantes"},
    )
    assert reject_response.status_code == 200
    rejected = reject_response.json()["draft"]
    assert rejected["status"] == "REJECTED"
    assert rejected["metadata"]["ready_to_send"] is False
    assert rejected["metadata"]["rejection_reason"] == "Coordonnees manquantes"


def test_training_draft_can_be_marked_manually_sent(tmp_path):
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
                "Matricule",
                "Nom & Prenom",
            ],
            [
                "CRM-01",
                "Gestion de la relation client",
                "TT",
                "Formateur",
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
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    )
    draft = generate_response.json()["drafts"][0]

    sent_response = client.post(f"/planning/drafts/{draft['id']}/manual-sent")

    assert sent_response.status_code == 200
    sent = sent_response.json()["draft"]
    assert sent["status"] == "SENT"
    assert sent["metadata"]["last_review_action"] == "sent"
    assert sent["metadata"]["provider_message_id"] == "manual_outlook_send"


def test_training_analytics_endpoints_return_counts(tmp_path):
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
                "Matricule",
                "Nom & Prenom",
            ],
            [
                "CRM-01",
                "Gestion de la relation client",
                "TT",
                "Formateur",
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
    client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    )

    overview = client.get("/planning/analytics/overview")
    files = client.get("/planning/analytics/files")
    drafts = client.get("/planning/analytics/drafts")

    assert overview.status_code == 200
    assert overview.json()["imports"]["total_imports"] == 1
    assert overview.json()["files"]["excel_files"] == 1
    assert overview.json()["drafts"]["total_drafts"] == 1
    assert files.json()["by_extension"] == [{"extension": "xlsx", "count": 1}]
    assert drafts.json()["by_email_type"][0]["email_type"] == "confirmation_presence"


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
                "Grande residence",
                "Resp RH",
                "Email Resp RH",
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
                "Tunis",
                "Responsable RH Tunis",
                "rh.tunis@tunisietelecom.tn",
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


def test_training_draft_review_summary_and_bulk_actions(tmp_path):
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
                "Grande residence",
                "Resp RH",
                "Email Resp RH",
            ],
            [
                "S31",
                "Securite SI",
                "TT Formation",
                "Anouar ALAYA",
                "2026-10-10",
                "2026-10-11",
                "Tunis",
                "10001",
                "AMRI Salma",
                "salma.amri@tunisietelecom.tn",
                "Direction Centrale des Services",
                "Responsable RH Services",
                "rh.services@tunisietelecom.tn",
            ],
            [
                "S31",
                "Securite SI",
                "TT Formation",
                "Anouar ALAYA",
                "2026-10-10",
                "2026-10-11",
                "Tunis",
                "10002",
                "TRABELSI Karim",
                "karim.trabelsi@tunisietelecom.tn",
                "Direction Regionale Gabes",
                "Responsable RH Gabes",
                "rh.gabes@tunisietelecom.tn",
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
    generated = client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    ).json()["drafts"]
    draft_ids = [draft["id"] for draft in generated]

    review_response = client.get(
        "/planning/drafts/review",
        params={"import_id": import_id, "draft_status": "NEEDS_CONTACTS"},
    )
    assert review_response.status_code == 200
    review = review_response.json()
    assert review["summary"]["waiting_review"] == 0
    assert review["summary"]["needs_action"] == 2
    assert review["count"] == 2

    approve_response = client.post(
        "/planning/drafts/bulk-action",
        json={"draft_ids": [draft_ids[0], draft_ids[0], draft_ids[1], 999], "action": "approve"},
    )

    assert approve_response.status_code == 200
    approved = approve_response.json()
    assert approved["status"] == "partial"
    assert approved["requested"] == 3
    assert approved["succeeded"] == 2
    assert approved["failed"] == 1
    assert {draft["status"] for draft in approved["drafts"]} == {"APPROVED"}
    assert approved["errors"][0]["draft_id"] == 999

    reject_response = client.post(
        "/planning/drafts/bulk-action",
        json={
            "draft_ids": [draft_ids[0]],
            "action": "reject",
            "reason": "Envoyer plus tard",
        },
    )
    assert reject_response.status_code == 200
    rejected = reject_response.json()["drafts"][0]
    assert rejected["status"] == "REJECTED"
    assert rejected["metadata"]["rejection_reason"] == "Envoyer plus tard"


def test_contact_matching_review_flags_missing_and_name_matches(tmp_path):
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
                "Grande residence",
                "Resp RH",
            ],
            [
                "S21",
                "Pilotage reseau IP",
                "2026-11-03",
                "2026-11-04",
                "Tunis",
                "90009",
                "TRABELSI Karim",
                "Tunis",
                "Responsable RH Tunis",
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

    initial_review = client.get(
        "/planning/contact-review",
        params={"import_id": import_id},
    ).json()

    assert initial_review["missing"] == 0
    assert initial_review["matched"] == 1
    assert initial_review["contacts"][0]["status"] == "matched"
    assert initial_review["contacts"][0]["needs_review"] is False

    contacts_csv = (
        "Nom & Prenom,Email\n"
        "Responsable RH Tunis,rh.tunis@tunisietelecom.tn\n"
    ).encode()
    contact_response = client.post(
        "/planning/contacts/import",
        files={"files": ("contacts.csv", contacts_csv, "text/csv")},
    )
    assert contact_response.status_code == 200
    apply_response = client.post(
        "/planning/contacts/apply",
        params={"import_id": import_id},
    )
    assert apply_response.status_code == 200

    name_review = client.get(
        "/planning/contact-review",
        params={"import_id": import_id},
    ).json()

    assert name_review["missing"] == 0
    assert name_review["matched"] == 1
    assert name_review["contacts"][0]["match_method"] == "residence"
    assert name_review["contacts"][0]["needs_review"] is False

    save_response = client.post(
        "/planning/contacts",
        json={
            "full_name": "Responsable RH Tunis",
            "email": "rh.tunis@tunisietelecom.tn",
        },
    )
    assert save_response.status_code == 200

    exact_review = client.get(
        "/planning/contact-review",
        params={"import_id": import_id},
    ).json()

    assert exact_review["matched"] == 1
    assert exact_review["review"] == 0
    assert exact_review["contacts"][0]["match_method"] == "residence"
    assert exact_review["contacts"][0]["needs_review"] is False
