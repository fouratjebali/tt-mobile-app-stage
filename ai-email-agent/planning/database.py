from __future__ import annotations

import json
import os
import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from planning.contact_parser import EmployeeContact, normalize_name
from planning.models import (
    PlanningFileResult,
    PlanningImportResult,
    PlanningParticipant,
    TrainingSession,
)
from planning.training_agent import TrainingDraft


DEFAULT_DB_PATH = Path(__file__).resolve().parents[1] / "data" / "tt_mail_assistant.db"
EDITABLE_DRAFT_STATUSES = {"WAITING_REVIEW", "EDITED", "NEEDS_CONTACTS"}


class PlanningDatabase:
    def __init__(self, db_path: Path | str | None = None) -> None:
        configured_path = os.getenv("PLANNING_DB_PATH", "").strip()
        self.db_path = Path(db_path or configured_path or DEFAULT_DB_PATH)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.initialize()

    def initialize(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                PRAGMA foreign_keys = ON;

                CREATE TABLE IF NOT EXISTS planning_imports (
                    import_id TEXT PRIMARY KEY,
                    created_at TEXT NOT NULL,
                    status TEXT NOT NULL,
                    total_sessions INTEGER NOT NULL DEFAULT 0,
                    total_participants INTEGER NOT NULL DEFAULT 0,
                    missing_email_count INTEGER NOT NULL DEFAULT 0,
                    warning_count INTEGER NOT NULL DEFAULT 0,
                    error_count INTEGER NOT NULL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS planning_files (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    import_id TEXT NOT NULL,
                    filename TEXT NOT NULL,
                    status TEXT NOT NULL,
                    sheets_json TEXT NOT NULL DEFAULT '[]',
                    warnings_json TEXT NOT NULL DEFAULT '[]',
                    errors_json TEXT NOT NULL DEFAULT '[]',
                    FOREIGN KEY (import_id)
                        REFERENCES planning_imports(import_id)
                        ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS training_sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    import_id TEXT NOT NULL,
                    file_id INTEGER NOT NULL,
                    session_key TEXT NOT NULL,
                    code_session TEXT NOT NULL DEFAULT '',
                    lms_session_number TEXT NOT NULL DEFAULT '',
                    malek_number TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL DEFAULT 'UNKNOWN',
                    axis TEXT NOT NULL DEFAULT '',
                    domain TEXT NOT NULL DEFAULT '',
                    project TEXT NOT NULL DEFAULT '',
                    training_type TEXT NOT NULL DEFAULT '',
                    training_mode TEXT NOT NULL DEFAULT '',
                    certification_nature TEXT NOT NULL DEFAULT '',
                    module_code TEXT NOT NULL DEFAULT '',
                    module TEXT NOT NULL DEFAULT '',
                    cabinet TEXT NOT NULL DEFAULT '',
                    trainer TEXT NOT NULL DEFAULT '',
                    selected_trainer TEXT NOT NULL DEFAULT '',
                    year TEXT NOT NULL DEFAULT '',
                    month TEXT NOT NULL DEFAULT '',
                    week TEXT NOT NULL DEFAULT '',
                    duration_days TEXT NOT NULL DEFAULT '',
                    start_date TEXT NOT NULL DEFAULT '',
                    end_date TEXT NOT NULL DEFAULT '',
                    schedule TEXT NOT NULL DEFAULT '',
                    hours_per_day TEXT NOT NULL DEFAULT '',
                    total_hours TEXT NOT NULL DEFAULT '',
                    location TEXT NOT NULL DEFAULT '',
                    accommodation_location TEXT NOT NULL DEFAULT '',
                    responsible_engagement TEXT NOT NULL DEFAULT '',
                    candidate_count TEXT NOT NULL DEFAULT '',
                    source_file TEXT NOT NULL DEFAULT '',
                    source_sheet TEXT NOT NULL DEFAULT '',
                    source_rows_json TEXT NOT NULL DEFAULT '[]',
                    missing_fields_json TEXT NOT NULL DEFAULT '[]',
                    FOREIGN KEY (import_id)
                        REFERENCES planning_imports(import_id)
                        ON DELETE CASCADE,
                    FOREIGN KEY (file_id)
                        REFERENCES planning_files(id)
                        ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_training_sessions_import
                    ON training_sessions(import_id);
                CREATE INDEX IF NOT EXISTS idx_training_sessions_key
                    ON training_sessions(session_key);
                CREATE INDEX IF NOT EXISTS idx_training_sessions_dates
                    ON training_sessions(start_date, end_date);

                CREATE TABLE IF NOT EXISTS training_participants (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    import_id TEXT NOT NULL,
                    session_id INTEGER NOT NULL,
                    session_key TEXT NOT NULL,
                    matricule TEXT NOT NULL DEFAULT '',
                    full_name TEXT NOT NULL DEFAULT '',
                    email TEXT NOT NULL DEFAULT '',
                    residence TEXT NOT NULL DEFAULT '',
                    direction TEXT NOT NULL DEFAULT '',
                    hr_responsible TEXT NOT NULL DEFAULT '',
                    source_row INTEGER NOT NULL DEFAULT 0,
                    missing_fields_json TEXT NOT NULL DEFAULT '[]',
                    FOREIGN KEY (import_id)
                        REFERENCES planning_imports(import_id)
                        ON DELETE CASCADE,
                    FOREIGN KEY (session_id)
                        REFERENCES training_sessions(id)
                        ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_training_participants_import
                    ON training_participants(import_id);
                CREATE INDEX IF NOT EXISTS idx_training_participants_session
                    ON training_participants(session_id);
                CREATE INDEX IF NOT EXISTS idx_training_participants_matricule
                    ON training_participants(matricule);

                CREATE TABLE IF NOT EXISTS employee_contacts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    matricule TEXT NOT NULL UNIQUE,
                    normalized_name TEXT NOT NULL DEFAULT '',
                    full_name TEXT NOT NULL DEFAULT '',
                    email TEXT NOT NULL DEFAULT '',
                    residence TEXT NOT NULL DEFAULT '',
                    direction TEXT NOT NULL DEFAULT '',
                    hr_responsible TEXT NOT NULL DEFAULT '',
                    source_file TEXT NOT NULL DEFAULT '',
                    source_row INTEGER NOT NULL DEFAULT 0,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_employee_contacts_email
                    ON employee_contacts(email);

                CREATE TABLE IF NOT EXISTS training_email_drafts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    import_id TEXT,
                    session_key TEXT NOT NULL,
                    email_type TEXT NOT NULL,
                    subject TEXT NOT NULL DEFAULT '',
                    body TEXT NOT NULL DEFAULT '',
                    html_body TEXT NOT NULL DEFAULT '',
                    recipients_json TEXT NOT NULL DEFAULT '[]',
                    cc_json TEXT NOT NULL DEFAULT '[]',
                    status TEXT NOT NULL DEFAULT 'DRAFTED',
                    metadata_json TEXT NOT NULL DEFAULT '{}',
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (import_id)
                        REFERENCES planning_imports(import_id)
                        ON DELETE SET NULL
                );

                CREATE INDEX IF NOT EXISTS idx_training_email_drafts_import
                    ON training_email_drafts(import_id);
                CREATE INDEX IF NOT EXISTS idx_training_email_drafts_session
                    ON training_email_drafts(session_key);
                CREATE INDEX IF NOT EXISTS idx_training_email_drafts_status
                    ON training_email_drafts(status);

                CREATE TABLE IF NOT EXISTS training_email_send_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    draft_id INTEGER,
                    recipient_email TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL,
                    provider_message_id TEXT NOT NULL DEFAULT '',
                    error TEXT NOT NULL DEFAULT '',
                    sent_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (draft_id)
                        REFERENCES training_email_drafts(id)
                        ON DELETE SET NULL
                );

                CREATE INDEX IF NOT EXISTS idx_training_send_logs_draft
                    ON training_email_send_logs(draft_id);

                CREATE TABLE IF NOT EXISTS planning_automation_settings (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    auto_run_after_import INTEGER NOT NULL DEFAULT 1,
                    default_email_type TEXT NOT NULL DEFAULT 'auto',
                    include_population INTEGER NOT NULL DEFAULT 1,
                    max_drafts_per_run INTEGER NOT NULL DEFAULT 100,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                INSERT OR IGNORE INTO planning_automation_settings (
                    id,
                    auto_run_after_import,
                    default_email_type,
                    include_population,
                    max_drafts_per_run
                )
                VALUES (1, 1, 'auto', 1, 100);
                """
            )
            self._ensure_column(connection, "employee_contacts", "normalized_name", "TEXT NOT NULL DEFAULT ''")
            self._ensure_column(connection, "employee_contacts", "residence", "TEXT NOT NULL DEFAULT ''")
            self._ensure_column(connection, "employee_contacts", "source_file", "TEXT NOT NULL DEFAULT ''")
            self._ensure_column(connection, "employee_contacts", "source_row", "INTEGER NOT NULL DEFAULT 0")
            self._ensure_column(connection, "training_email_drafts", "html_body", "TEXT NOT NULL DEFAULT ''")
            self._ensure_column(connection, "training_email_drafts", "metadata_json", "TEXT NOT NULL DEFAULT '{}'")
            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_employee_contacts_normalized_name
                    ON employee_contacts(normalized_name)
                """
            )

    def get_automation_settings(self) -> dict[str, Any]:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT *
                FROM planning_automation_settings
                WHERE id = 1
                """
            ).fetchone()
        if row is None:
            return {
                "auto_run_after_import": True,
                "default_email_type": "auto",
                "include_population": True,
                "max_drafts_per_run": 100,
                "updated_at": "",
            }
        return {
            "auto_run_after_import": bool(row["auto_run_after_import"]),
            "default_email_type": row["default_email_type"] or "auto",
            "include_population": bool(row["include_population"]),
            "max_drafts_per_run": int(row["max_drafts_per_run"] or 100),
            "updated_at": row["updated_at"] or "",
        }

    def update_automation_settings(
        self,
        *,
        auto_run_after_import: bool | None = None,
        default_email_type: str | None = None,
        include_population: bool | None = None,
        max_drafts_per_run: int | None = None,
    ) -> dict[str, Any]:
        current = self.get_automation_settings()
        next_email_type = (
            current["default_email_type"]
            if default_email_type is None
            else default_email_type.strip().lower()
        )
        if next_email_type not in {"auto", "sensibilisation", "confirmation_presence"}:
            raise ValueError("Unsupported automation email type.")
        next_limit = (
            current["max_drafts_per_run"]
            if max_drafts_per_run is None
            else max(1, min(500, int(max_drafts_per_run)))
        )
        next_auto_run = (
            current["auto_run_after_import"]
            if auto_run_after_import is None
            else bool(auto_run_after_import)
        )
        next_include_population = (
            current["include_population"]
            if include_population is None
            else bool(include_population)
        )

        with self._connect() as connection:
            connection.execute(
                """
                UPDATE planning_automation_settings
                SET
                    auto_run_after_import = ?,
                    default_email_type = ?,
                    include_population = ?,
                    max_drafts_per_run = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = 1
                """,
                (
                    1 if next_auto_run else 0,
                    next_email_type,
                    1 if next_include_population else 0,
                    next_limit,
                ),
            )
            connection.commit()
        return self.get_automation_settings()

    def save_import(self, result: PlanningImportResult) -> None:
        with self._connect() as connection:
            connection.execute("PRAGMA foreign_keys = ON")
            connection.execute("BEGIN")
            connection.execute(
                """
                INSERT OR REPLACE INTO planning_imports (
                    import_id,
                    created_at,
                    status,
                    total_sessions,
                    total_participants,
                    missing_email_count,
                    warning_count,
                    error_count
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    result.import_id,
                    result.created_at,
                    result.status,
                    result.total_sessions,
                    result.total_participants,
                    result.missing_email_count,
                    result.warning_count,
                    result.error_count,
                ),
            )
            connection.execute(
                "DELETE FROM planning_files WHERE import_id = ?",
                (result.import_id,),
            )

            for file_result in result.files:
                file_cursor = connection.execute(
                    """
                    INSERT INTO planning_files (
                        import_id,
                        filename,
                        status,
                        sheets_json,
                        warnings_json,
                        errors_json
                    )
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        result.import_id,
                        file_result.filename,
                        file_result.status,
                        _json(file_result.sheets),
                        _json(file_result.warnings),
                        _json(file_result.errors),
                    ),
                )
                file_id = int(file_cursor.lastrowid)
                for session in file_result.sessions:
                    self._insert_session(connection, result.import_id, file_id, session)

            connection.commit()

    def add_candidate_files(
        self,
        *,
        import_id: str,
        files: list[PlanningFileResult],
    ) -> dict[str, Any]:
        with self._connect() as connection:
            existing_import = connection.execute(
                "SELECT import_id FROM planning_imports WHERE import_id = ?",
                (import_id,),
            ).fetchone()
            if existing_import is None:
                raise ValueError(f"Planning import {import_id} not found.")

            session_rows = connection.execute(
                """
                SELECT id, session_key, code_session
                FROM training_sessions
                WHERE import_id = ?
                """,
                (import_id,),
            ).fetchall()
            by_code = {
                str(row["code_session"]).strip().lower(): row
                for row in session_rows
                if str(row["code_session"] or "").strip()
            }
            by_key = {row["session_key"]: row for row in session_rows}

            linked_sessions = 0
            created_sessions = 0
            participants_added = 0
            participants_skipped = 0

            connection.execute("BEGIN")
            for file_result in files:
                file_cursor = connection.execute(
                    """
                    INSERT INTO planning_files (
                        import_id,
                        filename,
                        status,
                        sheets_json,
                        warnings_json,
                        errors_json
                    )
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        import_id,
                        file_result.filename,
                        file_result.status,
                        _json(file_result.sheets),
                        _json(file_result.warnings),
                        _json(file_result.errors),
                    ),
                )
                file_id = int(file_cursor.lastrowid)
                for session in file_result.sessions:
                    key = str(session.code_session or "").strip().lower()
                    target = by_code.get(key) if key else by_key.get(session.session_key)
                    if target is None:
                        session_id = self._insert_session(
                            connection,
                            import_id,
                            file_id,
                            session,
                        )
                        by_key[session.session_key] = {
                            "id": session_id,
                            "session_key": session.session_key,
                            "code_session": session.code_session,
                        }
                        if key:
                            by_code[key] = by_key[session.session_key]
                        created_sessions += 1
                        participants_added += len(session.participants)
                        continue

                    linked_sessions += 1
                    for participant in session.participants:
                        if self._participant_exists(
                            connection,
                            int(target["id"]),
                            participant,
                        ):
                            participants_skipped += 1
                            continue
                        self._insert_participant(
                            connection,
                            import_id,
                            int(target["id"]),
                            str(target["session_key"]),
                            participant,
                            session.source_file,
                        )
                        participants_added += 1

            self._refresh_import_counts(connection, import_id)
            connection.commit()

        return {
            "import_id": import_id,
            "files": len(files),
            "linked_sessions": linked_sessions,
            "created_sessions": created_sessions,
            "participants_added": participants_added,
            "participants_skipped": participants_skipped,
        }

    def list_imports(self) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT
                    import_id,
                    created_at,
                    status,
                    total_sessions,
                    total_participants,
                    missing_email_count,
                    warning_count,
                    error_count
                FROM planning_imports
                ORDER BY created_at DESC
                """
            ).fetchall()
            return [self._import_summary(connection, row) for row in rows]

    def get_import(self, import_id: str) -> dict[str, Any] | None:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT
                    import_id,
                    created_at,
                    status,
                    total_sessions,
                    total_participants,
                    missing_email_count,
                    warning_count,
                    error_count
                FROM planning_imports
                WHERE import_id = ?
                """,
                (import_id,),
            ).fetchone()
            if row is None:
                return None

            file_rows = connection.execute(
                """
                SELECT id, filename, status, sheets_json, warnings_json, errors_json
                FROM planning_files
                WHERE import_id = ?
                ORDER BY id
                """,
                (import_id,),
            ).fetchall()
            files: list[dict[str, Any]] = []
            for file_row in file_rows:
                session_rows = connection.execute(
                    """
                    SELECT *
                    FROM training_sessions
                    WHERE file_id = ?
                    ORDER BY start_date, module, id
                    """,
                    (file_row["id"],),
                ).fetchall()
                files.append(
                    {
                        "filename": file_row["filename"],
                        "status": file_row["status"],
                        "sheets": _loads(file_row["sheets_json"]),
                        "sessions": [
                            self._session_to_dict(connection, session_row)
                            for session_row in session_rows
                        ],
                        "warnings": _loads(file_row["warnings_json"]),
                        "errors": _loads(file_row["errors_json"]),
                    }
                )

            return {
                "import_id": row["import_id"],
                "created_at": row["created_at"],
                "status": row["status"],
                "files": files,
                "total_sessions": row["total_sessions"],
                "total_participants": row["total_participants"],
                "missing_email_count": row["missing_email_count"],
                "warning_count": row["warning_count"],
                "error_count": row["error_count"],
            }

    def list_sessions(
        self,
        *,
        import_id: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        clauses: list[str] = []
        params: list[Any] = []
        if import_id:
            clauses.append("s.import_id = ?")
            params.append(import_id)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        params.extend([limit, offset])

        with self._connect() as connection:
            rows = connection.execute(
                f"""
                SELECT
                    s.*,
                    COUNT(p.id) AS participant_count,
                    SUM(
                        CASE
                            WHEN p.email = '' THEN 1
                            ELSE 0
                        END
                    ) AS missing_email_count
                FROM training_sessions s
                LEFT JOIN training_participants p ON p.session_id = s.id
                {where}
                GROUP BY s.id
                ORDER BY s.start_date, s.module, s.id
                LIMIT ? OFFSET ?
                """,
                params,
            ).fetchall()
            return [self._session_summary(row) for row in rows]

    def get_session(
        self,
        session_key: str,
        *,
        import_id: str | None = None,
    ) -> dict[str, Any] | None:
        clauses = ["session_key = ?"]
        params: list[Any] = [session_key]
        if import_id:
            clauses.append("import_id = ?")
            params.append(import_id)

        with self._connect() as connection:
            row = connection.execute(
                f"""
                SELECT *
                FROM training_sessions
                WHERE {' AND '.join(clauses)}
                ORDER BY id DESC
                LIMIT 1
                """,
                params,
            ).fetchone()
            if row is None:
                return None
            return self._session_to_dict(connection, row)

    def list_missing_contacts(
        self,
        *,
        import_id: str | None = None,
        limit: int = 200,
    ) -> list[dict[str, Any]]:
        clauses = ["email = ''"]
        params: list[Any] = []
        if import_id:
            clauses.append("import_id = ?")
            params.append(import_id)
        params.append(limit)

        with self._connect() as connection:
            rows = connection.execute(
                f"""
                SELECT
                    matricule,
                    full_name,
                    residence,
                    direction,
                    hr_responsible,
                    COUNT(*) AS session_count,
                    MIN(source_row) AS first_source_row
                FROM training_participants
                WHERE {' AND '.join(clauses)}
                GROUP BY matricule, full_name, residence, direction, hr_responsible
                ORDER BY full_name, matricule
                LIMIT ?
                """,
                params,
            ).fetchall()
            return [dict(row) for row in rows]

    def list_contact_reviews(
        self,
        *,
        import_id: str | None = None,
        review_only: bool = False,
        limit: int = 200,
        offset: int = 0,
    ) -> dict[str, Any]:
        clauses: list[str] = []
        params: list[Any] = []
        if import_id:
            clauses.append("p.import_id = ?")
            params.append(import_id)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""

        with self._connect() as connection:
            participant_rows = connection.execute(
                f"""
                SELECT
                    p.id,
                    p.import_id,
                    p.matricule,
                    p.full_name,
                    p.email,
                    p.direction,
                    p.hr_responsible,
                    p.source_row,
                    s.session_key,
                    s.module,
                    s.start_date,
                    s.end_date
                FROM training_participants AS p
                JOIN training_sessions AS s
                    ON s.id = p.session_id
                {where}
                ORDER BY p.full_name, p.matricule, s.start_date, s.module
                """,
                params,
            ).fetchall()
            contacts = connection.execute(
                """
                SELECT
                    matricule,
                    normalized_name,
                    full_name,
                    email,
                    residence,
                    direction,
                    hr_responsible,
                    source_file,
                    source_row,
                    updated_at
                FROM employee_contacts
                WHERE email != ''
                """
            ).fetchall()

        by_matricule = {
            row["matricule"]: row
            for row in contacts
            if row["matricule"] and not str(row["matricule"]).startswith("name:")
        }
        by_email = {str(row["email"]).lower(): row for row in contacts if row["email"]}
        name_counts: dict[str, int] = {}
        by_name: dict[str, sqlite3.Row] = {}
        for row in contacts:
            normalized_name = row["normalized_name"]
            if not normalized_name:
                continue
            name_counts[normalized_name] = name_counts.get(normalized_name, 0) + 1
            by_name[normalized_name] = row

        grouped: dict[tuple[str, str, str], dict[str, Any]] = {}
        for participant in participant_rows:
            matricule = participant["matricule"] or ""
            full_name = participant["full_name"] or ""
            email = participant["email"] or ""
            normalized_name = _normalize_participant_name(full_name)
            matricule_contact = by_matricule.get(matricule) if matricule else None
            name_contact = (
                by_name.get(normalized_name)
                if normalized_name and name_counts.get(normalized_name) == 1
                else None
            )
            email_contact = by_email.get(email.lower()) if email else None
            contact = matricule_contact or name_contact or email_contact

            if not email:
                status_value = "missing"
                match_method = "none"
                needs_review = True
                reason = "Email missing from planning."
                suggested_email = contact["email"] if contact is not None else ""
            elif (
                matricule_contact is not None
                and str(matricule_contact["email"]).lower() == email.lower()
            ):
                status_value = "matched"
                match_method = "matricule"
                needs_review = False
                reason = "Matched by matricule."
                suggested_email = email
            elif (
                name_contact is not None
                and str(name_contact["email"]).lower() == email.lower()
            ):
                status_value = "review"
                match_method = "name"
                needs_review = True
                reason = "Matched by name. Please verify before sending."
                suggested_email = email
            else:
                status_value = "matched"
                match_method = "planning"
                needs_review = False
                reason = "Email provided by planning."
                suggested_email = email

            key = (matricule, normalized_name, email or suggested_email)
            if key not in grouped:
                grouped[key] = {
                    "matricule": matricule,
                    "full_name": full_name,
                    "email": email,
                    "suggested_email": suggested_email,
                    "direction": participant["direction"] or "",
                    "hr_responsible": participant["hr_responsible"] or "",
                    "match_method": match_method,
                    "status": status_value,
                    "needs_review": needs_review,
                    "reason": reason,
                    "contact_source": contact["source_file"] if contact is not None else "",
                    "session_count": 0,
                    "sessions": [],
                }
            item = grouped[key]
            item["session_count"] += 1
            if len(item["sessions"]) < 3:
                item["sessions"].append(
                    {
                        "session_key": participant["session_key"] or "",
                        "module": participant["module"] or "",
                        "start_date": participant["start_date"] or "",
                        "end_date": participant["end_date"] or "",
                    }
                )

        items = list(grouped.values())
        items.sort(key=lambda item: (not item["needs_review"], item["full_name"], item["matricule"]))
        counts = {
            "total": len(items),
            "matched": sum(1 for item in items if item["status"] == "matched"),
            "review": sum(1 for item in items if item["status"] == "review"),
            "missing": sum(1 for item in items if item["status"] == "missing"),
        }
        if review_only:
            items = [item for item in items if item["needs_review"]]
        return {
            **counts,
            "contacts": items[offset : offset + limit],
        }

    def save_contacts(self, contacts: list[EmployeeContact]) -> dict[str, Any]:
        imported = 0
        skipped = 0
        with self._connect() as connection:
            for contact in contacts:
                contact_key = _contact_key(contact)
                if not contact_key:
                    skipped += 1
                    continue
                connection.execute(
                    """
                    INSERT INTO employee_contacts (
                        matricule,
                        normalized_name,
                        full_name,
                        email,
                        residence,
                        direction,
                        hr_responsible,
                        source_file,
                        source_row,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                    ON CONFLICT(matricule) DO UPDATE SET
                        normalized_name = excluded.normalized_name,
                        full_name = excluded.full_name,
                        email = CASE
                            WHEN excluded.email != '' THEN excluded.email
                            ELSE employee_contacts.email
                        END,
                        residence = CASE
                            WHEN excluded.residence != '' THEN excluded.residence
                            ELSE employee_contacts.residence
                        END,
                        direction = CASE
                            WHEN excluded.direction != '' THEN excluded.direction
                            ELSE employee_contacts.direction
                        END,
                        hr_responsible = CASE
                            WHEN excluded.hr_responsible != '' THEN excluded.hr_responsible
                            ELSE employee_contacts.hr_responsible
                        END,
                        source_file = excluded.source_file,
                        source_row = excluded.source_row,
                        updated_at = CURRENT_TIMESTAMP
                    """,
                    (
                        contact_key,
                        contact.normalized_name,
                        contact.full_name,
                        contact.email,
                        contact.residence,
                        contact.direction,
                        contact.hr_responsible,
                        contact.source_file,
                        contact.source_row,
                    ),
                )
                imported += 1
            connection.commit()
        return {
            "imported": imported,
            "skipped": skipped,
        }

    def list_contacts(self, *, limit: int = 200, offset: int = 0) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT
                    matricule,
                    normalized_name,
                    full_name,
                    email,
                    residence,
                    direction,
                    hr_responsible,
                    source_file,
                    source_row,
                    updated_at
                FROM employee_contacts
                ORDER BY full_name, matricule
                LIMIT ? OFFSET ?
                """,
                (limit, offset),
            ).fetchall()
            return [_contact_row(row) for row in rows]

    def apply_contact_mapping(self, *, import_id: str | None = None) -> dict[str, Any]:
        with self._connect() as connection:
            contacts = connection.execute(
                """
                SELECT matricule, normalized_name, email, residence, direction, hr_responsible
                FROM employee_contacts
                WHERE email != ''
                """
            ).fetchall()
            by_matricule = {
                row["matricule"]: row
                for row in contacts
                if row["matricule"] and not str(row["matricule"]).startswith("name:")
            }
            name_counts: dict[str, int] = {}
            by_name: dict[str, sqlite3.Row] = {}
            for row in contacts:
                normalized_name = row["normalized_name"]
                if not normalized_name:
                    continue
                name_counts[normalized_name] = name_counts.get(normalized_name, 0) + 1
                by_name[normalized_name] = row

            clauses = ["email = ''"]
            params: list[Any] = []
            if import_id:
                clauses.append("import_id = ?")
                params.append(import_id)
            participants = connection.execute(
                f"""
                SELECT id, import_id, matricule, full_name, missing_fields_json
                FROM training_participants
                WHERE {' AND '.join(clauses)}
                """,
                params,
            ).fetchall()

            mapped = 0
            unmatched = 0
            for participant in participants:
                contact = None
                matricule = participant["matricule"]
                if matricule and matricule in by_matricule:
                    contact = by_matricule[matricule]
                else:
                    normalized_name = _normalize_participant_name(participant["full_name"])
                    if normalized_name and name_counts.get(normalized_name) == 1:
                        contact = by_name[normalized_name]

                if contact is None:
                    unmatched += 1
                    continue

                missing_fields = [
                    field
                    for field in _loads(participant["missing_fields_json"])
                    if field != "email"
                ]
                connection.execute(
                    """
                    UPDATE training_participants
                    SET
                        email = ?,
                        residence = COALESCE(NULLIF(residence, ''), ?),
                        direction = COALESCE(NULLIF(direction, ''), ?),
                        hr_responsible = COALESCE(NULLIF(hr_responsible, ''), ?),
                        missing_fields_json = ?
                    WHERE id = ?
                    """,
                    (
                        contact["email"],
                        contact["residence"],
                        contact["direction"],
                        contact["hr_responsible"],
                        _json(missing_fields),
                        participant["id"],
                    ),
                )
                mapped += 1

            affected_imports = self._affected_import_ids(connection, import_id)
            for affected_import_id in affected_imports:
                self._refresh_import_counts(connection, affected_import_id)

            connection.commit()

        return {
            "mapped": mapped,
            "unmatched": unmatched,
            "import_id": import_id or "",
        }

    def save_training_draft(self, draft: TrainingDraft) -> dict[str, Any]:
        with self._connect() as connection:
            cursor = connection.execute(
                """
                INSERT INTO training_email_drafts (
                    import_id,
                    session_key,
                    email_type,
                    subject,
                    body,
                    html_body,
                    recipients_json,
                    cc_json,
                    status,
                    metadata_json,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """,
                (
                    draft.import_id,
                    draft.session_key,
                    draft.email_type,
                    draft.subject,
                    draft.body,
                    draft.html_body,
                    _json(draft.recipients),
                    _json(draft.cc),
                    draft.status,
                    _json(draft.metadata),
                ),
            )
            connection.commit()
            draft_id = int(cursor.lastrowid)
        stored = self.get_training_draft(draft_id)
        return stored or {"id": draft_id, **draft.to_dict()}

    def list_training_drafts(
        self,
        *,
        import_id: str | None = None,
        session_key: str | None = None,
        status: str | list[str] | None = None,
        email_type: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        clauses: list[str] = []
        params: list[Any] = []
        if import_id:
            clauses.append("import_id = ?")
            params.append(import_id)
        if session_key:
            clauses.append("session_key = ?")
            params.append(session_key)
        if status:
            statuses = (
                [status]
                if isinstance(status, str)
                else [item for item in status if item]
            )
            if statuses:
                placeholders = ", ".join("?" for _ in statuses)
                clauses.append(f"status IN ({placeholders})")
                params.extend(statuses)
        if email_type:
            clauses.append("email_type = ?")
            params.append(email_type)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        params.extend([limit, offset])

        with self._connect() as connection:
            rows = connection.execute(
                f"""
                SELECT *
                FROM training_email_drafts
                {where}
                ORDER BY created_at DESC, id DESC
                LIMIT ? OFFSET ?
                """,
                params,
            ).fetchall()
            return [self._draft_row(row) for row in rows]

    def get_training_draft(self, draft_id: int) -> dict[str, Any] | None:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT *
                FROM training_email_drafts
                WHERE id = ?
                """,
                (draft_id,),
            ).fetchone()
            return self._draft_row(row) if row is not None else None

    def has_training_draft_for_session(
        self,
        *,
        import_id: str,
        session_key: str,
    ) -> bool:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT id
                FROM training_email_drafts
                WHERE import_id = ?
                  AND session_key = ?
                  AND status != 'REJECTED'
                LIMIT 1
                """,
                (import_id, session_key),
            ).fetchone()
            return row is not None

    def update_training_draft(
        self,
        draft_id: int,
        *,
        subject: str | None = None,
        body: str | None = None,
        html_body: str | None = None,
        recipients: list[str] | None = None,
        cc: list[str] | None = None,
    ) -> dict[str, Any] | None:
        draft = self.get_training_draft(draft_id)
        if draft is None:
            return None
        if draft["status"] not in EDITABLE_DRAFT_STATUSES:
            raise ValueError("Only drafts waiting for review can be edited.")

        next_subject = draft["subject"] if subject is None else subject.strip()
        next_body = draft["body"] if body is None else body.strip()
        next_html_body = draft["html_body"] if html_body is None else html_body.strip()
        next_recipients = draft["recipients"] if recipients is None else _clean_emails(recipients)
        next_cc = draft["cc"] if cc is None else _clean_emails(cc)
        next_status = "EDITED" if next_recipients else "NEEDS_CONTACTS"
        metadata = {
            **draft["metadata"],
            "ready_to_send": False,
            "review_status": next_status.lower(),
            "last_review_action": "edited",
            "edited_at": _utc_now(),
        }

        with self._connect() as connection:
            connection.execute(
                """
                UPDATE training_email_drafts
                SET
                    subject = ?,
                    body = ?,
                    html_body = ?,
                    recipients_json = ?,
                    cc_json = ?,
                    status = ?,
                    metadata_json = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (
                    next_subject,
                    next_body,
                    next_html_body,
                    _json(next_recipients),
                    _json(next_cc),
                    next_status,
                    _json(metadata),
                    draft_id,
                ),
            )
            connection.commit()
        return self.get_training_draft(draft_id)

    def regenerate_training_draft(
        self,
        draft_id: int,
        draft: TrainingDraft,
    ) -> dict[str, Any] | None:
        current = self.get_training_draft(draft_id)
        if current is None:
            return None
        if current["status"] == "SENT":
            raise ValueError("Sent drafts cannot be regenerated.")

        next_status = "WAITING_REVIEW" if draft.recipients else "NEEDS_CONTACTS"
        metadata = {
            **draft.metadata,
            "ready_to_send": False,
            "review_status": next_status.lower(),
            "last_review_action": "regenerated",
            "regenerated_at": _utc_now(),
            "previous_status": current["status"],
            "previous_email_type": current["email_type"],
        }

        with self._connect() as connection:
            connection.execute(
                """
                UPDATE training_email_drafts
                SET
                    email_type = ?,
                    subject = ?,
                    body = ?,
                    html_body = ?,
                    recipients_json = ?,
                    cc_json = ?,
                    status = ?,
                    metadata_json = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (
                    draft.email_type,
                    draft.subject,
                    draft.body,
                    draft.html_body,
                    _json(draft.recipients),
                    _json(draft.cc),
                    next_status,
                    _json(metadata),
                    draft_id,
                ),
            )
            connection.commit()
        return self.get_training_draft(draft_id)

    def approve_training_draft(self, draft_id: int) -> dict[str, Any] | None:
        draft = self.get_training_draft(draft_id)
        if draft is None:
            return None
        if draft["status"] not in EDITABLE_DRAFT_STATUSES and draft["status"] != "APPROVED":
            raise ValueError("Only reviewed drafts can be approved.")
        if not draft["recipients"]:
            raise ValueError("A training draft needs at least one recipient before approval.")
        if not draft["subject"].strip() or not draft["body"].strip():
            raise ValueError("A training draft needs a subject and body before approval.")

        metadata = {
            **draft["metadata"],
            "ready_to_send": True,
            "review_status": "approved",
            "last_review_action": "approved",
            "approved_at": _utc_now(),
        }
        return self._update_draft_status(draft_id, status="APPROVED", metadata=metadata)

    def reject_training_draft(
        self,
        draft_id: int,
        *,
        reason: str = "",
    ) -> dict[str, Any] | None:
        draft = self.get_training_draft(draft_id)
        if draft is None:
            return None
        if draft["status"] == "SENT":
            raise ValueError("Sent drafts cannot be rejected.")

        metadata = {
            **draft["metadata"],
            "ready_to_send": False,
            "review_status": "rejected",
            "last_review_action": "rejected",
            "rejected_at": _utc_now(),
            "rejection_reason": reason.strip(),
        }
        return self._update_draft_status(draft_id, status="REJECTED", metadata=metadata)

    def mark_training_draft_sent(
        self,
        draft_id: int,
        *,
        provider_message_id: str = "",
    ) -> dict[str, Any] | None:
        draft = self.get_training_draft(draft_id)
        if draft is None:
            return None

        metadata = {
            **draft["metadata"],
            "ready_to_send": False,
            "review_status": "sent",
            "last_review_action": "sent",
            "sent_at": _utc_now(),
            "provider_message_id": provider_message_id,
        }
        updated = self._update_draft_status(draft_id, status="SENT", metadata=metadata)
        for recipient in draft["recipients"]:
            self.log_training_send(
                draft_id,
                recipient_email=recipient,
                status="sent",
                provider_message_id=provider_message_id,
            )
        return updated

    def log_training_send(
        self,
        draft_id: int,
        *,
        recipient_email: str,
        status: str,
        provider_message_id: str = "",
        error: str = "",
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO training_email_send_logs (
                    draft_id,
                    recipient_email,
                    status,
                    provider_message_id,
                    error,
                    sent_at
                )
                VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                """,
                (
                    draft_id,
                    recipient_email,
                    status,
                    provider_message_id,
                    error,
                ),
            )
            connection.commit()

    def list_training_send_logs(
        self,
        *,
        import_id: str | None = None,
        draft_id: int | None = None,
        status: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        clauses: list[str] = []
        params: list[Any] = []
        if import_id:
            clauses.append("d.import_id = ?")
            params.append(import_id)
        if draft_id is not None:
            clauses.append("l.draft_id = ?")
            params.append(draft_id)
        if status:
            clauses.append("LOWER(l.status) = LOWER(?)")
            params.append(status)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        params.extend([limit, offset])

        with self._connect() as connection:
            rows = connection.execute(
                f"""
                SELECT
                    l.id,
                    l.draft_id,
                    l.recipient_email,
                    l.status,
                    l.provider_message_id,
                    l.error,
                    l.sent_at,
                    d.import_id,
                    d.session_key,
                    d.email_type,
                    d.subject
                FROM training_email_send_logs AS l
                LEFT JOIN training_email_drafts AS d
                    ON d.id = l.draft_id
                {where}
                ORDER BY l.sent_at DESC, l.id DESC
                LIMIT ? OFFSET ?
                """,
                params,
            ).fetchall()
        return [
            {
                "id": int(row["id"]),
                "draft_id": int(row["draft_id"] or 0),
                "import_id": row["import_id"] or "",
                "session_key": row["session_key"] or "",
                "email_type": row["email_type"] or "",
                "subject": row["subject"] or "",
                "recipient_email": row["recipient_email"] or "",
                "status": row["status"] or "",
                "provider_message_id": row["provider_message_id"] or "",
                "error": row["error"] or "",
                "sent_at": row["sent_at"] or "",
            }
            for row in rows
        ]

    def _update_draft_status(
        self,
        draft_id: int,
        *,
        status: str,
        metadata: dict[str, Any],
    ) -> dict[str, Any] | None:
        with self._connect() as connection:
            connection.execute(
                """
                UPDATE training_email_drafts
                SET
                    status = ?,
                    metadata_json = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (status, _json(metadata), draft_id),
            )
            connection.commit()
        return self.get_training_draft(draft_id)

    def _insert_session(
        self,
        connection: sqlite3.Connection,
        import_id: str,
        file_id: int,
        session: TrainingSession,
    ) -> int:
        cursor = connection.execute(
            """
            INSERT INTO training_sessions (
                import_id,
                file_id,
                session_key,
                code_session,
                lms_session_number,
                malek_number,
                status,
                axis,
                domain,
                project,
                training_type,
                training_mode,
                certification_nature,
                module_code,
                module,
                cabinet,
                trainer,
                selected_trainer,
                year,
                month,
                week,
                duration_days,
                start_date,
                end_date,
                schedule,
                hours_per_day,
                total_hours,
                location,
                accommodation_location,
                responsible_engagement,
                candidate_count,
                source_file,
                source_sheet,
                source_rows_json,
                missing_fields_json
            )
            VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            (
                import_id,
                file_id,
                session.session_key,
                session.code_session,
                session.lms_session_number,
                session.malek_number,
                session.status,
                session.axis,
                session.domain,
                session.project,
                session.training_type,
                session.training_mode,
                session.certification_nature,
                session.module_code,
                session.module,
                session.cabinet,
                session.trainer,
                session.selected_trainer,
                session.year,
                session.month,
                session.week,
                session.duration_days,
                session.start_date,
                session.end_date,
                session.schedule,
                session.hours_per_day,
                session.total_hours,
                session.location,
                session.accommodation_location,
                session.responsible_engagement,
                session.candidate_count,
                session.source_file,
                session.source_sheet,
                _json(session.source_rows),
                _json(session.missing_fields),
            ),
        )
        session_id = int(cursor.lastrowid)
        for participant in session.participants:
            self._insert_participant(
                connection,
                import_id,
                session_id,
                session.session_key,
                participant,
                session.source_file,
            )
        return session_id

    def _insert_participant(
        self,
        connection: sqlite3.Connection,
        import_id: str,
        session_id: int,
        session_key: str,
        participant: PlanningParticipant,
        source_file: str,
    ) -> None:
        connection.execute(
            """
            INSERT INTO training_participants (
                import_id,
                session_id,
                session_key,
                matricule,
                full_name,
                email,
                residence,
                direction,
                hr_responsible,
                source_row,
                missing_fields_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                import_id,
                session_id,
                session_key,
                participant.matricule,
                participant.full_name,
                participant.email,
                participant.residence,
                participant.direction,
                participant.hr_responsible,
                participant.source_row,
                _json(participant.missing_fields),
            ),
        )
        if participant.matricule and participant.email:
            connection.execute(
                """
                INSERT INTO employee_contacts (
                    matricule,
                    normalized_name,
                    full_name,
                    email,
                    residence,
                    direction,
                    hr_responsible,
                    source_file,
                    source_row,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(matricule) DO UPDATE SET
                    normalized_name = excluded.normalized_name,
                    full_name = excluded.full_name,
                    email = CASE
                        WHEN excluded.email != '' THEN excluded.email
                        ELSE employee_contacts.email
                    END,
                    residence = CASE
                        WHEN excluded.residence != '' THEN excluded.residence
                        ELSE employee_contacts.residence
                    END,
                    direction = CASE
                        WHEN excluded.direction != '' THEN excluded.direction
                        ELSE employee_contacts.direction
                    END,
                    hr_responsible = CASE
                        WHEN excluded.hr_responsible != '' THEN excluded.hr_responsible
                        ELSE employee_contacts.hr_responsible
                    END,
                    source_file = excluded.source_file,
                    source_row = excluded.source_row,
                    updated_at = CURRENT_TIMESTAMP
                """,
                (
                    participant.matricule,
                    _normalize_participant_name(participant.full_name),
                    participant.full_name,
                    participant.email,
                    participant.residence,
                    participant.direction,
                    participant.hr_responsible,
                    source_file,
                    participant.source_row,
                ),
            )

    def _participant_exists(
        self,
        connection: sqlite3.Connection,
        session_id: int,
        participant: PlanningParticipant,
    ) -> bool:
        if participant.matricule:
            row = connection.execute(
                """
                SELECT id
                FROM training_participants
                WHERE session_id = ? AND matricule = ?
                LIMIT 1
                """,
                (session_id, participant.matricule),
            ).fetchone()
            return row is not None
        if participant.email:
            row = connection.execute(
                """
                SELECT id
                FROM training_participants
                WHERE session_id = ? AND lower(email) = lower(?)
                LIMIT 1
                """,
                (session_id, participant.email),
            ).fetchone()
            return row is not None
        if participant.full_name:
            row = connection.execute(
                """
                SELECT id
                FROM training_participants
                WHERE session_id = ? AND full_name = ?
                LIMIT 1
                """,
                (session_id, participant.full_name),
            ).fetchone()
            return row is not None
        return False

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        try:
            yield connection
        finally:
            connection.close()

    def _ensure_column(
        self,
        connection: sqlite3.Connection,
        table: str,
        column: str,
        definition: str,
    ) -> None:
        existing = {
            row["name"]
            for row in connection.execute(f"PRAGMA table_info({table})").fetchall()
        }
        if column not in existing:
            connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")

    def _affected_import_ids(
        self,
        connection: sqlite3.Connection,
        import_id: str | None,
    ) -> list[str]:
        if import_id:
            return [import_id]
        rows = connection.execute("SELECT import_id FROM planning_imports").fetchall()
        return [row["import_id"] for row in rows]

    def _refresh_import_counts(
        self,
        connection: sqlite3.Connection,
        import_id: str,
    ) -> None:
        counts = connection.execute(
            """
            SELECT
                COUNT(*) AS total_participants,
                SUM(CASE WHEN email = '' THEN 1 ELSE 0 END) AS missing_email_count
            FROM training_participants
            WHERE import_id = ?
            """,
            (import_id,),
        ).fetchone()
        session_count = connection.execute(
            """
            SELECT COUNT(*) AS total_sessions
            FROM training_sessions
            WHERE import_id = ?
            """,
            (import_id,),
        ).fetchone()
        missing_email_count = int(counts["missing_email_count"] or 0)
        current = connection.execute(
            """
            SELECT warning_count, error_count
            FROM planning_imports
            WHERE import_id = ?
            """,
            (import_id,),
        ).fetchone()
        if current is None:
            return
        if int(current["error_count"] or 0):
            status = "error"
        elif int(current["warning_count"] or 0) or missing_email_count:
            status = "needs_review"
        else:
            status = "ok"
        connection.execute(
            """
            UPDATE planning_imports
            SET
                total_sessions = ?,
                total_participants = ?,
                missing_email_count = ?,
                status = ?
            WHERE import_id = ?
            """,
            (
                int(session_count["total_sessions"] or 0),
                int(counts["total_participants"] or 0),
                missing_email_count,
                status,
                import_id,
            ),
        )

    def _import_summary(
        self,
        connection: sqlite3.Connection,
        row: sqlite3.Row,
    ) -> dict[str, Any]:
        file_rows = connection.execute(
            """
            SELECT
                filename,
                status,
                warnings_json,
                errors_json,
                (
                    SELECT COUNT(*)
                    FROM training_sessions s
                    WHERE s.file_id = planning_files.id
                ) AS session_count
            FROM planning_files
            WHERE import_id = ?
            ORDER BY id
            """,
            (row["import_id"],),
        ).fetchall()
        return {
            "import_id": row["import_id"],
            "created_at": row["created_at"],
            "status": row["status"],
            "total_sessions": row["total_sessions"],
            "total_participants": row["total_participants"],
            "missing_email_count": row["missing_email_count"],
            "warning_count": row["warning_count"],
            "error_count": row["error_count"],
            "files": [
                {
                    "filename": file_row["filename"],
                    "status": file_row["status"],
                    "sessions": file_row["session_count"],
                    "warnings": len(_loads(file_row["warnings_json"])),
                    "errors": len(_loads(file_row["errors_json"])),
                }
                for file_row in file_rows
            ],
        }

    def _session_to_dict(
        self,
        connection: sqlite3.Connection,
        row: sqlite3.Row,
    ) -> dict[str, Any]:
        data = self._session_base_dict(row)
        participant_rows = connection.execute(
            """
            SELECT *
            FROM training_participants
            WHERE session_id = ?
            ORDER BY source_row, full_name, id
            """,
            (row["id"],),
        ).fetchall()
        data["participants"] = [
            {
                "matricule": participant["matricule"],
                "full_name": participant["full_name"],
                "email": participant["email"],
                "residence": participant["residence"],
                "direction": participant["direction"],
                "hr_responsible": participant["hr_responsible"],
                "source_row": participant["source_row"],
                "missing_fields": _loads(participant["missing_fields_json"]),
            }
            for participant in participant_rows
        ]
        return data

    def _session_summary(self, row: sqlite3.Row) -> dict[str, Any]:
        data = self._session_base_dict(row)
        data["participant_count"] = row["participant_count"] or 0
        data["missing_email_count"] = row["missing_email_count"] or 0
        return data

    def _session_base_dict(self, row: sqlite3.Row) -> dict[str, Any]:
        return {
            "import_id": row["import_id"],
            "session_key": row["session_key"],
            "code_session": row["code_session"],
            "lms_session_number": row["lms_session_number"],
            "malek_number": row["malek_number"],
            "status": row["status"],
            "axis": row["axis"],
            "domain": row["domain"],
            "project": row["project"],
            "training_type": row["training_type"],
            "training_mode": row["training_mode"],
            "certification_nature": row["certification_nature"],
            "module_code": row["module_code"],
            "module": row["module"],
            "cabinet": row["cabinet"],
            "trainer": row["trainer"],
            "selected_trainer": row["selected_trainer"],
            "year": row["year"],
            "month": row["month"],
            "week": row["week"],
            "duration_days": row["duration_days"],
            "start_date": row["start_date"],
            "end_date": row["end_date"],
            "schedule": row["schedule"],
            "hours_per_day": row["hours_per_day"],
            "total_hours": row["total_hours"],
            "location": row["location"],
            "accommodation_location": row["accommodation_location"],
            "responsible_engagement": row["responsible_engagement"],
            "candidate_count": row["candidate_count"],
            "source_file": row["source_file"],
            "source_sheet": row["source_sheet"],
            "source_rows": _loads(row["source_rows_json"]),
            "missing_fields": _loads(row["missing_fields_json"]),
        }

    def _draft_row(self, row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "import_id": row["import_id"] or "",
            "session_key": row["session_key"],
            "email_type": row["email_type"],
            "subject": row["subject"],
            "body": row["body"],
            "html_body": row["html_body"],
            "recipients": _loads(row["recipients_json"]),
            "cc": _loads(row["cc_json"]),
            "status": row["status"],
            "metadata": _loads(row["metadata_json"]) or {},
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }


def sanitize_import_id(import_id: str) -> str:
    return "".join(char for char in import_id if char.isalnum() or char in ("-", "_"))


def _json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def _loads(value: str) -> Any:
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return []


def _clean_emails(values: list[str]) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()
    for value in values:
        email = str(value).strip()
        key = email.lower()
        if not email or key in seen:
            continue
        cleaned.append(email)
        seen.add(key)
    return cleaned


def _utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _contact_key(contact: EmployeeContact) -> str:
    if contact.matricule:
        return contact.matricule
    if contact.normalized_name:
        return f"name:{contact.normalized_name}"
    return ""


def _contact_row(row: sqlite3.Row) -> dict[str, Any]:
    matricule = str(row["matricule"] or "")
    return {
        "matricule": "" if matricule.startswith("name:") else matricule,
        "normalized_name": row["normalized_name"],
        "full_name": row["full_name"],
        "email": row["email"],
        "residence": row["residence"],
        "direction": row["direction"],
        "hr_responsible": row["hr_responsible"],
        "source_file": row["source_file"],
        "source_row": row["source_row"],
        "updated_at": row["updated_at"],
    }


def _normalize_participant_name(value: str) -> str:
    return normalize_name(value)
