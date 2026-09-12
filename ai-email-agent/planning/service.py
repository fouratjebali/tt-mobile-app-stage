from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

from planning.contact_parser import ContactDirectoryParser, EmployeeContact
from planning.database import PlanningDatabase, sanitize_import_id
from planning.models import (
    PlanningFileResult,
    PlanningImportResult,
    PlanningParticipant,
    TrainingSession,
)
from planning.parser import PlanningExcelParser
from planning.training_agent import FrenchTrainingAgent


class PlanningImportService:
    def __init__(
        self,
        *,
        parser: PlanningExcelParser | None = None,
        contact_parser: ContactDirectoryParser | None = None,
        training_agent: FrenchTrainingAgent | None = None,
        database: PlanningDatabase | None = None,
        db_path: Path | str | None = None,
    ) -> None:
        self.parser = parser or PlanningExcelParser()
        self.contact_parser = contact_parser or ContactDirectoryParser()
        self.training_agent = training_agent or FrenchTrainingAgent()
        self.database = database or PlanningDatabase(db_path)

    def get_automation_settings(self) -> dict[str, Any]:
        return self.database.get_automation_settings()

    def update_automation_settings(
        self,
        *,
        auto_run_after_import: bool | None = None,
        default_email_type: str | None = None,
        include_population: bool | None = None,
        max_drafts_per_run: int | None = None,
    ) -> dict[str, Any]:
        return self.database.update_automation_settings(
            auto_run_after_import=auto_run_after_import,
            default_email_type=default_email_type,
            include_population=include_population,
            max_drafts_per_run=max_drafts_per_run,
        )

    def import_files(self, files: list[tuple[str, bytes]]) -> PlanningImportResult:
        if not files:
            raise ValueError("At least one planning file is required.")
        if len(files) > 5:
            raise ValueError("A maximum of 5 planning files can be imported at once.")

        result = self.preview_import_files(files)
        self.database.save_import(result)
        return result

    def preview_import_files(self, files: list[tuple[str, bytes]]) -> PlanningImportResult:
        if not files:
            raise ValueError("At least one planning file is required.")
        if len(files) > 5:
            raise ValueError("A maximum of 5 planning files can be imported at once.")

        import_id = uuid.uuid4().hex
        file_results = [
            self.parser.parse_workbook(filename=filename, content=content)
            for filename, content in files
        ]
        self._merge_session_catalogue_and_candidates(file_results)
        return PlanningImportResult.build(import_id=import_id, files=file_results)

    def _merge_session_catalogue_and_candidates(
        self,
        file_results: list[PlanningFileResult],
    ) -> None:
        grouped: dict[str, list[tuple[PlanningFileResult, TrainingSession]]] = {}
        for file_result in file_results:
            for session in file_result.sessions:
                key = self._session_merge_key(session)
                grouped.setdefault(key, []).append((file_result, session))

        for group in grouped.values():
            if len(group) < 2:
                continue

            primary_file, primary_session = max(
                group,
                key=lambda item: self._session_detail_score(item[1]),
            )
            seen_participants = {
                self._participant_key(participant)
                for participant in primary_session.participants
            }

            for file_result, session in group:
                if session is primary_session:
                    continue
                self._fill_missing_session_fields(primary_session, session)
                primary_session.source_rows.extend(
                    row
                    for row in session.source_rows
                    if row not in primary_session.source_rows
                )
                for participant in session.participants:
                    participant_key = self._participant_key(participant)
                    if participant_key in seen_participants:
                        continue
                    primary_session.participants.append(participant)
                    seen_participants.add(participant_key)
                file_result.sessions = [
                    item for item in file_result.sessions if item is not session
                ]

            if primary_file.status == "ok" and any(
                "responsible_email" in participant.missing_fields
                for participant in primary_session.participants
            ):
                primary_file.status = "needs_review"

        for file_result in file_results:
            self._refresh_file_status(file_result)

    def _session_merge_key(self, session: TrainingSession) -> str:
        if session.code_session.strip():
            return f"code:{session.code_session.strip().lower()}"
        return f"session:{session.session_key}"

    def _session_detail_score(self, session: TrainingSession) -> int:
        fields = (
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
        )
        return sum(1 for value in fields if str(value).strip())

    def _fill_missing_session_fields(
        self,
        primary: TrainingSession,
        secondary: TrainingSession,
    ) -> None:
        for field_name in (
            "code_session",
            "lms_session_number",
            "malek_number",
            "status",
            "axis",
            "domain",
            "project",
            "training_type",
            "training_mode",
            "certification_nature",
            "module_code",
            "module",
            "cabinet",
            "trainer",
            "selected_trainer",
            "year",
            "month",
            "week",
            "duration_days",
            "start_date",
            "end_date",
            "schedule",
            "hours_per_day",
            "total_hours",
            "location",
            "accommodation_location",
            "responsible_engagement",
            "candidate_count",
        ):
            current = str(getattr(primary, field_name)).strip()
            replacement = str(getattr(secondary, field_name)).strip()
            if not current and replacement:
                setattr(primary, field_name, replacement)

    def _participant_key(self, participant: PlanningParticipant) -> str:
        if participant.matricule.strip():
            return f"matricule:{participant.matricule.strip().lower()}"
        if participant.email.strip():
            return f"email:{participant.email.strip().lower()}"
        return f"name:{participant.full_name.strip().lower()}:{participant.source_row}"

    def _refresh_file_status(self, file_result: PlanningFileResult) -> None:
        if file_result.errors:
            file_result.status = "error"
        elif file_result.warnings or any(
            session.missing_fields
            or any(participant.missing_fields for participant in session.participants)
            for session in file_result.sessions
        ):
            file_result.status = "needs_review"
        else:
            file_result.status = "ok"

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
        year: str | int | None = None,
        month: str | int | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        status: str | None = None,
        domain: str | None = None,
        training_mode: str | None = None,
        training_type: str | None = None,
        cabinet: str | None = None,
        location: str | None = None,
        responsible: str | None = None,
        search: str | None = None,
        has_participants: bool | None = None,
        missing_contacts: bool | None = None,
        sort_by: str = "start_date",
        sort_direction: str = "asc",
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.list_sessions(
            import_id=safe_import_id,
            year=year,
            month=month,
            date_from=date_from,
            date_to=date_to,
            status=status,
            domain=domain,
            training_mode=training_mode,
            training_type=training_type,
            cabinet=cabinet,
            location=location,
            responsible=responsible,
            search=search,
            has_participants=has_participants,
            missing_contacts=missing_contacts,
            sort_by=sort_by,
            sort_direction=sort_direction,
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

    def list_contact_reviews(
        self,
        *,
        import_id: str | None = None,
        review_only: bool = False,
        limit: int = 200,
        offset: int = 0,
    ) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.list_contact_reviews(
            import_id=safe_import_id,
            review_only=review_only,
            limit=limit,
            offset=offset,
        )

    def import_contacts(self, files: list[tuple[str, bytes]]) -> dict[str, Any]:
        if not files:
            raise ValueError("At least one responsible contact file is required.")
        if len(files) > 5:
            raise ValueError("A maximum of 5 responsible contact files can be imported at once.")

        file_results = [
            self.contact_parser.parse_file(filename=filename, content=content)
            for filename, content in files
        ]
        contacts = [
            contact
            for file_result in file_results
            for contact in file_result.contacts
        ]
        saved = self.database.save_contacts(contacts)
        status = "ok" if contacts else "error"
        if any(file_result.errors for file_result in file_results):
            status = "partial" if contacts else "error"
        return {
            "status": status,
            "imported": saved["imported"],
            "skipped": saved["skipped"]
            + sum(file_result.skipped_count for file_result in file_results),
            "files": [file_result.to_dict() for file_result in file_results],
        }

    def import_candidates_for_import(
        self,
        *,
        import_id: str,
        files: list[tuple[str, bytes]],
    ) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id)
        if not safe_import_id:
            raise ValueError("A valid planning import id is required.")
        if not files:
            raise ValueError("At least one candidate file is required.")
        if len(files) > 5:
            raise ValueError("A maximum of 5 candidate files can be imported at once.")

        file_results = [
            self.parser.parse_workbook(filename=filename, content=content)
            for filename, content in files
        ]
        result = self.database.add_candidate_files(
            import_id=safe_import_id,
            files=file_results,
        )
        mapping = self.database.apply_contact_mapping(import_id=safe_import_id)
        return {
            "status": "ok",
            **result,
            "mapped_contacts": mapping["mapped"],
            "unmatched_contacts": mapping["unmatched"],
            "files": [file_result.to_dict() for file_result in file_results],
        }

    def list_contacts(self, *, limit: int = 200, offset: int = 0) -> list[dict[str, Any]]:
        return self.database.list_contacts(limit=limit, offset=offset)

    def list_responsibles(
        self,
        *,
        search: str | None = None,
        role: str | None = None,
        residence: str | None = None,
        direction: str | None = None,
        has_email: bool | None = None,
        duplicate_emails: bool | None = None,
        source_file: str | None = None,
        limit: int = 200,
        offset: int = 0,
    ) -> dict[str, Any]:
        return self.database.list_responsibles(
            search=search,
            role=role,
            residence=residence,
            direction=direction,
            has_email=has_email,
            duplicate_emails=duplicate_emails,
            source_file=source_file,
            limit=limit,
            offset=offset,
        )

    def get_responsible(self, contact_key: str) -> dict[str, Any] | None:
        return self.database.get_responsible(contact_key)

    def save_responsible(
        self,
        *,
        role: str,
        residence: str,
        email: str,
        full_name: str = "",
        direction: str = "",
        hr_responsible: str = "",
    ) -> dict[str, Any]:
        return self.database.save_responsible(
            role=role,
            residence=residence,
            email=email,
            full_name=full_name,
            direction=direction,
            hr_responsible=hr_responsible,
            source_file="admin",
        )

    def delete_responsible(self, contact_key: str) -> bool:
        return self.database.delete_responsible(contact_key)

    def apply_contact_mapping(self, *, import_id: str | None = None) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.apply_contact_mapping(import_id=safe_import_id)

    def save_contact(
        self,
        *,
        matricule: str = "",
        full_name: str = "",
        email: str,
        direction: str = "",
        hr_responsible: str = "",
        source_file: str = "mobile",
    ) -> dict[str, Any]:
        cleaned_email = email.strip().lower()
        if "@" not in cleaned_email:
            raise ValueError("A valid email address is required.")
        if not matricule.strip() and not full_name.strip():
            raise ValueError("A matricule or employee name is required.")

        contact = EmployeeContact(
            matricule=matricule.strip(),
            full_name=full_name.strip(),
            email=cleaned_email,
            direction=direction.strip(),
            hr_responsible=hr_responsible.strip(),
            source_file=source_file,
        )
        return self.database.save_contacts([contact])

    def generate_training_drafts(
        self,
        *,
        import_id: str | None = None,
        session_key: str | None = None,
        email_type: str = "auto",
        include_population: bool = True,
        limit: int = 100,
        skip_existing: bool = False,
        replace_existing: bool = False,
        upcoming_days: int | None = 7,
        responsables: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        deleted_existing = 0
        if replace_existing and safe_import_id:
            deleted_existing = self.database.delete_editable_training_drafts(
                import_id=safe_import_id,
                session_key=session_key,
            )
            skip_existing = False
        if session_key:
            session = self.database.get_session(session_key, import_id=safe_import_id)
            sessions = [session] if session is not None else []
            window = {
                "mode": "single_session",
                "date_from": None,
                "date_to": None,
                "target_date": None,
            }
        else:
            sessions, window = self._select_sessions_for_draft_window(
                import_id=safe_import_id,
                upcoming_days=upcoming_days,
                limit=limit,
            )
        sessions = [session for session in sessions if self._can_generate_training_draft(session)]

        drafts = []
        skipped = 0
        errors = []
        for session in sessions:
            existing_keys: set[str] = set()
            if skip_existing and safe_import_id:
                existing_keys = {
                    str(draft.get("metadata", {}).get("responsible_key") or "unassigned")
                    for draft in self.database.list_training_drafts(
                        import_id=safe_import_id,
                        session_key=session["session_key"],
                        limit=500,
                    )
                    if draft.get("status") != "REJECTED"
                }
            try:
                for group_session in self.training_agent.responsible_groups(
                    session,
                    responsables=responsables or [],
                ):
                    responsible_key = self.training_agent.responsible_key(group_session)
                    if skip_existing and responsible_key in existing_keys:
                        skipped += 1
                        continue
                    draft = self.training_agent.generate_draft(
                        group_session,
                        email_type=email_type,
                        include_population=include_population,
                    )
                    drafts.append(self.database.save_training_draft(draft))
            except ValueError as exc:
                errors.append(
                    {
                        "session_key": session.get("session_key", ""),
                        "error": str(exc),
                    }
                )

        return {
            "status": "ok" if not errors else "partial",
            "generated": len(drafts),
            "skipped_existing": skipped,
            "deleted_existing": deleted_existing,
            "upcoming_days": upcoming_days if session_key is None else None,
            "window": window,
            "errors": errors,
            "drafts": drafts,
        }

    def run_training_automation(
        self,
        *,
        import_id: str | None = None,
        email_type: str | None = None,
        include_population: bool | None = None,
        limit: int | None = None,
        replace_existing: bool = False,
        requested_by: str = "",
        upcoming_days: int | None = 7,
        responsables: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        automation_settings = self.database.get_automation_settings()
        configured_email_type = (
            str(automation_settings["default_email_type"] or "").strip().lower()
        )
        resolved_email_type = email_type or (
            "confirmation_presence"
            if configured_email_type == "auto"
            else configured_email_type
        )
        resolved_include_population = (
            automation_settings["include_population"]
            if include_population is None
            else include_population
        )
        resolved_limit = limit or automation_settings["max_drafts_per_run"]
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        if safe_import_id is None:
            imports = self.database.list_imports()
            safe_import_id = imports[0]["import_id"] if imports else None
        job = self.database.start_automation_job(
            job_type="draft_generation",
            import_id=safe_import_id or "",
            requested_by=requested_by,
            parameters={
                "import_id": safe_import_id or "",
                "email_type": resolved_email_type,
                "include_population": resolved_include_population,
                "limit": resolved_limit,
                "replace_existing": replace_existing,
                "upcoming_days": upcoming_days,
            },
        )
        job_id = int(job["id"])

        if not safe_import_id:
            result = {
                "status": "empty",
                "job_id": job_id,
                "import_id": "",
                "mapped": 0,
                "unmatched": 0,
                "generated": 0,
                "skipped_existing": 0,
                "errors": [],
                "drafts": [],
            }
            self.database.append_automation_job_log(
                job_id,
                level="warning",
                message="No planning import found for automation.",
            )
            self.database.finish_automation_job(job_id, status="EMPTY", result=result)
            return result

        try:
            self.database.append_automation_job_log(
                job_id,
                message="Applying responsible contact mapping.",
                context={"import_id": safe_import_id},
            )
            mapping = self.database.apply_contact_mapping(import_id=safe_import_id)
            self.database.append_automation_job_log(
                job_id,
                message="Responsible contact mapping finished.",
                context={
                    "mapped": mapping["mapped"],
                    "unmatched": mapping["unmatched"],
                },
            )
            generated = self.generate_training_drafts(
                import_id=safe_import_id,
                email_type=resolved_email_type,
                include_population=resolved_include_population,
                limit=resolved_limit,
                skip_existing=not replace_existing,
                replace_existing=replace_existing,
                upcoming_days=upcoming_days,
                responsables=responsables or [],
            )
            status = "ok"
            if generated["errors"]:
                status = "partial"
            result = {
                "status": status,
                "job_id": job_id,
                "import_id": safe_import_id,
                "mapped": mapping["mapped"],
                "unmatched": mapping["unmatched"],
                "generated": generated["generated"],
                "skipped_existing": generated["skipped_existing"],
                "deleted_existing": generated.get("deleted_existing", 0),
                "upcoming_days": generated.get("upcoming_days"),
                "window": generated.get("window"),
                "errors": generated["errors"],
                "settings": {
                    **automation_settings,
                    "default_email_type": resolved_email_type,
                    "include_population": resolved_include_population,
                    "max_drafts_per_run": resolved_limit,
                },
                "drafts": generated["drafts"],
            }
            self.database.append_automation_job_log(
                job_id,
                level="warning" if generated["errors"] else "info",
                message="Training draft generation finished.",
                context={
                    "generated": generated["generated"],
                    "skipped_existing": generated["skipped_existing"],
                    "deleted_existing": generated.get("deleted_existing", 0),
                    "error_count": len(generated["errors"]),
                },
            )
            self.database.finish_automation_job(
                job_id,
                status="PARTIAL" if generated["errors"] else "OK",
                result=result,
            )
            return result
        except Exception as exc:
            self.database.append_automation_job_log(
                job_id,
                level="error",
                message="Automation job stopped with an error.",
                context={"error": str(exc)},
            )
            self.database.finish_automation_job(
                job_id,
                status="ERROR",
                error=str(exc),
            )
            raise

    def list_automation_jobs(
        self,
        *,
        import_id: str | None = None,
        status: str | None = None,
        job_type: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.list_automation_jobs(
            import_id=safe_import_id,
            status=status,
            job_type=job_type,
            limit=limit,
            offset=offset,
        )

    def get_automation_job(self, job_id: int) -> dict[str, Any] | None:
        return self.database.get_automation_job(job_id)

    def list_automation_job_logs(
        self,
        job_id: int,
        *,
        limit: int = 200,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        return self.database.list_automation_job_logs(
            job_id,
            limit=limit,
            offset=offset,
        )

    def _can_generate_training_draft(self, session: dict[str, Any]) -> bool:
        if not (session.get("participants") or []):
            return False
        start_date = str(session.get("start_date") or "").strip()
        if not start_date:
            return True
        try:
            return datetime.fromisoformat(start_date).date() >= date.today()
        except ValueError:
            return True

    def _select_sessions_for_draft_window(
        self,
        *,
        import_id: str | None,
        upcoming_days: int | None,
        limit: int,
    ) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        if upcoming_days is None:
            return self._load_sessions(import_id=import_id, limit=limit), {
                "mode": "all",
                "date_from": None,
                "date_to": None,
                "target_date": None,
            }

        today = date.today()
        target = today + timedelta(days=upcoming_days)
        exact_sessions = self._load_sessions(
            import_id=import_id,
            date_from=target.isoformat(),
            date_to=target.isoformat(),
            limit=limit,
        )
        exact_sessions = [
            session
            for session in exact_sessions
            if self._session_starts_between(session, target, target)
        ]
        if exact_sessions:
            return exact_sessions, {
                "mode": "exact_target_day",
                "date_from": target.isoformat(),
                "date_to": target.isoformat(),
                "target_date": target.isoformat(),
            }

        fallback_end = target + timedelta(days=upcoming_days)
        fallback_sessions = self._load_sessions(
            import_id=import_id,
            date_from=target.isoformat(),
            date_to=fallback_end.isoformat(),
            limit=limit,
        )
        fallback_sessions = [
            session
            for session in fallback_sessions
            if self._session_starts_between(session, target, fallback_end)
        ]
        return fallback_sessions, {
            "mode": "fallback_range",
            "date_from": target.isoformat(),
            "date_to": fallback_end.isoformat(),
            "target_date": target.isoformat(),
        }

    def _load_sessions(
        self,
        *,
        import_id: str | None,
        limit: int,
        date_from: str | None = None,
        date_to: str | None = None,
    ) -> list[dict[str, Any]]:
        session_page = self.database.list_sessions(
            import_id=import_id,
            date_from=date_from,
            date_to=date_to,
            limit=limit,
            offset=0,
        )
        return [
            full_session
            for summary in session_page["sessions"]
            if (
                full_session := self.database.get_session(
                    summary["session_key"],
                    import_id=import_id,
                )
            )
            is not None
        ]

    def _session_starts_between(
        self,
        session: dict[str, Any],
        start: date,
        end: date,
    ) -> bool:
        session_start = self._parse_session_date(str(session.get("start_date") or ""))
        if session_start is None:
            return False
        return start <= session_start <= end

    def _parse_session_date(self, value: str) -> date | None:
        try:
            return datetime.fromisoformat(value).date()
        except ValueError:
            return None

    def list_training_drafts(
        self,
        *,
        import_id: str | None = None,
        session_key: str | None = None,
        status: str | None = None,
        email_type: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        statuses = (
            [
                item.strip().upper()
                for item in status.split(",")
                if item.strip()
            ]
            if status
            else None
        )
        safe_email_type = email_type.strip().lower() if email_type else None
        return self.database.list_training_drafts(
            import_id=safe_import_id,
            session_key=session_key,
            status=statuses,
            email_type=safe_email_type,
            limit=limit,
            offset=offset,
        )

    def get_training_draft_review(
        self,
        *,
        import_id: str | None = None,
        session_key: str | None = None,
        status: str | None = None,
        email_type: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> dict[str, Any]:
        drafts = self.list_training_drafts(
            import_id=import_id,
            session_key=session_key,
            status=status,
            email_type=email_type,
            limit=limit,
            offset=offset,
        )
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        safe_email_type = email_type.strip().lower() if email_type else None
        counts = self.database.count_training_drafts_by_status(
            import_id=safe_import_id,
            session_key=session_key,
            email_type=safe_email_type,
        )
        return {
            "status": "ok",
            "count": len(drafts),
            "drafts": drafts,
            "summary": {
                "total": counts.get("TOTAL", 0),
                "needs_action": counts.get("NEEDS_ACTION", 0),
                "waiting_review": counts.get("WAITING_REVIEW", 0),
                "edited": counts.get("EDITED", 0),
                "needs_contacts": counts.get("NEEDS_CONTACTS", 0),
                "approved": counts.get("APPROVED", 0),
                "rejected": counts.get("REJECTED", 0),
                "sent": counts.get("SENT", 0),
            },
            "filters": {
                "import_id": safe_import_id or "",
                "session_key": session_key or "",
                "draft_status": status or "",
                "email_type": safe_email_type or "",
                "limit": limit,
                "offset": offset,
            },
        }

    def list_training_send_logs(
        self,
        *,
        import_id: str | None = None,
        draft_id: int | None = None,
        status: str | None = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list[dict[str, Any]]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        return self.database.list_training_send_logs(
            import_id=safe_import_id,
            draft_id=draft_id,
            status=status,
            limit=limit,
            offset=offset,
        )

    def get_training_draft(self, draft_id: int) -> dict[str, Any] | None:
        return self.database.get_training_draft(draft_id)

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
        return self.database.update_training_draft(
            draft_id,
            subject=subject,
            body=body,
            html_body=html_body,
            recipients=recipients,
            cc=cc,
        )

    def regenerate_training_draft(
        self,
        draft_id: int,
        *,
        email_type: str = "auto",
        include_population: bool = True,
    ) -> dict[str, Any] | None:
        current = self.database.get_training_draft(draft_id)
        if current is None:
            return None
        if current["status"] == "SENT":
            raise ValueError("Sent drafts cannot be regenerated.")

        safe_import_id = sanitize_import_id(current["import_id"])
        if not safe_import_id:
            raise ValueError("This draft is not linked to a planning import.")

        self.database.apply_contact_mapping(import_id=safe_import_id)
        session = self.database.get_session(
            current["session_key"],
            import_id=safe_import_id,
        )
        if session is None:
            raise ValueError("The original training session was not found.")

        session = self.training_agent.group_for_existing_draft(
            session,
            current.get("metadata", {}),
        )
        draft = self.training_agent.generate_draft(
            session,
            email_type=email_type,
            include_population=include_population,
        )
        return self.database.regenerate_training_draft(draft_id, draft)

    def approve_training_draft(self, draft_id: int) -> dict[str, Any] | None:
        return self.database.approve_training_draft(draft_id)

    def reject_training_draft(
        self,
        draft_id: int,
        *,
        reason: str = "",
    ) -> dict[str, Any] | None:
        return self.database.reject_training_draft(draft_id, reason=reason)

    def bulk_review_training_drafts(
        self,
        *,
        draft_ids: list[int],
        action: str,
        reason: str = "",
        email_type: str = "auto",
        include_population: bool = True,
    ) -> dict[str, Any]:
        normalized_action = action.strip().lower()
        if normalized_action not in {"approve", "reject", "regenerate"}:
            raise ValueError("Bulk action must be approve, reject or regenerate.")

        results: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []
        for draft_id in _unique_positive_ids(draft_ids):
            try:
                if normalized_action == "approve":
                    draft = self.approve_training_draft(draft_id)
                elif normalized_action == "reject":
                    draft = self.reject_training_draft(draft_id, reason=reason)
                else:
                    draft = self.regenerate_training_draft(
                        draft_id,
                        email_type=email_type,
                        include_population=include_population,
                    )
            except ValueError as exc:
                errors.append({"draft_id": draft_id, "error": str(exc)})
                continue

            if draft is None:
                errors.append(
                    {
                        "draft_id": draft_id,
                        "error": f"Training draft {draft_id} not found.",
                    }
                )
            else:
                results.append(draft)

        return _bulk_result(normalized_action, draft_ids, results, errors)

    def bulk_send_training_drafts(
        self,
        *,
        draft_ids: list[int],
        outlook_sender: Any,
        access_token: str,
        confirmed: bool = False,
        confirmed_draft_count: int | None = None,
        confirmed_total_recipient_count: int | None = None,
    ) -> dict[str, Any]:
        unique_ids = _unique_positive_ids(draft_ids)
        if not unique_ids:
            raise ValueError("At least one valid training draft id is required.")
        if not confirmed:
            raise ValueError("Bulk send confirmation is required before sending drafts.")
        if confirmed_draft_count != len(unique_ids):
            raise ValueError("Draft confirmation count does not match the selected drafts.")

        preflight_drafts: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []
        for draft_id in unique_ids:
            draft = self.get_training_draft(draft_id)
            if draft is None:
                errors.append(
                    {
                        "draft_id": draft_id,
                        "error": f"Training draft {draft_id} not found.",
                    }
                )
                continue
            if draft["status"] != "APPROVED":
                errors.append(
                    {
                        "draft_id": draft_id,
                        "error": "Only approved training drafts can be sent.",
                    }
                )
                continue
            if not draft["recipients"]:
                errors.append(
                    {
                        "draft_id": draft_id,
                        "error": "A training draft needs at least one recipient before sending.",
                    }
                )
                continue
            preflight_drafts.append(draft)

        if errors:
            return _bulk_result("send", draft_ids, [], errors)

        total_recipients = sum(len(draft["recipients"]) for draft in preflight_drafts)
        if confirmed_total_recipient_count != total_recipients:
            raise ValueError("Recipient confirmation count does not match the approved drafts.")

        results = []
        for draft in preflight_drafts:
            try:
                sent = self.send_training_draft(
                    int(draft["id"]),
                    outlook_sender=outlook_sender,
                    access_token=access_token,
                    confirmed=True,
                    confirmed_recipient_count=len(draft["recipients"]),
                    confirmed_subject=draft["subject"],
                )
            except Exception as exc:
                errors.append({"draft_id": int(draft["id"]), "error": str(exc)})
                continue
            if sent is not None:
                results.append(sent)

        return _bulk_result("send", draft_ids, results, errors)

    def send_training_draft(
        self,
        draft_id: int,
        *,
        outlook_sender: Any,
        access_token: str,
        confirmed: bool = False,
        confirmed_recipient_count: int | None = None,
        confirmed_subject: str = "",
    ) -> dict[str, Any] | None:
        draft = self.database.get_training_draft(draft_id)
        if draft is None:
            return None
        if draft["status"] != "APPROVED":
            raise ValueError("Only approved training drafts can be sent.")
        if not draft["recipients"]:
            raise ValueError("A training draft needs at least one recipient before sending.")
        if not confirmed:
            raise ValueError("Send confirmation is required before sending this draft.")
        if confirmed_recipient_count != len(draft["recipients"]):
            raise ValueError("Recipient confirmation does not match the approved draft.")
        if confirmed_subject.strip() != draft["subject"].strip():
            raise ValueError("Subject confirmation does not match the approved draft.")

        try:
            sent = outlook_sender.send_mail(
                access_token=access_token,
                subject=draft["subject"],
                body=draft["body"],
                html_body=draft["html_body"],
                recipients=draft["recipients"],
                cc=draft["cc"],
            )
        except Exception as exc:
            for recipient in draft["recipients"]:
                self.database.log_training_send(
                    draft_id,
                    recipient_email=recipient,
                    status="error",
                    error=str(exc),
                )
            raise

        provider_message_id = str(sent.get("message_id") or "").strip()
        return self.database.mark_training_draft_sent(
            draft_id,
            provider_message_id=provider_message_id,
        )


def _unique_positive_ids(values: list[int]) -> list[int]:
    ids: list[int] = []
    seen: set[int] = set()
    for value in values:
        try:
            draft_id = int(value)
        except (TypeError, ValueError):
            continue
        if draft_id <= 0 or draft_id in seen:
            continue
        ids.append(draft_id)
        seen.add(draft_id)
    return ids


def _bulk_result(
    action: str,
    requested_ids: list[int],
    drafts: list[dict[str, Any]],
    errors: list[dict[str, Any]],
) -> dict[str, Any]:
    succeeded = len(drafts)
    failed = len(errors)
    if succeeded and failed:
        status = "partial"
    elif failed:
        status = "error"
    else:
        status = "ok"
    return {
        "status": status,
        "action": action,
        "requested": len(_unique_positive_ids(requested_ids)),
        "succeeded": succeeded,
        "failed": failed,
        "drafts": drafts,
        "errors": errors,
    }
