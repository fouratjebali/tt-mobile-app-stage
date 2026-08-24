from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook

from api import app
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
    assert "email" in session.participants[0].missing_fields


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
    monkeypatch.setenv("PLANNING_IMPORT_DIR", str(tmp_path))
    from api import planning_import_service

    planning_import_service.storage_dir = tmp_path
    content = workbook_bytes(
        [
            ["Code session", "Module", "Date Debut", "Date Fin", "Lieu de formation"],
            ["S1", "Formation securite", "2026-09-01", "2026-09-02", "Tunis"],
        ]
    )
    client = TestClient(app)

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
