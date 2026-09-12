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


def test_automation_generates_next_7_days_residence_responsible_drafts(tmp_path):
    from api import planning_import_service
    from datetime import date, timedelta

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)
    start_date = (date.today() + timedelta(days=3)).isoformat()
    end_date = (date.today() + timedelta(days=4)).isoformat()
    later_date = (date.today() + timedelta(days=12)).isoformat()
    planning = workbook_bytes(
        [
            [
                "Code session",
                "Module",
                "Formateur designe",
                "Date Debut",
                "Date Fin",
                "Lieu de formation",
            ],
            [
                "S-UP-1",
                "Exploitation IPMSAN Nokia",
                "Maher ben Hassine",
                start_date,
                end_date,
                "Salle1 DCSI pole El Ghazela",
            ],
            [
                "S-LATER-1",
                "Formation hors fenetre",
                "Formateur futur",
                later_date,
                later_date,
                "Tunis",
            ],
        ]
    )
    candidates = workbook_bytes(
        [
            ["Code session", "Matricules", "Nom & Prenom", "Grande residence"],
            ["S-UP-1", "10001", "BEN ALI Sami", "DIRECTION REGIONALE SFAX"],
            ["S-UP-1", "10002", "TRABELSI Ines", "DIRECTION REGIONALE SFAX"],
            ["S-UP-1", "10003", "AMRI Yassine", "DIRECTION REGIONALE SOUSSE"],
            ["S-LATER-1", "10004", "MANSOUR Lina", "DIRECTION REGIONALE TUNIS"],
        ]
    )
    import_response = client.post(
        "/planning/import/session-candidates",
        files={
            "sessions_file": (
                "sessions.xlsx",
                planning,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ),
            "candidates_file": (
                "candidates.xlsx",
                candidates,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            ),
        },
    )
    assert import_response.status_code == 200
    import_id = import_response.json()["import_id"]

    run_response = client.post(
        "/planning/automation/run",
        json={
            "import_id": import_id,
            "upcoming_days": 7,
            "responsables": [
                {
                    "nom_complet": "Responsable RH Sfax",
                    "fonction": "Responsable RH",
                    "grande_residence": "DIRECTION REGIONALE SFAX",
                },
                {
                    "nom_complet": "Directeur Regional Sfax",
                    "fonction": "DIR C/R",
                    "grande_residence": "DIRECTION REGIONALE SFAX",
                },
                {
                    "nom_complet": "Responsable RH Sousse",
                    "fonction": "Responsable RH",
                    "grande_residence": "DIRECTION REGIONALE SOUSSE",
                },
            ],
        },
    )

    assert run_response.status_code == 200
    payload = run_response.json()
    assert payload["generated"] == 2
    assert payload["skipped_existing"] == 0
    assert payload["settings"]["default_email_type"] == "confirmation_presence"
    drafts_by_residence = {
        draft["metadata"]["responsible_residence"]: draft
        for draft in payload["drafts"]
    }
    assert set(drafts_by_residence) == {
        "DIRECTION REGIONALE SFAX",
        "DIRECTION REGIONALE SOUSSE",
    }

    sfax_draft = drafts_by_residence["DIRECTION REGIONALE SFAX"]
    assert sfax_draft["email_type"] == "confirmation_presence"
    assert sfax_draft["status"] == "WAITING_REVIEW"
    assert sfax_draft["metadata"]["responsible_names"] == [
        "Responsable RH Sfax",
        "Directeur Regional Sfax",
    ]
    assert sfax_draft["metadata"]["participant_count"] == 2
    assert "BEN ALI Sami" in sfax_draft["body"]
    assert "TRABELSI Ines" in sfax_draft["body"]
    assert "AMRI Yassine" not in sfax_draft["body"]
    assert "Responsables concernes" in sfax_draft["body"]
    assert "Responsable RH Sfax" in sfax_draft["body"]
    assert "Directeur Regional Sfax" in sfax_draft["body"]

    sousse_draft = drafts_by_residence["DIRECTION REGIONALE SOUSSE"]
    assert sousse_draft["metadata"]["participant_count"] == 1
    assert sousse_draft["metadata"]["responsible_names"] == ["Responsable RH Sousse"]
    assert "AMRI Yassine" in sousse_draft["body"]
    assert "BEN ALI Sami" not in sousse_draft["body"]

    drafts_review = client.get(
        "/planning/drafts/review",
        params={"import_id": import_id},
    ).json()
    assert drafts_review["summary"]["waiting_review"] == 2
    assert drafts_review["summary"]["needs_action"] == 2

    second_run = client.post(
        "/planning/automation/run",
        json={
            "import_id": import_id,
            "upcoming_days": 7,
            "responsables": [
                {
                    "nom_complet": "Responsable RH Sfax",
                    "fonction": "Responsable RH",
                    "grande_residence": "DIRECTION REGIONALE SFAX",
                },
                {
                    "nom_complet": "Responsable RH Sousse",
                    "fonction": "Responsable RH",
                    "grande_residence": "DIRECTION REGIONALE SOUSSE",
                },
            ],
        },
    ).json()
    assert second_run["generated"] == 0
    assert second_run["skipped_existing"] == 2


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
                "Grande residence",
                "Resp RH",
            ],
            [
                "S9",
                "Architecture reseau mobile",
                "2026-09-15",
                "2026-09-16",
                "El Ghazela",
                "30003",
                "MANSOUR Yassine",
                "Direction Centrale des Reseaux",
                "Resp RH Reseaux",
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
            ["Grande residence", "resp RH", "DIR C/R"],
            [
                "Direction Centrale des Reseaux",
                "rh.reseaux@tunisietelecom.tn",
                "dir.reseaux@tunisietelecom.tn",
            ],
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
    assert first_payload["mapped"] == 0
    assert first_payload["generated"] == 1
    assert first_payload["skipped_existing"] == 0
    draft = first_payload["drafts"][0]
    assert draft["recipients"] == []
    assert draft["status"] == "NEEDS_CONTACTS"
    assert draft["metadata"]["recipient_role"] == "responsable_rh_direction"
    assert draft["metadata"]["participant_count"] == 1
    assert draft["metadata"]["responsible_name"] == ""
    assert first_payload["job_id"] > 0

    jobs_response = client.get(
        "/planning/automation/jobs",
        params={"import_id": import_id, "job_status": "OK"},
    )
    assert jobs_response.status_code == 200
    jobs_payload = jobs_response.json()
    assert jobs_payload["count"] == 1
    assert jobs_payload["jobs"][0]["requested_by"] == ""
    assert jobs_payload["jobs"][0]["result"]["generated"] == 1

    job_detail_response = client.get(
        f"/planning/automation/jobs/{first_payload['job_id']}"
    )
    assert job_detail_response.status_code == 200
    job = job_detail_response.json()["job"]
    assert job["status"] == "OK"
    assert job["import_id"] == import_id
    assert len(job["logs"]) >= 4

    logs_response = client.get(
        f"/planning/automation/jobs/{first_payload['job_id']}/logs"
    )
    assert logs_response.status_code == 200
    assert logs_response.json()["logs"][0]["message"] == "Automation job started."

    second_run = client.post(
        "/planning/automation/run",
        json={"import_id": import_id, "requested_by": "planner@tunisietelecom.tn"},
    )

    assert second_run.status_code == 200
    second_payload = second_run.json()
    assert second_payload["generated"] == 0
    assert second_payload["skipped_existing"] == 1

    requested_jobs = client.get(
        "/planning/automation/jobs",
        params={"import_id": import_id, "limit": 10},
    ).json()["jobs"]
    assert requested_jobs[0]["requested_by"] == "planner@tunisietelecom.tn"


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
                "Grande residence",
                "Resp RH",
            ],
            [
                "S10",
                "Cloud et securite",
                "2026-09-24",
                "2026-09-25",
                "Tunis",
                "40004",
                "SAIDI Ines",
                "Direction Centrale des Services",
                "Resp RH Services",
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
    assert missing_before.json()["count"] == 0

    save_response = client.post(
        "/planning/contacts",
        json={
            "full_name": "Resp RH Services",
            "email": "rh.services@tunisietelecom.tn",
            "direction": "Direction Centrale des Services",
            "hr_responsible": "Resp RH Services",
        },
    )
    assert save_response.status_code == 200

    apply_response = client.post(
        "/planning/contacts/apply",
        params={"import_id": import_id},
    )
    assert apply_response.status_code == 200
    assert apply_response.json()["mapped"] == 0

    missing_after = client.get(
        "/planning/missing-contacts",
        params={"import_id": import_id},
    )
    assert missing_after.json()["count"] == 0


def test_planning_automation_settings_control_default_run(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)

    settings_response = client.patch(
        "/planning/automation/settings",
        json={
            "auto_run_after_import": False,
            "default_email_type": "sensibilisation",
            "include_population": False,
            "max_drafts_per_run": 1,
        },
    )
    assert settings_response.status_code == 200
    settings_payload = settings_response.json()["settings"]
    assert settings_payload["auto_run_after_import"] is False
    assert settings_payload["default_email_type"] == "sensibilisation"
    assert settings_payload["include_population"] is False
    assert settings_payload["max_drafts_per_run"] == 1

    get_response = client.get("/planning/automation/settings")
    assert get_response.status_code == 200
    assert get_response.json()["settings"]["default_email_type"] == "sensibilisation"

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
                "Email",
            ],
            [
                "S11",
                "Communication client",
                "2026-09-15",
                "2026-09-15",
                "Tunis",
                "50005",
                "ALI Sami",
                "sami.ali@tunisietelecom.tn",
            ],
            [
                "S12",
                "Gestion incidents",
                "2026-09-16",
                "2026-09-16",
                "Tunis",
                "50006",
                "KARRAY Lina",
                "lina.karray@tunisietelecom.tn",
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

    run_response = client.post(
        "/planning/automation/run",
        json={"import_id": import_id},
    )
    assert run_response.status_code == 200
    payload = run_response.json()
    assert payload["generated"] == 1
    assert payload["settings"]["default_email_type"] == "sensibilisation"
    assert payload["settings"]["include_population"] is False
    assert payload["settings"]["max_drafts_per_run"] == 1
    assert payload["drafts"][0]["email_type"] == "sensibilisation"


def test_automation_generates_one_draft_per_session_residence_with_responsables(tmp_path):
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
            ],
            [
                "S20",
                "Exploitation IPMSAN",
                "2026-09-15",
                "2026-09-16",
                "El Ghazela",
                "10001",
                "AMRI Salma",
                "Direction Regionale Sfax",
            ],
            [
                "S20",
                "Exploitation IPMSAN",
                "2026-09-15",
                "2026-09-16",
                "El Ghazela",
                "10002",
                "TRABELSI Karim",
                "Direction Regionale Sfax",
            ],
            [
                "S20",
                "Exploitation IPMSAN",
                "2026-09-15",
                "2026-09-16",
                "El Ghazela",
                "10003",
                "SAIDI Ines",
                "Direction Regionale Sousse",
            ],
            [
                "S20",
                "Exploitation IPMSAN",
                "2026-09-15",
                "2026-09-16",
                "El Ghazela",
                "10004",
                "BEN SALEM Amira",
                "Direction Regionale Tunis",
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

    response = client.post(
        "/planning/automation/run",
        json={
            "import_id": import_id,
            "responsables": [
                {
                    "nom_complet": "Responsable RH Sfax",
                    "fonction": "Resp RH",
                    "grande_residence": "Direction Regionale Sfax",
                },
                {
                    "nom_complet": "Directeur Regional Sfax",
                    "fonction": "DIR C/R",
                    "grande_residence": "Direction Regionale Sfax",
                },
                {
                    "nom_complet": "Responsable RH Sousse",
                    "fonction": "Resp RH",
                    "grande_residence": "Direction Regionale Sousse",
                },
                {
                    "nom_complet": "Responsable RH Tunis",
                    "fonction": "Resp RH",
                    "grande_residence": "Direction Regionale Tunis",
                },
            ],
        },
    )

    assert response.status_code == 200
    drafts = response.json()["drafts"]
    assert response.json()["generated"] == 3
    by_residence = {
        draft["metadata"]["responsible_residence"]: draft for draft in drafts
    }
    assert by_residence["Direction Regionale Sfax"]["metadata"]["participant_count"] == 2
    assert by_residence["Direction Regionale Sfax"]["metadata"]["responsible_names"] == [
        "Responsable RH Sfax",
        "Directeur Regional Sfax",
    ]
    assert "AMRI Salma" in by_residence["Direction Regionale Sfax"]["body"]
    assert "TRABELSI Karim" in by_residence["Direction Regionale Sfax"]["body"]
    assert "SAIDI Ines" not in by_residence["Direction Regionale Sfax"]["body"]
    assert by_residence["Direction Regionale Sfax"]["recipients"] == []
    assert by_residence["Direction Regionale Sfax"]["status"] == "WAITING_REVIEW"
