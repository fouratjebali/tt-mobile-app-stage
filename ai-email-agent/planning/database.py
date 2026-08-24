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
from planning.models import PlanningImportResult, TrainingSession
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
                """
            )
            self._ensure_column(connection, "employee_contacts", "normalized_name", "TEXT NOT NULL DEFAULT ''")
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

    def save_contacts(self, contacts: list[EmployeeContact]) -> dict[str, Any]:
        imported = 0
        skipped = 0
        with self._connect() as connection:
            for contact in contacts:
                contact_key = _contact_key(contact)
                if not contact_key or not contact.email:
                    skipped += 1
                    continue
                connection.execute(
                    """
                    INSERT INTO employee_contacts (
                        matricule,
                        normalized_name,
                        full_name,
                        email,
                        direction,
                        hr_responsible,
                        source_file,
                        source_row,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                    ON CONFLICT(matricule) DO UPDATE SET
                        normalized_name = excluded.normalized_name,
                        full_name = excluded.full_name,
                        email = excluded.email,
                        direction = excluded.direction,
                        hr_responsible = excluded.hr_responsible,
                        source_file = excluded.source_file,
                        source_row = excluded.source_row,
                        updated_at = CURRENT_TIMESTAMP
                    """,
                    (
                        contact_key,
                        contact.normalized_name,
                        contact.full_name,
                        contact.email,
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
                SELECT matricule, normalized_name, email, direction, hr_responsible
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
                        direction = COALESCE(NULLIF(direction, ''), ?),
                        hr_responsible = COALESCE(NULLIF(hr_responsible, ''), ?),
                        missing_fields_json = ?
                    WHERE id = ?
                    """,
                    (
                        contact["email"],
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
        status: str | None = None,
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
            clauses.append("status = ?")
            params.append(status)
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
    ) -> None:
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
                    session.session_key,
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
                        direction,
                        hr_responsible,
                        source_file,
                        source_row,
                        updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                    ON CONFLICT(matricule) DO UPDATE SET
                        normalized_name = excluded.normalized_name,
                        full_name = excluded.full_name,
                        email = excluded.email,
                        direction = excluded.direction,
                        hr_responsible = excluded.hr_responsible,
                        source_file = excluded.source_file,
                        source_row = excluded.source_row,
                        updated_at = CURRENT_TIMESTAMP
                    """,
                    (
                        participant.matricule,
                        _normalize_participant_name(participant.full_name),
                        participant.full_name,
                        participant.email,
                        participant.direction,
                        participant.hr_responsible,
                        session.source_file,
                        participant.source_row,
                    ),
                )

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
                total_participants = ?,
                missing_email_count = ?,
                status = ?
            WHERE import_id = ?
            """,
            (
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
        "direction": row["direction"],
        "hr_responsible": row["hr_responsible"],
        "source_file": row["source_file"],
        "source_row": row["source_row"],
        "updated_at": row["updated_at"],
    }


def _normalize_participant_name(value: str) -> str:
    return normalize_name(value)
