from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date, datetime
from typing import Any

from planning.email_templates import TrainingEmailTemplates


SUPPORTED_EMAIL_TYPES = {
    "auto",
    "sensibilisation",
    "confirmation_presence",
    "rappel",
    "report",
    "annulation",
}


@dataclass(slots=True)
class TrainingDraft:
    session_key: str
    import_id: str
    email_type: str
    subject: str
    body: str
    html_body: str
    recipients: list[str]
    cc: list[str] = field(default_factory=list)
    status: str = "WAITING_REVIEW"
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class FrenchTrainingAgent:
    """French-first agent for Tunisie Telecom training communication drafts."""

    def __init__(self, templates: TrainingEmailTemplates | None = None) -> None:
        self.templates = templates or TrainingEmailTemplates()

    def generate_draft(
        self,
        session: dict[str, Any],
        *,
        email_type: str = "auto",
        include_population: bool = True,
    ) -> TrainingDraft:
        normalized_type = self._resolve_email_type(session, email_type)
        participants = session.get("participants", []) or []
        recipients = self._responsible_emails(session, participants)
        missing_recipient_count = 0 if recipients else 1
        rendered = self.templates.render(
            session,
            email_type=normalized_type,
            include_population=include_population,
        )
        status = "WAITING_REVIEW" if recipients else "NEEDS_CONTACTS"

        return TrainingDraft(
            session_key=str(session.get("session_key") or ""),
            import_id=str(session.get("import_id") or ""),
            email_type=normalized_type,
            subject=rendered.subject,
            body=rendered.body,
            html_body=rendered.html_body,
            recipients=recipients,
            status=status,
            metadata={
                "language": "fr",
                "generated_by": "french_training_agent",
                "participant_count": len(participants),
                "recipient_role": "responsable_rh_direction",
                "responsible_key": self.responsible_key(session),
                "responsible_name": str(session.get("responsible_name") or ""),
                "responsible_residence": str(session.get("responsible_residence") or ""),
                "responsible_direction": str(session.get("responsible_direction") or ""),
                "candidate_matricules": [
                    str(participant.get("matricule") or "")
                    for participant in participants
                    if str(participant.get("matricule") or "").strip()
                ],
                "candidate_email_flow_disabled": True,
                "missing_recipient_count": missing_recipient_count,
                "requires_user_review": True,
                "template_locked": True,
                "has_html_body": True,
            },
        )

    def _resolve_email_type(self, session: dict[str, Any], email_type: str) -> str:
        requested = email_type.strip().lower()
        if requested not in SUPPORTED_EMAIL_TYPES:
            raise ValueError(
                "Unsupported training email type. Use auto, sensibilisation, "
                "confirmation_presence, rappel, report, or annulation."
            )
        if requested != "auto":
            return requested

        status = str(session.get("status") or "").upper()
        if status == "CANCELLED":
            return "annulation"
        if status == "POSTPONED":
            return "report"
        if self._starts_soon(session):
            return "rappel"
        return "confirmation_presence"

    def responsible_groups(self, session: dict[str, Any]) -> list[dict[str, Any]]:
        participants = session.get("participants", []) or []
        if not participants:
            return [self._session_for_group(session, [], {}, 0)]

        grouped: dict[str, dict[str, Any]] = {}
        order: list[str] = []
        for participant in participants:
            profile = self._responsible_profile(participant)
            group_key = self._responsible_key_from_profile(profile)
            if group_key not in grouped:
                grouped[group_key] = {
                    "profile": profile,
                    "participants": [],
                    "index": len(order),
                }
                order.append(group_key)
            grouped[group_key]["participants"].append(participant)

        return [
            self._session_for_group(
                session,
                grouped[group_key]["participants"],
                grouped[group_key]["profile"],
                grouped[group_key]["index"],
            )
            for group_key in order
        ]

    def group_for_existing_draft(
        self,
        session: dict[str, Any],
        metadata: dict[str, Any],
    ) -> dict[str, Any]:
        expected_key = str(metadata.get("responsible_key") or "")
        if not expected_key:
            return session
        for group in self.responsible_groups(session):
            if self.responsible_key(group) == expected_key:
                return group
        return session

    def responsible_key(self, session: dict[str, Any]) -> str:
        explicit = str(session.get("responsible_key") or "").strip()
        if explicit:
            return explicit
        profile = {
            "name": str(session.get("responsible_name") or ""),
            "email": str(session.get("responsible_email") or ""),
            "residence": str(session.get("responsible_residence") or ""),
            "direction": str(session.get("responsible_direction") or ""),
        }
        return self._responsible_key_from_profile(profile)

    def _responsible_emails(
        self,
        session: dict[str, Any],
        participants: list[dict[str, Any]],
    ) -> list[str]:
        values = [str(session.get("responsible_email") or "")]
        values.extend(str(participant.get("responsible_email") or "") for participant in participants)
        seen = set()
        emails = []
        for value in values:
            email = value.strip().lower()
            if "@" not in email or email in seen:
                continue
            seen.add(email)
            emails.append(email)
        return emails

    def _responsible_profile(self, participant: dict[str, Any]) -> dict[str, str]:
        return {
            "name": str(participant.get("hr_responsible") or "").strip(),
            "email": str(participant.get("responsible_email") or "").strip().lower(),
            "residence": str(participant.get("residence") or "").strip(),
            "direction": str(participant.get("direction") or "").strip(),
        }

    def _session_for_group(
        self,
        session: dict[str, Any],
        participants: list[dict[str, Any]],
        profile: dict[str, str],
        index: int,
    ) -> dict[str, Any]:
        group_session = {
            **session,
            "participants": participants,
            "responsible_name": profile.get("name", ""),
            "responsible_email": profile.get("email", ""),
            "responsible_residence": profile.get("residence", ""),
            "responsible_direction": profile.get("direction", ""),
        }
        group_session["responsible_key"] = self._responsible_key_from_profile(profile) or (
            f"{session.get('session_key', '')}:group:{index}"
        )
        return group_session

    def _responsible_key_from_profile(self, profile: dict[str, str]) -> str:
        raw = "|".join(
            str(profile.get(field) or "").strip().lower()
            for field in ("email", "name", "residence", "direction")
            if str(profile.get(field) or "").strip()
        )
        return raw or "unassigned"

    def _starts_soon(self, session: dict[str, Any]) -> bool:
        start = self._parse_date(str(session.get("start_date") or ""))
        if start is None:
            return False
        delta = (start - date.today()).days
        return 0 <= delta <= 3

    def _parse_date(self, value: str) -> date | None:
        try:
            return datetime.fromisoformat(value).date()
        except ValueError:
            return None
