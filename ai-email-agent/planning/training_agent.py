from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date, datetime
from typing import Any


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
    recipients: list[str]
    cc: list[str] = field(default_factory=list)
    status: str = "WAITING_REVIEW"
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class FrenchTrainingAgent:
    """French-first agent for Tunisie Telecom training communication drafts."""

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
        subject = self._subject(session, normalized_type)
        body = self._body(
            session,
            normalized_type,
            include_population=include_population,
        )
        status = "WAITING_REVIEW" if recipients else "NEEDS_CONTACTS"

        return TrainingDraft(
            session_key=str(session.get("session_key") or ""),
            import_id=str(session.get("import_id") or ""),
            email_type=normalized_type,
            subject=subject,
            body=body,
            recipients=recipients,
            status=status,
            metadata={
                "language": "fr",
                "generated_by": "french_training_agent",
                "participant_count": len(participants),
                "missing_recipient_count": missing_recipient_count,
                "requires_user_review": True,
                "template_locked": True,
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

    def _subject(self, session: dict[str, Any], email_type: str) -> str:
        module = self._module(session)
        subjects = {
            "sensibilisation": f"Sensibilisation à participer à la formation : {module}",
            "confirmation_presence": f"Confirmation de présence formation {module}",
            "rappel": f"Rappel formation : {module}",
            "report": f"Report de la formation : {module}",
            "annulation": f"Annulation de la formation : {module}",
        }
        return subjects[email_type]

    def _body(
        self,
        session: dict[str, Any],
        email_type: str,
        *,
        include_population: bool,
    ) -> str:
        if email_type == "sensibilisation":
            return self._sensibilisation_body(session, include_population=include_population)
        if email_type == "confirmation_presence":
            return self._confirmation_body(session, include_population=include_population)
        if email_type == "rappel":
            return self._rappel_body(session, include_population=include_population)
        if email_type == "report":
            return self._report_body(session, include_population=include_population)
        if email_type == "annulation":
            return self._annulation_body(session, include_population=include_population)
        raise ValueError(f"Unsupported training email type: {email_type}")

    def _sensibilisation_body(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> str:
        lines = [
            "Bonjour,",
            "",
            "Dans le cadre du développement des compétences de nos collaborateurs, "
            f"nous organisons une formation sur « {self._module(session)} ».",
            "",
            self._details_block(session),
        ]
        if include_population:
            population = self._population_block(session)
            if population:
                lines.extend(["", population])
        lines.extend(
            [
                "",
                "Cette session offrira l'opportunité d'acquérir de nouvelles connaissances "
                "et de renforcer les compétences utiles au quotidien professionnel.",
                "",
                "Nous vous invitons à relayer cette information et à encourager la participation "
                "des collaborateurs concernés.",
                "",
                "Votre mobilisation contribuera au succès de cette action de formation.",
                "",
                "Pour toute information complémentaire, n'hésitez pas à nous contacter.",
                "",
                "Cordialement,",
            ]
        )
        return "\n".join(lines)

    def _confirmation_body(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> str:
        lines = [
            "Bonjour,",
            "",
            "Dans le cadre de la mise en œuvre du plan de formation 2026 et afin de "
            "concrétiser les besoins exprimés par les collaborateurs, nous vous invitons "
            "à confirmer votre présence dans les meilleurs délais.",
            "",
            self._details_block(session),
        ]
        if include_population:
            participants = self._participants_table(session)
            if participants:
                lines.extend(["", participants])
        lines.extend(
            [
                "",
                "Nous attirons également votre attention sur l'importance de signaler toute "
                "absence ou indisponibilité afin de garantir la bonne organisation de la session.",
                "",
                "Merci de nous confirmer votre présence par retour d'email.",
                "",
                "Cordialement,",
            ]
        )
        return "\n".join(lines)

    def _rappel_body(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> str:
        lines = [
            "Bonjour,",
            "",
            f"Nous vous rappelons que la formation « {self._module(session)} » est programmée prochainement.",
            "",
            self._details_block(session),
        ]
        if include_population:
            participants = self._participants_table(session)
            if participants:
                lines.extend(["", participants])
        lines.extend(
            [
                "",
                "Merci de prendre les dispositions nécessaires pour assurer votre présence "
                "et de nous informer rapidement en cas d'empêchement.",
                "",
                "Cordialement,",
            ]
        )
        return "\n".join(lines)

    def _report_body(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> str:
        lines = [
            "Bonjour,",
            "",
            f"Nous vous informons que la formation « {self._module(session)} » est reportée.",
            "",
            self._details_block(session),
        ]
        if include_population:
            participants = self._participants_table(session)
            if participants:
                lines.extend(["", participants])
        lines.extend(
            [
                "",
                "Une nouvelle communication vous sera transmise dès confirmation de la date retenue.",
                "",
                "Cordialement,",
            ]
        )
        return "\n".join(lines)

    def _annulation_body(
        self,
        session: dict[str, Any],
        *,
        include_population: bool,
    ) -> str:
        lines = [
            "Bonjour,",
            "",
            f"Nous vous informons que la formation « {self._module(session)} » est annulée.",
            "",
            self._details_block(session),
        ]
        if include_population:
            participants = self._participants_table(session)
            if participants:
                lines.extend(["", participants])
        lines.extend(
            [
                "",
                "Nous vous remercions pour votre compréhension et vous tiendrons informés "
                "en cas de reprogrammation.",
                "",
                "Cordialement,",
            ]
        )
        return "\n".join(lines)

    def _details_block(self, session: dict[str, Any]) -> str:
        details = [
            f"Thème de la formation : {self._module(session)}",
            f"Durée du cours : {self._date_range(session)}",
            f"Programme du cours : {self._schedule(session)}",
            f"Lieu principal : {self._value(session, 'location', 'À préciser')}",
            f"Cabinet de formation : {self._cabinet(session)}",
            f"Formateur : {self._trainer(session)}",
        ]
        return "\n".join(details)

    def _population_block(self, session: dict[str, Any]) -> str:
        participants = session.get("participants", []) or []
        if not participants:
            return ""
        grouped: dict[str, list[str]] = {}
        for participant in participants:
            group = (
                str(participant.get("residence") or participant.get("direction") or "Population cible")
                .strip()
            )
            name = str(participant.get("full_name") or "").strip()
            matricule = str(participant.get("matricule") or "").strip()
            if not name and not matricule:
                continue
            label = f"{matricule} {name}".strip()
            grouped.setdefault(group, []).append(label)

        if not grouped:
            return ""
        lines = ["Population cible :"]
        for group, names in grouped.items():
            lines.extend(["", group.upper() + " :"])
            lines.extend(names)
        return "\n".join(lines)

    def _participants_table(self, session: dict[str, Any]) -> str:
        participants = session.get("participants", []) or []
        rows = []
        for participant in participants:
            matricule = str(participant.get("matricule") or "").strip()
            name = str(participant.get("full_name") or "").strip()
            if matricule or name:
                rows.append(f"- {matricule} {name}".strip())
        if not rows:
            return ""
        return "Participants concernés :\n" + "\n".join(rows)

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

    def _module(self, session: dict[str, Any]) -> str:
        return self._value(session, "module", "la formation")

    def _cabinet(self, session: dict[str, Any]) -> str:
        return self._value(session, "cabinet", "À préciser")

    def _trainer(self, session: dict[str, Any]) -> str:
        return self._value(
            session,
            "selected_trainer",
            self._value(session, "trainer", "À préciser"),
        )

    def _schedule(self, session: dict[str, Any]) -> str:
        return self._value(session, "schedule", "08:30 - 14:30 Afrique/Tunis")

    def _date_range(self, session: dict[str, Any]) -> str:
        start = self._value(session, "start_date", "")
        end = self._value(session, "end_date", "")
        if start and end and start != end:
            return f"du {self._format_date(start)} au {self._format_date(end)}"
        if start:
            return f"le {self._format_date(start)}"
        return "À préciser"

    def _format_date(self, value: str) -> str:
        parsed = self._parse_date(value)
        if parsed is None:
            return value
        return parsed.strftime("%d/%m/%Y")

    def _value(self, session: dict[str, Any], key: str, fallback: str) -> str:
        value = str(session.get(key) or "").strip()
        return value if value else fallback
