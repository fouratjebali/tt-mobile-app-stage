from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import date, datetime
import re
import unicodedata
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
        responsible_profiles = session.get("responsibles", []) or []
        recipients: list[str] = []
        missing_responsible_count = 0 if responsible_profiles else 1
        rendered = self.templates.render(
            session,
            email_type=normalized_type,
            include_population=include_population,
        )
        status = "WAITING_REVIEW" if responsible_profiles else "NEEDS_CONTACTS"
        responsible_names = [
            str(profile.get("nom_complet") or profile.get("name") or "").strip()
            for profile in responsible_profiles
            if str(profile.get("nom_complet") or profile.get("name") or "").strip()
        ]
        responsible_functions = [
            str(profile.get("fonction") or profile.get("role") or "").strip()
            for profile in responsible_profiles
            if str(profile.get("fonction") or profile.get("role") or "").strip()
        ]

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
                "responsible_name": ", ".join(responsible_names),
                "responsible_names": responsible_names,
                "responsible_functions": responsible_functions,
                "responsibles": responsible_profiles,
                "responsible_count": len(responsible_profiles),
                "responsible_residence": str(session.get("responsible_residence") or ""),
                "responsible_direction": str(session.get("responsible_direction") or ""),
                "candidate_matricules": [
                    str(participant.get("matricule") or "")
                    for participant in participants
                    if str(participant.get("matricule") or "").strip()
                ],
                "candidate_email_flow_disabled": True,
                "manual_outlook_send": True,
                "missing_recipient_count": 0,
                "missing_responsible_count": missing_responsible_count,
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

    def responsible_groups(
        self,
        session: dict[str, Any],
        *,
        responsables: list[dict[str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        participants = session.get("participants", []) or []
        responsable_lookup = self._responsable_lookup(responsables or [])
        if not participants:
            return [self._session_for_group(session, [], {}, 0, responsable_lookup)]

        grouped: dict[str, dict[str, Any]] = {}
        order: list[str] = []
        for participant in participants:
            profile = self._responsible_profile(participant, responsable_lookup)
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
                responsable_lookup,
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
                return {
                    **group,
                    "responsible_name": str(metadata.get("responsible_name") or group.get("responsible_name") or ""),
                    "responsibles": metadata.get("responsibles") or group.get("responsibles") or [],
                }
        return session

    def responsible_key(self, session: dict[str, Any]) -> str:
        explicit = str(session.get("responsible_key") or "").strip()
        if explicit:
            return explicit
        profile = {
            "name": str(session.get("responsible_name") or ""),
            "residence": str(session.get("responsible_residence") or ""),
            "direction": str(session.get("responsible_direction") or ""),
        }
        return self._responsible_key_from_profile(profile)

    def _responsible_profile(
        self,
        participant: dict[str, Any],
        responsable_lookup: dict[str, list[dict[str, str]]],
    ) -> dict[str, Any]:
        residence = str(participant.get("residence") or participant.get("direction") or "").strip()
        direction = str(participant.get("direction") or residence).strip()
        responsibles = responsable_lookup.get(_normalize_key(residence), [])
        fallback_name = str(participant.get("hr_responsible") or "").strip()
        if not responsibles and fallback_name:
            responsibles = [
                {
                    "nom_complet": fallback_name,
                    "fonction": "Responsable RH",
                    "grande_residence": residence,
                }
            ]
        return {
            "name": ", ".join(
                responsible["nom_complet"]
                for responsible in responsibles
                if responsible.get("nom_complet")
            ),
            "residence": residence,
            "direction": direction,
            "responsibles": responsibles,
        }

    def _session_for_group(
        self,
        session: dict[str, Any],
        participants: list[dict[str, Any]],
        profile: dict[str, Any],
        index: int,
        responsable_lookup: dict[str, list[dict[str, str]]],
    ) -> dict[str, Any]:
        residence = str(profile.get("residence") or "").strip()
        responsibles = list(profile.get("responsibles") or [])
        if not responsibles and residence:
            responsibles = responsable_lookup.get(_normalize_key(residence), [])
        group_session = {
            **session,
            "participants": participants,
            "responsible_name": profile.get("name", ""),
            "responsible_email": "",
            "responsible_residence": residence,
            "responsible_direction": profile.get("direction", ""),
            "responsibles": responsibles,
        }
        group_session["responsible_key"] = self._responsible_key_from_profile(profile) or (
            f"{session.get('session_key', '')}:group:{index}"
        )
        return group_session

    def _responsible_key_from_profile(self, profile: dict[str, Any]) -> str:
        residence = _normalize_key(str(profile.get("residence") or ""))
        if residence:
            return f"residence:{residence}"
        raw = "|".join(
            str(profile.get(field) or "").strip().lower()
            for field in ("name", "direction")
            if str(profile.get(field) or "").strip()
        )
        return raw or "unassigned"

    def _responsable_lookup(
        self,
        responsables: list[dict[str, Any]],
    ) -> dict[str, list[dict[str, str]]]:
        lookup: dict[str, list[dict[str, str]]] = {}
        seen: set[tuple[str, str, str]] = set()
        for item in responsables:
            residence = str(
                item.get("grande_residence")
                or item.get("residence")
                or item.get("direction")
                or ""
            ).strip()
            name = str(item.get("nom_complet") or item.get("full_name") or "").strip()
            fonction = str(item.get("fonction") or item.get("role") or "").strip()
            if not residence or not name:
                continue
            key = _normalize_key(residence)
            dedupe_key = (key, _normalize_key(name), _normalize_key(fonction))
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            lookup.setdefault(key, []).append(
                {
                    "nom_complet": name,
                    "fonction": fonction,
                    "grande_residence": residence,
                }
            )
        return lookup

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


def _normalize_key(value: str) -> str:
    text = "".join(
        char
        for char in unicodedata.normalize("NFKD", value)
        if not unicodedata.combining(char)
    )
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()
