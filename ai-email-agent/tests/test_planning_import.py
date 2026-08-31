from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook

from api import app
from planning.database import PlanningDatabase
from planning.parser import PlanningExcelParser


def workbook_bytes(rows: list[list[object]]) -> bytes:
    workbook = Workbook()
    worksheet = workbook.active
    for row in rows:
        worksheet.append(row)
    output = BytesIO()
    workbook.save(output)
    return output.getvalue()


def test_parser_imports_participant_planning_format():
    content = workbook_bytes(
        [
            [
                "Axe Strategique de la formation",
                "Domaine d'activite",
                "Projet",
                "Code Module",
                "Module",
                "Cabinet",
                "Formateur",
                "Lieu de formation",
                "Annee",
                "Mois",
                "Semaine",
                "Duree (j)",
                "Date Debut",
                "Date Fin",
                "Code session",
                "Matricules",
                "Nom & Prenom",
                "Grande residence",
                "resp RH",
                "DIR C/R",
            ],
            [
                "PROFESSIONNALISATION",
                "Nouvelles Technologies",
                "Programme IPMSAN Nokia",
                "TF401",
                "Exploitation des IPMSAN Nokia",
                "Formateur interne",
                "Maher ben Hassine",
                "Salle1 DCSI pole El Ghazela",
                2026,
                "Septembre",
                "S36-26",
                2,
                "2026-09-01",
                "2026-09-02",
                "TF401-01-2026",
                75266,
                "BOUNEB Zied",
                "Direction Centrale des Reseaux",
                "Salim Mebili",
                "DCSI",
            ],
        ]
    )

    result = PlanningExcelParser().parse_workbook("planning.xlsx", content)

    assert result.status == "needs_review"
    assert len(result.sessions) == 1
    session = result.sessions[0]
    assert session.module == "Exploitation des IPMSAN Nokia"
    assert session.location == "Salle1 DCSI pole El Ghazela"
    assert len(session.participants) == 1
    assert session.participants[0].full_name == "BOUNEB Zied"
    assert "responsible_email" in session.participants[0].missing_fields


def test_parser_detects_legend_then_session_header_format():
    content = workbook_bytes(
        [
            ["", "", "", "A", "Sessions Annulees"],
            ["", "", "", "R", "Sessions Realisees"],
            ["Planning de formation 2026"],
            [],
            [],
            list(range(1, 11)),
            [
                "Code session",
                "N Session LMS",
                "N Malek",
                "Etat",
                "Axe Strategique de la formation",
                "Domaine d'activite",
                "Projet",
                "Type",
                "Mode Formation",
                "Nature Formation",
                "Code Module",
                "Module",
                "Cabinet",
                "Formateur(s) retenu(s)",
                "Formateur designe",
                "Annee",
                "Mois",
                "Semaine",
                "Duree (j)",
                "Date Debut",
                "Date Fin",
                "Horaire",
                "Nbre d'heures/Par jour",
                "Total NB Heures",
                "Lieu de formation",
                "Responsable Engagement",
                "Lieu Hebergement",
                "Nbre Candidats",
            ],
            [
                "C1-GM190-03-2026",
                25362,
                "",
                "PC",
                "PROFESSIONNALISATION",
                "Commercial et Marketing",
                "Experience Client",
                "intra-entreprise",
                "Formation Presentielle",
                "Non Certifiante",
                "GM190",
                "Accueil et Communication",
                "Formateur interne",
                "Olfa Ben Saad",
                "Olfa Ben Saad",
                2026,
                "Septembre",
                "S36-26",
                3,
                "2026-09-08",
                "2026-09-10",
                "de 08h30 a 14h30",
                6,
                18,
                "Salle formation Tunis",
                "Besma Trabelsi",
                "Tunis",
                12,
            ],
        ]
    )

    result = PlanningExcelParser().parse_workbook("sessions.xlsx", content)

    assert result.status == "ok"
    assert len(result.sessions) == 1
    session = result.sessions[0]
    assert session.status == "CONFIRMED"
    assert session.schedule == "de 08h30 a 14h30"
    assert session.candidate_count == "12"


def test_planning_import_api_stores_and_lists_import(tmp_path, monkeypatch):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    content = workbook_bytes(
        [
            ["Code session", "Module", "Date Debut", "Date Fin", "Lieu de formation"],
            ["S1", "Formation securite", "2026-09-01", "2026-09-02", "Tunis"],
        ]
    )
    client = TestClient(app)

    preview_response = client.post(
        "/planning/import/preview",
        files={
            "files": (
                "planning.xlsx",
                content,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert preview_response.status_code == 200
    preview_payload = preview_response.json()
    assert preview_payload["total_sessions"] == 1
    assert preview_payload["files"][0]["sessions"][0]["module"] == "Formation securite"

    imports_before_save = client.get("/planning/imports")
    assert imports_before_save.status_code == 200
    assert imports_before_save.json() == []

    response = client.post(
        "/planning/import",
        files={
            "files": (
                "planning.xlsx",
                content,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["total_sessions"] == 1
    assert payload["files"][0]["sessions"][0]["module"] == "Formation securite"

    list_response = client.get("/planning/imports")
    assert list_response.status_code == 200
    imports = list_response.json()
    assert imports[0]["import_id"] == payload["import_id"]

    sessions_response = client.get(
        "/planning/sessions",
        params={"import_id": payload["import_id"]},
    )
    assert sessions_response.status_code == 200
    sessions = sessions_response.json()["sessions"]
    assert sessions[0]["module"] == "Formation securite"
    assert sessions[0]["participant_count"] == 0

    detail_response = client.get(
        f"/planning/sessions/{sessions[0]['session_key']}",
        params={"import_id": payload["import_id"]},
    )
    assert detail_response.status_code == 200
    assert detail_response.json()["session"]["module"] == "Formation securite"


def test_planning_import_api_lists_missing_contacts(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    content = workbook_bytes(
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
                "S2",
                "Formation transmission",
                "2026-09-12",
                "2026-09-13",
                "Sfax",
                "76052",
                "JABRI Jawher",
            ],
        ]
    )
    client = TestClient(app)

    response = client.post(
        "/planning/import",
        files={
            "files": (
                "participants.xlsx",
                content,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert response.status_code == 200
    payload = response.json()

    missing_response = client.get(
        "/planning/missing-contacts",
        params={"import_id": payload["import_id"]},
    )
    assert missing_response.status_code == 200
    contacts = missing_response.json()["contacts"]
    assert contacts[0]["matricule"] == ""
    assert contacts[0]["full_name"] == "Responsable formation"


def test_employee_contact_mapping_fills_missing_participant_email(tmp_path):
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
                "S3",
                "Formation fibre optique",
                "2026-09-20",
                "2026-09-21",
                "Gabes",
                "76052",
                "JABRI Jawher",
                "DIRECTION REGIONALE GABES",
                "Responsable RH Gabes",
            ],
        ]
    )
    planning_response = client.post(
        "/planning/import",
        files={
            "files": (
                "planning.xlsx",
                planning,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert planning_response.status_code == 200
    import_id = planning_response.json()["import_id"]

    contacts = workbook_bytes(
        [
            ["Nom et Prenom", "Email", "Direction", "Grande residence"],
            [
                "Responsable RH Gabes",
                "rh.gabes@tunisietelecom.tn",
                "DIRECTION REGIONALE GABES",
                "DIRECTION REGIONALE GABES",
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
    assert contacts_response.json()["imported"] == 1

    saved_contacts = client.get("/planning/contacts")
    assert saved_contacts.status_code == 200
    assert saved_contacts.json()["contacts"][0]["email"] == "rh.gabes@tunisietelecom.tn"

    apply_response = client.post(
        "/planning/contacts/apply",
        params={"import_id": import_id},
    )
    assert apply_response.status_code == 200
    assert apply_response.json()["mapped"] == 1

    missing_response = client.get(
        "/planning/missing-contacts",
        params={"import_id": import_id},
    )
    assert missing_response.status_code == 200
    assert missing_response.json()["count"] == 0

    import_response = client.get(f"/planning/imports/{import_id}")
    assert import_response.status_code == 200
    payload = import_response.json()
    assert payload["missing_email_count"] == 0
    participant = payload["files"][0]["sessions"][0]["participants"][0]
    assert participant["email"] == ""
    assert participant["responsible_email"] == "rh.gabes@tunisietelecom.tn"
    assert "responsible_email" not in participant["missing_fields"]


def test_combined_session_and_candidate_workbooks_are_merged(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)

    sessions = workbook_bytes(
        [
            [
                "Code session",
                "N Session LMS",
                "Etat",
                "Module",
                "Cabinet",
                "Formateur designe",
                "Date Debut",
                "Date Fin",
                "Horaire",
                "Lieu de formation",
                "Nbre Candidats",
            ],
            [
                "S7",
                "25362",
                "PC",
                "Accueil et Communication",
                "Cabinet TT",
                "Olfa Ben Saad",
                "2026-09-08",
                "2026-09-10",
                "de 08h30 a 14h30",
                "Salle formation Tunis",
                1,
            ],
        ]
    )
    candidates = workbook_bytes(
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
                "resp RH",
                "DIR C/R",
            ],
            [
                "S7",
                "Accueil et Communication",
                "2026-09-08",
                "2026-09-10",
                "Salle formation Tunis",
                "76052",
                "JABRI Jawher",
                "Tunis",
                "Responsable RH Tunis",
                "DR Tunis",
            ],
        ]
    )

    response = client.post(
        "/planning/import",
        files=[
            (
                "files",
                (
                    "sessions.xlsx",
                    sessions,
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                ),
            ),
            (
                "files",
                (
                    "candidates.xlsx",
                    candidates,
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                ),
            ),
        ],
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["total_sessions"] == 1
    assert payload["total_participants"] == 1
    assert payload["missing_email_count"] == 1

    sessions_response = client.get(
        "/planning/sessions",
        params={"import_id": payload["import_id"]},
    )
    assert sessions_response.status_code == 200
    stored_sessions = sessions_response.json()["sessions"]
    assert len(stored_sessions) == 1
    assert stored_sessions[0]["candidate_count"] == "1"
    assert stored_sessions[0]["participant_count"] == 1


def test_candidate_workbook_can_enrich_existing_import(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)

    sessions = workbook_bytes(
        [
            ["Code session", "Module", "Date Debut", "Date Fin", "Lieu de formation"],
            ["S8", "Gestion des reclamations", "2026-10-01", "2026-10-02", "Tunis"],
        ]
    )
    import_response = client.post(
        "/planning/import",
        files={
            "files": (
                "sessions.xlsx",
                sessions,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert import_response.status_code == 200
    import_id = import_response.json()["import_id"]

    candidates = workbook_bytes(
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
                "S8",
                "Gestion des reclamations",
                "2026-10-01",
                "2026-10-02",
                "Tunis",
                "88110",
                "BEN ALI Sarra",
                "Tunis",
            ],
        ]
    )
    candidate_response = client.post(
        "/planning/contacts/import",
        params={"import_id": import_id},
        files={
            "files": (
                "candidates.xlsx",
                candidates,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )

    assert candidate_response.status_code == 200
    candidate_payload = candidate_response.json()
    assert candidate_payload["linked_sessions"] == 1
    assert candidate_payload["created_sessions"] == 0
    assert candidate_payload["participants_added"] == 1

    sessions_response = client.get(
        "/planning/sessions",
        params={"import_id": import_id},
    )
    stored_sessions = sessions_response.json()["sessions"]
    assert len(stored_sessions) == 1
    assert stored_sessions[0]["participant_count"] == 1

    detail_response = client.get(
        f"/planning/sessions/{stored_sessions[0]['session_key']}",
        params={"import_id": import_id},
    )
    participant = detail_response.json()["session"]["participants"][0]
    assert participant["full_name"] == "BEN ALI Sarra"
    assert participant["residence"] == "Tunis"


def test_candidate_import_accepts_missing_email_without_clearing_known_contact(tmp_path):
    from api import planning_import_service

    planning_import_service.database = PlanningDatabase(tmp_path / "planning.db")
    client = TestClient(app)

    contacts = workbook_bytes(
        [
            ["Matricule", "Nom et Prenom", "Email", "Direction"],
            ["76052", "JABRI Jawher", "jawher.jabri@tunisietelecom.tn", "DR Gabes"],
        ]
    )
    candidates = workbook_bytes(
        [
            ["Matricules", "Nom & Prenom", "Grande residence", "resp RH", "DIR C/R"],
            ["76052", "JABRI Jawher", "Gabes", "Responsable RH Gabes", "DR Gabes"],
        ]
    )

    contact_response = client.post(
        "/planning/contacts/import",
        files={
            "files": (
                "contacts.xlsx",
                contacts,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert contact_response.status_code == 200
    assert contact_response.json()["imported"] == 1

    candidate_response = client.post(
        "/planning/contacts/import",
        files={
            "files": (
                "candidates.xlsx",
                candidates,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert candidate_response.status_code == 200
    assert candidate_response.json()["imported"] == 1

    saved_contacts = client.get("/planning/contacts")
    assert saved_contacts.status_code == 200
    saved = saved_contacts.json()["contacts"][0]
    assert saved["email"] == "jawher.jabri@tunisietelecom.tn"
    assert saved["residence"] == "Gabes"


def test_responsible_directory_import_maps_by_residence_and_lists_ready_first(tmp_path):
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
                "S31",
                "Exploitation IPMSAN",
                "2026-09-01",
                "2026-09-02",
                "El Ghazela",
                "75266",
                "BOUNEB Zied",
                "Direction Centrale des Services",
            ],
            [
                "S31",
                "Exploitation IPMSAN",
                "2026-09-01",
                "2026-09-02",
                "El Ghazela",
                "76052",
                "JABRI Jawher",
                "Direction Regionale Gabes",
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

    directory = workbook_bytes(
        [
            ["Grande résidence", "resp RH", "DIR C/R"],
            [
                "Direction Centrale des Services",
                "saloua.benkhoud@tunisietelecom.tn",
                "abdallah.abaza@tunisietelecom.tn",
            ],
        ]
    )
    contacts_response = client.post(
        "/planning/contacts/import",
        files={
            "files": (
                "annuaire.xlsx",
                directory,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )
    assert contacts_response.status_code == 200
    assert contacts_response.json()["imported"] == 2

    apply_response = client.post(
        "/planning/contacts/apply",
        params={"import_id": import_id},
    )
    assert apply_response.status_code == 200
    assert apply_response.json()["mapped"] == 1

    review = client.get(
        "/planning/contact-review",
        params={"import_id": import_id},
    ).json()
    assert review["matched"] == 1
    assert review["missing"] == 1
    assert review["contacts"][0]["email"] == "saloua.benkhoud@tunisietelecom.tn"
    assert review["contacts"][0]["status"] == "matched"
    assert review["contacts"][1]["status"] == "missing"

    generated = client.post(
        "/planning/drafts/generate",
        json={"import_id": import_id, "email_type": "confirmation_presence"},
    ).json()
    recipients = [draft["recipients"] for draft in generated["drafts"]]
    assert ["saloua.benkhoud@tunisietelecom.tn"] in recipients


def test_french_training_agent_generates_and_stores_confirmation_draft(tmp_path):
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
                "Horaire",
                "Lieu de formation",
                "Matricules",
                "Nom & Prenom",
                "Email",
                "Grande residence",
                "resp RH",
                "Email Resp RH",
                "DIR C/R",
            ],
            [
                "S4",
                "Exploitation des IPMSAN Nokia",
                "Formateur interne",
                "Maher ben Hassine",
                "2026-09-01",
                "2026-09-02",
                "de 08h30 a 14h30",
                "Salle1 DCSI pole El Ghazela",
                "75266",
                "BOUNEB Zied",
                "zied.bouneb@tunisietelecom.tn",
                "Direction Centrale des Reseaux",
                "Salim Mebili",
                "salim.mebili@tunisietelecom.tn",
                "Direction Centrale des Reseaux",
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

    generate_response = client.post(
        "/planning/drafts/generate",
        json={
            "import_id": import_id,
            "email_type": "confirmation_presence",
        },
    )
    assert generate_response.status_code == 200
    generated = generate_response.json()
    assert generated["generated"] == 1
    draft = generated["drafts"][0]
    assert draft["status"] == "WAITING_REVIEW"
    assert draft["recipients"] == ["salim.mebili@tunisietelecom.tn"]
    assert draft["subject"] == "Confirmation de presence formation Exploitation des IPMSAN Nokia"
    assert "Bonjour," in draft["body"]
    assert "Theme de la formation : Exploitation des IPMSAN Nokia" in draft["body"]
    assert "Duree du cours : du 01/09/2026 au 02/09/2026" in draft["body"]
    assert "Cabinet de Formation : Maher ben Hassine" in draft["body"]
    assert "Grande residence : Direction Centrale des Reseaux" in draft["body"]
    assert "Matricule | Nom et prenom | Grande residence" in draft["body"]
    assert "75266 | BOUNEB Zied | Direction Centrale des Reseaux" in draft["body"]
    assert "confirmer la disponibilite des collaborateurs" in draft["body"]
    assert "confirmer votre presence" not in draft["body"].lower()
    assert "<table" in draft["html_body"]
    assert "Matricule</th>" in draft["html_body"]
    assert "color: #19a8d8" in draft["html_body"]
    assert draft["metadata"]["language"] == "fr"
    assert draft["metadata"]["recipient_role"] == "responsable_rh_direction"
    assert draft["metadata"]["candidate_email_flow_disabled"] is True
    assert draft["metadata"]["has_html_body"] is True

    list_response = client.get(
        "/planning/drafts",
        params={"import_id": import_id},
    )
    assert list_response.status_code == 200
    assert list_response.json()["drafts"][0]["id"] == draft["id"]

    type_filter_response = client.get(
        "/planning/drafts",
        params={
            "import_id": import_id,
            "email_type": "confirmation_presence",
        },
    )
    assert type_filter_response.status_code == 200
    assert type_filter_response.json()["count"] == 1
    assert (
        type_filter_response.json()["drafts"][0]["email_type"]
        == "confirmation_presence"
    )

    missing_type_response = client.get(
        "/planning/drafts",
        params={
            "import_id": import_id,
            "email_type": "sensibilisation",
        },
    )
    assert missing_type_response.status_code == 200
    assert missing_type_response.json()["count"] == 0

    review_filter_response = client.get(
        "/planning/drafts",
        params={
            "import_id": import_id,
            "draft_status": "WAITING_REVIEW,EDITED",
        },
    )
    assert review_filter_response.status_code == 200
    assert review_filter_response.json()["count"] == 1

    detail_response = client.get(f"/planning/drafts/{draft['id']}")
    assert detail_response.status_code == 200
    assert detail_response.json()["draft"]["body"] == draft["body"]


def test_french_training_agent_marks_draft_as_needing_contacts(tmp_path):
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
                "S5",
                "Sécurité des échanges",
                "2026-09-04",
                "2026-09-05",
                "Tunis",
                "99999",
                "BEN SALEM Amira",
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
        json={
            "import_id": import_id,
            "email_type": "sensibilisation",
        },
    )

    assert generate_response.status_code == 200
    draft = generate_response.json()["drafts"][0]
    assert draft["status"] == "NEEDS_CONTACTS"
    assert draft["recipients"] == []
    assert draft["metadata"]["missing_recipient_count"] == 1
    assert "Population cible" in draft["body"]
    assert "BEN SALEM Amira" in draft["body"]
    assert "Sensibilisation a participer a la formation" in draft["subject"]
