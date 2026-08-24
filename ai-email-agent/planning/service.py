from __future__ import annotations

import uuid
from pathlib import Path
from typing import Any

from planning.database import PlanningDatabase, sanitize_import_id
from planning.models import PlanningImportResult
from planning.parser import PlanningExcelParser


class PlanningImportService:
    def __init__(
        self,
        *,
        parser: PlanningExcelParser | None = None,
        database: PlanningDatabase | None = None,
        db_path: Path | str | None = None,
    ) -> None:
        self.parser = parser or PlanningExcelParser()
        self.database = database or PlanningDatabase(db_path)

    def import_files(self, files: list[tuple[str, bytes]]) -> PlanningImportResult:
        if not files:
            raise ValueError("At least one planning file is required.")
        if len(files) > 5:
            raise ValueError("A maximum of 5 planning files can be imported at once.")

        import_id = uuid.uuid4().hex
        file_results = [
            self.parser.parse_workbook(filename=filename, content=content)
            for filename, content in files
        ]
        result = PlanningImportResult.build(import_id=import_id, files=file_results)
        self.database.save_import(result)
        return result

    def list_imports(self) -> list[dict[str, Any]]:
        return self.database.list_imports()

    def get_import(self, import_id: str) -> dict[str, Any] | None:
        safe_id = sanitize_import_id(import_id)
        if not safe_id:
            return None
        return self.database.get_import(safe_id)

    def list_sessions(
        self,
        *,
        import_id: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.list_sessions(
            import_id=safe_import_id,
            limit=limit,
            offset=offset,
        )

    def get_session(
        self,
        session_key: str,
        *,
        import_id: str | None = None,
    ) -> dict[str, Any] | None:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.get_session(session_key, import_id=safe_import_id)

    def list_missing_contacts(
        self,
        *,
        import_id: str | None = None,
        limit: int = 200,
    ) -> list[dict[str, Any]]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.list_missing_contacts(
            import_id=safe_import_id,
            limit=limit,
        )
