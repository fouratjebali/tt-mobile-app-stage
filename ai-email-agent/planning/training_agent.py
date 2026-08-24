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
        recipients = self._participant_emails(participants)
        missing_recipient_count = sum(1 for participant in participants if not participant.get("email"))
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

    def _participant_emails(self, participants: list[dict[str, Any]]) -> list[str]:
        seen = set()
        emails = []
        for participant in participants:
            email = str(participant.get("email") or "").strip().lower()
            if "@" not in email or email in seen:
                continue
            seen.add(email)
            emails.append(email)
        return emails

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
