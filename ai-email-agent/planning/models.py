from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any


@dataclass(slots=True)
class PlanningParticipant:
    matricule: str = ""
    full_name: str = ""
    email: str = ""
    residence: str = ""
    direction: str = ""
    hr_responsible: str = ""
    source_row: int = 0
    missing_fields: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(slots=True)
class TrainingSession:
    session_key: str
    code_session: str = ""
    lms_session_number: str = ""
    malek_number: str = ""
    status: str = "UNKNOWN"
    axis: str = ""
    domain: str = ""
    project: str = ""
    training_type: str = ""
    training_mode: str = ""
    certification_nature: str = ""
    module_code: str = ""
    module: str = ""
    cabinet: str = ""
    trainer: str = ""
    selected_trainer: str = ""
    year: str = ""
    month: str = ""
    week: str = ""
    duration_days: str = ""
    start_date: str = ""
    end_date: str = ""
    schedule: str = ""
    hours_per_day: str = ""
    total_hours: str = ""
    location: str = ""
    accommodation_location: str = ""
    responsible_engagement: str = ""
    candidate_count: str = ""
    source_file: str = ""
    source_sheet: str = ""
    source_rows: list[int] = field(default_factory=list)
    participants: list[PlanningParticipant] = field(default_factory=list)
    missing_fields: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["participants"] = [participant.to_dict() for participant in self.participants]
        return data


@dataclass(slots=True)
class PlanningFileResult:
    filename: str
    status: str
    sheets: list[str]
    sessions: list[TrainingSession] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["sessions"] = [session.to_dict() for session in self.sessions]
        return data


@dataclass(slots=True)
class PlanningImportResult:
    import_id: str
    created_at: str
    status: str
    files: list[PlanningFileResult]
    total_sessions: int
    total_participants: int
    missing_email_count: int
    warning_count: int
    error_count: int

    def to_dict(self) -> dict[str, Any]:
        data = asdict(self)
        data["files"] = [file_result.to_dict() for file_result in self.files]
        return data

    @classmethod
    def build(cls, import_id: str, files: list[PlanningFileResult]) -> "PlanningImportResult":
        total_sessions = sum(len(file_result.sessions) for file_result in files)
        total_participants = sum(
            len(session.participants)
            for file_result in files
            for session in file_result.sessions
        )
        missing_email_count = sum(
            1
            for file_result in files
            for session in file_result.sessions
            for participant in session.participants
            if "email" in participant.missing_fields
        )
        warning_count = sum(len(file_result.warnings) for file_result in files)
        error_count = sum(len(file_result.errors) for file_result in files)
        if error_count:
            status = "error"
        elif warning_count or missing_email_count:
            status = "needs_review"
        else:
            status = "ok"
        return cls(
            import_id=import_id,
            created_at=datetime.now(timezone.utc).isoformat(),
            status=status,
            files=files,
            total_sessions=total_sessions,
            total_participants=total_participants,
            missing_email_count=missing_email_count,
            warning_count=warning_count,
            error_count=error_count,
        )
