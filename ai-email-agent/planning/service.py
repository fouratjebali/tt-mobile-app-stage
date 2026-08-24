from __future__ import annotations

import json
import os
import uuid
from pathlib import Path
from typing import Any

from planning.models import PlanningImportResult
from planning.parser import PlanningExcelParser


DEFAULT_IMPORT_DIR = Path(__file__).resolve().parents[1] / "data" / "planning_imports"


class PlanningImportService:
    def __init__(
        self,
        *,
        parser: PlanningExcelParser | None = None,
        storage_dir: Path | None = None,
    ) -> None:
        configured_dir = os.getenv("PLANNING_IMPORT_DIR", "").strip()
        self.storage_dir = storage_dir or Path(configured_dir or DEFAULT_IMPORT_DIR)
        self.parser = parser or PlanningExcelParser()

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
        self._save_result(result)
        return result

    def list_imports(self) -> list[dict[str, Any]]:
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        summaries: list[dict[str, Any]] = []
        for path in sorted(self.storage_dir.glob("*.json"), reverse=True):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            summaries.append(
                {
                    "import_id": data.get("import_id", path.stem),
                    "created_at": data.get("created_at", ""),
                    "status": data.get("status", "unknown"),
                    "total_sessions": data.get("total_sessions", 0),
                    "total_participants": data.get("total_participants", 0),
                    "missing_email_count": data.get("missing_email_count", 0),
                    "warning_count": data.get("warning_count", 0),
                    "error_count": data.get("error_count", 0),
                    "files": [
                        {
                            "filename": item.get("filename", ""),
                            "status": item.get("status", "unknown"),
                            "sessions": len(item.get("sessions", [])),
                            "warnings": len(item.get("warnings", [])),
                            "errors": len(item.get("errors", [])),
                        }
                        for item in data.get("files", [])
                    ],
                }
            )
        return summaries

    def get_import(self, import_id: str) -> dict[str, Any] | None:
        safe_id = "".join(char for char in import_id if char.isalnum() or char in ("-", "_"))
        if not safe_id:
            return None
        path = self.storage_dir / f"{safe_id}.json"
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None

    def _save_result(self, result: PlanningImportResult) -> None:
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        path = self.storage_dir / f"{result.import_id}.json"
        path.write_text(
            json.dumps(result.to_dict(), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
