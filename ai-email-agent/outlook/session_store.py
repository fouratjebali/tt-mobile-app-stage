from __future__ import annotations

import secrets
import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

from planning.database import DEFAULT_DB_PATH


@dataclass(frozen=True)
class OutlookSession:
    session_token: str
    access_token: str
    refresh_token: str
    expires_at: str
    user_id: str
    email: str
    display_name: str
    photo_url: str


class OutlookSessionStore:
    def __init__(self, db_path: Path | str | None = None) -> None:
        self.db_path = Path(db_path or DEFAULT_DB_PATH)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.initialize()

    def initialize(self) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS outlook_sessions (
                    session_token TEXT PRIMARY KEY,
                    access_token TEXT NOT NULL,
                    refresh_token TEXT NOT NULL DEFAULT '',
                    expires_at TEXT NOT NULL DEFAULT '',
                    user_id TEXT NOT NULL DEFAULT '',
                    email TEXT NOT NULL DEFAULT '',
                    display_name TEXT NOT NULL DEFAULT '',
                    photo_url TEXT NOT NULL DEFAULT '',
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
                """
            )

    def create_session(
        self,
        *,
        access_token: str,
        refresh_token: str = "",
        expires_at: str = "",
        user_id: str = "",
        email: str = "",
        display_name: str = "",
        photo_url: str = "",
    ) -> OutlookSession:
        session_token = secrets.token_urlsafe(32)
        if not expires_at:
            expires_at = _default_expires_at()
        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO outlook_sessions (
                    session_token,
                    access_token,
                    refresh_token,
                    expires_at,
                    user_id,
                    email,
                    display_name,
                    photo_url,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """,
                (
                    session_token,
                    access_token,
                    refresh_token,
                    expires_at,
                    user_id,
                    email,
                    display_name,
                    photo_url,
                ),
            )
            connection.commit()
        session = self.get_session(session_token)
        if session is None:
            raise RuntimeError("Outlook session could not be stored.")
        return session

    def get_session(self, session_token: str) -> OutlookSession | None:
        if not session_token.strip():
            return None
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT *
                FROM outlook_sessions
                WHERE session_token = ?
                """,
                (session_token.strip(),),
            ).fetchone()
        return _session_from_row(row) if row is not None else None

    def update_tokens(
        self,
        session_token: str,
        *,
        access_token: str,
        refresh_token: str = "",
        expires_at: str = "",
    ) -> OutlookSession | None:
        with self._connect() as connection:
            connection.execute(
                """
                UPDATE outlook_sessions
                SET
                    access_token = ?,
                    refresh_token = CASE WHEN ? = '' THEN refresh_token ELSE ? END,
                    expires_at = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE session_token = ?
                """,
                (
                    access_token,
                    refresh_token,
                    refresh_token,
                    expires_at or _default_expires_at(),
                    session_token,
                ),
            )
            connection.commit()
        return self.get_session(session_token)

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.db_path)
        connection.row_factory = sqlite3.Row
        try:
            yield connection
        finally:
            connection.close()


def is_expiring_soon(expires_at: str, *, within_seconds: int = 120) -> bool:
    expires = _parse_datetime(expires_at)
    if expires is None:
        return False
    return expires <= datetime.now(timezone.utc) + timedelta(seconds=within_seconds)


def _session_from_row(row: sqlite3.Row) -> OutlookSession:
    return OutlookSession(
        session_token=row["session_token"],
        access_token=row["access_token"],
        refresh_token=row["refresh_token"],
        expires_at=row["expires_at"],
        user_id=row["user_id"],
        email=row["email"],
        display_name=row["display_name"],
        photo_url=row["photo_url"],
    )


def _parse_datetime(value: str) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _default_expires_at() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        + timedelta(minutes=50)
    ).isoformat()
