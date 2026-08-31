from __future__ import annotations

import uuid
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
    ) -> dict[str, Any]:
        safe_import_id = sanitize_import_id(import_id) if import_id else None
        if session_key:
            session = self.database.get_session(session_key, import_id=safe_import_id)
            sessions = [session] if session is not None else []
        else:
            summaries = self.database.list_sessions(
                import_id=safe_import_id,
                limit=limit,
                offset=0,
            )
            sessions = [
                full_session
                for summary in summaries
                if (
                    full_session := self.database.get_session(
                        summary["session_key"],
                        import_id=safe_import_id,
                    )
                )
                is not None
            ]

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
                for group_session in self.training_agent.responsible_groups(session):
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
    ) -> dict[str, Any]:
        automation_settings = self.database.get_automation_settings()
        resolved_email_type = email_type or automation_settings["default_email_type"]
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
        if not safe_import_id:
            return {
                "status": "empty",
                "import_id": "",
                "mapped": 0,
                "unmatched": 0,
                "generated": 0,
                "skipped_existing": 0,
                "errors": [],
                "drafts": [],
            }

        mapping = self.database.apply_contact_mapping(import_id=safe_import_id)
        generated = self.generate_training_drafts(
            import_id=safe_import_id,
            email_type=resolved_email_type,
            include_population=resolved_include_population,
            limit=resolved_limit,
            skip_existing=True,
        )
        status = "ok"
        if generated["errors"]:
            status = "partial"
        return {
            "status": status,
            "import_id": safe_import_id,
            "mapped": mapping["mapped"],
            "unmatched": mapping["unmatched"],
            "generated": generated["generated"],
            "skipped_existing": generated["skipped_existing"],
            "errors": generated["errors"],
            "settings": {
                **automation_settings,
                "default_email_type": resolved_email_type,
                "include_population": resolved_include_population,
                "max_drafts_per_run": resolved_limit,
            },
            "drafts": generated["drafts"],
        }

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
